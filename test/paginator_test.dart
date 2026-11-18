import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pergamino/features/reader/md_renderer.dart';
import 'package:pergamino/features/reader/pagination.dart';
import 'package:pergamino/features/reader/reader_content.dart';

const style = ReaderStyle(
    fontSize: 18, lineHeight: 1.5, text: Colors.black, muted: Colors.grey, accent: Colors.brown, font: _id);
TextStyle _id(TextStyle t) => t;

String longBook() {
  final b = StringBuffer('# Libro grande\n\n');
  for (var c = 1; c <= 3; c++) {
    b.write('## Capítulo $c\n\n');
    for (var p = 0; p < 25; p++) {
      b.write('Párrafo $p del capítulo $c con bastantes palabras para que el texto ocupe varias líneas en la página y haya que partirlo. ' * 3);
      b.write('\n\n');
    }
    b.write('- elemento uno\n- elemento dos\n\n');
  }
  return b.toString();
}

void main() {
  final content = parseBookText(longBook());

  Paginator make({double w = 340, double h = 520}) =>
      Paginator(content: content, style: style, width: w, height: h)..advance(maxPages: 100000);

  test('reparte el libro en varias páginas y no pierde texto', () {
    final p = make();
    expect(p.pages.length, greaterThan(10));
    expect(p.done, isTrue);
    // cada párrafo aparece completo: contamos palabras de los trozos y del libro
    var fromPages = 0;
    for (final page in p.pages) {
      for (final it in page.items) {
        if (it.whole) {
          fromPages += content.blocks[it.block].textContent.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        } else {
          final info = textBlockInfo(content.blocks[it.block], style)!;
          final text = sliceSpans(info.spans, it.start, it.end).map((s) => (s as TextSpan).text ?? '').join();
          fromPages += text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        }
      }
    }
    final total = content.blocks.fold<int>(
        0, (n, b) => n + b.textContent.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length);
    expect(fromPages, total);
  });

  test('el cálculo es determinista: mismo libro y tamaño, mismas páginas', () {
    final a = make();
    final b = make();
    expect(a.pages.length, b.pages.length);
    for (var i = 0; i < a.pages.length; i++) {
      expect(a.pages[i].firstBlock, b.pages[i].firstBlock);
      expect(a.pages[i].items.length, b.pages[i].items.length);
    }
  });

  test('una página más estrecha da más páginas', () {
    expect(make(w: 200).pages.length, greaterThan(make(w: 500).pages.length));
  });

  test('pageOfBlock devuelve la página que contiene el bloque', () {
    final p = Paginator(content: content, style: style, width: 340, height: 520);
    final target = content.chapterStarts[2]; // empieza el capítulo 3
    final idx = p.pageOfBlock(target);
    expect(p.pages[idx].firstBlock <= target, isTrue);
    if (idx + 1 < p.pages.length) {
      expect(p.pages[idx + 1].firstBlock > target, isTrue);
    }
  });

  test('ninguna página sale vacía y el contenido no se repite', () {
    final p = make();
    final seen = <String>{};
    for (final page in p.pages) {
      expect(page.items, isNotEmpty);
      for (final it in page.items) {
        if (!it.whole) {
          final key = '${it.block}:${it.start}';
          expect(seen.add(key), isTrue, reason: 'trozo repetido $key');
        }
      }
    }
  });
}
