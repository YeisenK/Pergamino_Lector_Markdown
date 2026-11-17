import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pergamino/data/settings.dart';
import 'package:pergamino/features/reader/reader_clock.dart';

void main() {
  test('formato 24 y 12 horas', () {
    expect(formatClock(DateTime(2026, 1, 1, 13, 5), use24h: true), '13:05');
    expect(formatClock(DateTime(2026, 1, 1, 0, 7), use24h: true), '00:07');
    expect(formatClock(DateTime(2026, 1, 1, 13, 5), use24h: false), '1:05 p. m.');
    expect(formatClock(DateTime(2026, 1, 1, 0, 7), use24h: false), '12:07 a. m.');
    expect(formatClock(DateTime(2026, 1, 1, 12, 0), use24h: false), '12:00 p. m.');
  });

  test('el ajuste del reloj se guarda', () {
    final s = const ReaderSettings(showClock: true);
    expect(ReaderSettings.fromJson(s.toJson()).showClock, isTrue);
    expect(ReaderSettings.fromJson({}).showClock, isFalse);
  });

  testWidgets('el reloj cambia al pasar el minuto', (tester) async {
    var t = DateTime(2026, 1, 1, 9, 59, 50);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(alwaysUse24HourFormat: true),
            child: ReaderClock(color: Colors.black, now: () => t))));
    expect(find.text('09:59'), findsOneWidget);
    t = DateTime(2026, 1, 1, 10, 0, 0);
    await tester.pump(const Duration(seconds: 11));
    expect(find.text('10:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
