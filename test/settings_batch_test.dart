import 'package:material_ui/material_ui.dart' show Brightness;
import 'package:flutter_test/flutter_test.dart';
import 'package:pergamino/app/theme.dart';
import 'package:pergamino/data/settings.dart';
import 'package:pergamino/features/reader/reader_content.dart';

void main() {
  test('modo noche automático elige el tema oscuro de noche', () {
    const s = ReaderSettings(autoNight: true, palette: ReaderPalette.sepia);
    expect(s.resolve(Brightness.light, now: DateTime(2026, 1, 1, 22)), ReaderPalette.oled);
    expect(s.resolve(Brightness.light, now: DateTime(2026, 1, 1, 12)), ReaderPalette.sepia);
    expect(isNightHour(DateTime(2026, 1, 1, 6, 59)), isTrue);
    expect(isNightHour(DateTime(2026, 1, 1, 7)), isFalse);
  });

  test('el espacio entre párrafos se guarda', () {
    final s = ReaderSettings.fromJson(const ReaderSettings(paraGap: 1.4).toJson());
    expect(s.paraGap, 1.4);
    expect(ReaderSettings.fromJson({'paraGap': 99}).paraGap, 2.0);
  });

  test('las notas al pie se convierten en párrafos visibles', () {
    expect(footnotesAsParagraphs('Texto[^1].\n\n[^1]: Nota aquí.'),
        'Texto[^1].\n\n[^1] Nota aquí.');
    final c = parseBookText('Un texto[^1].\n\n[^1]: Explicación.');
    final texts = c.blocks.map((b) => b.textContent).join(' ');
    expect(texts, contains('Explicación'));
  });
}
