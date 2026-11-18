import 'package:flutter_test/flutter_test.dart';
import 'package:pergamino/domain/book.dart';
import 'package:pergamino/domain/library_view.dart';

Book b(String id, String title, double p, DateTime added, [DateTime? opened]) =>
    Book(id: id, title: title, path: '/x', addedAt: added, lastOpened: opened, progress: p);

void main() {
  final d = DateTime(2026, 1, 1);
  final books = [
    b('1', 'Árbol', 0, d),
    b('2', 'Zorro', .5, d.add(const Duration(days: 1)), d.add(const Duration(days: 5))),
    b('3', 'bruma', 1, d.add(const Duration(days: 2)), d.add(const Duration(days: 3))),
    b('4', 'Caballo', .2, d.add(const Duration(days: 3))),
  ];

  test('filtros por estado', () {
    List<String> ids(LibraryFilter f) =>
        applyLibraryView(books, filter: f).map((e) => e.id).toList();
    expect(ids(LibraryFilter.sinEmpezar), ['1']);
    expect(ids(LibraryFilter.leyendo), containsAll(['2', '4']));
    expect(ids(LibraryFilter.leyendo), isNot(contains('3')));
    expect(ids(LibraryFilter.terminados), ['3']);
  });

  test('orden por título ignora acentos y mayúsculas', () {
    final r = applyLibraryView(books, sort: LibrarySort.titulo).map((e) => e.title).toList();
    expect(r, ['Árbol', 'bruma', 'Caballo', 'Zorro']);
  });

  test('orden por progreso y por último leído', () {
    expect(applyLibraryView(books, sort: LibrarySort.progreso).first.id, '3');
    expect(applyLibraryView(books).first.id, '2');
  });

  test('búsqueda sin acentos', () {
    expect(applyLibraryView(books, query: 'arbol').map((e) => e.id), ['1']);
  });

  test('minutos restantes', () {
    expect(minutesLeft(2200, 0, 220), 10);
    expect(minutesLeft(2200, 1, 220), 0);
    expect(minutesLeft(2200, .5, 0), 0);
  });
}
