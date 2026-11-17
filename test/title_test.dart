import 'package:flutter_test/flutter_test.dart';
import 'package:pergamino/data/book_repository.dart';
import 'package:pergamino/domain/book.dart';

void main() {
  splitTests();
  test('el título usa el archivo si contiene al encabezado y es más completo', () {
    expect(BooksNotifier.titleFor('# El círculo\n\ntexto', 'Capítulo 1 — El círculo'),
        'Capítulo 1 — El círculo');
  });
  test('si el encabezado ya es completo se usa el encabezado', () {
    expect(BooksNotifier.titleFor('# Capítulo 1 — El círculo\n', 'cap1'), 'Capítulo 1 — El círculo');
  });
  test('sin encabezado se usa el nombre del archivo', () {
    expect(BooksNotifier.titleFor('solo texto', 'Mi libro'), 'Mi libro');
  });
  test('un encabezado distinto del nombre manda el encabezado y limpia el formato', () {
    expect(BooksNotifier.titleFor('\n\n# **Meridia** _I_ #\n', 'libro_final'), 'Meridia I');
  });
  test('## no cuenta como título del libro', () {
    expect(BooksNotifier.titleFor('## Capítulo 1\n', 'archivo'), 'archivo');
  });
}

void splitTests() {
  test('splitTitle separa lo anterior al guion largo', () {
    final t = splitTitle('Capítulo 1 — El círculo');
    expect(t.kicker, 'Capítulo 1');
    expect(t.main, 'El círculo');
    expect(splitTitle('Sin guion').kicker, isNull);
    expect(splitTitle('A-B – C').kicker, isNull); // guion corto y medio no cuentan
    expect(splitTitle('— Solo final').main, 'Solo final');
    expect(splitTitle('Uno — Dos — Tres').main, 'Dos — Tres');
  });
}
