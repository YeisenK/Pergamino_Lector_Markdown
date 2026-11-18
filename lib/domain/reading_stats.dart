// Estadísticas de lectura. Todo se calcula en el teléfono; nada sale de él.

/// Pasado este tiempo sin actividad, la sesión deja de contar.
const idleLimit = Duration(minutes: 2);

class ReadingSession {
  final String id;
  final String bookId;
  final DateTime start; // inicio local de la sesión
  final int activeSeconds;
  final int words;
  const ReadingSession({
    required this.id,
    required this.bookId,
    required this.start,
    required this.activeSeconds,
    required this.words,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'start': start.toIso8601String(),
        'activeSeconds': activeSeconds,
        'words': words,
      };

  factory ReadingSession.fromJson(Map<String, dynamic> j) => ReadingSession(
        id: j['id'] as String,
        bookId: j['bookId'] as String,
        start: DateTime.parse(j['start'] as String),
        activeSeconds: j['activeSeconds'] as int,
        words: j['words'] as int,
      );
}

/// Cuenta el tiempo activo de una sesión. Cada actividad (toque, desplazamiento,
/// voz) suma el tiempo desde la anterior, pero nunca más de [idleLimit].
class ReadingTracker {
  ReadingTracker({required this.bookId, required DateTime now, required this.startWords})
      : start = now,
        _last = now;

  final String bookId;
  final DateTime start;
  final int startWords; // palabras ya leídas al empezar (progreso × total)
  DateTime _last;
  double _active = 0; // segundos
  bool _paused = false;
  int _lastWords = 0;

  /// Registra actividad. Si pasó más que [idleLimit] desde la última, solo cuenta el límite.
  void activity(DateTime now, {int? wordsNow}) {
    if (_paused) {
      _last = now;
      _paused = false;
      return;
    }
    final gap = now.difference(_last);
    final counted = gap > idleLimit ? idleLimit : gap;
    if (!gap.isNegative) _active += counted.inMilliseconds / 1000;
    _last = now;
    if (wordsNow != null) _lastWords = wordsNow;
  }

  /// Sin actividad al volver de segundo plano: no se cuenta el hueco.
  void pause(DateTime now) {
    if (_paused) return;
    activity(now);
    _paused = true;
  }

  void resume(DateTime now) {
    _paused = false;
    _last = now;
  }

  int get activeSeconds => _active.round();

  /// Cierra la sesión. Null si no hubo tiempo activo.
  ReadingSession? finish({required String id, required int wordsNow}) {
    if (_active < 1) return null;
    final words = (wordsNow - startWords).clamp(0, 1 << 30);
    _lastWords = wordsNow;
    return ReadingSession(
      id: id,
      bookId: bookId,
      start: start,
      activeSeconds: _active.round(),
      words: words,
    );
  }

  int get lastWords => _lastWords;
}

class StatsSummary {
  final int todayMin, weekMin, monthMin;
  final int streakDays;
  final List<({DateTime day, int minutes})> last14;
  final Map<String, int> minutesByBook; // ordenado de más a menos al mostrar
  final int? wpm; // velocidad medida, o null si hay pocos datos
  const StatsSummary({
    required this.todayMin,
    required this.weekMin,
    required this.monthMin,
    required this.streakDays,
    required this.last14,
    required this.minutesByBook,
    required this.wpm,
  });
}

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

StatsSummary summarize(List<ReadingSession> all, DateTime now) {
  final today = dayOf(now);
  final minutesByDay = <DateTime, int>{};
  final byBook = <String, int>{};
  var words = 0, seconds = 0;
  for (final s in all) {
    final d = dayOf(s.start);
    minutesByDay[d] = (minutesByDay[d] ?? 0) + (s.activeSeconds / 60).round();
    byBook[s.bookId] = (byBook[s.bookId] ?? 0) + (s.activeSeconds / 60).round();
    if (now.difference(s.start).inDays < 30) {
      words += s.words;
      seconds += s.activeSeconds;
    }
  }
  int sumDays(int from, int to) {
    var m = 0;
    for (var i = from; i <= to; i++) {
      m += minutesByDay[today.subtract(Duration(days: i))] ?? 0;
    }
    return m;
  }

  // racha: días seguidos con lectura, empezando hoy (o ayer si hoy aún no hay)
  var streak = 0;
  var cursor = (minutesByDay[today] ?? 0) > 0 ? today : today.subtract(const Duration(days: 1));
  while ((minutesByDay[cursor] ?? 0) > 0) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  final last14 = [
    for (var i = 13; i >= 0; i--)
      (day: today.subtract(Duration(days: i)), minutes: minutesByDay[today.subtract(Duration(days: i))] ?? 0),
  ];
  final monthStart = DateTime(today.year, today.month, 1);
  var month = 0;
  minutesByDay.forEach((d, m) {
    if (!d.isBefore(monthStart) && !d.isAfter(today)) month += m;
  });

  return StatsSummary(
    todayMin: minutesByDay[today] ?? 0,
    weekMin: sumDays(0, 6),
    monthMin: month,
    streakDays: streak,
    last14: last14,
    minutesByBook: byBook,
    wpm: estimateWpm(words, seconds),
  );
}

/// Palabras por minuto medidas. Hace falta al menos 5 minutos de datos.
int? estimateWpm(int words, int seconds) {
  if (seconds < 300 || words <= 0) return null;
  final wpm = (words / (seconds / 60)).round();
  return wpm.clamp(80, 600);
}
