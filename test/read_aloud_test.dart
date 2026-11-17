import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pergamino/data/settings.dart';
import 'package:pergamino/features/reader/md_renderer.dart';
import 'package:pergamino/features/reader/reader_content.dart';
import 'package:pergamino/tts/read_aloud.dart';
import 'package:pergamino/tts/sentences.dart';
import 'package:pergamino/tts/tts_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeEngine implements TtsEngine {
  final spoken = <String>[];
  final nexts = <String?>[];
  Completer<void>? _c;
  bool autoFinish = true;
  @override
  Future<void> speak(String text, {String? next}) async {
    spoken.add(text);
    nexts.add(next);
    _c = Completer<void>();
    if (autoFinish) _c!.complete();
    await _c!.future;
  }

  @override
  Future<void> stop() async {
    if (_c != null && !_c!.isCompleted) _c!.complete();
  }

  @override
  Future<void> setRate(double rate) async {}
  @override
  Future<void> dispose() async {}
}

const style = ReaderStyle(
    fontSize: 18, lineHeight: 1.5, text: Colors.black, muted: Colors.grey, accent: Colors.brown, font: _id);
TextStyle _id(TextStyle t) => t;

void main() {
  test('splitSentences: rangos válidos, une cortas y parte largas', () {
    const t = 'Hola. ¿Cómo estás? Muy bien, gracias por preguntar. Sí.';
    final s = splitSentences(t);
    expect(s, isNotEmpty);
    for (final (a, b) in s) {
      expect(t.substring(a, b).trim(), t.substring(a, b));
    }
    expect(t.substring(s.first.$1, s.first.$2), 'Hola. ¿Cómo estás?');
    final long = '${List.filled(60, 'palabra').join(', ')}.';
    final parts = splitSentences(long);
    expect(parts.length, greaterThan(1));
    expect(parts.every((e) => e.$2 - e.$1 <= 240), isTrue);
  });

  Future<(ProviderContainer, FakeEngine)> setup() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final engine = FakeEngine();
    final c = ProviderContainer(overrides: [
      prefsProvider.overrideWithValue(prefs),
      engineFactoryProvider.overrideWithValue((_) async => engine),
    ]);
    addTearDown(c.dispose);
    return (c, engine);
  }

  test('lee todas las frases en orden y avisa la siguiente', () async {
    final (c, engine) = await setup();
    final content = parseBookText('# Título\n\nPrimera frase larga de prueba. Segunda frase larga de prueba.\n\nOtro párrafo completo aquí.');
    await c.read(readAloudProvider.notifier).start(content, style, fromBlock: 0);
    await Future.delayed(const Duration(milliseconds: 100));
    expect(engine.spoken, [
      'Título',
      'Primera frase larga de prueba.',
      'Segunda frase larga de prueba.',
      'Otro párrafo completo aquí.',
    ]);
    expect(engine.nexts.first, 'Primera frase larga de prueba.');
    expect(engine.nexts.last, isNull);
    expect(c.read(readAloudProvider).active, isFalse); // terminó
  });

  test('pausa, siguiente y anterior', () async {
    final (c, engine) = await setup();
    engine.autoFinish = false;
    final content = parseBookText('Uno dos tres cuatro cinco seis. Siete ocho nueve diez once. Doce trece catorce quince.');
    final n = c.read(readAloudProvider.notifier);
    await n.start(content, style, fromBlock: 0);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(engine.spoken.last, startsWith('Uno'));
    await n.next();
    await Future.delayed(const Duration(milliseconds: 50));
    expect(c.read(readAloudProvider).segment!.text, startsWith('Siete'));
    await n.pause();
    expect(c.read(readAloudProvider).playing, isFalse);
    await n.previous();
    expect(c.read(readAloudProvider).segment!.text, startsWith('Uno'));
    expect(c.read(readAloudProvider).playing, isFalse);
    await n.resume();
    await Future.delayed(const Duration(milliseconds: 50));
    expect(engine.spoken.last, startsWith('Uno'));
    await n.stop();
    expect(c.read(readAloudProvider).active, isFalse);
  });
}
