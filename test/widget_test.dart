import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await tester.pumpWidget(const ProviderScope(child: PergaminoApp()));
    expect(find.byType(PergaminoApp), findsOneWidget);
  });
}
