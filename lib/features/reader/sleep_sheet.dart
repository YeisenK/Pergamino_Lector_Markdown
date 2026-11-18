import 'package:material_ui/material_ui.dart';

import '../../tts/read_aloud.dart';

/// Elige cuándo se detiene la lectura en voz alta. Devuelve null si se cancela.
Future<({Duration? after, bool chapterEnd, bool cancel})?> showSleepSheet(
    BuildContext context, ReadState st) {
  return showModalBottomSheet<({Duration? after, bool chapterEnd, bool cancel})>(
    context: context,
    showDragHandle: true,
    builder: (c) {
      Widget opt(String label, ({Duration? after, bool chapterEnd, bool cancel}) v,
              {IconData icon = Icons.bedtime_outlined}) =>
          ListTile(
            leading: Icon(icon),
            title: Text(label),
            onTap: () => Navigator.pop(c, v),
          );
      return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Detener la lectura', style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          for (final m in [15, 30, 45, 60])
            opt('$m minutos', (after: Duration(minutes: m), chapterEnd: false, cancel: false)),
          opt('Al terminar el capítulo',
              (after: null, chapterEnd: true, cancel: false),
              icon: Icons.menu_book_outlined),
          if (st.sleepMode != SleepMode.none)
            opt('Cancelar temporizador',
                (after: null, chapterEnd: false, cancel: true),
                icon: Icons.close),
        ]),
      );
    },
  );
}

String sleepLabel(ReadState st, DateTime now) {
  switch (st.sleepMode) {
    case SleepMode.none:
      return '';
    case SleepMode.chapterEnd:
      return 'fin de capítulo';
    case SleepMode.after:
      final left = st.sleepLeft(now) ?? Duration.zero;
      final mm = (left.inSeconds ~/ 60).toString().padLeft(2, '0');
      final ss = (left.inSeconds % 60).toString().padLeft(2, '0');
      return '$mm:$ss';
  }
}
