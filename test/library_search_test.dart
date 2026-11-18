import 'package:flutter_test/flutter_test.dart';
import 'package:pergamino/domain/book.dart';
import 'package:pergamino/domain/library_search.dart';

void main() {
  test('encuentra varias coincidencias en distintos libros, sin acentos', () {
    final hits = searchTexts('bastón', const [
      BookText('a', 'Uno', 'El bastón del rey. Después, otro baston.'),
      BookText('b', 'Dos', 'Nada que ver aquí.'),
    ]);
    expect(hits.length, 2);
    expect(hits.every((h) => h.bookId == 'a'), isTrue);
    expect(hits.first.fraction, lessThan(hits.last.fraction));
    expect(hits.first.snippet, contains('bastón'));
  });

  test('una búsqueda corta o sin resultados no devuelve nada', () {
    expect(searchTexts('x', const [BookText('a', 'U', 'xxx')]), isEmpty);
    expect(searchTexts('zzz', const [BookText('a', 'U', 'abc')]), isEmpty);
  });

  test('colecciones sin repetir y ordenadas', () {
    final b = [
      Book(id: '1', title: 'a', path: '', addedAt: DateTime(2026), collection: 'Meridia'),
      Book(id: '2', title: 'b', path: '', addedAt: DateTime(2026), collection: 'Álbum'),
      Book(id: '3', title: 'c', path: '', addedAt: DateTime(2026), collection: 'Meridia'),
      Book(id: '4', title: 'd', path: '', addedAt: DateTime(2026)),
    ];
    expect(collectionsOf(b), ['Álbum', 'Meridia']);
  });
}
