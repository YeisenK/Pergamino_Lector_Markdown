import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/book_repository.dart';
import '../../domain/library_search.dart';

class LibrarySearchPage extends ConsumerStatefulWidget {
  const LibrarySearchPage({super.key});

  @override
  ConsumerState<LibrarySearchPage> createState() => _LibrarySearchPageState();
}

class _LibrarySearchPageState extends ConsumerState<LibrarySearchPage> {
  final _ctrl = TextEditingController();
  List<LibraryHit>? _hits;
  bool _busy = false;
  int _read = 0;
  int _total = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) return;
    final books = ref.read(booksProvider).value ?? [];
    setState(() {
      _busy = true;
      _hits = null;
      _read = 0;
      _total = books.length;
    });
    final texts = <BookText>[];
    for (final b in books) {
      try {
        texts.add(BookText(b.id, b.title, await File(b.path).readAsString()));
      } catch (_) {}
      if (mounted) setState(() => _read++);
    }
    final hits = searchTexts(q, texts);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _hits = hits;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar en todos los libros')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Una palabra o frase',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: theme.colorScheme.onSurface.withValues(alpha: .06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: _search,
          ),
        ),
        if (_busy)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              LinearProgressIndicator(value: _total == 0 ? null : _read / _total),
              const SizedBox(height: 6),
              Text('Leyendo libros $_read de $_total', style: theme.textTheme.labelMedium),
            ]),
          ),
        if (_hits != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _hits!.isEmpty
                    ? 'Sin resultados'
                    : '${_hits!.length}${_hits!.length >= 200 ? '+' : ''} coincidencias',
                style: theme.textTheme.labelMedium,
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _hits?.length ?? 0,
            itemBuilder: (_, i) {
              final h = _hits![i];
              return ListTile(
                title: Text(h.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(h.snippet, maxLines: 3, overflow: TextOverflow.ellipsis),
                onTap: () => context.push(
                    '/read/${h.bookId}?f=${h.fraction.toStringAsFixed(5)}'),
              );
            },
          ),
        ),
      ]),
    );
  }
}
