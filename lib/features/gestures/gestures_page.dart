import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/features.dart';
import '../../data/gestures.dart';

class GesturesPage extends ConsumerWidget {
  const GesturesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zones = ref.watch(gesturesProvider);
    final paged = ref.watch(featuresProvider).contains(Feature.paginated);
    final n = ref.read(gesturesProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestos'),
        actions: [
          TextButton(onPressed: n.reset, child: const Text('Restablecer')),
        ],
      ),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Text(
            'Divide la pantalla en tres franjas verticales y elige qué hace cada toque. Mantener pulsado sigue sirviendo para seleccionar texto.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        for (final z in TapZone.values)
          ListTile(
            leading: Icon(switch (z) {
              TapZone.left => Icons.align_horizontal_left,
              TapZone.center => Icons.crop_square,
              TapZone.right => Icons.align_horizontal_right,
            }),
            title: Text(z.label),
            subtitle: Text(zones[z]!.label),
            onTap: () async {
              final picked = await showDialog<GestureAction>(
                context: context,
                builder: (c) => SimpleDialog(
                  title: Text('Toque en ${z.label.toLowerCase()}'),
                  children: [
                    for (final a in GestureAction.values)
                      if (paged || !a.needsPaged)
                        ListTile(
                          title: Text(a.label),
                          trailing: zones[z] == a
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.pop(c, a),
                        ),
                  ],
                ),
              );
              if (picked != null) n.set(z, picked);
            },
          ),
        if (!paged)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              'Las acciones de página aparecen al activar el modo paginado.',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        const SizedBox(height: 32),
      ]),
    );
  }
}
