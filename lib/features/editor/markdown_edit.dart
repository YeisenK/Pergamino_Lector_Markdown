import 'package:flutter/services.dart';

/// Inicio de la línea que contiene [offset].
int _lineStart(String text, int offset) =>
    offset <= 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;

/// Resultado de una edición: texto nuevo y selección donde queda el cursor.
class EditResult {
  final String text;
  final TextSelection selection;
  const EditResult(this.text, this.selection);
}

/// Envuelve la selección con [before] y [after] (negrita, cursiva, código…).
/// Sin selección inserta el par y deja el cursor en medio.
EditResult wrapSelection(String text, TextSelection sel, String before, String after) {
  final start = sel.start < 0 ? text.length : sel.start;
  final end = sel.end < 0 ? text.length : sel.end;
  final inner = text.substring(start, end);
  final next = text.replaceRange(start, end, '$before$inner$after');
  final caret = start + before.length + inner.length + (inner.isEmpty ? 0 : after.length);
  return EditResult(
    next,
    TextSelection.collapsed(offset: inner.isEmpty ? start + before.length : caret),
  );
}

/// Pone [prefix] al inicio de cada línea seleccionada (título, lista, cita).
/// Si todas ya lo tienen, lo quita.
EditResult prefixLines(String text, TextSelection sel, String prefix) {
  final s = sel.start < 0 ? 0 : sel.start;
  final e = sel.end < 0 ? text.length : sel.end;
  final lineStart = _lineStart(text, s);
  var lineEnd = text.indexOf('\n', e);
  if (lineEnd < 0) lineEnd = text.length;
  final lines = text.substring(lineStart, lineEnd).split('\n');
  final allHave = lines.every((l) => l.startsWith(prefix));
  final changed = [
    for (final l in lines)
      allHave ? l.substring(prefix.length) : '$prefix$l',
  ].join('\n');
  final next = text.replaceRange(lineStart, lineEnd, changed);
  return EditResult(
    next,
    TextSelection(baseOffset: lineStart, extentOffset: lineStart + changed.length),
  );
}

/// Cambia el nivel de título de la línea del cursor: #, ##, ### o quita el título.
EditResult heading(String text, TextSelection sel, int level) {
  final caret = sel.start < 0 ? 0 : sel.start;
  final lineStart = _lineStart(text, caret);
  var lineEnd = text.indexOf('\n', caret);
  if (lineEnd < 0) lineEnd = text.length;
  final line = text.substring(lineStart, lineEnd);
  final stripped = line.replaceFirst(RegExp(r'^#{1,6}\s+'), '');
  final prefix = level == 0 ? '' : '${'#' * level} ';
  final next = text.replaceRange(lineStart, lineEnd, '$prefix$stripped');
  return EditResult(
    next,
    TextSelection.collapsed(offset: lineStart + prefix.length),
  );
}
