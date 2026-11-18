import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Diccionario de español sin conexión. El archivo tiene una línea por palabra,
/// ordenada por clave: `clave<TAB>[{"w":…,"p":…,"g":[…]}]`. Se busca con búsqueda
/// binaria sobre el archivo, sin cargarlo en memoria.
/// Datos: Wiktionary en español vía kaikki.org (CC BY-SA 4.0).

const dictionaryUrl =
    'https://github.com/YeisenK/Pergamino_Lector_Markdown/releases/download/diccionario-es-v1/es.txt.gz';
const dictionaryDownloadMb = 11;
const dictionaryInstalledMb = 125;

class DictEntry {
  final String word;
  final String pos;
  final List<String> glosses;
  const DictEntry(this.word, this.pos, this.glosses);

  factory DictEntry.fromJson(Map<String, dynamic> j) => DictEntry(
        j['w'] as String,
        j['p'] as String,
        (j['g'] as List).cast<String>(),
      );
}

/// Clave de búsqueda, igual que en el generador: minúsculas, sin acentos, solo a-z, 0-9, guion y apóstrofo.
String dictKey(String word) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñç';
  const to = 'aaaaeeeeiiiiooooouuuunc';
  final sb = StringBuffer();
  for (final ch in word.toLowerCase().runes) {
    final c = String.fromCharCode(ch);
    final i = from.indexOf(c);
    final mapped = i >= 0 ? to[i] : c;
    if (RegExp(r"[a-z0-9\-' ]").hasMatch(mapped)) sb.write(mapped);
  }
  return sb.toString().trim();
}

/// Busca líneas en un archivo ordenado por bytes (búsqueda binaria por posiciones).
class SortedLineFile {
  SortedLineFile(this.path);
  final String path;

  /// Línea completa que empieza en [pos] (sin el salto de línea), y su longitud en bytes.
  static String _readLine(RandomAccessFile raf, int pos, int fileLen) {
    raf.setPositionSync(pos);
    final out = <int>[];
    while (true) {
      final chunk = raf.readSync(4096);
      if (chunk.isEmpty) break;
      final nl = chunk.indexOf(10);
      if (nl >= 0) {
        out.addAll(chunk.sublist(0, nl));
        break;
      }
      out.addAll(chunk);
    }
    return utf8.decode(out, allowMalformed: true);
  }

  /// Primer inicio de línea a partir de [pos] (incluido).
  static int _lineStartAtOrAfter(RandomAccessFile raf, int pos, int fileLen) {
    if (pos <= 0) return 0;
    raf.setPositionSync(pos - 1);
    final prev = raf.readSync(1);
    if (prev.isNotEmpty && prev[0] == 10) return pos;
    var p = pos;
    raf.setPositionSync(p);
    while (true) {
      final chunk = raf.readSync(4096);
      if (chunk.isEmpty) return fileLen;
      final nl = chunk.indexOf(10);
      if (nl >= 0) return p + nl + 1;
      p += chunk.length;
    }
  }

  /// Línea cuya clave (antes del tabulador) es [key], o null.
  /// Invariante: todas las líneas antes de [lo] tienen clave menor que [key].
  String? find(String key) {
    final f = File(path);
    if (!f.existsSync()) return null;
    final raf = f.openSync();
    try {
      final len = raf.lengthSync();
      var lo = 0, hi = len;
      while (hi - lo > 8192) {
        final mid = lo + (hi - lo) ~/ 2;
        final start = _lineStartAtOrAfter(raf, mid, len);
        if (start >= hi) {
          hi = mid;
          continue;
        }
        final line = _readLine(raf, start, len);
        final tab = line.indexOf('\t');
        final k = tab < 0 ? line : line.substring(0, tab);
        if (k.compareTo(key) < 0) {
          lo = start + utf8.encode(line).length + 1;
        } else {
          hi = mid;
        }
      }
      // búsqueda lineal corta desde [lo]
      var pos = lo;
      while (pos < len) {
        final line = _readLine(raf, pos, len);
        final tab = line.indexOf('\t');
        if (tab < 0) return null;
        final k = line.substring(0, tab);
        if (k == key) return line.substring(tab + 1);
        if (k.compareTo(key) > 0) return null;
        pos += utf8.encode(line).length + 1;
      }
      return null;
    } finally {
      raf.closeSync();
    }
  }
}

/// Definiciones de una palabra. Vacía si no está o si el diccionario no está instalado.
List<DictEntry> lookupIn(SortedLineFile file, String word) {
  final key = dictKey(word);
  if (key.isEmpty) return const [];
  final json = file.find(key);
  if (json == null) return const [];
  return (jsonDecode(json) as List)
      .map((e) => DictEntry.fromJson(e as Map<String, dynamic>))
      .toList();
}

class DictionaryStore {
  static Future<File> file() async {
    final dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'dict', 'es.txt'));
  }

  static Future<bool> installed() async => (await file()).existsSync();

  static Future<List<DictEntry>> lookup(String word) async {
    final f = await file();
    if (!f.existsSync()) return const [];
    return lookupIn(SortedLineFile(f.path), word);
  }
}

/// Estado de la descarga del diccionario.
class DictStatus {
  final bool installed;
  final double? progress; // 0..1 durante la descarga
  final String? error;
  const DictStatus({this.installed = false, this.progress, this.error});
}

final dictionaryProvider =
    NotifierProvider<DictionaryNotifier, DictStatus>(DictionaryNotifier.new);

class DictionaryNotifier extends Notifier<DictStatus> {
  @override
  DictStatus build() {
    _check();
    return const DictStatus();
  }

  Future<void> _check() async {
    state = DictStatus(installed: await DictionaryStore.installed());
  }

  Future<void> download() async {
    state = const DictStatus(progress: 0);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await client.getUrl(Uri.parse(dictionaryUrl));
      final res = await req.close();
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      final dest = await DictionaryStore.file();
      await dest.parent.create(recursive: true);
      final tmp = File('${dest.path}.part');
      final total = res.contentLength;
      var got = 0;
      final sink = tmp.openWrite();
      await for (final chunk in res) {
        got += chunk.length;
        sink.add(chunk);
        if (total > 0) state = DictStatus(progress: got / total);
      }
      await sink.close();
      // descomprime a su sitio definitivo
      final out = dest.openWrite();
      await tmp.openRead().transform(gzip.decoder).pipe(out);
      await tmp.delete();
      state = const DictStatus(installed: true);
    } catch (e) {
      state = DictStatus(error: 'No se pudo descargar el diccionario: $e');
    } finally {
      client.close();
    }
  }

  Future<void> remove() async {
    final f = await DictionaryStore.file();
    if (f.existsSync()) f.deleteSync();
    state = const DictStatus();
  }
}
