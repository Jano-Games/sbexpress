import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'uploads/image_prepare.dart';

Map<String, Object?> mobilePayMethodBody({
  required String provider,
  required String number,
  String label = '',
  String note = '',
  String currency = 'BDT',
  String? qrImage,
}) {
  return {
    'kind': 'mobile_banking',
    'provider': provider.trim(),
    'label': label.trim(),
    'number': number.trim(),
    'note': note.trim(),
    'currency': currency,
    if (qrImage != null && qrImage.isNotEmpty) 'qrImage': qrImage,
  };
}

Map<String, Object?> bankPayMethodBody({
  required String bankName,
  required String accountNumber,
  required String accountName,
  String branch = '',
  String district = '',
  String currency = 'BDT',
}) {
  return {
    'kind': 'bank_account',
    'bankName': bankName.trim(),
    'accountNumber': accountNumber.trim(),
    'accountName': accountName.trim(),
    'branch': branch.trim(),
    'district': district.trim(),
    'currency': currency,
  };
}

/// JPEG data URL small enough for the payment-method QR field (under 300 KB).
String? jpegQrDataUrl(Uint8List jpeg) {
  final decoded = img.decodeImage(jpeg);
  if (decoded == null) return null;
  for (final edge in [800, 600, 400, 240]) {
    final size = fittedSize(decoded.width, decoded.height, maxEdge: edge);
    final resized = size.width == decoded.width && size.height == decoded.height
        ? decoded
        : img.copyResize(decoded, width: size.width, height: size.height, interpolation: img.Interpolation.linear);
    for (final quality in [70, 50, 35]) {
      final encoded = img.encodeJpg(resized, quality: quality);
      if (encoded.length <= 280 * 1024) {
        return 'data:image/jpeg;base64,${base64Encode(encoded)}';
      }
    }
  }
  return null;
}
