import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pergamino/features/reader/md_renderer.dart';
import 'package:pergamino/features/reader/reader_content.dart';

const sample = '''# Libro

Un párrafo con *énfasis*, **negrita** y `código`.

## Capítulo 1

> Una cita

- uno
  - anidado
- dos

1. primero
2. segundo

| a | b |
|---|---|
| 1 | 2 |

```
bloque
```

---
''';

void main() {
  test('el AST sobrevive al Isolate y hay capítulos', () async {
    final c = await compute(parseBookText, sample);
    expect(c.chapterTitles, ['Libro', 'Capítulo 1']);
    expect(c.blocks, isNotEmpty);
  });

  testWidgets('todos los bloques se renderizan sin errores', (tester) async {
    final c = parseBookText(sample);
    const style = ReaderStyle(
        fontSize: 18,
        lineHeight: 1.5,
        text: Colors.black,
        muted: Colors.grey,
        accent: Colors.brown,
        font: _id);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: Column(children: [
      for (final b in c.blocks) buildBlock(b, style)
    ])))));
    expect(find.textContaining('énfasis', findRichText: true), findsOneWidget);
  });
}

TextStyle _id(TextStyle t) => t;
