import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../l10n/l10n.dart';
import 'api/api_exception.dart';

/// Saves bytes and opens the Android share sheet so the operator can view or send the file.
Future<void> shareBytes(
    {required List<int> bytes,
    required String filename,
    required String mimeType}) async {
  final safe = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
  final file = File('${Directory.systemTemp.path}/$safe');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: mimeType, name: safe)]));
}

/// Opens the Android share sheet with [text], e.g. a customer link.
Future<void> shareText(String text) =>
    SharePlus.instance.share(ShareParams(text: text));

Future<List<int>> downloadUrl(String url) async {
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode >= 400) {
      throw ApiException(
          status: response.statusCode,
          message: tr('Could not open the file ({status})',
              {'status': response.statusCode}),
          path: url);
    }
    return response.bodyBytes;
  } on ApiException {
    rethrow;
  } on SocketException catch (error) {
    throw ApiException(status: 0, message: error.message, path: url);
  } on http.ClientException catch (error) {
    throw ApiException(status: 0, message: error.message, path: url);
  }
}
