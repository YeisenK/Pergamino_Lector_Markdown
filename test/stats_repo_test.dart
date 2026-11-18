import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pergamino/data/reading_speed.dart';
import 'package:pergamino/data/settings.dart';
import 'package:pergamino/data/stats_repository.dart';
import 'package:pergamino/domain/reading_stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('guarda sesiones, actualiza la velocidad y borra todo', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    final repo = c.read(statsProvider.notifier);

    repo.add(ReadingSession(
        id: '1', bookId: 'b', start: DateTime.now(), activeSeconds: 600, words: 2400));
    expect(c.read(statsProvider).length, 1);
    expect(c.read(readingWpmProvider), 240); // 2400 palabras en 10 min
    expect(prefs.getString('stats_v1'), contains('"words":2400'));

    // sobrevive a reiniciar el contenedor (se lee de SharedPreferences)
    final c2 = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(c2.dispose);
    expect(c2.read(statsProvider).single.id, '1');

    c.read(statsProvider.notifier).clear();
    expect(c.read(statsProvider), isEmpty);
    expect(prefs.getString('stats_v1'), isNull);
  });

  test('la meta diaria tiene 20 minutos por defecto y se puede cambiar', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    expect(c.read(statsGoalProvider), 20);
    c.read(statsGoalProvider.notifier).set(45);
    expect(c.read(statsGoalProvider), 45);
  });
}
