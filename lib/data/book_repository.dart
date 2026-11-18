import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/book.dart';
import 'covers.dart';

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

  static const _okExt = {'.md', '.markdown', '.mdown', '.txt'};

  /// Abre el selector del sistema (varios archivos) e importa los .md.
  /// Devuelve null si se cancela. `skipped` cuenta los que no se pudieron importar.
  Future<({List<Book> added, int skipped})?> importFromPicker() async {
    final res = await FilePicker.pickFiles(type: FileType.any);
    if (res.isEmpty) return null;
    final added = <Book>[];
    var skipped = 0;
    for (final f in res) {
      final path = f.path;
      if (path == null || !_okExt.contains(p.extension(path).toLowerCase())) {
        skipped++;
        continue;
      }
      try {
        added.add(await importFile(File(path)));
      } catch (_) {
        skipped++;
      }
    }
    return (added: added, skipped: skipped);
  }

  Future<Book> importFile(File file, {String? name}) async {
    final dir = Directory(
        p.join((await getApplicationDocumentsDirectory()).path, 'books'));
    await dir.create(recursive: true);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final dest = await file.copy(p.join(dir.path, '$id.md'));
    final String text;
    try {
      text = await dest.readAsString();
    } catch (_) {
      await dest.delete(); // no era texto válido
      rethrow;
    }
    final book = Book(
      id: id,
      title: titleFor(text, p.basenameWithoutExtension(name ?? file.path)),
      path: dest.path,
      addedAt: DateTime.now(),
    );
    await _save([book, ...state.value ?? []]);
    return book;
  }

  Future<void> removeMany(Iterable<Book> books) async {
    final ids = books.map((b) => b.id).toSet();
    for (final b in books) {
      try {
        await File(b.path).delete();
      } catch (_) {}
    }
    await _save((state.value ?? []).where((x) => !ids.contains(x.id)).toList());
  }

  Future<void> remove(Book b) async {
    try {
      await File(b.path).delete();
    } catch (_) {}
    await _save((state.value ?? []).where((x) => x.id != b.id).toList());
  }

  /// Marca un libro como terminado (100 %) o lo vuelve a no terminado (0 %).
  Future<void> setFinished(String id, bool finished) async {
    await _save([
      for (final b in state.value ?? [])
        if (b.id == id) b.copyWith(progress: finished ? 1 : 0) else b
    ]);
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

  /// Título del libro: la primera línea «# …» del texto, salvo que el nombre del
  /// archivo la contenga y sea más completo (p. ej. «Capítulo 1 — El círculo.md»
  /// con «# El círculo» dentro). Sin encabezado se usa el nombre del archivo.
  static String titleFor(String text, String fileBase) {
    final m = RegExp(r'^[ \t]*#[ \t]+(.+?)[ \t]*#*[ \t]*$', multiLine: true)
        .firstMatch(text);
    final heading = m?.group(1)?.replaceAll(RegExp(r'[*_`]'), '').trim();
    final file = fileBase.trim();
    if (heading == null || heading.isEmpty) return file;
    if (file.length > heading.length &&
        file.toLowerCase().contains(heading.toLowerCase())) {
      return file;
    }
    return heading;
  }

  /// Pone una portada (la imagen se reduce y se guarda en la app). Null si no es imagen.
  Future<bool> setCover(String id, Uint8List imageBytes, {bool showTitle = true}) async {
    final jpg = encodeCover(imageBytes);
    if (jpg == null) return false;
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'covers'));
    await dir.create(recursive: true);
    final file = File(coverFileFor(dir, id));
    await file.writeAsBytes(jpg);
    await _save([
      for (final b in state.value ?? [])
        if (b.id == id) b.copyWith(coverPath: file.path, coverTitle: showTitle) else b
    ]);
    return true;
  }

  Future<void> setCollection(String id, String? name) async {
    final n = name?.trim();
    await _save([
      for (final b in state.value ?? [])
        if (b.id == id)
          b.copyWith(collection: (n == null || n.isEmpty) ? null : n, clearCollection: n == null || n.isEmpty)
        else
          b
    ]);
  }

  Future<void> setCoverTitle(String id, bool show) async {
    await _save([
      for (final b in state.value ?? [])
        if (b.id == id) b.copyWith(coverTitle: show) else b
    ]);
  }

  Future<void> removeCover(String id) async {
    for (final b in state.value ?? []) {
      if (b.id == id && b.coverPath != null) {
        try {
          await File(b.coverPath!).delete();
        } catch (_) {}
      }
    }
    await _save([
      for (final b in state.value ?? [])
        if (b.id == id) b.copyWith(clearCover: true) else b
    ]);
  }

  Future<void> rename(String id, String title) async {
    final t = title.trim();
    if (t.isEmpty) return;
    await _save([
      for (final b in state.value ?? [])
        if (b.id == id) b.copyWith(title: t) else b
    ]);
  }
}
