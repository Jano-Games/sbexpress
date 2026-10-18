import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/api_exception.dart';
import '../json_read.dart';
import '../models/session_user.dart';
import '../repositories/auth_repository.dart';
import 'session_store.dart';

class SessionController extends ChangeNotifier {
  SessionController({required this.store, required this.auth});

  final SessionStore store;
  final AuthRepository auth;

  SessionUser? user;
  bool ready = false;
  String? banner;

  Future<void> restore() async {
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
        banner = 'সেশন যাচাই এখনো হয়নি। নেটওয়ার্ক ফিরলে আবার চেষ্টা হবে।';
      } else {
        banner = error.message;
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    user = await auth.login(email: email, password: password);
    banner = null;
    notifyListeners();
  }

  Future<void> logout() async {
    await auth.logout();
    user = null;
    banner = null;
    notifyListeners();
  }

  Future<void> _clear() async {
    await store.writeToken(null);
    await store.writeUserJson(null);
    user = null;
  }
}
