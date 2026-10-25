import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../l10n/l10n.dart';

const int imageMaxEdge = 2000;
const int imageJpegQuality = 80;
const int imageUploadMaxBytes = 10 * 1024 * 1024;

/// Rejected before decode so a huge file never enters the image decoder.
const int imageInputMaxBytes = 25 * 1024 * 1024;

String get locationStrippedNote => tr('Location data removed');

enum ImageKind { jpeg, png, webp, heic, other }

class PreparedImage {
  const PreparedImage(
      {required this.bytes, required this.filename, required this.contentType});

  final Uint8List bytes;
  final String filename;
  final String contentType;

  int get size => bytes.length;
}

({int width, int height}) fittedSize(int width, int height,
    {int maxEdge = imageMaxEdge}) {
  final longest = width > height ? width : height;
  if (longest <= 0 || longest <= maxEdge) return (width: width, height: height);
  final scale = maxEdge / longest;
  final nextWidth = (width * scale).round();
  final nextHeight = (height * scale).round();
  return (
    width: nextWidth < 1 ? 1 : nextWidth,
    height: nextHeight < 1 ? 1 : nextHeight
  );
}

ImageKind sniffImage(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return ImageKind.jpeg;
  }
  const png = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length >= png.length && _matches(bytes, png)) return ImageKind.png;
  if (bytes.length >= 12 &&
      _ascii(bytes, 0, 4) == 'RIFF' &&
      _ascii(bytes, 8, 12) == 'WEBP') {
    return ImageKind.webp;
  }
  if (bytes.length >= 12 && _ascii(bytes, 4, 8) == 'ftyp') {
    final brand = _ascii(bytes, 8, 12).toLowerCase();
    const heicBrands = {
      'heic',
      'heix',
      'hevc',
      'hevx',
      'mif1',
      'msf1',
      'heim',
      'heis'
    };
    if (heicBrands.contains(brand)) return ImageKind.heic;
  }
  return ImageKind.other;
}

bool isHeicName(String name, String? mime) {
  final type = mime ?? '';
  return RegExp(r'image/hei[cf]', caseSensitive: false).hasMatch(type) ||
      RegExp(r'\.hei[cf]$', caseSensitive: false).hasMatch(name);
}

bool _isSvg(String name, String? mime) {
  final type = mime ?? '';
  return type == 'image/svg+xml' || name.toLowerCase().endsWith('.svg');
}

String safeFileName(String name) {
  final base = name
      .replaceAll(RegExp(r'\.[^.]+$'), '')
      .replaceAll(RegExp(r'[^\w.-]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final stem = base.isEmpty ? 'photo' : base;
  const ext = 'jpg';
  final max = 180 - ext.length - 1;
  final kept = stem.length <= max ? stem : stem.substring(0, max < 1 ? 1 : max);
  return '$kept.$ext';
}

/// Converts a camera or gallery photo to JPEG, longest edge ≤ 2000px, quality 80.
///
/// HEIC bytes are decoded by [decodeHeic] first. Re-encoding drops EXIF/GPS;
/// the server strips metadata again on promote.
Future<PreparedImage> prepareForUpload(
  Uint8List bytes, {
  required String name,
  String? mime,
  required Future<Uint8List> Function(Uint8List heic) decodeHeic,
}) async {
  if (bytes.isEmpty) {
    throw FormatException(tr('Empty files are not accepted.'));
  }
  if (bytes.length > imageInputMaxBytes) {
    throw FormatException(
        tr('The photo is over 25 MB. Choose a smaller file.'));
  }
  if (_isSvg(name, mime)) {
    throw FormatException(tr(
        'Unsupported format. SVG is not accepted. Use JPEG, PNG, WebP or HEIC.'));
  }
  final sniffed = sniffImage(bytes);
  final heic = sniffed == ImageKind.heic ||
      (sniffed == ImageKind.other && isHeicName(name, mime));
  if (heic) {
    final Uint8List jpeg;
    try {
      jpeg = await decodeHeic(bytes);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw FormatException(tr(
          'This HEIC photo could not be converted to JPEG on this device. Export it as JPEG and try again.'));
    }
    return _reencode(jpeg, name);
  }
  if (sniffed == ImageKind.jpeg ||
      sniffed == ImageKind.png ||
      sniffed == ImageKind.webp) {
    return _reencode(bytes, name);
  }
  throw FormatException(tr('Unsupported format. Use JPEG, PNG, WebP or HEIC.'));
}

PreparedImage _reencode(Uint8List bytes, String name) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw FormatException(tr(
        'Unsupported format. The photo could not be read. Use JPEG, PNG, WebP or HEIC.'));
  }
  final size = fittedSize(decoded.width, decoded.height);
  final resized = size.width == decoded.width && size.height == decoded.height
      ? decoded
      : img.copyResize(decoded,
          width: size.width,
          height: size.height,
          interpolation: img.Interpolation.linear);
  final encoded = img.encodeJpg(resized, quality: imageJpegQuality);
  if (encoded.length > imageUploadMaxBytes) {
    throw FormatException(tr(
        'The photo is still over 10 MB after compression. Choose a smaller photo.'));
  }
  return PreparedImage(
      bytes: encoded, filename: safeFileName(name), contentType: 'image/jpeg');
}

bool _matches(Uint8List bytes, List<int> prefix) {
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

String _ascii(Uint8List bytes, int start, int end) {
  return String.fromCharCodes(bytes.sublist(start, end));
}
