import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pergamino/data/backup.dart';
import 'package:pergamino/domain/book.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tmp;
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pergamino_test');
  });
  tearDown(() => tmp.delete(recursive: true));

  test('ida y vuelta: copia, restaurar en otro sitio, sin duplicar', () async {
    final src = File('${tmp.path}/origen.md')..writeAsStringSync('# Libro\n\nTexto.');
    final book = Book(
        id: 'b1', title: 'Libro', path: src.path, addedAt: DateTime(2026), progress: .4);
    SharedPreferences.setMockInitialValues({
      'books_v1': Book.encodeList([book]),
      'bookmarks_v1': '[{"bookId":"b1","index":3,"snippet":"hola","chapter":"Cap","createdAt":"2026-01-01T00:00:00.000"}]',
      'reader_settings_v1': '{"fontSize":22}',
      'reading_wpm_v1': 250,
    });
    final prefs = await SharedPreferences.getInstance();
    final bytes = buildBackup(prefs);
    expect(bytes.length, greaterThan(100));

    // nuevo teléfono: sin libros ni marcas
    SharedPreferences.setMockInitialValues({});
    final prefs2 = await SharedPreferences.getInstance();
    final dest = Directory('${tmp.path}/books');
    final r = await restoreBackup(bytes, prefs: prefs2, booksDir: dest);
    expect(r.booksAdded, 1);
    expect(r.marksAdded, 1);
    final restored = Book.decodeList(prefs2.getString('books_v1') ?? '[]');
    expect(restored.single.title, 'Libro');
    expect(File(restored.single.path).readAsStringSync(), contains('Texto.'));
    expect(prefs2.getString('bookmarks_v1'), contains('"index":3'));
    expect(prefs2.getInt('reading_wpm_v1'), 250);

    // restaurar otra vez no duplica nada
    final again = await restoreBackup(bytes, prefs: prefs2, booksDir: dest);
    expect(again.booksAdded, 0);
    expect(again.booksSkipped, 1);
    expect(again.marksAdded, 0);
    expect(Book.decodeList(prefs2.getString('books_v1') ?? '[]').length, 1);
  });

  test('una copia de otra versión se rechaza sin tocar nada', () async {
    final bad = Uint8List.fromList(
        ZipEncoder().encode(Archive()..addFile(ArchiveFile.string('backup.json',
            '{"app":"Pergamino","version":99,"prefs":{}}'))));
    SharedPreferences.setMockInitialValues({'books_v1': '[]'});
    final prefs = await SharedPreferences.getInstance();
    await expectLater(
        restoreBackup(bad, prefs: prefs, booksDir: Directory('${tmp.path}/b')),
        throwsA(isA<BackupException>()));
    expect(prefs.getString('books_v1'), '[]');
  });

  test('un archivo que no es una copia da error claro', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await expectLater(
        restoreBackup(Uint8List.fromList([1, 2, 3]), prefs: prefs, booksDir: tmp),
        throwsA(isA<BackupException>()));
  });
}
