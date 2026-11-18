import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/features.dart';

class FeaturesPage extends ConsumerWidget {
  const FeaturesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(featuresProvider);
    final n = ref.read(featuresProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Funciones')),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Text(
            'Activa solo lo que uses. Si desactivas una función, sus datos se conservan.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        for (final f in Feature.values)
          SwitchListTile(
            title: Text(f.label),
            subtitle: Text(f.hint),
            value: on.contains(f),
            onChanged: (v) => n.set(f, v),
          ),
        const SizedBox(height: 32),
      ]),
    );
  }
}
