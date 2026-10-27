import 'dart:convert';

import '../api/api_client.dart';
import '../json_read.dart';
import '../models/session_user.dart';
import '../session/session_store.dart';

class AuthRepository {
  AuthRepository(this.api, {SessionStore? store})
      : session = store ?? api.session;

  final ApiClient api;
  final SessionStore session;

  /// [remember] asks for a 30-day session instead of 12 hours. Older servers
  /// ignore it.
  Future<SessionUser> login(
      {required String email,
      required String password,
      bool remember = true}) async {
    final json = await api.postJson('/api/auth/login', body: {
      'email': email.trim(),
      'password': password,
      'remember': remember,
    });
    return _signedIn(json);
  }

  /// Signs in with this phone's fingerprint key; a 30-day session.
  Future<SessionUser> deviceLogin(String deviceToken) async {
    final json = await api
        .postJson('/api/auth/device-login', body: {'deviceToken': deviceToken});
    return _signedIn(json);
  }

  /// A new fingerprint key for the signed-in person. The server shows it
  /// only once.
  Future<String> createDeviceKey({String? label}) async {
    final json = await api.postJson('/api/auth/device', body: {
      if (label != null && label.isNotEmpty) 'label': label,
    });
    return requiredString(json, 'deviceToken');
  }

  /// Turns a fingerprint key off on the server. Needs no session.
  Future<void> revokeDeviceKey(String deviceToken) async {
    await api.postJson('/api/auth/device/revoke',
        body: {'deviceToken': deviceToken});
  }

  Future<SessionUser> me() async {
    final json = await api.getJson('/api/me');
    return SessionUser.fromJson(asJsonMap(json['user'], 'user'));
  }

  Future<void> logout() async {
    try {
      await api.postJson('/api/auth/logout');
    } finally {
      await session.writeToken(null);
      await session.writeUserJson(null);
    }
  }

  Future<SessionUser> _signedIn(Map<String, Object?> json) async {
    final token = requiredString(json, 'token');
    final user = SessionUser.fromJson(asJsonMap(json['user'], 'user'));
    await session.writeToken(token);
    await session.writeUserJson(jsonEncode(user.toJson()));
    return user;
  }
}
