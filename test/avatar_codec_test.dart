import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:oneup/features/profile/data/avatar_codec.dart';

void main() {
  test('centre-crops to square and caps at 512px JPEG', () {
    final src = Uint8List.fromList(img.encodePng(img.Image(width: 1200, height: 800)));
    final out = img.decodeJpg(squareJpeg(src))!;
    expect(out.width, 512);
    expect(out.height, 512);
  });
}
