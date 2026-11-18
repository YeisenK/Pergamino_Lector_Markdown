import 'package:flutter_test/flutter_test.dart';
import 'package:pergamino/data/auto_backup.dart';

void main() {
  test('toca copia si nunca se hizo o si pasaron 7 días', () {
    final now = DateTime(2026, 11, 18, 10);
    expect(autoBackupDue(null, now), isTrue);
    expect(autoBackupDue(now.subtract(const Duration(days: 6)), now), isFalse);
    expect(autoBackupDue(now.subtract(const Duration(days: 7)), now), isTrue);
  });

  test('borra las copias automáticas antiguas y conserva 3', () {
    final names = [
      'Pergamino-auto-2026-11-01.pergamino',
      'Pergamino-auto-2026-11-08.pergamino',
      'Pergamino-auto-2026-11-15.pergamino',
      'Pergamino-auto-2026-11-18.pergamino',
      'Pergamino-2026-10-02.pergamino', // copia manual: nunca se borra
      'otra cosa.txt',
    ];
    expect(autoBackupsToDelete(names), ['Pergamino-auto-2026-11-01.pergamino']);
    expect(autoBackupsToDelete(names.take(2).toList()), isEmpty);
  });

  test('el nombre lleva la fecha con ceros', () {
    expect(autoBackupName(DateTime(2026, 3, 4)), 'Pergamino-auto-2026-03-04.pergamino');
  });
}
