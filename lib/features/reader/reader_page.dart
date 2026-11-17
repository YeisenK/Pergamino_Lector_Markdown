import 'package:material_ui/material_ui.dart';

/// Placeholder: se implementa en la fase 2.
class ReaderPage extends StatelessWidget {
  const ReaderPage({super.key, required this.bookId});
  final String bookId;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Lector: $bookId')));
}
