import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../../l10n/l10n.dart';

/// The phone's fingerprint check. Widget tests pass a fake.
abstract class Biometrics {
  /// True when the phone can check a fingerprint and has one set up.
  Future<bool> available();

  /// Shows the system fingerprint prompt with [reason]. True when the person
  /// passed it, false when they cancelled it. Other failures throw a
  /// [FingerprintFailure] with a message for the screen.
  Future<bool> prompt(String reason);
}

/// Fingerprint sign-in could not go ahead; [message] is for the screen.
class FingerprintFailure implements Exception {
  const FingerprintFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// [Biometrics] on the phone through `local_auth`.
class DeviceBiometrics implements Biometrics {
  DeviceBiometrics({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> available() async {
    try {
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }

  @override
  Future<bool> prompt(String reason) async {
    try {
      return await _auth.authenticate(
          localizedReason: reason,
          biometricOnly: true,
          persistAcrossBackgrounding: true);
    } on LocalAuthException catch (error) {
      switch (error.code) {
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.systemCanceled:
        case LocalAuthExceptionCode.timeout:
        case LocalAuthExceptionCode.userRequestedFallback:
          return false;
        case LocalAuthExceptionCode.noBiometricsEnrolled:
        case LocalAuthExceptionCode.noBiometricHardware:
        case LocalAuthExceptionCode.noCredentialsSet:
        case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
          throw FingerprintFailure(tr('This phone has no fingerprint set up.'));
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          throw FingerprintFailure(tr(
              'Too many tries. Wait a moment, or sign in with your password.'));
        default:
          throw FingerprintFailure(tr(
              'Fingerprint sign-in did not work. Try again, or use your password.'));
      }
    } on PlatformException {
      throw FingerprintFailure(tr(
          'Fingerprint sign-in did not work. Try again, or use your password.'));
    }
  }
}
