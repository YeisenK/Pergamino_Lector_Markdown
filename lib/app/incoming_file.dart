import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/book_repository.dart';
import 'router.dart';

/// Recibe archivos .md abiertos desde otras apps («Abrir con» / compartir).
/// El lado nativo está en MainActivity.kt.
class IncomingFile {
  static const _channel = MethodChannel('pergamino/incoming');

  static void listen(WidgetRef ref) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'file') await _handle(ref, call.arguments);
    });
    // archivo con el que se lanzó la app
    _channel.invokeMethod('initial').then((v) => _handle(ref, v)).catchError((_) {});
  }

  static Future<void> _handle(WidgetRef ref, Object? args) async {
    if (args is! Map) return;
    final path = args['path'] as String?;
    if (path == null) return;
    final name = args['name'] as String?;
    try {
      final book = await ref
          .read(booksProvider.notifier)
          .importFile(File(path), name: name);
      router.go('/');
      router.push('/read/${book.id}');
    } catch (_) {}
  }
}
