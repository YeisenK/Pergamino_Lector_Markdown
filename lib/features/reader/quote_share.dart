import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/highlights.dart';

/// Tarjeta con la cita, lista para compartir como imagen.
class QuoteCard extends StatelessWidget {
  const QuoteCard({super.key, required this.text, required this.book, required this.chapter, required this.accent});
  final String text;
  final String book;
  final String chapter;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 540,
      padding: const EdgeInsets.fromLTRB(44, 48, 44, 40),
      decoration: const BoxDecoration(color: Color(0xFFF6F0E2)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 48, height: 4, color: accent),
          const SizedBox(height: 28),
          Text(
            '«$text»',
            style: GoogleFonts.literata(
              fontSize: 26,
              height: 1.45,
              fontStyle: FontStyle.italic,
              color: const Color(0xFF2B2620),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            book,
            style: GoogleFonts.literata(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2B2620),
            ),
          ),
          if (chapter.isNotEmpty)
            Text(chapter,
                style: GoogleFonts.literata(fontSize: 14, color: const Color(0xFF6B6255))),
          const SizedBox(height: 28),
          Text('Pergamino',
              style: GoogleFonts.literata(
                  fontSize: 12, letterSpacing: 1.5, color: const Color(0xFF8A8175))),
        ],
      ),
    );
  }
}

/// Muestra la tarjeta y la comparte como PNG.
Future<void> showQuoteShare(BuildContext context, Highlight h, String bookTitle) {
  final key = GlobalKey();
  return showDialog<void>(
    context: context,
    builder: (c) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          RepaintBoundary(
            key: key,
            child: QuoteCard(
              text: h.text,
              book: bookTitle,
              chapter: h.chapter,
              accent: h.color.color,
            ),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cerrar')),
            FilledButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Compartir'),
              onPressed: () async {
                final boundary = key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
                final ui.Image image = await boundary.toImage(pixelRatio: 3);
                final data = await image.toByteData(format: ui.ImageByteFormat.png);
                final bytes = data!.buffer.asUint8List();
                await SharePlus.instance.share(ShareParams(
                  files: [XFile.fromData(Uint8List.fromList(bytes), mimeType: 'image/png', name: 'cita.png')],
                  text: '«${h.text}» — $bookTitle',
                ));
              },
            ),
          ]),
        ]),
      ),
    ),
  );
}
