import 'package:flutter_tts/flutter_tts.dart';

import 'tts_engine.dart';

/// Voces del sistema Android (Google / Samsung), instantáneas y sin descargas.
class SystemEngine implements TtsEngine {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  String? _voiceKey;

  Future<void> _init() async {
    if (_ready) return;
    await _tts.awaitSpeakCompletion(true);
    await _tts.setVolume(1.0);
    _ready = true;
  }

  static Future<List<TtsVoice>> listVoices() async {
    final tts = FlutterTts();
    final raw = await tts.getVoices as List<dynamic>? ?? [];
    final out = <TtsVoice>[];
    for (final v in raw) {
      final m = Map<String, dynamic>.from(v as Map);
      final name = '${m['name']}';
      final locale = '${m['locale']}';
      if (!locale.toLowerCase().startsWith('es')) continue;
      final offline = m['network_required'] != '1';
      out.add(TtsVoice('sys:$name|$locale', name,
          '$locale${offline ? '' : ' · requiere internet'}'));
    }
    out.sort((a, b) => a.detail.compareTo(b.detail));
    return out;
  }

  Future<void> setVoice(String id) async {
    await _init();
    if (_voiceKey == id) return;
    _voiceKey = id;
    final body = id.substring(4);
    final i = body.lastIndexOf('|');
    final name = body.substring(0, i), locale = body.substring(i + 1);
    await _tts.setLanguage(locale);
    await _tts.setVoice({'name': name, 'locale': locale});
  }

  @override
  Future<void> speak(String text, {String? next}) async {
    await _init();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();

  @override
  Future<void> setRate(double rate) async {
    await _init();
    // en Android 0.5 es la velocidad normal
    await _tts.setSpeechRate((rate * 0.5).clamp(0.1, 1.0));
  }

  @override
  Future<void> dispose() => _tts.stop();
}
