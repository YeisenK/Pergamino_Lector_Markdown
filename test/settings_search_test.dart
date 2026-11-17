import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:pergamino/app/theme.dart';
import 'package:pergamino/data/settings.dart';
import 'package:pergamino/features/reader/book_search.dart';

void main() {
  test('ajustes: ida y vuelta JSON y límites', () {
    final s = const ReaderSettings(fontSize: 22, font: ReaderFont.inter, justify: true, palette: ReaderPalette.sepia);
    final back = ReaderSettings.fromJson(s.toJson());
    expect(back.fontSize, 22);
    expect(back.font, ReaderFont.inter);
    expect(back.palette, ReaderPalette.sepia);
    expect(ReaderSettings.fromJson({'fontSize': 999}).fontSize, 36);
    expect(ReaderSettings.fromJson({}).palette, isNull);
  });

  test('búsqueda ignora acentos y mayúsculas', () {
    final blocks = md.Document().parseLines(['Canción de INVIERNO', '', 'otro párrafo']);
    final hits = searchBlocks(blocks, 'cancion');
    expect(hits.single.index, 0);
    expect(searchBlocks(blocks, 'x'), isEmpty);
  });
}
