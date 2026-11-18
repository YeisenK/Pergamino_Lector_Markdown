import 'book.dart';

enum LibraryFilter {
  todos('Todos'),
  leyendo('Leyendo'),
  sinEmpezar('Sin empezar'),
  terminados('Terminados');

  const LibraryFilter(this.label);
  final String label;
}

enum LibrarySort {
  ultimoLeido('Último leído'),
  titulo('Título'),
  progreso('Progreso'),
  importado('Fecha de importación');

  const LibrarySort(this.label);
  final String label;
}

/// Un libro se considera terminado a partir del 98 % (tolera redondeos).
const finishedAt = .98;

bool isFinished(Book b) => b.progress >= finishedAt;

/// Quita acentos y pasa a minúsculas para comparar títulos y búsquedas.
String foldText(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[áàä]'), 'a')
    .replaceAll(RegExp('[éèë]'), 'e')
    .replaceAll(RegExp('[íìï]'), 'i')
    .replaceAll(RegExp('[óòö]'), 'o')
    .replaceAll(RegExp('[úùü]'), 'u')
    .replaceAll('ñ', 'n');

/// Lista visible de la biblioteca: filtro, orden y búsqueda por título.
List<Book> applyLibraryView(
  List<Book> books, {
  LibraryFilter filter = LibraryFilter.todos,
  LibrarySort sort = LibrarySort.ultimoLeido,
  String query = '',
}) {
  final q = foldText(query.trim());
  final out = books.where((b) {
    if (q.isNotEmpty && !foldText(b.title).contains(q)) return false;
    return switch (filter) {
      LibraryFilter.todos => true,
      LibraryFilter.leyendo => b.progress > 0 && !isFinished(b),
      LibraryFilter.sinEmpezar => b.progress <= 0,
      LibraryFilter.terminados => isFinished(b),
    };
  }).toList();
  int byDate(Book a, Book b) =>
      (b.lastOpened ?? b.addedAt).compareTo(a.lastOpened ?? a.addedAt);
  switch (sort) {
    case LibrarySort.ultimoLeido:
      out.sort(byDate);
    case LibrarySort.titulo:
      out.sort((a, b) => foldText(a.title).compareTo(foldText(b.title)));
    case LibrarySort.progreso:
      out.sort((a, b) => b.progress.compareTo(a.progress));
    case LibrarySort.importado:
      out.sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }
  return out;
}

/// Minutos restantes con una velocidad en palabras por minuto.
int minutesLeft(int totalWords, double progress, int wpm) {
  final left = totalWords * (1 - progress.clamp(0.0, 1.0));
  if (wpm <= 0) return 0;
  return (left / wpm).ceil();
}
