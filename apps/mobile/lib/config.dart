import 'package:flutter/foundation.dart';

import 'l10n/l10n.dart';

/// Production backend; release builds use it unless told otherwise.
const productionApiBaseUrl = 'https://api.sbexpress.jhotpot.app';

/// Backend origin. Release builds default to [productionApiBaseUrl], debug
/// builds and tests to this machine.
///
/// Override at build/run time:
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3002`
///
/// Release builds must use an `https` origin. Debug may use `http` only for
/// a loopback host (this machine, or the Android emulator host).
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: kReleaseMode ? productionApiBaseUrl : 'http://localhost:3002',
);

bool isLoopbackHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1' ||
      normalized == '10.0.2.2';
}

/// Release refuses every non-https origin. Debug allows http only on loopback.
String requireApiBaseUrl(String raw,
    {required bool releaseMode, required bool debugMode}) {
  final trimmed = raw.trim().replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      !uri.hasScheme ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw FormatException('API_BASE_URL is not a valid origin: $raw');
  }
  if (uri.scheme == 'https') return trimmed;
  if (uri.scheme == 'http' &&
      !releaseMode &&
      debugMode &&
      isLoopbackHost(uri.host)) {
    return trimmed;
  }
  if (releaseMode) {
    throw const FormatException(
        'Release builds require an https API_BASE_URL. http://localhost:3002 is for debug only.');
  }
  throw const FormatException(
      'http API_BASE_URL is only allowed for localhost in debug.');
}

/// Presigned upload URLs follow the same transport rule as the API origin.
void assertPresignedUploadUrl(String url,
    {required bool releaseMode, required bool debugMode}) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw FormatException(tr('The upload link is not valid.'));
  }
  if (uri.scheme == 'https') return;
  if (uri.scheme == 'http' &&
      !releaseMode &&
      debugMode &&
      isLoopbackHost(uri.host)) {
    return;
  }
  throw FormatException(tr('The upload link must use HTTPS.'));
}
