import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../platform/battery.dart';

/// «13:05» en 24 h, «1:05 p. m.» en 12 h.
String formatClock(DateTime t, {required bool use24h}) {
  final mm = t.minute.toString().padLeft(2, '0');
  if (use24h) return '${t.hour.toString().padLeft(2, '0')}:$mm';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:$mm ${t.hour < 12 ? 'a. m.' : 'p. m.'}';
}

/// Línea completa de la franja: hora · batería · progreso · capítulo (los que estén activos).
String clockLine({
  required String time,
  int? battery,
  bool showBattery = false,
  double? progress,
  bool showProgress = false,
  int? minutesLeft,
  String? chapter,
  bool showChapter = false,
}) {
  final parts = <String>[time];
  if (showBattery && battery != null) parts.add('$battery %');
  if (showProgress && progress != null) {
    final pct = '${(progress * 100).round()} %';
    parts.add(minutesLeft == null
        ? pct
        : '$pct  ·  quedan ${_duration(minutesLeft)}');
  }
  if (showChapter && chapter != null && chapter.isNotEmpty) parts.add(chapter);
  return parts.join('  ·  ');
}

/// «35 min» o «1 h 5 min».
String _duration(int minutes) {
  if (minutes < 60) return '~$minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '~$h h' : '~$h h $m min';
}

/// Reloj pequeño que se redibuja al cambiar el minuto. La batería se vuelve
/// a leer en cada minuto, no en bucle.
class ReaderClock extends StatefulWidget {
  const ReaderClock({
    super.key,
    required this.color,
    this.progress,
    this.minutesLeft,
    this.chapter,
    this.showBattery = false,
    this.showProgress = false,
    this.showChapter = false,
    this.now = DateTime.now,
  });
  final Color color;
  final double? progress;
  final int? minutesLeft;
  final String? chapter;
  final bool showBattery, showProgress, showChapter;
  final DateTime Function() now; // inyectable para pruebas

  @override
  State<ReaderClock> createState() => _ReaderClockState();
}

class _ReaderClockState extends State<ReaderClock> {
  late DateTime _t;
  int? _battery;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _t = widget.now();
    _refreshBattery();
    _schedule();
  }

  void _refreshBattery() {
    if (!widget.showBattery) return;
    batteryLevel().then((v) {
      if (mounted && v != _battery) setState(() => _battery = v);
    });
  }

  void _schedule() {
    final n = widget.now();
    // despierta justo al empezar el siguiente minuto
    final wait = Duration(seconds: 60 - n.second, milliseconds: -n.millisecond);
    _timer = Timer(wait.isNegative ? const Duration(seconds: 1) : wait, () {
      if (!mounted) return;
      setState(() => _t = widget.now());
      _refreshBattery();
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final text = clockLine(
      time: formatClock(_t, use24h: use24),
      battery: _battery,
      showBattery: widget.showBattery,
      progress: widget.progress,
      showProgress: widget.showProgress,
      minutesLeft: widget.minutesLeft,
      chapter: widget.chapter,
      showChapter: widget.showChapter,
    );
    return Semantics(
      label: 'Reloj: $text',
      child: ExcludeSemantics(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: widget.color,
            fontSize: 12,
            letterSpacing: .6,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
