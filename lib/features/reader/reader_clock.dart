import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// «13:05» en 24 h, «1:05 p. m.» en 12 h.
String formatClock(DateTime t, {required bool use24h}) {
  final mm = t.minute.toString().padLeft(2, '0');
  if (use24h) return '${t.hour.toString().padLeft(2, '0')}:$mm';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:$mm ${t.hour < 12 ? 'a. m.' : 'p. m.'}';
}

/// Reloj pequeño que solo se redibuja al cambiar el minuto.
class ReaderClock extends StatefulWidget {
  const ReaderClock({super.key, required this.color, this.now = DateTime.now});
  final Color color;
  final DateTime Function() now; // inyectable para pruebas

  @override
  State<ReaderClock> createState() => _ReaderClockState();
}

class _ReaderClockState extends State<ReaderClock> {
  late DateTime _t;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _t = widget.now();
    _schedule();
  }

  void _schedule() {
    final n = widget.now();
    // despierta justo al empezar el siguiente minuto
    final wait = Duration(seconds: 60 - n.second, milliseconds: -n.millisecond);
    _timer = Timer(wait.isNegative ? const Duration(seconds: 1) : wait, () {
      if (!mounted) return;
      setState(() => _t = widget.now());
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
    return Semantics(
      label: 'Hora ${formatClock(_t, use24h: use24)}',
      child: ExcludeSemantics(
        child: Text(
          formatClock(_t, use24h: use24),
          style: TextStyle(
            color: widget.color,
            fontSize: 12,
            letterSpacing: .8,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
