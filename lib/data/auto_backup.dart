import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup.dart';
import 'settings.dart';

const autoBackupEvery = Duration(days: 7);
const autoBackupKeep = 3;
const _kAuto = 'auto_backup_v1';

/// ¿Toca una copia? Si nunca se hizo, sí; si no, cuando pasa [every] desde la última.
bool autoBackupDue(DateTime? last, DateTime now, {Duration every = autoBackupEvery}) =>
    last == null || now.difference(last) >= every;

/// Nombre de la copia automática de un día.
String autoBackupName(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'Pergamino-auto-${d.year}-${two(d.month)}-${two(d.day)}.pergamino';
}

/// Copias automáticas a borrar: se conservan las [keep] más recientes.
List<String> autoBackupsToDelete(List<String> names, {int keep = autoBackupKeep}) {
  final autos = names.where((n) => RegExp(r'^Pergamino-auto-\d{4}-\d{2}-\d{2}\.pergamino$').hasMatch(n)).toList()
    ..sort((a, b) => b.compareTo(a)); // la fecha va en el nombre: más reciente primero
  return autos.length <= keep ? [] : autos.sublist(keep);
}

class AutoBackupConfig {
  final String? folder;
  final DateTime? last;
  final String? error;
  const AutoBackupConfig({this.folder, this.last, this.error});

  Map<String, dynamic> toJson() => {
        'folder': folder,
        'last': last?.toIso8601String(),
      };

  factory AutoBackupConfig.fromJson(Map<String, dynamic> j) => AutoBackupConfig(
        folder: j['folder'] as String?,
        last: j['last'] == null ? null : DateTime.parse(j['last'] as String),
      );
}

/// Ejecuta la copia automática si toca. Devuelve un mensaje para mostrar, o null si no hizo nada.
Future<String?> runAutoBackupIfDue(SharedPreferences prefs, DateTime now,
    {bool force = false}) async {
  final raw = prefs.getString(_kAuto);
  if (raw == null) return null;
  final cfg = AutoBackupConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  final folder = cfg.folder;
  if (folder == null || (!force && !autoBackupDue(cfg.last, now))) return null;
  try {
    final dir = Directory(folder);
    await dir.create(recursive: true);
    final bytes = buildBackup(prefs);
    await File('${dir.path}/${autoBackupName(now)}').writeAsBytes(bytes);
    for (final n in autoBackupsToDelete(dir.listSync().map((e) => e.uri.pathSegments.last).toList())) {
      await File('${dir.path}/$n').delete();
    }
    await prefs.setString(_kAuto, jsonEncode(AutoBackupConfig(folder: folder, last: now).toJson()));
    return 'Copia automática guardada.';
  } catch (e) {
    await prefs.setString(_kAuto, jsonEncode(AutoBackupConfig(folder: folder, last: cfg.last).toJson()));
    return 'No se pudo guardar la copia automática en esa carpeta: $e';
  }
}

final autoBackupProvider =
    NotifierProvider<AutoBackupNotifier, AutoBackupConfig>(AutoBackupNotifier.new);

class AutoBackupNotifier extends Notifier<AutoBackupConfig> {
  @override
  AutoBackupConfig build() {
    final raw = ref.read(prefsProvider).getString(_kAuto);
    if (raw == null) return const AutoBackupConfig();
    try {
      return AutoBackupConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AutoBackupConfig();
    }
  }

  void setFolder(String? folder) {
    state = AutoBackupConfig(folder: folder, last: state.last);
    ref.read(prefsProvider).setString(_kAuto, jsonEncode(state.toJson()));
  }
}
