import 'package:markdown/markdown.dart' as md;

class SearchHit {
  final int index;
  final String snippet;
  const SearchHit(this.index, this.snippet);
}

String _norm(String s) => s
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ü', 'u');

/// Busca [query] (sin distinguir mayúsculas ni acentos) en los bloques.
List<SearchHit> searchBlocks(List<md.Node> blocks, String query, {int limit = 200}) {
  final q = _norm(query.trim());
  if (q.length < 2) return const [];
  final hits = <SearchHit>[];
  for (var i = 0; i < blocks.length && hits.length < limit; i++) {
    final text = blocks[i].textContent.replaceAll(RegExp(r'\s+'), ' ');
    final at = _norm(text).indexOf(q);
    if (at < 0) continue;
    final start = (at - 40).clamp(0, text.length);
    final end = (at + q.length + 80).clamp(0, text.length);
    hits.add(SearchHit(
        i, '${start > 0 ? '…' : ''}${text.substring(start, end)}${end < text.length ? '…' : ''}'));
  }
  return hits;
}

String blockSnippet(md.Node n, [int max = 90]) {
  final t = n.textContent.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length <= max ? t : '${t.substring(0, max)}…';
}
