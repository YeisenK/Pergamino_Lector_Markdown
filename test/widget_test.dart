import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pergamino/data/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pergamino/domain/book.dart';
import 'package:pergamino/main.dart';

void main() {
  test('Book se serializa y deserializa', () {
    final b = Book(
        id: '1', title: 'T', path: '/a.md', addedAt: DateTime(2026), progress: .4);
    final back = Book.decodeList(Book.encodeList([b])).single;
    expect(back.title, 'T');
    expect(back.progress, .4);
  });

  testWidgets('La app arranca', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const PergaminoApp()));
    // espera a que terminen de cargarse las fuentes incluidas
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(PergaminoApp), findsOneWidget);
    // la carga de fuentes programa un frame extra: se consume antes de cerrar
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
