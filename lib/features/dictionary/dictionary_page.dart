import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/dictionary.dart';

class DictionaryPage extends ConsumerStatefulWidget {
  const DictionaryPage({super.key});

  @override
  ConsumerState<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends ConsumerState<DictionaryPage> {
  final _ctrl = TextEditingController();
  List<DictEntry>? _result;
  String _last = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    _last = q.trim();
    if (_last.isEmpty) return;
    final r = await DictionaryStore.lookup(_last);
    if (!mounted || _last != q.trim()) return;
    setState(() => _result = r);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = ref.watch(dictionaryProvider);
    final n = ref.read(dictionaryProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Diccionario')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (!status.installed) ...[
          Text(
            'Diccionario de español sin conexión. Ocupa unos $dictionaryInstalledMb MB en el teléfono (se descargan $dictionaryDownloadMb MB). Las definiciones vienen de Wiktionary, con licencia CC BY-SA 4.0.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (status.progress != null) ...[
            LinearProgressIndicator(value: status.progress == 0 ? null : status.progress),
            const SizedBox(height: 8),
            Text('Descargando… ${((status.progress ?? 0) * 100).round()} %',
                style: theme.textTheme.labelMedium),
          ] else
            FilledButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Descargar diccionario'),
              onPressed: n.download,
            ),
          if (status.error != null) ...[
            const SizedBox(height: 12),
            Text(status.error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ] else ...[
          TextField(
            controller: _ctrl,
            textInputAction: TextInputAction.search,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Escribe una palabra',
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
          const SizedBox(height: 12),
          if (_result != null && _result!.isEmpty)
            Text('No está en el diccionario.', style: theme.textTheme.bodyMedium),
          if (_result != null)
            for (final e in _result!) ...[
              Text('${e.word}  ·  ${e.pos}',
                  style: theme.textTheme.titleSmall?.copyWith(fontStyle: FontStyle.italic)),
              for (var i = 0; i < e.glosses.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text('${i + 1}. ${e.glosses[i]}', style: theme.textTheme.bodyMedium),
                ),
              const SizedBox(height: 14),
            ],
          const SizedBox(height: 24),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('Borrar diccionario del teléfono'),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Borrar diccionario'),
                    content: const Text('Podrás volver a descargarlo cuando quieras.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Borrar')),
                    ],
                  ),
                );
                if (ok == true) n.remove();
              },
            ),
          ),
        ],
      ]),
    );
  }
}
