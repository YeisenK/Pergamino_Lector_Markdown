import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pergamino/features/editor/markdown_edit.dart';

void main() {
  test('negrita sobre una palabra seleccionada', () {
    final r = wrapSelection('hola mundo', const TextSelection(baseOffset: 5, extentOffset: 10), '**', '**');
    expect(r.text, 'hola **mundo**');
  });

  test('sin selección inserta el par con el cursor en medio', () {
    final r = wrapSelection('ab', const TextSelection.collapsed(offset: 1), '*', '*');
    expect(r.text, 'a**b');
    expect(r.selection.baseOffset, 2);
  });

  test('prefijar y quitar lista en varias líneas', () {
    final r = prefixLines('uno\ndos', const TextSelection(baseOffset: 0, extentOffset: 7), '- ');
    expect(r.text, '- uno\n- dos');
    final back = prefixLines(r.text, const TextSelection(baseOffset: 0, extentOffset: 11), '- ');
    expect(back.text, 'uno\ndos');
  });

  test('título: cambia nivel y lo quita', () {
    final r = heading('Texto', const TextSelection.collapsed(offset: 2), 2);
    expect(r.text, '## Texto');
    final h = heading('## Texto', const TextSelection.collapsed(offset: 4), 1);
    expect(h.text, '# Texto');
    expect(heading('# Texto', const TextSelection.collapsed(offset: 3), 0).text, 'Texto');
  });
}
