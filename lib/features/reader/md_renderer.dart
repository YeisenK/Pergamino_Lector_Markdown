import 'package:markdown/markdown.dart' as md;
import 'package:material_ui/material_ui.dart';

class ReaderStyle {
  final double fontSize;
  final double lineHeight;
  final Color text;
  final Color muted;
  final Color accent;
  final TextStyle Function(TextStyle) font;
  final bool justify;
  const ReaderStyle({
    required this.fontSize,
    required this.lineHeight,
    required this.text,
    required this.muted,
    required this.accent,
    required this.font,
    this.justify = false,
  });

  TextStyle get body =>
      font(TextStyle(fontSize: fontSize, height: lineHeight, color: text));
}

/// Convierte un bloque (nodo de nivel superior del AST) en un widget.
Widget buildBlock(md.Node node, ReaderStyle s) {
  if (node is md.Text) return const SizedBox.shrink();
  final el = node as md.Element;
  switch (el.tag) {
    case 'h1':
    case 'h2':
    case 'h3':
    case 'h4':
    case 'h5':
    case 'h6':
      final scale = {'h1': 1.7, 'h2': 1.4, 'h3': 1.2, 'h4': 1.1, 'h5': 1.0, 'h6': .95}[el.tag]!;
      return Padding(
        padding: EdgeInsets.only(top: s.fontSize * 1.2, bottom: s.fontSize * .6),
        child: Text.rich(
          TextSpan(
              children: _inline(el.children, s, s.body.copyWith(
                  fontSize: s.fontSize * scale,
                  fontWeight: FontWeight.w700,
                  height: 1.25))),
        ),
      );
    case 'p':
      return _para(el.children, s, s.body);
    case 'blockquote':
      return Container(
        margin: EdgeInsets.symmetric(vertical: s.fontSize * .4),
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
            border: Border(left: BorderSide(color: s.accent, width: 3))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in el.children ?? <md.Node>[])
              if (c is md.Element)
                _para(c.children, s, s.body.copyWith(fontStyle: FontStyle.italic, color: s.muted))
          ],
        ),
      );
    case 'ul':
    case 'ol':
      return _list(el, s, 0);
    case 'pre':
      final code = el.textContent;
      return Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(vertical: s.fontSize * .5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: s.text.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(8)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(code.trimRight(),
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: s.fontSize * .85,
                  height: 1.4,
                  color: s.text)),
        ),
      );
    case 'hr':
      return Padding(
        padding: EdgeInsets.symmetric(vertical: s.fontSize * 1.2),
        child: Center(
            child: Text('· · ·',
                style: s.body.copyWith(color: s.muted, letterSpacing: 6))),
      );
    case 'table':
      return _table(el, s);
    default:
      return _para(el.children, s, s.body);
  }
}

Widget _para(List<md.Node>? kids, ReaderStyle s, TextStyle style) => Padding(
      padding: EdgeInsets.only(bottom: s.fontSize * .85),
      child: Text.rich(
        TextSpan(children: _inline(kids, s, style)),
        textAlign: s.justify ? TextAlign.justify : TextAlign.start,
      ),
    );

Widget _list(md.Element el, ReaderStyle s, int depth) {
  final ordered = el.tag == 'ol';
  var i = 0;
  return Padding(
    padding: EdgeInsets.only(
        left: depth * 18.0, bottom: depth == 0 ? s.fontSize * .85 : 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final li in el.children ?? <md.Node>[])
          if (li is md.Element && li.tag == 'li') ...[
            () {
              i++;
              final inline = <md.Node>[];
              final nested = <md.Element>[];
              for (final c in li.children ?? <md.Node>[]) {
                if (c is md.Element && (c.tag == 'ul' || c.tag == 'ol')) {
                  nested.add(c);
                } else if (c is md.Element && c.tag == 'p') {
                  inline.addAll(c.children ?? []);
                } else {
                  inline.add(c);
                }
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: s.fontSize * .3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                            width: 28,
                            child: Text(ordered ? '$i.' : '•',
                                style: s.body.copyWith(color: s.accent))),
                        Expanded(
                            child: Text.rich(
                                TextSpan(children: _inline(inline, s, s.body)))),
                      ],
                    ),
                  ),
                  for (final n in nested) _list(n, s, depth + 1),
                ],
              );
            }()
          ]
      ],
    ),
  );
}

Widget _table(md.Element el, ReaderStyle s) {
  final rows = <TableRow>[];
  void collect(md.Element section, bool head) {
    for (final tr in section.children ?? <md.Node>[]) {
      if (tr is! md.Element) continue;
      rows.add(TableRow(
        children: [
          for (final cell in tr.children ?? <md.Node>[])
            if (cell is md.Element)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text.rich(TextSpan(
                    children: _inline(
                        cell.children,
                        s,
                        s.body.copyWith(
                            fontSize: s.fontSize * .9,
                            fontWeight: head ? FontWeight.w700 : null)))),
              )
        ],
      ));
    }
  }

  for (final sec in el.children ?? <md.Node>[]) {
    if (sec is md.Element) collect(sec, sec.tag == 'thead');
  }
  return Padding(
    padding: EdgeInsets.only(bottom: s.fontSize * .85),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: s.text.withValues(alpha: .2)),
        children: rows,
      ),
    ),
  );
}

List<InlineSpan> _inline(List<md.Node>? nodes, ReaderStyle s, TextStyle base) {
  final out = <InlineSpan>[];
  for (final n in nodes ?? <md.Node>[]) {
    if (n is md.Text) {
      out.add(TextSpan(text: n.text, style: base));
    } else if (n is md.Element) {
      switch (n.tag) {
        case 'em':
          out.addAll(_inline(n.children, s, base.copyWith(fontStyle: FontStyle.italic)));
        case 'strong':
          out.addAll(_inline(n.children, s, base.copyWith(fontWeight: FontWeight.w700)));
        case 'del':
          out.addAll(_inline(n.children, s, base.copyWith(decoration: TextDecoration.lineThrough)));
        case 'code':
          out.add(TextSpan(
              text: n.textContent,
              style: base.copyWith(
                  fontFamily: 'monospace',
                  fontSize: (base.fontSize ?? s.fontSize) * .88,
                  backgroundColor: s.text.withValues(alpha: .08))));
        case 'a':
          out.addAll(_inline(n.children, s,
              base.copyWith(color: s.accent, decoration: TextDecoration.underline)));
        case 'br':
          out.add(const TextSpan(text: '\n'));
        case 'img':
          out.add(TextSpan(
              text: '[${n.attributes['alt'] ?? 'imagen'}]',
              style: base.copyWith(color: s.muted)));
        default:
          out.addAll(_inline(n.children, s, base));
      }
    }
  }
  return out;
}
