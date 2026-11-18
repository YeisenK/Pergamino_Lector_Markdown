import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings.dart';

/// Cada función nueva se puede activar o desactivar por separado.
/// Desactivarla oculta sus controles pero no borra sus datos.
enum Feature {
  clockExtras('Reloj con batería y progreso',
      'Muestra batería, progreso y capítulo en la franja superior.', true),
  backup('Copia de seguridad',
      'Guardar y restaurar todo en un archivo del teléfono.', true),
  sleepTimer('Temporizador de sueño',
      'Detiene la lectura en voz alta a la hora que elijas.', true),
  libraryFilters('Ordenar y filtrar biblioteca',
      'Orden y pestañas: Leyendo, Sin empezar, Terminados.', true),
  timeLeft('Progreso por capítulo y tiempo restante',
      'Barras en el índice y minutos que faltan para terminar.', true),
  notesExport('Exportar y buscar notas',
      'Guardar subrayados y notas como .md, y buscarlos.', true),
  voiceSkip('Qué leer en voz alta',
      'Elegir si se leen tablas, bloques de código y notas al pie.', true),
  stats('Estadísticas de lectura',
      'Tiempo, racha y velocidad. Se guardan solo en el teléfono.', false),
  gestures('Gestos configurables',
      'Elige qué hace cada zona de la pantalla al tocarla.', false),
  paginated('Modo paginado',
      'Leer por páginas en lugar de desplazarse de forma continua.', false),
  editor('Editor de libros',
      'Corrige o escribe el texto de tus libros dentro de la app.', false),
  dictionary('Diccionario',
      'Definiciones de palabras sin conexión. Se descarga una vez.', true);

  const Feature(this.label, this.hint, this.defaultOn);
  final String label;
  final String hint;
  final bool defaultOn;
}

const _kFeatures = 'features_v1';

final featuresProvider =
    NotifierProvider<FeaturesNotifier, Set<Feature>>(FeaturesNotifier.new);

/// Conjunto de funciones activas. Sin preferencia guardada, usa los valores por defecto.
class FeaturesNotifier extends Notifier<Set<Feature>> {
  @override
  Set<Feature> build() {
    final raw = ref.read(prefsProvider).getString(_kFeatures);
    if (raw == null) return _defaults();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final f in Feature.values)
          if (map[f.name] as bool? ?? f.defaultOn) f
      };
    } catch (_) {
      return _defaults();
    }
  }

  static Set<Feature> _defaults() =>
      {for (final f in Feature.values) if (f.defaultOn) f};

  bool isOn(Feature f) => state.contains(f);

  void set(Feature f, bool on) {
    state = on ? {...state, f} : (Set.of(state)..remove(f));
    ref.read(prefsProvider).setString(
        _kFeatures,
        jsonEncode({for (final x in Feature.values) x.name: state.contains(x)}));
  }
}
