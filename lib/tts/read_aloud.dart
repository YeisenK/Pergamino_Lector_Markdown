import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;

import '../data/settings.dart';
import '../features/reader/md_renderer.dart';
import '../features/reader/reader_content.dart';
import 'piper_engine.dart';
import 'sentences.dart';
import 'system_engine.dart';
import 'tts_engine.dart';
import 'voice_store.dart';

const _kVoice = 'tts_voice_v1';
const _kRate = 'tts_rate_v1';

class TtsVoiceNotifier extends Notifier<String?> {
  @override
  String? build() => ref.read(prefsProvider).getString(_kVoice);
  void set(String? id) {
    state = id;
    final p = ref.read(prefsProvider);
    id == null ? p.remove(_kVoice) : p.setString(_kVoice, id);
  }
}

final ttsVoiceProvider = NotifierProvider<TtsVoiceNotifier, String?>(TtsVoiceNotifier.new);

class TtsRateNotifier extends Notifier<double> {
  @override
  double build() => ref.read(prefsProvider).getDouble(_kRate) ?? 1.0;
  void set(double r) {
    state = r;
    ref.read(prefsProvider).setDouble(_kRate, r);
  }
}

final ttsRateProvider = NotifierProvider<TtsRateNotifier, double>(TtsRateNotifier.new);

/// Crea el motor para una voz. Se puede reemplazar en las pruebas.
final engineFactoryProvider =
    Provider<Future<TtsEngine> Function(String? voiceId)>((ref) {
  return (voiceId) async {
    if (voiceId != null && voiceId.startsWith('piper:')) {
      final pa = await ref.read(voiceStoreProvider.notifier).paths(voiceId.substring(6));
      return PiperEngine(model: pa.model, tokens: pa.tokens, dataDir: pa.dataDir);
    }
    final e = SystemEngine();
    await e.setVoice(voiceId ?? 'sys:|es-ES');
    return e;
  };
});

class Segment {
  final int block, part, start, end;
  final String text;
  const Segment(this.block, this.part, this.start, this.end, this.text);
}

/// Cuándo se detiene sola la lectura.
enum SleepMode { none, after, chapterEnd }

class ReadState {
  final bool active; // hay lectura en curso o en pausa
  final bool playing;
  final bool loading; // preparando la primera frase
  final Segment? segment;
  final String? error;
  final SleepMode sleepMode;
  final DateTime? sleepUntil; // solo con SleepMode.after
  const ReadState({
    this.active = false,
    this.playing = false,
    this.loading = false,
    this.segment,
    this.error,
    this.sleepMode = SleepMode.none,
    this.sleepUntil,
  });

  /// Tiempo que falta para la parada, o null si no hay temporizador por tiempo.
  Duration? sleepLeft(DateTime now) =>
      sleepUntil == null ? null : sleepUntil!.difference(now).isNegative
          ? Duration.zero
          : sleepUntil!.difference(now);
}

final readAloudProvider = NotifierProvider<ReadAloud, ReadState>(ReadAloud.new);

class ReadAloud extends Notifier<ReadState> {
  BookContent? _c;
  ReaderStyle? _style;
  TtsEngine? _engine;
  String? _engineVoice;
  int _gen = 0;
  final _segCache = <int, List<Segment>>{};
  int _block = 0, _idx = 0;
  bool _tables = false, _code = false, _footnotes = true;

  // temporizador de sueño
  Timer? _sleepTimer;
  Timer? _sleepTick;
  bool _stopAfterSegment = false;
  int? _sleepChapter;

  @override
  ReadState build() {
    ref.onDispose(() {
      _sleepTimer?.cancel();
      _sleepTick?.cancel();
      _engine?.dispose();
    });
    return const ReadState();
  }

