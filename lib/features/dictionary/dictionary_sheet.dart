import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/dictionary.dart';

/// Hoja con la definición de una palabra. Si el diccionario no está instalado, ofrece descargarlo.
Future<void> showDefinition(BuildContext context, String word) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => DefinitionSheet(word: word),
    );

class DefinitionSheet extends ConsumerWidget {
  const DefinitionSheet({super.key, required this.word});
  final String word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = ref.watch(dictionaryProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .7),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(word,
                    style: theme.textTheme.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                tooltip: 'Copiar',
                icon: const Icon(Icons.copy),
                onPressed: () => Clipboard.setData(ClipboardData(text: word)),
              ),
            ]),
            const SizedBox(height: 8),
            Flexible(
              child: !status.installed
                  ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        'Para ver definiciones, primero descarga el diccionario de español (≈ $dictionaryDownloadMb MB). Después funciona sin conexión.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('Ir al diccionario'),
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/diccionario');
                        },
                      ),
                    ])
                  : FutureBuilder<List<DictEntry>>(
                      future: DictionaryStore.lookup(word),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final list = snap.data!;
                        if (list.isEmpty) {
                          return Text(
                            'No está en el diccionario. Si es una forma conjugada o en plural, prueba con su forma básica.',
                            style: theme.textTheme.bodyMedium,
                          );
                        }
                        return ListView(shrinkWrap: true, children: [
                          for (final e in list) ...[
                            Text(e.pos,
                                style: theme.textTheme.labelLarge
                                    ?.copyWith(fontStyle: FontStyle.italic)),
                            const SizedBox(height: 4),
                            for (var i = 0; i < e.glosses.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text('${i + 1}. ${e.glosses[i]}',
                                    style: theme.textTheme.bodyMedium),
                              ),
                            const SizedBox(height: 10),
                          ],
                          Text('Wiktionary · CC BY-SA 4.0',
                              style: theme.textTheme.labelSmall),
                        ]);
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
