import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/book_repository.dart';
import '../../data/reading_speed.dart';
import '../../data/stats_repository.dart';
import '../../domain/reading_stats.dart';

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(statsProvider);
    final goal = ref.watch(statsGoalProvider);
    final wpm = ref.watch(readingWpmProvider);
    final books = ref.watch(booksProvider).value ?? [];
    final s = summarize(sessions, DateTime.now());
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget card(String label, String value, {String? sub}) => Expanded(
          child: Card(
            elevation: 0,
            color: scheme.onSurface.withValues(alpha: .05),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(value, style: theme.textTheme.titleLarge),
                if (sub != null) Text(sub, style: theme.textTheme.labelSmall),
              ]),
            ),
          ),
        );

    String mins(int m) => m >= 60 ? '${m ~/ 60} h ${m % 60} min' : '$m min';
    final maxDay = s.last14.fold<int>(1, (a, d) => d.minutes > a ? d.minutes : a);
    final byBook = s.minutesByBook.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: sessions.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Todavía no hay lecturas registradas.\nLas estadísticas aparecen cuando lees con el libro abierto.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
          : ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                card('Hoy', mins(s.todayMin)),
                const SizedBox(width: 8),
                card('Esta semana', mins(s.weekMin)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                card('Este mes', mins(s.monthMin)),
                const SizedBox(width: 8),
                card('Racha', '${s.streakDays} ${s.streakDays == 1 ? 'día' : 'días'}'),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                card('Velocidad', '$wpm',
                    sub: s.wpm == null
                        ? 'palabras por minuto · estimada'
                        : 'palabras por minuto · medida'),
              ]),
              const SizedBox(height: 20),
              Text('Meta de hoy: $goal min', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: goal <= 0 ? 0 : (s.todayMin / goal).clamp(0.0, 1.0),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              Row(children: [
                Text('${s.todayMin} de $goal min', style: theme.textTheme.labelMedium),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final v = await showDialog<int>(
                      context: context,
                      builder: (c) => SimpleDialog(
                        title: const Text('Meta diaria'),
                        children: [
                          for (final m in [10, 20, 30, 45, 60])
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(c, m),
                              child: Text('$m minutos'),
                            ),
                        ],
                      ),
                    );
                    if (v != null) ref.read(statsGoalProvider.notifier).set(v);
                  },
                  child: const Text('Cambiar'),
                ),
              ]),
              const SizedBox(height: 20),
              Text('Últimos 14 días', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                height: 110,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final d in s.last14)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Tooltip(
                            message: '${d.day.day}/${d.day.month}: ${d.minutes} min',
                            child: Container(
                              height: d.minutes == 0
                                  ? 3
                                  : (d.minutes / maxDay * 100).clamp(6, 100).toDouble(),
                              decoration: BoxDecoration(
                                color: d.minutes == 0
                                    ? scheme.onSurface.withValues(alpha: .12)
                                    : scheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (byBook.isNotEmpty) ...[
                Text('Tiempo por libro', style: theme.textTheme.titleSmall),
                for (final e in byBook.take(8))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      books.where((b) => b.id == e.key).firstOrNull?.title ??
                          'Libro eliminado',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(mins(e.value)),
                  ),
              ],
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Borrar estadísticas'),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Borrar estadísticas'),
                        content: const Text(
                            'Se borrará todo el historial de lectura. Tus libros y notas no se tocan.'),
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
                    if (ok == true) ref.read(statsProvider.notifier).clear();
                  },
                ),
              ),
              const SizedBox(height: 32),
            ]),
    );
  }
}
