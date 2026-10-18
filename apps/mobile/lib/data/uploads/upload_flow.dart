import 'package:flutter/foundation.dart';

import '../../config.dart';
import '../api/api_exception.dart';
import 'image_prepare.dart';

class UploadException implements Exception {
  const UploadException(this.message, {this.status});

  final String message;
  final int? status;

  bool get expired => message.toLowerCase().contains('expired') || message.contains('মেয়াদ');

  @override
  String toString() => message;
}

class UploadReservation {
  const UploadReservation({required this.reference, required this.uploadUrl, required this.expiresAt});

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
  if (status == 503 || RegExp(r'not configured', caseSensitive: false).hasMatch(message) || message.contains('স্টোরেজ')) {
    return 'স্টোরেজ এখনো তৈরি হয়নি। অ্যাডমিন স্টোরেজ সেটআপ শেষ করলে আপলোড চালু হবে।';
  }
  if (status == 429 || RegExp(r'too many uploads', caseSensitive: false).hasMatch(message)) {
    return 'অল্প সময়ে অনেক আপলোড হয়েছে। এক মিনিট পর একই ছবি দিয়ে চেষ্টা করুন।';
  }
  if (RegExp(r'expired|মেয়াদ', caseSensitive: false).hasMatch(message)) {
    return 'আপলোডের মেয়াদ শেষ। একই ছবি দিয়ে আবার চেষ্টা করুন।';
  }
  if (status == 0 ||
      error is ApiException && error.isNetwork ||
      RegExp(r'failed to fetch|socketexception|clientexception|network|cors|connection', caseSensitive: false).hasMatch(message)) {
    return 'নেটওয়ার্ক বা স্টোরেজ CORS-এর কারণে আপলোড পৌঁছায়নি। একই ছবি দিয়ে আবার চেষ্টা করুন।';
  }
  if (message.contains('ফরম্যাট মেলেনি') || RegExp(r'format|content type|unsupported', caseSensitive: false).hasMatch(message)) {
    return message.contains('ফরম্যাট') ? message : 'ফরম্যাট মেলেনি। JPEG, PNG, WebP বা HEIC দিন।';
  }
  if (status != null && status >= 400) {
    return 'আপলোড ব্যর্থ ($status): $message একই ছবি দিয়ে আবার চেষ্টা করুন।';
  }
  if (message.isNotEmpty) return message;
  return 'আপলোড ব্যর্থ। একই ছবি দিয়ে আবার চেষ্টা করুন।';
}

/// Reserves, uploads, and completes. A failed attempt retries the same bytes.
Future<String> transferPreparedUpload({
  required PreparedImage file,
  required Future<UploadReservation> Function(PreparedImage file) reserve,
  required Future<void> Function(UploadReservation reservation, PreparedImage file, void Function(double progress) onProgress) put,
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
    assertPresignedUploadUrl(reservation.uploadUrl, releaseMode: kReleaseMode, debugMode: kDebugMode);
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
      final expired = RegExp(r'expired', caseSensitive: false).hasMatch(message);
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
  throw UploadException(describeUploadError(lastError ?? StateError('upload failed')));
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
