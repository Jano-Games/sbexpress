import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_store.dart';

class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage}) : _storage = storage ?? secureSessionStorage();

  /// Pinned options. Android backup rules exclude this preferences file.
  static const storageNamespace = 'sbexpress_secure';

  static FlutterSecureStorage secureSessionStorage() {
    return const FlutterSecureStorage(
      aOptions: AndroidOptions(
        resetOnError: false,
        storageNamespace: storageNamespace,
        preferencesKeyPrefix: 'sbx.',
        keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
        storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
        synchronizable: false,
      ),
    );
  }

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
