import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sbexpress/data/api/api_client.dart';
import 'package:sbexpress/data/models/payment_review.dart';
import 'package:sbexpress/data/models/session_user.dart';
import 'package:sbexpress/data/repositories/auth_repository.dart';
import 'package:sbexpress/data/repositories/review_repository.dart';
import 'package:sbexpress/data/session/session_store.dart';
import 'package:sbexpress/features/auth/login_screen.dart';
import 'package:sbexpress/features/more/destinations.dart';
import 'package:sbexpress/widgets/ui.dart';

void main() {
  test('login sends email and password and stores the account role', () async {
    final store = MemorySessionStore();
    late Map<String, Object?> sent;
    final api = ApiClient(
      baseUrl: 'http://localhost:3002',
      session: store,
      httpClient: MockClient((request) async {
        sent = jsonDecode(request.body) as Map<String, Object?>;
        expect(request.headers['authorization'], isNull);
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'token': 'tok',
            'user': {
              'id': 'u1',
              'name': 'Hub Mina',
              'email': 'mina@sbx.test',
              'role': 'hub',
              'roleLabel': 'Hub Manager · Dhaka',
            },
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final user = await AuthRepository(api)
        .login(email: 'Mina@sbx.test', password: 'secret');
    expect(sent.keys.toSet(), {'email', 'password'});
    expect(sent.containsKey('role'), isFalse);
    expect(sent['email'], 'Mina@sbx.test');
    expect(user.role, UserRole.hub);
    expect(store.token, 'tok');
    expect(parseRole('admin'), UserRole.admin);
    expect(() => parseRole('customer'), throwsFormatException);
  });

  test('payment approve sends an idempotency key', () async {
    final store = MemorySessionStore()..token = 'tok';
    String? key;
    final api = ApiClient(
      baseUrl: 'http://localhost:3002',
      session: store,
      httpClient: MockClient((request) async {
        key = request.headers['idempotency-key'];
        expect(request.url.path, '/api/shipments/SH-1/receipt/approve');
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );
    await ReviewRepository(api).approve(PaymentReviewItem.shipment({
      'code': 'SH-1',
      'supplierCode': 'C-1',
      'supplierName': 'Nila',
      'method': 'bKash',
      'amount': 10,
      'sourceCurrency': 'BDT',
      'sourceAmount': 10,
      'txnRef': 'TX',
      'date': '2026-10-18T00:00:00.000Z',
      'screenshot': null,
    }));
    expect(key, matches(RegExp(r'^[0-9a-f-]{36}$')));
  });

  test('hub more menu has no finance or invoice tools', () {
    final hub = moreDestinations(UserRole.hub).map((item) => item.id).toSet();
    final admin =
        moreDestinations(UserRole.admin).map((item) => item.id).toSet();
    expect(hub.contains('finance'), isFalse);
    expect(hub.contains('invoice-share'), isFalse);
    expect(admin.contains('finance'), isTrue);
  });

  testWidgets('login has email and password and no role picker',
      (tester) async {
    String? email;
    await tester.pumpWidget(MaterialApp(
      home: LoginScreen(onSubmit: (value, password) async {
        email = value;
        expect(password, 'secret');
      }),
    ));
    expect(find.byType(DropdownButton<UserRole>), findsNothing);
    expect(find.byType(Radio<UserRole>), findsNothing);
    expect(find.text('OTP পাঠান'), findsNothing);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(find.byKey(const Key('login-password')), findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('login-email')), 'mina@sbx.test');
    await tester.enterText(find.byKey(const Key('login-password')), 'secret');
    await tester.ensureVisible(find.byKey(const Key('login-submit')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump();
    expect(email, 'mina@sbx.test');
  });

  testWidgets('hub bottom nav has five tabs with flights and 48px targets',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            bottomNavigationBar: AppBottomNav(index: 0, onChanged: (_) {}))));
    for (var i = 0; i < 5; i++) {
      final size = tester.getSize(find.byKey(Key('nav-$i')));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(find.byKey(const Key('nav-pill')), findsOneWidget);
    expect(find.text('হোম'), findsOneWidget);
    expect(find.text('শিপমেন্ট'), findsOneWidget);
    expect(find.text('ফ্লাইট'), findsOneWidget);
    expect(find.text('কাজ'), findsOneWidget);
    expect(find.text('আরও'), findsOneWidget);
  });
}
