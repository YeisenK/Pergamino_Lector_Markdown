import 'package:flutter_test/flutter_test.dart';
import 'package:pergamino/features/reader/reader_clock.dart';

void main() {
  test('la línea del reloj solo muestra lo activo', () {
    expect(clockLine(time: '13:05'), '13:05');
    expect(
        clockLine(time: '13:05', battery: 87, showBattery: true, progress: .42, showProgress: true,
            chapter: 'Capítulo 3', showChapter: true),
        '13:05  ·  87 %  ·  42 %  ·  Capítulo 3');
    expect(clockLine(time: '13:05', battery: null, showBattery: true), '13:05');
    expect(clockLine(time: '13:05', progress: .5, showProgress: false), '13:05');
    expect(clockLine(time: '13:05', progress: .5, showProgress: true, minutesLeft: 35),
        '13:05  ·  50 %  ·  quedan ~35 min');
    expect(clockLine(time: '13:05', progress: .5, showProgress: true, minutesLeft: 75),
        '13:05  ·  50 %  ·  quedan ~1 h 15 min');
  });
}
