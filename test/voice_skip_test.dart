
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

const doc = '''Texto normal.

| a | b |
|---|---|
| uno | dos |

```
codigo aqui
```

[^1] Nota al pie de prueba.
''';

Future<List<String>> run({bool tables = false, bool code = false, bool footnotes = true}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final eng = Rec();
  final c = ProviderContainer(overrides: [
    prefsProvider.overrideWithValue(prefs),
    engineFactoryProvider.overrideWithValue((_) async => eng),
  ]);
  addTearDown(c.dispose);
  final content = parseBookText(doc);
  await c.read(readAloudProvider.notifier).start(content, style,
      fromBlock: 0, tables: tables, code: code, footnotes: footnotes);
  await Future.delayed(const Duration(milliseconds: 80));
  return eng.spoken;
}

void main() {
  test('por defecto se saltan tablas y código, y se leen las notas al pie', () async {
    final s = await run();
    expect(s.join(' '), contains('Texto normal'));
    expect(s.join(' '), isNot(contains('uno')));
    expect(s.join(' '), isNot(contains('codigo')));
    expect(s.join(' '), contains('Nota al pie'));
  });

  test('con los interruptores activos se leen tablas y código; sin notas al pie no', () async {
    final s = await run(tables: true, code: true, footnotes: false);
    expect(s.join(' '), contains('uno'));
    expect(s.join(' '), contains('codigo'));
    expect(s.join(' '), isNot(contains('Nota al pie')));
  });
}
