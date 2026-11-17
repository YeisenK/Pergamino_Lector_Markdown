import 'dart:convert';

class Book {
  final String id;
  final String title;
  final String path;
  final DateTime addedAt;
  final DateTime? lastOpened;
  final double progress; // 0..1

  const Book({
    required this.id,
    required this.title,
    required this.path,
    required this.addedAt,
    this.lastOpened,
    this.progress = 0,
  });

  Book copyWith({String? title, DateTime? lastOpened, double? progress}) => Book(
        id: id,
        title: title ?? this.title,
        path: path,
        addedAt: addedAt,
        lastOpened: lastOpened ?? this.lastOpened,
        progress: progress ?? this.progress,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'path': path,
        'addedAt': addedAt.toIso8601String(),
        'lastOpened': lastOpened?.toIso8601String(),
        'progress': progress,
      };

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: j['id'] as String,
        title: j['title'] as String,
        path: j['path'] as String,
        addedAt: DateTime.parse(j['addedAt'] as String),
        lastOpened: j['lastOpened'] == null
            ? null
            : DateTime.parse(j['lastOpened'] as String),
        progress: (j['progress'] as num?)?.toDouble() ?? 0,
      );

  static String encodeList(List<Book> books) =>
      jsonEncode(books.map((b) => b.toJson()).toList());

  static List<Book> decodeList(String s) => (jsonDecode(s) as List)
      .map((e) => Book.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// Separa «Capítulo 1 — El círculo» en (antetítulo: «Capítulo 1», título: «El círculo»)
/// usando el primer guion largo (—). Sin guion largo no hay antetítulo.
({String? kicker, String main}) splitTitle(String title) {
  final i = title.indexOf('—');
  if (i < 0) return (kicker: null, main: title.trim());
  final kicker = title.substring(0, i).trim();
  final main = title.substring(i + 1).trim();
  if (kicker.isEmpty || main.isEmpty) return (kicker: null, main: title.replaceAll('—', ' ').trim());
  return (kicker: kicker, main: main);
}
