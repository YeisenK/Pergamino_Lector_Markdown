import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Portadas: se reducen a 600 px de ancho y se guardan como JPEG para no ocupar
/// espacio (una portada de 6 MB queda en unos 60 KB).
const coverMaxWidth = 600;

/// Decodifica una imagen y la devuelve como JPEG reducido. Null si no es una imagen.
Uint8List? encodeCover(Uint8List input) {
  final decoded = img.decodeImage(input);
  if (decoded == null) return null;
  final small = decoded.width > coverMaxWidth
      ? img.copyResize(decoded, width: coverMaxWidth)
      : decoded;
  return Uint8List.fromList(img.encodeJpg(small, quality: 86));
}

/// Ruta de la portada de un libro dentro de [coversDir].
String coverFileFor(Directory coversDir, String bookId) =>
    p.join(coversDir.path, '$bookId.jpg');
