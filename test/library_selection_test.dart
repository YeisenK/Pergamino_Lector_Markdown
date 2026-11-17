import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pergamino/data/book_repository.dart';
import 'package:pergamino/data/settings.dart';
import 'package:pergamino/domain/book.dart';
import 'package:pergamino/features/library/library_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('seleccionar varios libros y eliminarlos', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final books = [
      for (final t in ['Libro Uno', 'Libro Dos', 'Libro Tres'])
        Book(id: t, title: t, path: '/no/existe/$t.md', addedAt: DateTime(2026))
    ];
    SharedPreferences.setMockInitialValues({'books_v1': Book.encodeList(books)});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [prefsProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MaterialApp(home: LibraryPage())));
    await tester.runAsync(() => GoogleFonts.pendingFonts());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Libro Uno'), findsOneWidget);
    expect(find.text('Biblioteca'), findsOneWidget);

    await tester.longPress(find.text('Libro Uno'));
    await tester.pump();
    expect(find.text('1 seleccionado'), findsOneWidget);

    await tester.tap(find.text('Libro Dos'));
    await tester.pump();
    expect(find.text('2 seleccionados'), findsOneWidget);

    await tester.tap(find.byTooltip('Eliminar seleccionados'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar 2 libros'), findsOneWidget);
    await tester.tap(find.text('Eliminar'));
    // el borrado de archivos usa E/S real: se deja avanzar fuera del reloj simulado
    // (cada borrado es una espera real; se alternan esperas y frames)
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Libro Uno'), findsNothing);
    expect(find.text('Libro Dos'), findsNothing);
    expect(find.text('Libro Tres'), findsOneWidget);
    expect(find.text('Biblioteca'), findsOneWidget); // salió del modo selección
    expect(container.read(booksProvider).value!.map((b) => b.title), ['Libro Tres']);
    expect(prefs.getString('books_v1'), contains('Libro Tres'));
    expect(prefs.getString('books_v1'), isNot(contains('Libro Uno')));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
