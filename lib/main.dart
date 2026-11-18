import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/incoming_file.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'data/auto_backup.dart';
import 'data/features.dart';
import 'data/settings.dart';

final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Las fuentes van dentro de la app (google_fonts/); nunca se descargan.
  GoogleFonts.config.allowRuntimeFetching = false;
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const PergaminoApp(),
  ));
}

class PergaminoApp extends ConsumerStatefulWidget {
  const PergaminoApp({super.key});

  @override
  ConsumerState<PergaminoApp> createState() => _PergaminoAppState();
}

class _PergaminoAppState extends ConsumerState<PergaminoApp> {
  @override
  void initState() {
    super.initState();
    IncomingFile.listen(ref);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!ref.read(featuresProvider).contains(Feature.backup)) return;
      final msg = await runAutoBackupIfDue(ref.read(prefsProvider), DateTime.now());
      if (msg != null) {
        rootMessengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(msg)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final p = s.palette;
    return MaterialApp.router(
      scaffoldMessengerKey: rootMessengerKey,
      title: 'Pergamino',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(p ?? ReaderPalette.paper),
      darkTheme: buildTheme(p ?? ReaderPalette.oled),
      themeMode: p == null
          ? ThemeMode.system
          : (p.isDark ? ThemeMode.dark : ThemeMode.light),
      routerConfig: router,
    );
  }
}
