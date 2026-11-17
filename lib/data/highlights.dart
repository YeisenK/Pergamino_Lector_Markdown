import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'settings.dart';

enum HlColor {
  yellow('Amarillo', Color(0xFFFFD54F)),
  green('Verde', Color(0xFF81C784)),
  blue('Azul', Color(0xFF64B5F6)),
  pink('Rosa', Color(0xFFF06292));

  const HlColor(this.label, this.color);
  final String label;
  final Color color;
}

class Highlight {
  final String id;
  final String bookId;
  final int block; // índice de bloque
  final int part; // fragmento de texto dentro del bloque (listas, citas…)
  final int start;
  final int end;
  final String text;
  final HlColor color;
  final String? note;
  final String chapter;
  final DateTime createdAt;

  const Highlight({
    required this.id,
    required this.bookId,
    required this.block,
    required this.part,
    required this.start,
    required this.end,
    required this.text,
    required this.color,
    required this.chapter,
    required this.createdAt,
    this.note,
  });

  Highlight copyWith({HlColor? color, String? note, bool clearNote = false}) =>
      Highlight(
        id: id,
        bookId: bookId,
        block: block,
        part: part,
        start: start,
        end: end,
        text: text,
        color: color ?? this.color,
        note: clearNote ? null : (note ?? this.note),
        chapter: chapter,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'block': block,
        'part': part,
        'start': start,
        'end': end,
        'text': text,
        'color': color.name,
        'note': note,
        'chapter': chapter,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Highlight.fromJson(Map<String, dynamic> j) => Highlight(
        id: j['id'] as String,
        bookId: j['bookId'] as String,
        block: j['block'] as int,
        part: j['part'] as int,
        start: j['start'] as int,
        end: j['end'] as int,
        text: j['text'] as String,
        color: HlColor.values.asNameMap()[j['color']] ?? HlColor.yellow,
        note: j['note'] as String?,
        chapter: j['chapter'] as String? ?? '',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

const _kHighlights = 'highlights_v1';

final highlightsProvider =
    NotifierProvider<HighlightsNotifier, List<Highlight>>(HighlightsNotifier.new);

class HighlightsNotifier extends Notifier<List<Highlight>> {
  @override
  List<Highlight> build() {
    final raw = ref.read(prefsProvider).getString(_kHighlights);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Highlight.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _save(List<Highlight> l) {
    state = l;
    ref
        .read(prefsProvider)
        .setString(_kHighlights, jsonEncode(l.map((h) => h.toJson()).toList()));
  }

  void add(Highlight h) => _save([...state, h]);

  void update(Highlight h) =>
      _save([for (final x in state) x.id == h.id ? h : x]);

  void remove(String id) => _save(state.where((h) => h.id != id).toList());

  void removeBook(String bookId) =>
      _save(state.where((h) => h.bookId != bookId).toList());
}

/// Texto en Markdown con todos los subrayados y notas de un libro.
String exportHighlights(String title, List<Highlight> list) {
  final b = StringBuffer('# Notas de $title\n');
  final sorted = [...list]..sort((a, b) =>
      a.block != b.block ? a.block.compareTo(b.block) : a.start.compareTo(b.start));
  String? chapter;
  for (final h in sorted) {
    if (h.chapter != chapter) {
      chapter = h.chapter;
      b.write('\n## ${h.chapter}\n');
    }
    b.write('\n> ${h.text.replaceAll('\n', '\n> ')}\n');
    if (h.note != null && h.note!.trim().isNotEmpty) {
      b.write('\n${h.note!.trim()}\n');
    }
  }
  return b.toString();
}
