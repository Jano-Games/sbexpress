import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sbexpress/app.dart';
import 'package:sbexpress/data/repositories/auth_repository.dart';
import 'package:sbexpress/data/session/session_controller.dart';
import 'package:sbexpress/data/session/session_store.dart';
import 'package:sbexpress/l10n/bn.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'support/screen_fixtures.dart';

const _storage = FlutterSecureStorage();

Map<String, Object?> _hubUser() => {
      'id': 'u-hub',
      'name': 'Mina',
      'email': 'hub@sbx.test',
      'role': 'hub',
      'roleLabel': 'Hub Manager Dhaka',
    };

http.Response _json(Object body) => http.Response.bytes(
    utf8.encode(jsonEncode(body)), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    appLanguage.value = AppLanguage.bn;
  });
  tearDown(() => appLanguage.value = AppLanguage.bn);

  test('a fresh install starts in English and remembers Bangla', () async {
    final store = LanguageStore(storage: _storage);
    await store.load();
    expect(appLanguage.value, AppLanguage.en);

    await store.save(AppLanguage.bn);
    expect(await _storage.read(key: LanguageStore.key), 'bn');
    appLanguage.value = AppLanguage.en;
    await store.load();
    expect(appLanguage.value, AppLanguage.bn);
  });

  testWidgets('sign-in reads in English by default', (tester) async {
    await LanguageStore(storage: _storage).load();
    final api = screenFixtureApi();
    final session =
        SessionController(store: MemorySessionStore(), auth: AuthRepository(api));
    await tester.pumpWidget(SbExpressApp(
        session: session,
        api: api,
        language: LanguageStore(storage: _storage)));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text(bnStrings['Sign in']!), findsNothing);
  });

  testWidgets('the hub app switches to Bangla from More and back',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final language = LanguageStore(storage: _storage);
    await language.load();
    final sessionStore = MemorySessionStore()
      ..token = 'tok'
      ..userJson = jsonEncode(_hubUser());
    final api = screenFixtureApi(intercept: (request) async {
      final path = request.url.path;
      if (path == '/api/me') return _json({'user': _hubUser()});
      if (path == '/api/dashboard/hub') {
        return _json({
          'todayLabel': 'Sun 25 Oct 2026',
          'atHubCount': 0,
          'incoming': {
            'kg': 0,
            'count': 0,
            'flightCode': null,
            'flightDate': null
          },
          'openTodoCount': 0,
          'notices': <Object?>[],
          'toProcess': <Object?>[],
        });
      }
      return null;
    });
    final session =
        SessionController(store: sessionStore, auth: AuthRepository(api));
    await tester.pumpWidget(
        SbExpressApp(session: session, api: api, language: language));
    await tester.pumpAndSettle();

    for (final label in ['Home', 'Shipments', 'Flights', 'Tasks', 'More']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);

    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();
    expect(appLanguage.value, AppLanguage.bn);
    expect(await _storage.read(key: LanguageStore.key), 'bn');
    expect(find.text(bnStrings['More']!), findsWidgets);
    expect(find.text('Home'), findsNothing);

    if (find.text(bnStrings['Language']!).evaluate().isEmpty) {
      await tester.tap(find.text(bnStrings['More']!).last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(appLanguage.value, AppLanguage.en);
    expect(find.text('More'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