  /// Bloques que no se leen según los ajustes «Qué leer en voz alta».
  bool _skipBlock(md.Node n) {
    if (n is! md.Element) return false;
    if (n.tag == 'table') return !_tables;
    if (n.tag == 'pre') return !_code;
    if (n.tag == 'p' && n.textContent.trimLeft().startsWith('[^')) return !_footnotes;
    return false;
  }

  List<Segment> _segs(int b) => _segCache.putIfAbsent(b, () {
        final out = <Segment>[];
        if (_skipBlock(_c!.blocks[b])) return out;
        var parts = blockParts(_c!.blocks[b], _style!);
        // tablas y código no producen fragmentos al pintarse: se leen como texto plano
        if (parts.isEmpty && _c!.blocks[b].textContent.trim().isNotEmpty) {
          parts = [_c!.blocks[b].textContent.replaceAll(RegExp(r'\s+'), ' ')];
        }
        for (var p = 0; p < parts.length; p++) {
          for (final (s, e) in splitSentences(parts[p])) {
            out.add(Segment(b, p, s, e, parts[p].substring(s, e)));
          }
        }
        return out;
      });

  int _chapterOf(int block) {
    var ch = 0;
    for (var i = 0; i < _c!.chapterStarts.length; i++) {
      if (_c!.chapterStarts[i] <= block) ch = i;
    }
    return ch;
  }

  /// Primera posición con texto a partir de [block]; null si no queda nada.
  (int, int)? _firstFrom(int block) {
    for (var b = block; b < _c!.blocks.length; b++) {
      if (_segs(b).isNotEmpty) return (b, 0);
    }
    return null;
  }

  (int, int)? _after(int b, int i) {
    if (i + 1 < _segs(b).length) return (b, i + 1);
    return _firstFrom(b + 1);
  }

  (int, int)? _before(int b, int i) {
    if (i > 0) return (b, i - 1);
    for (var k = b - 1; k >= 0; k--) {
      final s = _segs(k);
      if (s.isNotEmpty) return (k, s.length - 1);
    }
    return null;
  }

  Future<void> _ensureEngine() async {
    final voice = ref.read(ttsVoiceProvider);
    if (_engine != null && _engineVoice == voice) return;
    await _engine?.dispose();
    _engine = await ref.read(engineFactoryProvider)(voice);
    _engineVoice = voice;
    await _engine!.setRate(ref.read(ttsRateProvider));
  }

  /// Empieza a leer desde el bloque [fromBlock].
  Future<void> start(BookContent c, ReaderStyle style,
      {required int fromBlock,
      bool tables = false,
      bool code = false,
      bool footnotes = true}) async {
    _gen++;
    await _engine?.stop();
    _c = c;
    _style = style;
    _tables = tables;
    _code = code;
    _footnotes = footnotes;
    _segCache.clear();
    final pos = _firstFrom(fromBlock);
    if (pos == null) {
      state = const ReadState(error: 'No hay texto para leer aquí.');
      return;
    }
    _block = pos.$1;
    _idx = pos.$2;
    state = ReadState(
        active: true,
        playing: true,
        loading: true,
        segment: _segs(_block)[_idx],
        sleepMode: state.sleepMode,
        sleepUntil: state.sleepUntil);
    _run();
  }

  Future<void> _run() async {
    final gen = ++_gen;
    try {
      await _ensureEngine();
      while (gen == _gen) {
        // temporizador «fin de capítulo»: se para al entrar en otro capítulo
        if (state.sleepMode == SleepMode.chapterEnd &&
            _sleepChapter != null &&
            _chapterOf(_block) != _sleepChapter) {
          _finish();
          return;
        }
        final seg = _segs(_block)[_idx];
        final nx = _after(_block, _idx);
        state = _withSegment(seg, playing: true, loading: false);
        await _engine!.speak(seg.text, next: nx == null ? null : _segs(nx.$1)[nx.$2].text);
        if (gen != _gen) return;
        if (_stopAfterSegment) {
          _finish();
          return;
        }
        if (nx == null) {
          _finish();
          return;
        }
        _block = nx.$1;
        _idx = nx.$2;
      }
    } catch (e) {
      if (gen == _gen) {
        state = ReadState(
            active: true,
            playing: false,
            segment: state.segment,
            error: '$e',
            sleepMode: state.sleepMode,
            sleepUntil: state.sleepUntil);
      }
    }
  }

