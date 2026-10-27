abstract class SessionStore {
  Future<String?> readToken();
  Future<void> writeToken(String? token);
  Future<String?> readUserJson();
  Future<void> writeUserJson(String? json);

  /// The fingerprint sign-in key for this phone. Read it only after the
  /// person passed the fingerprint prompt.
  Future<String?> readDeviceKey();
  Future<void> writeDeviceKey(String? key);

  /// Who the fingerprint key belongs to (`{id, name, email}` as JSON), so the
  /// sign-in screen can greet them before the prompt.
  Future<String?> readDeviceOwnerJson();
  Future<void> writeDeviceOwnerJson(String? json);
}

class MemorySessionStore implements SessionStore {
  String? token;
  String? userJson;
  String? deviceKey;
  String? deviceOwnerJson;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<void> writeToken(String? value) async {
    token = value;
  }

  @override
  Future<String?> readUserJson() async => userJson;

  @override
  Future<void> writeUserJson(String? json) async {
    userJson = json;
  }

  @override
  Future<String?> readDeviceKey() async => deviceKey;

  @override
  Future<void> writeDeviceKey(String? key) async {
    deviceKey = key;
  }

  @override
  Future<String?> readDeviceOwnerJson() async => deviceOwnerJson;

  @override
  Future<void> writeDeviceOwnerJson(String? json) async {
    deviceOwnerJson = json;
  }
}
