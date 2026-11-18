import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pergamino/data/settings.dart';
import 'package:pergamino/features/reader/md_renderer.dart';
import 'package:pergamino/features/reader/reader_content.dart';
import 'package:pergamino/tts/read_aloud.dart';
import 'package:pergamino/tts/tts_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Rec implements TtsEngine {
  final spoken = <String>[];
  @override
  Future<void> speak(String text, {String? next}) async => spoken.add(text);
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

void main() {
  test('leer desde aquí empieza en la frase donde se tocó', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final eng = Rec();
    final c = ProviderContainer(overrides: [
      prefsProvider.overrideWithValue(prefs),
      engineFactoryProvider.overrideWithValue((_) async => eng),
    ]);
    addTearDown(c.dispose);
    final content = parseBookText('Primera frase de prueba aquí. Segunda frase de prueba aquí. Tercera frase de prueba aquí.');
    // el punto tocado cae en la segunda frase
    final offset = content.blocks.first.textContent.indexOf('Segunda');
    await c.read(readAloudProvider.notifier).start(content, style,
        fromBlock: 0, part: 0, offset: offset);
    await Future.delayed(const Duration(milliseconds: 80));
    expect(eng.spoken.first, startsWith('Segunda'));
    expect(eng.spoken.any((s) => s.startsWith('Primera')), isFalse);
    await c.read(readAloudProvider.notifier).stop();
  });
}
