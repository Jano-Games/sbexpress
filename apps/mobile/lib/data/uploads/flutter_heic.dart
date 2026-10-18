import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

Future<Uint8List> flutterDecodeHeic(Uint8List bytes) async {
  try {
    final converted = await FlutterImageCompress.compressWithList(
      bytes,
      quality: 90,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    if (converted.isEmpty) {
      throw const FormatException('এই HEIC ছবি এই ডিভাইসে JPEG-এ রূপান্তর হয়নি। JPEG হিসেবে এক্সপোর্ট করে আবার দিন।');
    }
    return converted;
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('এই HEIC ছবি এই ডিভাইসে JPEG-এ রূপান্তর হয়নি। JPEG হিসেবে এক্সপোর্ট করে আবার দিন।');
  }
}
