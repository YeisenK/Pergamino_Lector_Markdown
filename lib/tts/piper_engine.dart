import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import 'tts_engine.dart';

/// Piper (VITS) con sherpa-onnx. La síntesis corre en un Isolate frase a frase
/// y mientras suena una frase ya se prepara la siguiente.
class PiperEngine implements TtsEngine {
  PiperEngine({required this.model, required this.tokens, required this.dataDir});
  final String model, tokens, dataDir;

  Isolate? _iso;
  SendPort? _send;
  final _pending = <int, Completer<Map>>{};
  int _seq = 0;
  double _rate = 1.0;
  final _cache = <String, Future<String>>{};
  final AudioPlayer _player = AudioPlayer();
  Completer<void>? _playing;
  late final Directory _tmp;

  /// Estadísticas de la última frase (para comparar voces).
  int lastSynthMs = 0;
  int lastAudioMs = 0;

  Future<void> _ensure() async {
    if (_send != null) return;
    _tmp = Directory(p.join((await getTemporaryDirectory()).path, 'tts'))
      ..createSync(recursive: true);
    final rp = ReceivePort();
    _iso = await Isolate.spawn(_worker, [
      rp.sendPort,
      {'model': model, 'tokens': tokens, 'dataDir': dataDir}
    ]);
    final ready = Completer<SendPort>();
    rp.listen((m) {
      if (m is SendPort) {
        ready.complete(m);
      } else if (m is Map) {
        _pending.remove(m['id'])?.complete(m);
      }
    });
    _send = await ready.future;
    _player.onPlayerComplete.listen((_) => _playing?.complete());
  }

  Future<String> _synth(String text) {
    final key = '${_rate.toStringAsFixed(2)}|$text';
    return _cache.putIfAbsent(key, () async {
      await _ensure();
      final id = _seq++;
      final c = Completer<Map>();
      _pending[id] = c;
      final out = p.join(_tmp.path, 's$id.wav');
      _send!.send({'id': id, 'text': text, 'speed': _rate, 'out': out});
      final r = await c.future;
      if (r['error'] != null) throw StateError('${r['error']}');
      lastSynthMs = r['synthMs'] as int;
      lastAudioMs = r['audioMs'] as int;
      return out;
    });
  }

  @override
  Future<void> speak(String text, {String? next}) async {
    final path = await _synth(text);
    if (next != null) {
      // prepara la frase siguiente mientras suena esta
      // ignore: unawaited_futures
      _synth(next).catchError((_) => '');
    }
    final done = Completer<void>();
    _playing = done;
    await _player.play(DeviceFileSource(path));
    await done.future;
    _cache.remove('${_rate.toStringAsFixed(2)}|$text');
    try {
      File(path).deleteSync();
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    if (_playing != null && !_playing!.isCompleted) _playing!.complete();
  }

  @override
  Future<void> setRate(double rate) async {
    if (rate != _rate) _cache.clear();
    _rate = rate;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _player.dispose();
    _iso?.kill(priority: Isolate.immediate);
    _iso = null;
    _send = null;
  }
}

void _worker(List args) {
  final SendPort main = args[0];
  final cfg = Map<String, String>.from(args[1] as Map);
  final rp = ReceivePort();
  main.send(rp.sendPort);
  sherpa.initBindings();
  late final sherpa.OfflineTts tts;
  try {
    tts = sherpa.OfflineTts(sherpa.OfflineTtsConfig(
      model: sherpa.OfflineTtsModelConfig(
        vits: sherpa.OfflineTtsVitsModelConfig(
          model: cfg['model']!,
          tokens: cfg['tokens']!,
          dataDir: cfg['dataDir']!,
        ),
        numThreads: 2,
        debug: false,
        provider: 'cpu',
      ),
    ));
  } catch (e) {
    rp.listen((m) => main.send({'id': (m as Map)['id'], 'error': 'No se pudo cargar la voz: $e'}));
    return;
  }
  rp.listen((m) {
    final msg = m as Map;
    try {
      final sw = Stopwatch()..start();
      final audio = tts.generate(
          text: msg['text'] as String, sid: 0, speed: (msg['speed'] as num).toDouble());
      final synthMs = sw.elapsedMilliseconds;
      if (audio.samples.isEmpty) throw 'síntesis vacía';
      sherpa.writeWave(
          filename: msg['out'] as String,
          samples: audio.samples,
          sampleRate: audio.sampleRate);
      main.send({
        'id': msg['id'],
        'synthMs': synthMs,
        'audioMs': (audio.samples.length * 1000 / audio.sampleRate).round(),
      });
    } catch (e) {
      main.send({'id': msg['id'], 'error': '$e'});
    }
  });
}
