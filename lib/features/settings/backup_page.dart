import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart' show getExternalStorageDirectory, getApplicationDocumentsDirectory;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/auto_backup.dart';
import '../../data/backup.dart';
import '../../data/bookmarks.dart';
import '../../data/book_repository.dart';
import '../../data/features.dart';
import '../../data/highlights.dart';
import '../../data/library_prefs.dart';
import '../../data/gestures.dart';
import '../../data/reading_speed.dart';
import '../../data/stats_repository.dart';
import '../../tts/read_aloud.dart';
import '../../data/settings.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;
  String? _message;

  String get _fileName {
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Pergamino-${d.year}-${two(d.month)}-${two(d.day)}.pergamino';
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final bytes = buildBackup(prefs);
      final saved = await FilePicker.saveFile(
        fileName: _fileName,
        bytes: bytes,
      );
      setState(() => _message = saved == null
          ? 'Exportación cancelada.'
          : 'Copia guardada (${(bytes.length / 1048576).toStringAsFixed(1)} MB).');
    } catch (e) {
      setState(() => _message = 'No se pudo crear la copia: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Restaurar copia'),
        content: const Text(
            'Los libros nuevos se añaden a tu biblioteca. Los ajustes y funciones se reemplazan con los de la copia. No se borra nada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Restaurar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final res = await FilePicker.pickFiles(type: FileType.any);
      if (res.isEmpty || res.first.path == null) {
        setState(() => _busy = false);
        return;
      }
      final bytes = await File(res.first.path!).readAsBytes();
      final prefs = await SharedPreferences.getInstance();
      final docs = await getApplicationDocumentsDirectory();
      final r = await restoreBackup(bytes,
          prefs: prefs,
          booksDir: Directory(p.join(docs.path, 'books')),
          coversDir: Directory(p.join(docs.path, 'covers')));
      // los notifiers leen las preferencias al crearse: se recargan
      ref.invalidate(booksProvider);
      ref.invalidate(bookmarksProvider);
      ref.invalidate(highlightsProvider);
      ref.invalidate(settingsProvider);
      ref.invalidate(featuresProvider);
      ref.invalidate(libraryViewProvider);
      ref.invalidate(readingWpmProvider);
      ref.invalidate(statsProvider);
      ref.invalidate(statsGoalProvider);
      ref.invalidate(gesturesProvider);
      ref.invalidate(ttsVoiceProvider);
      ref.invalidate(ttsRateProvider);
      setState(() => _message =
          'Restaurado: ${r.booksAdded} libros nuevos, ${r.booksSkipped} ya existían, ${r.marksAdded} marcas o subrayados añadidos.');
    } on BackupException catch (e) {
      setState(() => _message = '$e');
    } catch (e) {
      setState(() => _message = 'No se pudo restaurar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Copia de seguridad')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(
          'Guarda en tu teléfono un archivo con tu biblioteca, progreso, marcadores, subrayados, notas y ajustes. Sin nube: tú decides dónde se guarda, por ejemplo en Descargas.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Text(
          'Aviso: el archivo contiene el texto completo de tus libros. Guárdalo en un lugar que solo tú controles.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _busy ? null : _export,
          icon: const Icon(Icons.save_alt),
          label: const Text('Crear copia en el teléfono'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _restore,
          icon: const Icon(Icons.restore),
          label: const Text('Restaurar desde una copia'),
        ),
        const SizedBox(height: 28),
        const Divider(),
        Text('Copia automática', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Cada 7 días, al abrir Pergamino, se guarda una copia dentro del almacenamiento de la app (se conservan las 3 últimas). Para tener una copia fuera del teléfono, usa «Crear copia en el teléfono» de arriba.',
          style: theme.textTheme.bodySmall,
        ),
        Builder(builder: (context) {
          final auto = ref.watch(autoBackupProvider);
          final folder = auto.folder;
          return Column(children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Copia automática semanal'),
              subtitle: Text(folder == null
                  ? 'Desactivada'
                  : '$folder${auto.last == null ? '' : ' · última: ${auto.last!.day}/${auto.last!.month}'}'),
              value: folder != null,
              onChanged: (v) async {
                if (!v) {
                  ref.read(autoBackupProvider.notifier).setFolder(null);
                  return;
                }
                // Carpeta propia de la app: Android no deja escribir en otras carpetas sin permisos especiales.
                final base = await getExternalStorageDirectory() ??
                    await getApplicationDocumentsDirectory();
                ref
                    .read(autoBackupProvider.notifier)
                    .setFolder(p.join(base.path, 'copias-automaticas'));
              },
            ),
            if (folder != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Hacer una copia automática ahora'),
                  onPressed: () async {
                    final msg = await runAutoBackupIfDue(
                        await SharedPreferences.getInstance(), DateTime.now(),
                        force: true);
                    if (mounted) setState(() => _message = msg);
                  },
                ),
              ),
          ]);
        }),
        if (_busy) ...[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ],
        if (_message != null) ...[
          const SizedBox(height: 24),
          Text(_message!, style: theme.textTheme.bodyMedium),
        ],
      ]),
    );
  }
}
