import 'package:material_ui/material_ui.dart';

import 'md_renderer.dart';
import 'pagination.dart';
import 'reader_content.dart';

typedef PageSelect = void Function(
    int block, int part, int start, int end, String text, bool withNote);

/// Contenido de una página: bloques enteros y trozos de párrafos.
Widget pageContent(
  BookPage page,
  BookContent c,
  ReaderStyle style,
  Map<int, List<Mark>> marks,
  PageSelect onSelect,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final it in page.items)
        if (it.whole)
          buildBlock(
            c.blocks[it.block],
            style,
            BlockCtx(
              marks: marks[it.block] ?? const [],
              onSelect: (part, s, e, t, n) => onSelect(it.block, part, s, e, t, n),
            ),
          )
        else
          renderTextSlice(
            textBlockInfo(c.blocks[it.block], style)!,
            it.start,
            it.end,
            BlockCtx(
              marks: shiftMarks(marks[it.block] ?? const [], it.start, it.end),
              onSelect: (part, s, e, t, n) =>
                  onSelect(it.block, part, s + it.start, e + it.start, t, n),
            ),
            first: it.start == 0,
          ),
    ],
  );
}
