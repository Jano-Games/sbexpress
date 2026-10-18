abstract class SessionStore {
  Future<String?> readToken();
  Future<void> writeToken(String? token);
  Future<String?> readUserJson();
  Future<void> writeUserJson(String? json);
}

class MemorySessionStore implements SessionStore {
  String? token;
  String? userJson;

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
}
