import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../l10n/l10n.dart';
import '../api/api_exception.dart';
import '../json_read.dart';
import '../models/session_user.dart';
import '../repositories/auth_repository.dart';
import 'biometrics.dart';
import 'session_store.dart';

/// The person a phone's fingerprint key signs in.
class FingerprintOwner {
  const FingerprintOwner(
      {required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;

  /// "Sadia" for "Sadia Karim", for "Welcome back, Sadia".
  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.first.isEmpty ? name : parts.first;
  }

  factory FingerprintOwner.fromJson(Map<String, Object?> json) =>
      FingerprintOwner(
          id: requiredString(json, 'id'),
          name: requiredString(json, 'name'),
          email: requiredString(json, 'email'));

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'email': email};
}

class SessionController extends ChangeNotifier {
  SessionController(
      {required this.store, required this.auth, Biometrics? biometrics})
      : biometrics = biometrics ?? DeviceBiometrics();

  final SessionStore store;
  final AuthRepository auth;
  final Biometrics biometrics;

  SessionUser? user;
  bool ready = false;
  String? banner;

  /// Who can sign in with a fingerprint on this phone; null when nobody.
  /// Signing out keeps it.
  FingerprintOwner? fingerprint;

  /// The signed-in person has fingerprint sign-in on this phone.
  bool get fingerprintOn =>
      fingerprint != null && user != null && fingerprint!.id == user!.id;

  Future<void> restore() async {
    fingerprint = await _readOwner();
    final token = await store.readToken();
    final cached = await store.readUserJson();
    if (token == null || token.isEmpty) {
      ready = true;
      notifyListeners();
      return;
    }
    if (cached != null && cached.isNotEmpty) {
      try {
        user = SessionUser.fromJson(asJsonMap(jsonDecode(cached), 'user'));
      } on FormatException {
        user = null;
      }
    }
    try {
      user = await auth.me();
      await store.writeUserJson(jsonEncode(user!.toJson()));
      banner = null;
    } on ApiException catch (error) {
      if (error.status == 401 || error.status == 403) {
        await _clear();
      } else if (user != null) {
        banner = tr(
            'Your session has not been checked yet. It will retry when the network is back.');
      } else {
        banner = error.message;
      }
    }
    ready = true;
    notifyListeners();
  }

  /// [remember] keeps this phone signed in for 30 days instead of 12 hours.
  Future<void> login(String email, String password,
      [bool remember = true]) async {
    user =
        await auth.login(email: email, password: password, remember: remember);
    banner = null;
    notifyListeners();
  }

  /// Asks for the fingerprint, then signs in with this phone's key. False
  /// when the person cancelled the prompt. A key the server turned down is
  /// deleted, so the password form takes over.
  Future<bool> loginWithFingerprint() async {
    if (!await biometrics
        .prompt(tr('Touch the fingerprint sensor to sign in.'))) {
      return false;
    }
    final key = await store.readDeviceKey();
    if (key == null || key.isEmpty) {
      await _forgetFingerprint();
      notifyListeners();
      throw FingerprintFailure(_turnedOff());
    }
    try {
      user = await auth.deviceLogin(key);
    } on ApiException catch (error) {
      if (error.status == 401) {
        await _forgetFingerprint();
        notifyListeners();
        throw FingerprintFailure(
            error.message == _turnedOffText ? _turnedOff() : error.message);
      }
      if (error.status == 404) throw FingerprintFailure(_serverTooOld());
      rethrow;
    }
    banner = null;
    notifyListeners();
    return true;
  }

  /// Turns fingerprint sign-in on for the signed-in person. False when they
  /// cancelled the prompt.
  Future<bool> enableFingerprint() async {
    final current = user;
    if (current == null) return false;
    if (!await biometrics.available()) {
      throw FingerprintFailure(tr('This phone has no fingerprint set up.'));
    }
    if (!await biometrics.prompt(
        tr('Touch the fingerprint sensor to turn on fingerprint sign-in.'))) {
      return false;
    }
    final String key;
    try {
      key = await auth.createDeviceKey(label: _deviceLabel());
    } on ApiException catch (error) {
      if (error.status == 404) throw FingerprintFailure(_serverTooOld());
      rethrow;
    }
    // One key per phone: an older one, maybe someone else's, is turned off.
    final previous = await store.readDeviceKey();
    final owner = FingerprintOwner(
        id: current.id, name: current.name, email: current.email);
    await store.writeDeviceKey(key);
    await store.writeDeviceOwnerJson(jsonEncode(owner.toJson()));
    fingerprint = owner;
    if (previous != null && previous.isNotEmpty && previous != key) {
      await _revokeQuietly(previous);
    }
    notifyListeners();
    return true;
  }

  /// Turns fingerprint sign-in off on this phone. The key is deleted here
  /// even when the server cannot be told.
  Future<void> disableFingerprint() async {
    final key = await store.readDeviceKey();
    try {
      if (key != null && key.isNotEmpty) await _revokeQuietly(key);
    } finally {
      await _forgetFingerprint();
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await auth.logout();
    user = null;
    banner = null;
    notifyListeners();
  }

  /// Any 401, including one mid-session, drops the saved token and the user.
  /// Does not call the logout endpoint, which would 401 again.
  Future<void> handleUnauthorized() async {
    final hadUser = user != null;
    await _clear();
    banner = null;
    ready = true;
    if (hadUser) notifyListeners();
  }

  Future<void> _clear() async {
    await store.writeToken(null);
    await store.writeUserJson(null);
    user = null;
  }

  Future<FingerprintOwner?> _readOwner() async {
    final json = await store.readDeviceOwnerJson();
    if (json == null || json.isEmpty) return null;
    try {
      return FingerprintOwner.fromJson(asJsonMap(jsonDecode(json), 'owner'));
    } on FormatException {
      return null;
    }
  }

  Future<void> _forgetFingerprint() async {
    await store.writeDeviceKey(null);
    await store.writeDeviceOwnerJson(null);
    fingerprint = null;
  }

  Future<void> _revokeQuietly(String key) async {
    try {
      await auth.revokeDeviceKey(key);
    } on ApiException {
      // Deleted on this phone anyway, so nobody can use it from here.
    }
  }
}

/// The server's words when a fingerprint key is no longer accepted.
const _turnedOffText =
    'Fingerprint sign-in was turned off. Sign in with your password.';

String _turnedOff() =>
    tr('Fingerprint sign-in was turned off. Sign in with your password.');

String _serverTooOld() =>
    tr('The server needs an update before fingerprint sign-in works.');

String _deviceLabel() => Platform.isIOS ? 'iPhone' : 'Android phone';
