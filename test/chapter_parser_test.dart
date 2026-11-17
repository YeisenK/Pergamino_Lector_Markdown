import 'package:flutter_test/flutter_test.dart';
import 'package:pergamino/features/reader/chapter_parser.dart';

void main() {
  test('divide por # y ## e ignora código', () {
    const md = '# Libro\nintro\n## Cap 1\ntexto\n```\n# no es capitulo\n```\n## Cap 2\nfin\n';
    final c = parseChapters(md);
    expect(c.map((e) => e.title), ['Libro', 'Cap 1', 'Cap 2']);
    expect(c[1].markdown, contains('# no es capitulo'));
  });

  test('texto sin encabezados es un solo capítulo', () {
    expect(parseChapters('hola\nmundo').length, 1);
  });
}
