import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pergamino/data/covers.dart';

void main() {
  test('una portada grande se reduce a 600 px y queda como JPEG', () {
    final big = img.Image(width: 1600, height: 2400);
    img.fill(big, color: img.ColorRgb8(60, 40, 90));
    final png = Uint8List.fromList(img.encodePng(big));
    final out = encodeCover(png)!;
    final decoded = img.decodeJpg(out)!;
    expect(decoded.width, coverMaxWidth);
    expect(out.length, lessThan(png.length));
  });

  test('un archivo que no es imagen se rechaza', () {
    expect(encodeCover(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });
}
