import 'package:flutter/foundation.dart';

import '../../config.dart';
import '../../l10n/l10n.dart';
import '../api/api_exception.dart';
import 'image_prepare.dart';

class UploadException implements Exception {
  const UploadException(this.message, {this.status});

  final String message;
  final int? status;

  bool get expired =>
      message.toLowerCase().contains('expired') ||
      message.contains(tr('expired'));

  @override
  String toString() => message;
}

class UploadReservation {
  const UploadReservation(
      {required this.reference,
      required this.uploadUrl,
      required this.expiresAt});

  final String reference;
  final String uploadUrl;
  final String expiresAt;
}

class OptionalScreenshot {
  const OptionalScreenshot({this.reference, this.warning});

  final String? reference;
  final String? warning;

  bool get attached => reference != null;
}

String describeUploadError(Object error) {
  final status = error is ApiException
      ? error.status
      : error is UploadException
          ? error.status
          : null;
  final message = error is ApiException
      ? error.message
      : error is UploadException
          ? error.message
          : error is FormatException
              ? error.message
              : error.toString();
  if (status == 503 ||
      RegExp(r'not configured', caseSensitive: false).hasMatch(message) ||
      message.contains(tr('Storage'))) {
    return tr(
        'Storage is not set up yet. Uploads start once an admin finishes storage setup.');
  }
  if (status == 429 ||
      RegExp(r'too many uploads', caseSensitive: false).hasMatch(message)) {
    return tr(
        'Too many uploads in a short time. Wait a minute and try again with the same photo.');
  }
  if (RegExp(r'expired', caseSensitive: false).hasMatch(message) ||
      message.contains(tr('expired'))) {
    return tr('The upload expired. Try again with the same photo.');
  }
  if (status == 0 ||
      error is ApiException && error.isNetwork ||
      RegExp(r'failed to fetch|socketexception|clientexception|network|cors|connection',
              caseSensitive: false)
          .hasMatch(message)) {
    return tr(
        'The upload did not reach storage (network or storage CORS). Try again with the same photo.');
  }
  if (message.contains(tr('Unsupported format')) ||
      RegExp(r'format|content type|unsupported', caseSensitive: false)
          .hasMatch(message)) {
    return message.contains(tr('format'))
        ? message
        : tr('Unsupported format. Use JPEG, PNG, WebP or HEIC.');
  }
  if (status != null && status >= 400) {
    return tr(
        'Upload failed ({status}): {message} Try again with the same photo.',
        {'status': status, 'message': message});
  }
  if (message.isNotEmpty) return message;
  return tr('Upload failed. Try again with the same photo.');
}

/// Reserves, uploads, and completes. A failed attempt retries the same bytes.
Future<String> transferPreparedUpload({
  required PreparedImage file,
  required Future<UploadReservation> Function(PreparedImage file) reserve,
  required Future<void> Function(UploadReservation reservation,
          PreparedImage file, void Function(double progress) onProgress)
      put,
  required Future<void> Function(String reference) complete,
  void Function(double progress)? onProgress,
  int maxAttempts = 2,
}) async {
  Object? lastError;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final UploadReservation reservation;
    try {
      reservation = await reserve(file);
    } catch (error) {
      lastError = error;
      final status = error is ApiException ? error.status : null;
      if (status != null && status < 500 && status != 429) break;
      continue;
    }
    assertPresignedUploadUrl(reservation.uploadUrl,
        releaseMode: kReleaseMode, debugMode: kDebugMode);
    try {
      await put(reservation, file, onProgress ?? (_) {});
    } catch (error) {
      lastError = error;
      continue;
    }
    try {
      await complete(reservation.reference);
      onProgress?.call(1);
      return reservation.reference;
    } catch (error) {
      final message = error is ApiException ? error.message : error.toString();
      final expired =
          RegExp(r'expired', caseSensitive: false).hasMatch(message);
      if (!expired) {
        try {
          await complete(reservation.reference);
          onProgress?.call(1);
          return reservation.reference;
        } catch (again) {
          lastError = again;
          break;
        }
      }
      lastError = error;
    }
  }
  throw UploadException(
      describeUploadError(lastError ?? StateError('upload failed')));
}

/// Screenshot upload failure returns a warning and still lets payment continue.
Future<OptionalScreenshot> optionalScreenshot({
  PreparedImage? image,
  required Future<String> Function(PreparedImage image) upload,
}) async {
  if (image == null) return const OptionalScreenshot();
  try {
    return OptionalScreenshot(reference: await upload(image));
  } catch (error) {
    return OptionalScreenshot(warning: describeUploadError(error));
  }
}

bool paymentSubmissionAllowed(OptionalScreenshot screenshot) {
  final _ = screenshot.warning;
  return true;
}
