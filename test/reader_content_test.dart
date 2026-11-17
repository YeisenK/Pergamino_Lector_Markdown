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
  marksTests();
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

void marksTests() {
  testWidgets('las marcas parten el texto y blockParts numera fragmentos', (tester) async {
    final c = parseBookText('- uno dos\n- tres cuatro\n');
    const style = ReaderStyle(
        fontSize: 18, lineHeight: 1.5, text: Colors.black, muted: Colors.grey, accent: Colors.brown, font: _id);
    final parts = blockParts(c.blocks.first, style);
    expect(parts, ['uno dos', 'tres cuatro']);
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: buildBlock(
      c.blocks.first,
      style,
      BlockCtx(
        marks: [
          Mark(key: 'a', part: 1, start: 0, end: 4, color: Colors.yellow, onTap: () => tapped = true)
        ],
        onSelect: (_, _, _, _, _) {},
      ),
    ))));
    final spans = <TextSpan>[];
    void walk(InlineSpan s) {
      if (s is TextSpan) {
        spans.add(s);
        s.children?.forEach(walk);
      }
    }
    for (final w in tester.widgetList<SelectableText>(find.byType(SelectableText))) {
      walk(w.textSpan!);
    }
    expect(spans.any((s) => s.text == 'tres' && s.style?.backgroundColor == Colors.yellow), isTrue);
    expect(tapped, isFalse);
  });
}
