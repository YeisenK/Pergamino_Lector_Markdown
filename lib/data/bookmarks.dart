import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings.dart';

class Bookmark {
  final String bookId;
  final int index; // índice de bloque
  final String snippet;
  final String chapter;
  final DateTime createdAt;
  const Bookmark({
    required this.bookId,
    required this.index,
    required this.snippet,
    required this.chapter,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'index': index,
        'snippet': snippet,
        'chapter': chapter,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
        bookId: j['bookId'] as String,
        index: j['index'] as int,
        snippet: j['snippet'] as String,
        chapter: j['chapter'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

const _kBookmarks = 'bookmarks_v1';

final bookmarksProvider =
    NotifierProvider<BookmarksNotifier, List<Bookmark>>(BookmarksNotifier.new);

class BookmarksNotifier extends Notifier<List<Bookmark>> {
  @override
  List<Bookmark> build() {
    final raw = ref.read(prefsProvider).getString(_kBookmarks);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Bookmark.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _save(List<Bookmark> l) {
    state = l;
    ref
        .read(prefsProvider)
        .setString(_kBookmarks, jsonEncode(l.map((b) => b.toJson()).toList()));
  }

  List<Bookmark> forBook(String id) =>
      state.where((b) => b.bookId == id).toList()
        ..sort((a, b) => a.index.compareTo(b.index));

  void add(Bookmark b) => _save([...state, b]);

  void remove(Bookmark b) => _save(state
      .where((x) => !(x.bookId == b.bookId && x.index == b.index))
      .toList());

  void removeBook(String id) => _save(state.where((b) => b.bookId != id).toList());
}
