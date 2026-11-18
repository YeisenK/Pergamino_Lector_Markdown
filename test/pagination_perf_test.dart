import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pergamino/features/reader/md_renderer.dart';
import 'package:pergamino/features/reader/pagination.dart';
import 'package:pergamino/features/reader/reader_content.dart';

const style = ReaderStyle(
    fontSize: 19, lineHeight: 1.6, text: Colors.black, muted: Colors.grey, accent: Colors.brown, font: _id);
TextStyle _id(TextStyle t) => t;

void main() {
  test('tiempo de paginar ~1 MB (referencia; en el teléfono se mide aparte)', () {
    final b = StringBuffer();
    var ch = 0;
    while (b.length < 1000000) {
      ch++;
      b.write('## Capítulo $ch\n\n');
      for (var p = 0; p < 12; p++) {
        b.write('Un párrafo de prueba con algo de texto para medir la paginación del libro completo, sin prisas. ' * 4);
        b.write('\n\n');
      }
    }
    final content = parseBookText(b.toString());
    final sw = Stopwatch()..start();
    final pager = Paginator(content: content, style: style, width: 360, height: 640)
      ..advance(maxPages: 1 << 30);
    sw.stop();
    // ignore: avoid_print
    print('paginado: ${pager.pages.length} páginas en ${sw.elapsedMilliseconds} ms (${content.blocks.length} bloques)');
    expect(pager.pages, isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
