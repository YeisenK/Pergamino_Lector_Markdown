/// Divide un texto en frases (rangos [inicio, fin) sobre el texto original),
/// pensadas para sintetizar y resaltar una a una.
List<(int, int)> splitSentences(String t, {int minLen = 18, int maxLen = 240}) {
  final raw = <(int, int)>[];
  void push(int a, int b) {
    while (a < b && t[a].trim().isEmpty) {
      a++;
    }
    while (b > a && t[b - 1].trim().isEmpty) {
      b--;
    }
    if (b > a && RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(t.substring(a, b))) {
      raw.add((a, b));
    }
  }

  var start = 0;
  final re = RegExp(r'[.!?…]+["»”’)\]]*(?=\s|$)|\n');
  for (final m in re.allMatches(t)) {
    push(start, m.end);
    start = m.end;
  }
  push(start, t.length);

  // une fragmentos muy cortos con el siguiente («—No.», «Sí.»)
  final merged = <(int, int)>[];
  for (var i = 0; i < raw.length; i++) {
    var cur = raw[i];
    while (cur.$2 - cur.$1 < minLen && i + 1 < raw.length) {
      cur = (cur.$1, raw[++i].$2);
    }
    merged.add(cur);
  }

  // parte las frases larguísimas en comas, punto y coma o espacios
  final out = <(int, int)>[];
  for (var (a, b) in merged) {
    while (b - a > maxLen) {
      final window = t.substring(a, a + maxLen);
      var cut = -1;
      for (final m in RegExp(r'[,;:]\s').allMatches(window)) {
        if (m.end >= 80) cut = m.end;
      }
      if (cut < 0) cut = window.lastIndexOf(' ');
      if (cut <= 0) cut = maxLen;
      out.add((a, a + cut));
      a += cut;
      while (a < b && t[a].trim().isEmpty) {
        a++;
      }
    }
    if (b > a) out.add((a, b));
  }
  return out;
}
