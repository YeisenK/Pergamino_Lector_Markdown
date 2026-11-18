import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/book.dart';

/// Versión del formato `.pergamino`. Si no coincide al restaurar, no se toca nada.
const backupVersion = 1;

/// Claves de preferencias que forman parte de la copia.
const backupKeys = [
  'books_v1',
  'bookmarks_v1',
  'highlights_v1',
  'reader_settings_v1',
  'features_v1',
  'library_view_v1',
  'tts_voice_v1',
  'tts_rate_v1',
  'reading_wpm_v1',
];

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RestoreResult {
  final int booksAdded;
  final int booksSkipped;
  final int marksAdded;
  const RestoreResult(this.booksAdded, this.booksSkipped, this.marksAdded);
}

/// Crea el archivo ZIP: `backup.json` (versión, fecha, preferencias) y `books/<id>.md`.
Uint8List buildBackup(SharedPreferences prefs) {
  final values = <String, Map<String, dynamic>>{};
  for (final k in backupKeys) {
    final v = prefs.get(k);
    if (v == null) continue;
    values[k] = {'type': v.runtimeType.toString(), 'value': v};
  }
  final rawBooks = prefs.getString('books_v1');
  final books = rawBooks == null ? <Book>[] : Book.decodeList(rawBooks);

  final archive = Archive()
    ..addFile(ArchiveFile.string(
        'backup.json',
        jsonEncode({
          'app': 'Pergamino',
          'version': backupVersion,
          'createdAt': DateTime.now().toIso8601String(),
          'prefs': values,
        })));
  for (final b in books) {
    final f = File(b.path);
    if (!f.existsSync()) continue;
    final bytes = f.readAsBytesSync();
    archive.addFile(ArchiveFile.bytes('books/${b.id}.md', bytes));
  }
  final out = ZipEncoder().encode(archive);
  return Uint8List.fromList(out);
}

/// Restaura una copia. Los libros que ya existen (mismo id) no se duplican;
/// marcadores y subrayados se fusionan por clave; ajustes y funciones se reemplazan.
Future<RestoreResult> restoreBackup(
  Uint8List zipBytes, {
  required SharedPreferences prefs,
  required Directory booksDir,
}) async {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(zipBytes);
  } catch (_) {
    throw BackupException('El archivo no es una copia de Pergamino.');
  }
  final meta = archive.findFile('backup.json');
  if (meta == null) {
    throw BackupException('El archivo no es una copia de Pergamino.');
  }
  final root = jsonDecode(utf8.decode(meta.content as List<int>)) as Map<String, dynamic>;
  if (root['app'] != 'Pergamino') {
    throw BackupException('El archivo no es una copia de Pergamino.');
  }
  if (root['version'] != backupVersion) {
    throw BackupException(
        'Esta copia es de otra versión del formato (${root['version']}). No se ha cambiado nada.');
  }
  final values = root['prefs'] as Map<String, dynamic>;

  // libros: se añaden los que no existen
  final current = prefs.getString('books_v1') == null
      ? <Book>[]
      : Book.decodeList(prefs.getString('books_v1')!);
  final ids = current.map((b) => b.id).toSet();
  final incoming = values['books_v1'] == null
      ? <Book>[]
      : Book.decodeList((values['books_v1'] as Map)['value'] as String);
  await booksDir.create(recursive: true);
  var added = 0, skipped = 0;
  final merged = [...current];
  for (final b in incoming) {
    if (ids.contains(b.id)) {
      skipped++;
      continue;
    }
    final file = archive.findFile('books/${b.id}.md');
    if (file == null) {
      skipped++;
      continue;
    }
    final dest = File('${booksDir.path}/${b.id}.md');
    await dest.writeAsBytes(file.content as List<int>);
    merged.add(b.withPath(dest.path));
    ids.add(b.id);
    added++;
  }
  await prefs.setString('books_v1', Book.encodeList(merged));

  // marcadores y subrayados: unión por clave
  var marks = 0;
  for (final key in ['bookmarks_v1', 'highlights_v1']) {
    final incomingRaw = values[key] == null ? null : (values[key] as Map)['value'] as String;
    if (incomingRaw == null) continue;
    final existing = prefs.getString(key);
    final list = <Map<String, dynamic>>[
      if (existing != null) ...(jsonDecode(existing) as List).cast<Map<String, dynamic>>(),
    ];
    final keys = list.map(_markKey).toSet();
    for (final m in (jsonDecode(incomingRaw) as List).cast<Map<String, dynamic>>()) {
      if (keys.add(_markKey(m))) {
        list.add(m);
        marks++;
      }
    }
    await prefs.setString(key, jsonEncode(list));
  }

  // ajustes y funciones: se reemplazan con los de la copia
  for (final k in backupKeys) {
    if (k == 'books_v1' || k == 'bookmarks_v1' || k == 'highlights_v1') continue;
    final entry = values[k] as Map<String, dynamic>?;
    if (entry == null) continue;
    final v = entry['value'];
    switch (entry['type']) {
      case 'String':
        await prefs.setString(k, v as String);
      case 'int':
        await prefs.setInt(k, v as int);
      case 'double':
        await prefs.setDouble(k, (v as num).toDouble());
      case 'bool':
        await prefs.setBool(k, v as bool);
    }
  }
  return RestoreResult(added, skipped, marks);
}

String _markKey(Map<String, dynamic> m) =>
    m.containsKey('block')
        ? 'h:${m['id']}'
        : 'b:${m['bookId']}:${m['index']}';
