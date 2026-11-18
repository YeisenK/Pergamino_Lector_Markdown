import 'package:flutter_test/flutter_test.dart';
import 'package:pergamino/domain/reading_stats.dart';

ReadingSession s(String id, DateTime start, int minutes, {int words = 0, String book = 'b1'}) =>
    ReadingSession(
        id: id, bookId: book, start: start, activeSeconds: minutes * 60, words: words);

void main() {
  final now = DateTime(2026, 11, 17, 12);

  test('una pausa de más de 2 minutos no cuenta como lectura', () {
    final t = ReadingTracker(bookId: 'b', now: now, startWords: 0);
    t.activity(now.add(const Duration(seconds: 30)));
    t.activity(now.add(const Duration(minutes: 10))); // gap de 9.5 min: solo cuenta 2
    expect(t.activeSeconds, 30 + 120);
  });

  test('al volver de segundo plano no se cuenta el hueco', () {
    final t = ReadingTracker(bookId: 'b', now: now, startWords: 0);
    t.pause(now.add(const Duration(seconds: 20)));
    t.resume(now.add(const Duration(hours: 3)));
    t.activity(now.add(const Duration(hours: 3, seconds: 10)));
    expect(t.activeSeconds, 30);
  });

  test('una sesión sin tiempo activo no se guarda y las palabras se restan del inicio', () {
    final t = ReadingTracker(bookId: 'b', now: now, startWords: 1000);
    expect(t.finish(id: 'x', wordsNow: 1000), isNull);
    final t2 = ReadingTracker(bookId: 'b', now: now, startWords: 1000);
    t2.activity(now.add(const Duration(minutes: 1)));
    final r = t2.finish(id: 'y', wordsNow: 1250)!;
    expect(r.words, 250);
    expect(r.activeSeconds, 60);
  });

  test('resumen: hoy, semana, mes y racha', () {
    final sessions = [
      s('1', now, 20),
      s('2', now.subtract(const Duration(days: 1)), 30),
      s('3', now.subtract(const Duration(days: 2)), 10),
      s('4', now.subtract(const Duration(days: 4)), 15), // hueco en el día 3
    ];
    final r = summarize(sessions, now);
    expect(r.todayMin, 20);
    expect(r.weekMin, 20 + 30 + 10 + 15);
    expect(r.streakDays, 3); // hoy, ayer, anteayer
    expect(r.last14.length, 14);
    expect(r.last14.last.minutes, 20);
  });

  test('la racha empieza ayer si hoy todavía no se ha leído', () {
    final r = summarize([s('1', now.subtract(const Duration(days: 1)), 5)], now);
    expect(r.streakDays, 1);
    expect(r.todayMin, 0);
  });

  test('una sesión que empieza a las 23:50 cuenta para el día en que empezó', () {
    final late = DateTime(2026, 11, 16, 23, 50);
    final r = summarize([s('1', late, 20)], DateTime(2026, 11, 17, 0, 30));
    expect(r.todayMin, 0);
    expect(r.last14[12].minutes, 20);
  });

  test('velocidad: solo con al menos 5 minutos y palabras', () {
    expect(estimateWpm(1000, 200), isNull);
    expect(estimateWpm(0, 600), isNull);
    expect(estimateWpm(2400, 600), 240);
  });

  test('libros: minutos por libro', () {
    final r = summarize([s('1', now, 20, book: 'a'), s('2', now, 5, book: 'b'), s('3', now, 10, book: 'a')], now);
    expect(r.minutesByBook['a'], 30);
    expect(r.minutesByBook['b'], 5);
  });
}
