import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings.dart';

enum TapZone {
  left('Izquierda'),
  center('Centro'),
  right('Derecha');

  const TapZone(this.label);
  final String label;
}

enum GestureAction {
  none('Sin acción'),
  toggleControls('Mostrar / ocultar controles'),
  scrollUp('Subir una pantalla'),
  scrollDown('Bajar una pantalla'),
  pagePrev('Página anterior (paginado)'),
  pageNext('Página siguiente (paginado)'),
  voicePlayPause('Reproducir / pausar voz');

  const GestureAction(this.label);
  final String label;

  /// Las acciones de página solo tienen sentido con el modo paginado.
  bool get needsPaged => this == pagePrev || this == pageNext;
}

/// Acción por defecto de cada zona: el centro muestra los controles, como siempre.
const defaultZones = {
  TapZone.left: GestureAction.none,
  TapZone.center: GestureAction.toggleControls,
  TapZone.right: GestureAction.none,
};

const _kZones = 'gesture_zones_v1';

final gesturesProvider =
    NotifierProvider<GesturesNotifier, Map<TapZone, GestureAction>>(GesturesNotifier.new);

class GesturesNotifier extends Notifier<Map<TapZone, GestureAction>> {
  @override
  Map<TapZone, GestureAction> build() {
    final raw = ref.read(prefsProvider).getString(_kZones);
    if (raw == null) return Map.of(defaultZones);
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final z in TapZone.values)
          z: GestureAction.values.asNameMap()[m[z.name]] ?? defaultZones[z]!,
      };
    } catch (_) {
      return Map.of(defaultZones);
    }
  }

  void set(TapZone z, GestureAction a) {
    state = {...state, z: a};
    ref.read(prefsProvider).setString(
        _kZones, jsonEncode({for (final e in state.entries) e.key.name: e.value.name}));
  }

  void reset() {
    state = Map.of(defaultZones);
    ref.read(prefsProvider).remove(_kZones);
  }
}

/// Zona según la posición horizontal del toque.
TapZone zoneAt(double x, double width) {
  final f = x / width;
  if (f < 1 / 3) return TapZone.left;
  if (f > 2 / 3) return TapZone.right;
  return TapZone.center;
}
