import '../../domain/chapter.dart';

/// Divide un documento Markdown en capítulos según encabezados # y ##,
/// ignorando los que aparecen dentro de bloques de código.
List<Chapter> parseChapters(String text) {
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  final chapters = <Chapter>[];
  final buf = StringBuffer();
  String title = '';
  var level = 1;
  var inFence = false;
  final head = RegExp(r'^(#{1,2})\s+(.+?)\s*#*\s*$');

  void flush() {
    final body = buf.toString();
    if (body.trim().isNotEmpty) {
      chapters.add(Chapter(
          title: title.isEmpty ? 'Inicio' : title, level: level, markdown: body));
    }
    buf.clear();
  }

  for (final line in lines) {
    if (line.trimLeft().startsWith('```') || line.trimLeft().startsWith('~~~')) {
      inFence = !inFence;
    }
    final m = inFence ? null : head.firstMatch(line);
    if (m != null) {
      flush();
      title = m.group(2)!.replaceAll(RegExp(r'[*_`]'), '');
      level = m.group(1)!.length;
    }
    buf.writeln(line);
  }
  flush();
  return chapters;
}
