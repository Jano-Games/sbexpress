import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_store.dart';

class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const tokenKey = 'sbx.token';
  static const userKey = 'sbx.user';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() => _storage.read(key: tokenKey);

  @override
  Future<void> writeToken(String? token) {
    if (token == null || token.isEmpty) return _storage.delete(key: tokenKey);
    return _storage.write(key: tokenKey, value: token);
  }

  @override
  Future<String?> readUserJson() => _storage.read(key: userKey);

  @override
  Future<void> writeUserJson(String? json) {
    if (json == null || json.isEmpty) return _storage.delete(key: userKey);
    return _storage.write(key: userKey, value: json);
  }
}
