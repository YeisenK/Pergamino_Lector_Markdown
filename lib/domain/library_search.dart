import 'book.dart';
import 'library_view.dart';

/// Una coincidencia en un libro. [fraction] es la posición (0–1) dentro del texto.
class LibraryHit {
  final String bookId;
  final String title;
  final String snippet;
  final double fraction;
  const LibraryHit(this.bookId, this.title, this.snippet, this.fraction);
}

/// Texto de un libro, ya leído, para buscar en él.
class BookText {
  final String id;
  final String title;
  final String text;
  const BookText(this.id, this.title, this.text);
}

/// Busca [query] en todos los textos (sin distinguir mayúsculas ni acentos).
/// Devuelve como mucho [limit] coincidencias con un poco de contexto alrededor.
List<LibraryHit> searchTexts(String query, List<BookText> books, {int limit = 200}) {
  final q = foldText(query.trim());
  if (q.length < 2) return const [];
  final hits = <LibraryHit>[];
  for (final b in books) {
    final folded = foldText(b.text);
    var at = folded.indexOf(q);
    while (at >= 0 && hits.length < limit) {
      final from = (at - 50).clamp(0, b.text.length);
      final to = (at + q.length + 70).clamp(0, b.text.length);
      final snippet = b.text.substring(from, to).replaceAll(RegExp(r'\s+'), ' ').trim();
      hits.add(LibraryHit(
        b.id,
        b.title,
        '${from > 0 ? '…' : ''}$snippet${to < b.text.length ? '…' : ''}',
        b.text.isEmpty ? 0 : at / b.text.length,
      ));
      at = folded.indexOf(q, at + q.length);
    }
    if (hits.length >= limit) break;
  }
  return hits;
}

/// Colecciones existentes, sin repetir y en orden alfabético.
List<String> collectionsOf(List<Book> books) {
  final set = <String>{
    for (final b in books)
      if (b.collection != null && b.collection!.isNotEmpty) b.collection!,
  };
  return set.toList()..sort((a, b) => foldText(a).compareTo(foldText(b)));
}
