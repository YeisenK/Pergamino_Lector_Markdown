import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme.dart';

enum ReaderFont {
  literata('Literata', 'Serif de lectura'),
  sourceSerif('Source Serif', 'Serif clásica'),
  inter('Inter', 'Sans moderna'),
  atkinson('Atkinson', 'Alta legibilidad');

  const ReaderFont(this.label, this.hint);
  final String label;
  final String hint;

  TextStyle apply(TextStyle t) => switch (this) {
        ReaderFont.literata => GoogleFonts.literata(textStyle: t),
        ReaderFont.sourceSerif => GoogleFonts.sourceSerif4(textStyle: t),
        ReaderFont.inter => GoogleFonts.inter(textStyle: t),
        ReaderFont.atkinson => GoogleFonts.atkinsonHyperlegible(textStyle: t),
      };
}

/// Noche: de las 20:00 a las 7:00.
bool isNightHour(DateTime t) => t.hour >= 20 || t.hour < 7;

class ReaderSettings {
  final double fontSize;
  final double lineHeight;
  final double margin;
  final double maxWidth;
  final ReaderFont font;
  final bool justify;
  final bool showClock;
  final bool paged; // modo paginado (requiere la función activa)
  final bool autoNight; // tema oscuro entre las 20:00 y las 7:00
  final double paraGap; // espacio entre párrafos, multiplicador de la letra
  final bool clockBattery;
  final bool clockProgress;
  final bool clockChapter;
  final bool voiceTables;
  final bool voiceCode;
  final bool voiceFootnotes;
  final ReaderPalette? palette; // null = automático (sistema)

  const ReaderSettings({
    this.fontSize = 19,
    this.lineHeight = 1.6,
    this.margin = 24,
    this.maxWidth = 680,
    this.font = ReaderFont.literata,
    this.justify = false,
    this.showClock = false,
    this.paged = false,
    this.autoNight = false,
    this.paraGap = .85,
    this.clockBattery = true,
    this.clockProgress = false,
    this.clockChapter = false,
    this.voiceTables = false,
    this.voiceCode = false,
    this.voiceFootnotes = true,
    this.palette,
  });

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? margin,
    double? maxWidth,
    ReaderFont? font,
    bool? justify,
    bool? showClock,
    bool? paged,
    bool? autoNight,
    double? paraGap,
    bool? clockBattery,
    bool? clockProgress,
    bool? clockChapter,
    bool? voiceTables,
    bool? voiceCode,
    bool? voiceFootnotes,
    ReaderPalette? palette,
    bool autoPalette = false,
  }) =>
      ReaderSettings(
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        margin: margin ?? this.margin,
        maxWidth: maxWidth ?? this.maxWidth,
        font: font ?? this.font,
        justify: justify ?? this.justify,
        showClock: showClock ?? this.showClock,
        paged: paged ?? this.paged,
        autoNight: autoNight ?? this.autoNight,
        paraGap: paraGap ?? this.paraGap,
        clockBattery: clockBattery ?? this.clockBattery,
        clockProgress: clockProgress ?? this.clockProgress,
        clockChapter: clockChapter ?? this.clockChapter,
        voiceTables: voiceTables ?? this.voiceTables,
        voiceCode: voiceCode ?? this.voiceCode,
        voiceFootnotes: voiceFootnotes ?? this.voiceFootnotes,
        palette: autoPalette ? null : (palette ?? this.palette),
      );

  /// Paleta efectiva según el brillo del sistema cuando está en automático.
  ReaderPalette resolve(Brightness system, {DateTime? now}) {
    if (autoNight && isNightHour(now ?? DateTime.now())) return ReaderPalette.oled;
    return palette ??
        (system == Brightness.dark ? ReaderPalette.oled : ReaderPalette.paper);
  }

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'margin': margin,
        'maxWidth': maxWidth,
        'font': font.name,
        'justify': justify,
        'showClock': showClock,
        'paged': paged,
        'autoNight': autoNight,
        'paraGap': paraGap,
        'clockBattery': clockBattery,
        'clockProgress': clockProgress,
        'clockChapter': clockChapter,
        'voiceTables': voiceTables,
        'voiceCode': voiceCode,
        'voiceFootnotes': voiceFootnotes,
        'palette': palette?.name,
      };

  factory ReaderSettings.fromJson(Map<String, dynamic> j) {
    const d = ReaderSettings();
    double n(String k, double def, double lo, double hi) =>
        ((j[k] as num?)?.toDouble() ?? def).clamp(lo, hi);
    return ReaderSettings(
      fontSize: n('fontSize', d.fontSize, 12, 36),
      lineHeight: n('lineHeight', d.lineHeight, 1.1, 2.4),
      margin: n('margin', d.margin, 8, 72),
      maxWidth: n('maxWidth', d.maxWidth, 420, 960),
      font: ReaderFont.values.asNameMap()[j['font']] ?? d.font,
      justify: j['justify'] as bool? ?? d.justify,
      showClock: j['showClock'] as bool? ?? d.showClock,
      paged: j['paged'] as bool? ?? d.paged,
      autoNight: j['autoNight'] as bool? ?? d.autoNight,
      paraGap: n('paraGap', d.paraGap, .3, 2.0),
      clockBattery: j['clockBattery'] as bool? ?? d.clockBattery,
      clockProgress: j['clockProgress'] as bool? ?? d.clockProgress,
      clockChapter: j['clockChapter'] as bool? ?? d.clockChapter,
      voiceTables: j['voiceTables'] as bool? ?? d.voiceTables,
      voiceCode: j['voiceCode'] as bool? ?? d.voiceCode,
      voiceFootnotes: j['voiceFootnotes'] as bool? ?? d.voiceFootnotes,
      palette: ReaderPalette.values.asNameMap()[j['palette']],
    );
  }
}

final prefsProvider = Provider<SharedPreferences>(
    (ref) => throw UnimplementedError('prefsProvider sin override'));

const _kSettings = 'reader_settings_v1';

final settingsProvider =
    NotifierProvider<SettingsNotifier, ReaderSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<ReaderSettings> {
  @override
  ReaderSettings build() {
    final raw = ref.read(prefsProvider).getString(_kSettings);
    if (raw == null) return const ReaderSettings();
    try {
      return ReaderSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ReaderSettings();
    }
  }

  void update(ReaderSettings s) {
    state = s;
    ref.read(prefsProvider).setString(_kSettings, jsonEncode(s.toJson()));
  }

  void reset() => update(ReaderSettings(palette: state.palette));
}
