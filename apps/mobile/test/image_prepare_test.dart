import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sbexpress/data/uploads/image_prepare.dart';

Uint8List jpeg({required int width, required int height}) {
  final picture = img.Image(width: width, height: height);
  img.fill(picture, color: img.ColorRgb8(20, 80, 90));
  return img.encodeJpg(picture, quality: 90);
}

void main() {
  test('fitted size caps the longest edge at 2000', () {
    expect(fittedSize(4000, 1000), (width: 2000, height: 500));
    expect(fittedSize(800, 600), (width: 800, height: 600));
  });

  test('jpeg and png are re-encoded under 2000px at the upload quality', () async {
    final prepared = await prepareForUpload(
      jpeg(width: 2100, height: 20),
      name: 'hub photo.HEIC.JPG',
      decodeHeic: (_) async => Uint8List(0),
    );
    expect(prepared.contentType, 'image/jpeg');
    expect(prepared.filename, endsWith('.jpg'));
    final decoded = img.decodeJpg(prepared.bytes)!;
    expect(decoded.width, 2000);
    expect(decoded.height, 19);
    expect(prepared.bytes[0], 0xff);
    expect(prepared.bytes[1], 0xd8);
  });

  test('png bytes are converted to jpeg', () async {
    final picture = img.Image(width: 12, height: 8);
    final prepared = await prepareForUpload(img.encodePng(picture), name: 'scan.png', mime: 'image/png', decodeHeic: (_) async => Uint8List(0));
    expect(prepared.contentType, 'image/jpeg');
    expect(img.decodeJpg(prepared.bytes)!.width, 12);
  });

  test('heic is converted with the injected decoder before the jpeg rules', () async {
    final header = Uint8List(16);
    header.setRange(4, 8, 'ftyp'.codeUnits);
    header.setRange(8, 12, 'heic'.codeUnits);
    expect(sniffImage(header), ImageKind.heic);
    final prepared = await prepareForUpload(
      header,
      name: 'IMG.HEIC',
      mime: 'image/heic',
      decodeHeic: (_) async => jpeg(width: 30, height: 10),
    );
    expect(prepared.contentType, 'image/jpeg');
    expect(img.decodeJpg(prepared.bytes)!.width, 30);
  });

  test('heic without a decoder and svg are specific format errors', () async {
    final header = Uint8List(16);
    header.setRange(4, 8, 'ftyp'.codeUnits);
    header.setRange(8, 12, 'heic'.codeUnits);
    await expectLater(
      prepareForUpload(header, name: 'a.heic', decodeHeic: (_) async => throw StateError('no codec')),
      throwsA(predicate<FormatException>((error) => error.message.contains('HEIC'))),
    );
    await expectLater(
      prepareForUpload(Uint8List.fromList('<svg'.codeUnits), name: 'icon.svg', mime: 'image/svg+xml', decodeHeic: (_) async => Uint8List(0)),
      throwsA(predicate<FormatException>((error) => error.message.contains('ফরম্যাট'))),
    );
  });
}
