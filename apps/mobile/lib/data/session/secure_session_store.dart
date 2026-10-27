import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_store.dart';

class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? secureSessionStorage();

  /// Pinned options. Android backup rules exclude this preferences file.
  static const storageNamespace = 'sbexpress_secure';

  static FlutterSecureStorage secureSessionStorage() {
    return const FlutterSecureStorage(
      aOptions: AndroidOptions(
        resetOnError: false,
        storageNamespace: storageNamespace,
        preferencesKeyPrefix: 'sbx.',
        keyCipherAlgorithm:
            KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
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

  /// Fingerprint sign-in. Signing out keeps both.
  static const deviceKeyKey = 'sbx.device.key';
  static const deviceOwnerKey = 'sbx.device.owner';

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

  @override
  Future<String?> readDeviceKey() => _storage.read(key: deviceKeyKey);

  @override
  Future<void> writeDeviceKey(String? key) {
    if (key == null || key.isEmpty) return _storage.delete(key: deviceKeyKey);
    return _storage.write(key: deviceKeyKey, value: key);
  }

  @override
  Future<String?> readDeviceOwnerJson() => _storage.read(key: deviceOwnerKey);

  @override
  Future<void> writeDeviceOwnerJson(String? json) {
    if (json == null || json.isEmpty) {
      return _storage.delete(key: deviceOwnerKey);
    }
    return _storage.write(key: deviceOwnerKey, value: json);
  }
}
