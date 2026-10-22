import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Centre-crop to a square and downscale to ≤512px JPEG (strips EXIF/location metadata).
Uint8List squareJpeg(Uint8List input, {int size = 512, int quality = 82}) {
  final decoded = img.decodeImage(input);
  if (decoded == null) throw const FormatException('Unsupported image');
  final oriented = img.bakeOrientation(decoded);
  final side = oriented.width < oriented.height ? oriented.width : oriented.height;
  final sq = img.copyCrop(oriented, x: (oriented.width - side) ~/ 2, y: (oriented.height - side) ~/ 2, width: side, height: side);
  final out = side > size ? img.copyResize(sq, width: size, height: size, interpolation: img.Interpolation.average) : sq;
  out.exif = img.ExifData();
  return Uint8List.fromList(img.encodeJpg(out, quality: quality));
}
