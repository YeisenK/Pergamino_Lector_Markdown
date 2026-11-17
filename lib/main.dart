import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';

void main() => runApp(const ProviderScope(child: PergaminoApp()));

class PergaminoApp extends StatelessWidget {
  const PergaminoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pergamino',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(ReaderPalette.paper),
      darkTheme: buildTheme(ReaderPalette.oled),
      routerConfig: router,
    );
  }
}
