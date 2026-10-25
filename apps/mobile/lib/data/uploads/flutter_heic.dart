import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../l10n/l10n.dart';

Future<Uint8List> flutterDecodeHeic(Uint8List bytes) async {
  try {
    final converted = await FlutterImageCompress.compressWithList(
      bytes,
      quality: 90,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    if (converted.isEmpty) {
      throw FormatException(tr(
          'This HEIC photo could not be converted to JPEG on this device. Export it as JPEG and try again.'));
    }
    return converted;
  } on FormatException {
    rethrow;
  } catch (_) {
    throw FormatException(tr(
        'This HEIC photo could not be converted to JPEG on this device. Export it as JPEG and try again.'));
  }
}
