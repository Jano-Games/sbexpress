import 'dart:convert';

import '../api/api_client.dart';
import '../json_read.dart';
import '../models/session_user.dart';
import '../session/session_store.dart';

class AuthRepository {
  AuthRepository(this.api, {SessionStore? store}) : session = store ?? api.session;

  final ApiClient api;
  final SessionStore session;

  Future<SessionUser> login({required String email, required String password}) async {
    final json = await api.postJson('/api/auth/login', body: {
      'email': email.trim(),
      'password': password,
    });
    final token = requiredString(json, 'token');
    final user = SessionUser.fromJson(asJsonMap(json['user'], 'user'));
    await session.writeToken(token);
    await session.writeUserJson(jsonEncode(user.toJson()));
    return user;
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
}
