import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pergamino/data/dictionary.dart';

void main() {
  late Directory tmp;
  late SortedLineFile file;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('dict_test');
    final keys = ['abrir', 'arbol', 'casa', 'casas', 'zorro', 'ñandu'];
    final lines = [
      for (final k in keys)
        '${dictKey(k)}\t[{"w":"$k","p":"sustantivo","g":["definición de $k"]}]',
    ]..sort((a, b) => a.split('\t').first.compareTo(b.split('\t').first));
    final f = File('${tmp.path}/es.txt')..writeAsStringSync('${lines.join('\n')}\n');
    file = SortedLineFile(f.path);
  });

  tearDownAll(() => tmp.deleteSync(recursive: true));

  test('encuentra cada palabra del archivo, sin importar acentos ni mayúsculas', () {
    final casa = lookupIn(file, 'Casa');
    expect(casa.single.word, 'casa');
    expect(casa.single.glosses.single, 'definición de casa');
    expect(lookupIn(file, 'árbol').single.word, 'arbol');
    expect(lookupIn(file, 'ÑANDU').single.word, 'ñandu');
  });

  test('todas las entradas se encuentran, incluidas las primeras y las últimas', () {
    for (final w in ['abrir', 'arbol', 'casa', 'casas', 'zorro', 'ñandu']) {
      expect(lookupIn(file, w), isNotEmpty, reason: w);
    }
  });

  test('palabras que no están devuelven vacío', () {
    expect(lookupIn(file, 'perro'), isEmpty);
    expect(lookupIn(file, 'aaa'), isEmpty);
    expect(lookupIn(file, 'zzzz'), isEmpty);
    expect(lookupIn(file, ''), isEmpty);
  });

  test('la clave quita acentos y signos', () {
    expect(dictKey('Canción'), 'cancion');
    expect(dictKey('¿Qué?'), 'que');
  });
}
