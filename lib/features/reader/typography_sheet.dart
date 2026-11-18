import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../data/features.dart';
import '../../data/settings.dart';

Future<void> showTypographySheet(BuildContext context) => showModalBottomSheet(
      context: context,
      barrierColor: Colors.transparent, // se ve el texto cambiar en vivo
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => const TypographySheet(),
    );

class TypographySheet extends ConsumerWidget {
  const TypographySheet({super.key, this.paletteOnly = false});
  final bool paletteOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final label = Theme.of(context).textTheme.labelLarge!;

    Widget slider(String name, double v, double lo, double hi, String shown,
            ValueChanged<double> on, {int? divisions}) =>
        Row(children: [
          SizedBox(width: 92, child: Text(name, style: label)),
          Expanded(
            child: Slider(
              value: v.clamp(lo, hi),
              min: lo,
              max: hi,
              divisions: divisions,
              onChanged: on,
            ),
          ),
          SizedBox(
              width: 44,
              child: Text(shown, textAlign: TextAlign.end, style: label)),
        ]);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tema', style: label),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              _Swatch(
                  label: 'Auto',
                  selected: s.palette == null,
                  background: const Color(0xFF8A8A8A),
                  child: const Icon(Icons.brightness_auto, size: 20),
                  onTap: () => n.update(s.copyWith(autoPalette: true))),
              for (final p in ReaderPalette.values)
                _Swatch(
                    label: p.label,
                    selected: s.palette == p,
                    background: p.background,
                    child: Text('Aa',
                        style: TextStyle(
                            color: p.text, fontWeight: FontWeight.w700)),
                    onTap: () => n.update(s.copyWith(palette: p))),
            ]),
          ),
          if (!paletteOnly) ...[
            const SizedBox(height: 14),
            slider('Tamaño', s.fontSize, 12, 36, s.fontSize.round().toString(),
                (v) => n.update(s.copyWith(fontSize: v.roundToDouble())),
                divisions: 24),
            slider('Interlineado', s.lineHeight, 1.1, 2.4,
                s.lineHeight.toStringAsFixed(2),
                (v) => n.update(s.copyWith(lineHeight: (v * 20).round() / 20))),
            slider('Márgenes', s.margin, 8, 72, s.margin.round().toString(),
                (v) => n.update(s.copyWith(margin: v.roundToDouble()))),
            slider('Ancho', s.maxWidth, 420, 960, s.maxWidth.round().toString(),
                (v) => n.update(s.copyWith(maxWidth: (v / 10).round() * 10.0))),
            const SizedBox(height: 6),
            Text('Fuente', style: label),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final f in ReaderFont.values)
                ChoiceChip(
                  selected: s.font == f,
                  label: Text(f.label, style: f.apply(const TextStyle())),
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    n.update(s.copyWith(font: f));
                  },
                ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Texto justificado'),
              value: s.justify,
              onChanged: (v) => n.update(s.copyWith(justify: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrar reloj'),
              subtitle: const Text('Una franja discreta arriba mientras lees'),
              value: s.showClock,
              onChanged: (v) => n.update(s.copyWith(showClock: v)),
            ),
            if (s.showClock && ref.watch(featuresProvider).contains(Feature.clockExtras))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  FilterChip(
                    label: const Text('Batería'),
                    selected: s.clockBattery,
                    onSelected: (v) => n.update(s.copyWith(clockBattery: v)),
                  ),
                  FilterChip(
                    label: const Text('Progreso'),
                    selected: s.clockProgress,
                    onSelected: (v) => n.update(s.copyWith(clockProgress: v)),
                  ),
                  FilterChip(
                    label: const Text('Capítulo'),
                    selected: s.clockChapter,
                    onSelected: (v) => n.update(s.copyWith(clockChapter: v)),
                  ),
                ]),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: n.reset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restablecer'),
                style: TextButton.styleFrom(foregroundColor: scheme.onSurface),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(
      {required this.label,
      required this.selected,
      required this.background,
      required this.child,
      required this.onTap});
  final String label;
  final bool selected;
  final Color background;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Tema $label',
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected ? scheme.primary : scheme.outlineVariant,
                    width: selected ? 3 : 1),
              ),
              child: child,
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ]),
        ),
      ),
    );
  }
}
