import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

enum ReaderPalette {
  paper('Papel', Color(0xFFF6F0E2), Color(0xFF2B2620)),
  white('Blanco', Color(0xFFFFFFFF), Color(0xFF1A1A1A)),
  sepia('Sepia', Color(0xFFEBDDBF), Color(0xFF45341F)),
  gray('Gris', Color(0xFF2B2D31), Color(0xFFD0D1D4)),
  oled('Negro', Color(0xFF000000), Color(0xFFBDBDBD));

  const ReaderPalette(this.label, this.background, this.text);
  final String label;
  final Color background;
  final Color text;

  bool get isDark => background.computeLuminance() < 0.3;
  Color get muted => Color.alphaBlend(text.withValues(alpha: .55), background);
  Color get accent => isDark ? const Color(0xFFD9A864) : const Color(0xFF8A5A2B);
}

ThemeData buildTheme(ReaderPalette p) {
  final base = ThemeData(
    brightness: p.isDark ? Brightness.dark : Brightness.light,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.accent,
      brightness: p.isDark ? Brightness.dark : Brightness.light,
      surface: p.background,
      onSurface: p.text,
    ),
    scaffoldBackgroundColor: p.background,
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: GoogleFonts.literataTextTheme(base.textTheme)
        .apply(bodyColor: p.text, displayColor: p.text),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
  );
}
