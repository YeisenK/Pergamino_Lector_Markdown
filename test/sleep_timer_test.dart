
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pergamino/data/settings.dart';
import 'package:pergamino/features/reader/md_renderer.dart';
import 'package:pergamino/features/reader/reader_content.dart';
import 'package:pergamino/tts/read_aloud.dart';
import 'package:pergamino/tts/tts_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cada frase tarda [ms] en sonar.
class SlowEngine implements TtsEngine {
  SlowEngine(this.ms);
  final int ms;
  final spoken = <String>[];
  @override
  Future<void> speak(String text, {String? next}) async {
    spoken.add(text);
    await Future.delayed(Duration(milliseconds: ms));
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> setRate(double rate) async {}
  @override
  Future<void> dispose() async {}
}

const style = ReaderStyle(
    fontSize: 18, lineHeight: 1.5, text: Colors.black, muted: Colors.grey, accent: Colors.brown, font: _id);
TextStyle _id(TextStyle t) => t;

const book = '''# Uno

Frase de primer capítulo número uno. Otra frase del primer capítulo.

## Dos

Frase del segundo capítulo número uno. Otra frase del segundo capítulo.
''';

Future<(ProviderContainer, SlowEngine)> setup(int ms) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final eng = SlowEngine(ms);
  final c = ProviderContainer(overrides: [
    prefsProvider.overrideWithValue(prefs),
    engineFactoryProvider.overrideWithValue((_) async => eng),
  ]);
  addTearDown(c.dispose);
  return (c, eng);
}

void main() {
  test('temporizador por tiempo: termina la frase actual y se detiene', () async {
    final (c, eng) = await setup(40);
    final n = c.read(readAloudProvider.notifier);
    await n.start(parseBookText(book), style, fromBlock: 0);
    await Future.delayed(const Duration(milliseconds: 10));
    n.setSleep(after: const Duration(milliseconds: 20));
    expect(c.read(readAloudProvider).sleepMode, SleepMode.after);
    await Future.delayed(const Duration(milliseconds: 400));
    expect(c.read(readAloudProvider).active, isFalse);
    expect(eng.spoken.length, lessThan(5)); // no llegó a leer todo el libro
    expect(eng.spoken.first, 'Uno');
  });

  test('fin de capítulo: no pasa al segundo capítulo', () async {
    final (c, eng) = await setup(5);
    final n = c.read(readAloudProvider.notifier);
    await n.start(parseBookText(book), style, fromBlock: 0);
    n.setSleep(chapterEnd: true);
    expect(c.read(readAloudProvider).sleepMode, SleepMode.chapterEnd);
    await Future.delayed(const Duration(milliseconds: 300));
    expect(eng.spoken.any((s) => s.contains('segundo')), isFalse);
    expect(eng.spoken.any((s) => s.contains('primer')), isTrue);
    expect(c.read(readAloudProvider).active, isFalse);
  });

  test('cancelar el temporizador lo quita del estado', () async {
    final (c, _) = await setup(50);
    final n = c.read(readAloudProvider.notifier);
    await n.start(parseBookText(book), style, fromBlock: 0);
    n.setSleep(after: const Duration(minutes: 30));
    expect(c.read(readAloudProvider).sleepMode, SleepMode.after);
    n.cancelSleep();
    expect(c.read(readAloudProvider).sleepMode, SleepMode.none);
    await n.stop();
  });
}
