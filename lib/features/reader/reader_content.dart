import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;

import 'chapter_parser.dart';

class BookContent {
  final List<md.Node> blocks;
  final List<int> chapterStarts; // índice de bloque donde empieza cada capítulo
  final List<String> chapterTitles;
  const BookContent(this.blocks, this.chapterStarts, this.chapterTitles);
}

/// Lee el archivo y parsea en un Isolate para no bloquear la UI.
Future<BookContent> loadBook(String path) async {
  final text = await File(path).readAsString();
  return compute(parseBookText, text);
}

BookContent parseBookText(String text) {
  final chapters = parseChapters(text);
  final blocks = <md.Node>[];
  final starts = <int>[];
  final titles = <String>[];
  final doc = md.Document(extensionSet: md.ExtensionSet.gitHubFlavored);
  for (final c in chapters) {
    starts.add(blocks.length);
    titles.add(c.title);
    blocks.addAll(doc.parseLines(c.markdown.split('\n')));
  }
  return BookContent(blocks, starts, titles);
}

final bookContentProvider = FutureProvider.family<BookContent, String>(
    (ref, path) => loadBook(path));

final _wordCache = Expando<int>();

/// Palabras totales del libro (calculado una vez por contenido).
int wordCount(BookContent c) {
  final cached = _wordCache[c];
  if (cached != null) return cached;
  var n = 0;
  for (final b in c.blocks) {
    n += RegExp(r'\S+').allMatches(b.textContent).length;
  }
  _wordCache[c] = n;
  return n;
}
