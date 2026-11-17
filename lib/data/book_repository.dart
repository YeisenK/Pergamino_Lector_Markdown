import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/book.dart';

const _kBooks = 'books_v1';

final booksProvider =
    AsyncNotifierProvider<BooksNotifier, List<Book>>(BooksNotifier.new);

class BooksNotifier extends AsyncNotifier<List<Book>> {
  @override
  Future<List<Book>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBooks);
    return raw == null ? [] : Book.decodeList(raw);
  }

  Future<void> _save(List<Book> books) async {
    state = AsyncData(books);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBooks, Book.encodeList(books));
  }

  /// Abre el selector del sistema e importa un .md. Devuelve el libro o null.
  Future<Book?> importFromPicker() async {
    final res = await FilePicker.pickFiles(type: FileType.any);
    final src = res.isEmpty ? null : res.first.path;
    if (src == null) return null;
    return importFile(File(src));
  }

  Future<Book> importFile(File file, {String? name}) async {
    final dir = Directory(
        p.join((await getApplicationDocumentsDirectory()).path, 'books'));
    await dir.create(recursive: true);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final dest = await file.copy(p.join(dir.path, '$id.md'));
    final text = await dest.readAsString();
    final book = Book(
      id: id,
      title: _extractTitle(text, p.basenameWithoutExtension(name ?? file.path)),
      path: dest.path,
      addedAt: DateTime.now(),
    );
    await _save([book, ...state.value ?? []]);
    return book;
  }

  Future<void> remove(Book b) async {
    try {
      await File(b.path).delete();
    } catch (_) {}
    await _save((state.value ?? []).where((x) => x.id != b.id).toList());
  }

  Future<void> updateProgress(String id, double progress) async {
    await _save([
      for (final b in state.value ?? [])
        if (b.id == id)
          b.copyWith(progress: progress.clamp(0, 1), lastOpened: DateTime.now())
        else
          b
    ]);
  }

  static String _extractTitle(String text, String fallback) {
    final m = RegExp(r'^\s*#\s+(.+?)\s*#*\s*$', multiLine: true).firstMatch(text);
    final t = m?.group(1)?.replaceAll(RegExp(r'[*_`]'), '').trim();
    return (t == null || t.isEmpty) ? fallback : t;
  }
}
