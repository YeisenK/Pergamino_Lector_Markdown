import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/book_repository.dart';
import '../reader/reader_content.dart';
import 'markdown_edit.dart';

/// Editor del texto de un libro. Cambia la copia guardada en Pergamino,
/// nunca el archivo original de tu ordenador. Antes de guardar se conserva
/// la versión anterior para poder volver atrás.
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key, required this.bookId});
  final String bookId;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _saved = '';
  bool _loaded = false;
  bool _dirty = false;
  String? _path;
  String? _title;

  String get _bakPath => '${_path!}.bak';

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final d = _ctrl.text != _saved;
      if (d != _dirty) setState(() => _dirty = d);
    });
    _load();
  }

  Future<void> _load() async {
    final book = ref.read(booksProvider).value?.where((b) => b.id == widget.bookId).firstOrNull;
    if (book == null) return;
    _path = book.path;
    _title = book.title;
    final text = await File(book.path).readAsString();
    if (!mounted) return;
    _saved = text;
    _ctrl.text = text;
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _apply(EditResult r) {
    _ctrl.value = TextEditingValue(text: r.text, selection: r.selection);
    _focus.requestFocus();
  }

  TextSelection get _sel => _ctrl.selection;

  Future<void> _save() async {
    final path = _path!;
    final prev = File(path);
    if (await prev.exists()) await prev.copy(_bakPath);
    await File(path).writeAsString(_ctrl.text);
    _saved = _ctrl.text;
    ref.invalidate(bookContentProvider(path));
    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
          content: Text('Guardado. La versión anterior queda para deshacer.'),
          duration: Duration(milliseconds: 1600)));
  }

  Future<void> _restorePrevious() async {
    if (!File(_bakPath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay una versión anterior.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Volver a la versión anterior'),
        content: const Text(
            'El texto actual se reemplaza por la versión anterior. Tendrás que guardar para que se quede.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reemplazar')),
        ],
      ),
    );
    if (ok != true) return;
    final prev = await File(_bakPath).readAsString();
    _ctrl.text = prev;
    _ctrl.selection = const TextSelection.collapsed(offset: 0);
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cambios sin guardar'),
        content: const Text('¿Quieres guardar antes de salir?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 'discard'), child: const Text('Descartar')),
          TextButton(onPressed: () => Navigator.pop(c, 'cancel'), child: const Text('Seguir editando')),
          FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('Guardar')),
        ],
      ),
    );
    if (choice == 'save') {
      await _save();
      return true;
    }
    return choice == 'discard';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tools = <(IconData, String, VoidCallback)>[
      (Icons.format_bold, 'Negrita', () => _apply(wrapSelection(_ctrl.text, _sel, '**', '**'))),
      (Icons.format_italic, 'Cursiva', () => _apply(wrapSelection(_ctrl.text, _sel, '*', '*'))),
      (Icons.title, 'Título', () => _apply(heading(_ctrl.text, _sel, 1))),
      (Icons.looks_two_outlined, 'Subtítulo', () => _apply(heading(_ctrl.text, _sel, 2))),
      (Icons.format_list_bulleted, 'Lista', () => _apply(prefixLines(_ctrl.text, _sel, '- '))),
      (Icons.format_quote, 'Cita', () => _apply(prefixLines(_ctrl.text, _sel, '> '))),
      (Icons.code, 'Código', () => _apply(wrapSelection(_ctrl.text, _sel, '`', '`'))),
    ];

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cerrar',
            onPressed: () async {
              if (await _confirmLeave() && context.mounted) context.pop();
            },
          ),
          title: Text(_title ?? 'Editor', maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Versión anterior',
              icon: const Icon(Icons.history),
              onPressed: _loaded ? _restorePrevious : null,
            ),
            FilledButton(
              onPressed: _dirty ? _save : null,
              child: const Text('Guardar'),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      for (final t in tools)
                        IconButton(
                          tooltip: t.$2,
                          icon: Icon(t.$1),
                          onPressed: t.$3,
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 15,
                      height: 1.45,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                  ),
                ),
              ]),
      ),
    );
  }
}
