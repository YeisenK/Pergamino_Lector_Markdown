import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'voice_catalog.dart';

class VoiceStatus {
  final bool installed;
  final double? progress; // 0..1 descargando, null si no
  final bool extracting;
  final String? error;
  const VoiceStatus({this.installed = false, this.progress, this.extracting = false, this.error});
}

final voiceStoreProvider =
    NotifierProvider<VoiceStore, Map<String, VoiceStatus>>(VoiceStore.new);

class VoiceStore extends Notifier<Map<String, VoiceStatus>> {
  @override
  Map<String, VoiceStatus> build() {
    _scan();
    return {};
  }

  Future<Directory> _root() async => Directory(
      p.join((await getApplicationSupportDirectory()).path, 'voices'));

  Future<Directory> dirOf(String id) async => Directory(p.join((await _root()).path, id));

  Future<void> _scan() async {
    final next = <String, VoiceStatus>{};
    for (final v in piperCatalog) {
      next[v.id] = VoiceStatus(installed: await isInstalled(v.id));
    }
    state = next;
  }

  Future<bool> isInstalled(String id) async {
    final d = await dirOf(id);
    return File(p.join(d.path, 'tokens.txt')).existsSync() &&
        Directory(p.join(d.path, 'espeak-ng-data')).existsSync() &&
        d.listSync().any((f) => f.path.endsWith('.onnx'));
  }

  /// Rutas que necesita sherpa-onnx para una voz instalada.
  Future<({String model, String tokens, String dataDir})> paths(String id) async {
    final d = await dirOf(id);
    final model = d.listSync().firstWhere((f) => f.path.endsWith('.onnx')).path;
    return (
      model: model,
      tokens: p.join(d.path, 'tokens.txt'),
      dataDir: p.join(d.path, 'espeak-ng-data'),
    );
  }

  void _set(String id, VoiceStatus s) => state = {...state, id: s};

  Future<void> download(PiperVoice v) async {
    _set(v.id, const VoiceStatus(progress: 0));
    final tmp = File(p.join((await getTemporaryDirectory()).path, '${v.id}.tar.bz2'));
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
      final req = await client.getUrl(Uri.parse(v.url));
      final res = await req.close();
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      final total = res.contentLength;
      var got = 0;
      final sink = tmp.openWrite();
      await for (final chunk in res) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) _set(v.id, VoiceStatus(progress: got / total));
      }
      await sink.close();
      client.close();

      _set(v.id, const VoiceStatus(progress: 1, extracting: true));
      final dest = await dirOf(v.id);
      if (dest.existsSync()) dest.deleteSync(recursive: true);
      await compute(_extract, [tmp.path, dest.path]);
      _set(v.id, VoiceStatus(installed: await isInstalled(v.id)));
    } catch (e) {
      _set(v.id, VoiceStatus(error: 'No se pudo descargar: $e'));
    } finally {
      if (tmp.existsSync()) tmp.deleteSync();
    }
  }

  Future<void> remove(String id) async {
    final d = await dirOf(id);
    if (d.existsSync()) d.deleteSync(recursive: true);
    _set(id, const VoiceStatus());
  }
}

/// Descomprime el .tar.bz2 quitando la carpeta raíz del paquete.
void _extract(List<String> args) {
  final bytes = File(args[0]).readAsBytesSync();
  final tar = BZip2Decoder().decodeBytes(bytes);
  final archive = TarDecoder().decodeBytes(tar);
  for (final f in archive) {
    final parts = p.split(f.name)..removeAt(0);
    if (parts.isEmpty) continue;
    final out = p.joinAll([args[1], ...parts]);
    if (f.isFile) {
      File(out)
        ..createSync(recursive: true)
        ..writeAsBytesSync(f.content as List<int>);
    } else {
      Directory(out).createSync(recursive: true);
    }
  }
}
