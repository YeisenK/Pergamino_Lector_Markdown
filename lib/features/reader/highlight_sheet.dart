import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/book_repository.dart';
import '../../data/highlights.dart';
import 'quote_share.dart';

Future<void> showHighlightSheet(BuildContext context, String id) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => HighlightSheet(id: id),
    );

class HighlightSheet extends ConsumerStatefulWidget {
  const HighlightSheet({super.key, required this.id});
  final String id;

  @override
  ConsumerState<HighlightSheet> createState() => _HighlightSheetState();
}

class _HighlightSheetState extends ConsumerState<HighlightSheet> {
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final h = ref.read(highlightsProvider).where((x) => x.id == widget.id).firstOrNull;
    _note = TextEditingController(text: h?.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = ref.watch(highlightsProvider).where((x) => x.id == widget.id).firstOrNull;
    if (h == null) return const SizedBox(height: 80);
    final n = ref.read(highlightsProvider.notifier);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: h.color.color.withValues(alpha: .25),
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: h.color.color, width: 4)),
            ),
            child: Text(h.text,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(height: 4),
          if (h.chapter.isNotEmpty)
            Text(h.chapter, style: theme.textTheme.labelSmall),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Añade una nota…',
              filled: true,
              fillColor: theme.colorScheme.onSurface.withValues(alpha: .06),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
            onChanged: (v) => n.update(v.trim().isEmpty
                ? h.copyWith(clearNote: true)
                : h.copyWith(note: v)),
          ),
          const SizedBox(height: 14),
          Row(children: [
            for (final c in HlColor.values)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Semantics(
                  button: true,
                  label: c.label,
                  selected: c == h.color,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      n.update(h.copyWith(color: c));
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c.color,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: c == h.color
                                ? theme.colorScheme.onSurface
                                : Colors.transparent,
                            width: 3),
                      ),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            IconButton(
              tooltip: 'Compartir como imagen',
              icon: const Icon(Icons.image_outlined),
              onPressed: () => showQuoteShare(
                context,
                h,
                ref.read(booksProvider).value
                        ?.where((b) => b.id == h.bookId)
                        .firstOrNull
                        ?.title ??
                    '',
              ),
            ),
            IconButton(
              tooltip: 'Copiar',
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(
                    text: exportHighlights('', [h]).split('\n').skip(1).join('\n').trim()));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Copiado'), duration: Duration(milliseconds: 1000)));
              },
            ),
            IconButton(
              tooltip: 'Eliminar subrayado',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                n.remove(h.id);
                Navigator.pop(context);
              },
            ),
          ]),
        ]),
      ),
    );
  }
}
