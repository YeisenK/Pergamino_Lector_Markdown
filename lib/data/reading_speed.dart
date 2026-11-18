import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings.dart';

const _kWpm = 'reading_wpm_v1';
const defaultWpm = 220;

/// Velocidad de lectura en palabras por minuto. Empieza en 220 y se actualiza
/// con la medición de las estadísticas.
final readingWpmProvider =
    NotifierProvider<ReadingWpmNotifier, int>(ReadingWpmNotifier.new);

class ReadingWpmNotifier extends Notifier<int> {
  @override
  int build() => ref.read(prefsProvider).getInt(_kWpm) ?? defaultWpm;

  void set(int wpm) {
    final v = wpm.clamp(80, 600);
    state = v;
    ref.read(prefsProvider).setInt(_kWpm, v);
  }
}
