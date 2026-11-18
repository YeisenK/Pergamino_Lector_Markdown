import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/reading_stats.dart';
import 'reading_speed.dart';
import 'settings.dart';

const _kStats = 'stats_v1';
const _kGoal = 'stats_goal_v1';
const defaultGoalMinutes = 20;

final statsProvider =
    NotifierProvider<StatsNotifier, List<ReadingSession>>(StatsNotifier.new);

class StatsNotifier extends Notifier<List<ReadingSession>> {
  @override
  List<ReadingSession> build() {
    final raw = ref.read(prefsProvider).getString(_kStats);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => ReadingSession.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void add(ReadingSession s) {
    state = [...state, s];
    _save();
    // con datos suficientes, la velocidad medida sustituye a la de 220 ppm
    final wpm = summarize(state, DateTime.now()).wpm;
    if (wpm != null) ref.read(readingWpmProvider.notifier).set(wpm);
  }

  void clear() {
    state = [];
    ref.read(prefsProvider).remove(_kStats);
  }

  void _save() => ref
      .read(prefsProvider)
      .setString(_kStats, jsonEncode(state.map((s) => s.toJson()).toList()));
}

final statsGoalProvider = NotifierProvider<StatsGoalNotifier, int>(StatsGoalNotifier.new);

class StatsGoalNotifier extends Notifier<int> {
  @override
  int build() => ref.read(prefsProvider).getInt(_kGoal) ?? defaultGoalMinutes;

  void set(int minutes) {
    state = minutes;
    ref.read(prefsProvider).setInt(_kGoal, minutes);
  }
}