  ReadState _withSegment(Segment? seg, {required bool playing, required bool loading}) =>
      ReadState(
        active: true,
        playing: playing,
        loading: loading,
        segment: seg,
        sleepMode: state.sleepMode,
        sleepUntil: state.sleepUntil,
      );

  void _finish() {
    _stopAfterSegment = false;
    _cancelSleep();
    state = const ReadState();
  }

  // ---- temporizador de sueño ----

  /// Para la lectura después de [after] (con la frase actual terminada), o al
  /// llegar al final del capítulo actual si [chapterEnd] es verdadero.
  void setSleep({Duration? after, bool chapterEnd = false}) {
    _cancelSleep();
    if (!state.active) return;
    if (chapterEnd) {
      _sleepChapter = _chapterOf(_block);
      state = _sleepState(SleepMode.chapterEnd, null);
      return;
    }
    if (after == null) return;
    final until = DateTime.now().add(after);
    _sleepTimer = Timer(after, _sleepDue);
    _sleepTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.sleepMode == SleepMode.after) {
        state = _sleepState(SleepMode.after, until);
      }
    });
    state = _sleepState(SleepMode.after, until);
  }

  ReadState _sleepState(SleepMode mode, DateTime? until) => ReadState(
        active: state.active,
        playing: state.playing,
        loading: state.loading,
        segment: state.segment,
        error: state.error,
        sleepMode: mode,
        sleepUntil: until,
      );

  void cancelSleep() {
    _cancelSleep();
    if (state.active) state = _sleepState(SleepMode.none, null);
  }

  void _cancelSleep() {
    _sleepTimer?.cancel();
    _sleepTick?.cancel();
    _sleepTimer = null;
    _sleepTick = null;
    _sleepChapter = null;
  }

  void _sleepDue() {
    _sleepTimer = null;
    if (!state.active) return;
    if (state.playing) {
      // deja terminar la frase actual para no cortar una palabra
      _stopAfterSegment = true;
    } else {
      _finish();
    }
  }

  Future<void> pause() async {
    if (!state.active || !state.playing) return;
    _gen++;
    await _engine?.stop();
    state = _withSegment(state.segment, playing: false, loading: false);
  }

  Future<void> resume() async {
    if (!state.active || state.playing) return;
    _stopAfterSegment = false;
    state = _withSegment(state.segment, playing: true, loading: true);
    _run();
  }

  Future<void> toggle() => state.playing ? pause() : resume();

  Future<void> _jump((int, int)? pos) async {
    if (pos == null || !state.active) return;
    final wasPlaying = state.playing;
    _gen++;
    await _engine?.stop();
    _block = pos.$1;
    _idx = pos.$2;
    state = _withSegment(_segs(_block)[_idx], playing: wasPlaying, loading: false);
    if (wasPlaying) _run();
  }

  Future<void> next() => _jump(_after(_block, _idx));
  Future<void> previous() => _jump(_before(_block, _idx));

  Future<void> setRate(double r) async {
    ref.read(ttsRateProvider.notifier).set(r);
    await _engine?.setRate(r);
    if (state.playing) await _jump((_block, _idx)); // reinicia la frase con la nueva velocidad
  }

  Future<void> stop() async {
    _gen++;
    _cancelSleep();
    await _engine?.stop();
    state = const ReadState();
  }

  /// Cambia de voz: se vuelve a crear el motor en la próxima frase.
  Future<void> voiceChanged() async {
    if (state.active && state.playing) await _jump((_block, _idx));
  }
}
