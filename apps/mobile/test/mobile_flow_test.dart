import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sbexpress/app_scope.dart';
import 'package:sbexpress/data/api/api_client.dart';
import 'package:sbexpress/data/models/session_user.dart';
import 'package:sbexpress/data/repositories/auth_repository.dart';
import 'package:sbexpress/data/session/session_controller.dart';
import 'package:sbexpress/data/session/session_store.dart';
import 'package:sbexpress/features/admin/payment_review_screen.dart';
import 'package:sbexpress/features/shell/main_shell.dart';
import 'package:sbexpress/features/tasks/tasks_screen.dart';
import 'package:sbexpress/theme/app_theme.dart';

Widget _app(Widget home, Future<http.Response> Function(http.Request) handler,
    {UserRole role = UserRole.admin}) {
  final store = MemorySessionStore()..token = 'test';
  final api = ApiClient(
      baseUrl: 'http://localhost:3002',
      session: store,
      httpClient: MockClient(handler));
  final session = SessionController(store: store, auth: AuthRepository(api))
    ..user = SessionUser(
        id: 'u1',
        name: 'Tester',
        email: 'test@sbx.test',
        role: role,
        roleLabel: role.name)
    ..ready = true;
  return AppScope.wired(
      session: session,
      api: api,
      child: MaterialApp(theme: buildAppTheme(), home: home));
}

http.Response _json(Object data) =>
    http.Response.bytes(utf8.encode(jsonEncode(data)), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, Object?> _receipt(String code) => {
      'code': code,
      'supplierCode': 'C-1',
      'supplierName': 'Customer $code',
      'method': 'Bank',
      'amount': 1900,
      'sourceCurrency': 'CNY',
      'sourceAmount': 100,
      'txnRef': 'TX-$code',
      'date': '21 Oct 2026',
      'screenshot': null,
    };

void main() {
  testWidgets('tabs load on first visit and preserve an open note',
      (tester) async {
    final paths = <String>[];
    await tester.pumpWidget(_app(const MainShell(), (request) async {
      paths.add(request.url.path);
      return _json(switch (request.url.path) {
        '/api/dashboard/hub' => {
            'todayLabel': 'Today',
            'atHubCount': 0,
            'incoming': {
              'kg': 0,
              'count': 0,
              'flightCode': null,
              'flightDate': null
            },
            'openTodoCount': 0,
            'notices': [],
            'toProcess': []
          },
        '/api/todos' => {'todos': []},
        '/api/shipments' => {'shipments': []},
        '/api/flights/hub' => {'upcoming': [], 'arrived': []},
        _ => <String, Object?>{},
      });
    }, role: UserRole.hub));
    await tester.pumpAndSettle();
    expect(paths, ['/api/dashboard/hub']);
    await tester.tap(find.byKey(const Key('nav-3')));
    await tester.pumpAndSettle();
    expect(paths.where((path) => path == '/api/todos').length, 1);
    await tester.tap(find.byTooltip('নতুন নোট'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(TasksScreen), matching: find.byType(TextField)),
        'Keep my draft');
    await tester.tap(find.byKey(const Key('nav-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('Keep my draft'), findsOneWidget);
    expect(paths.where((path) => path == '/api/todos').length, 1);
    expect(paths.contains('/api/shipments'), isFalse);
    expect(paths.contains('/api/flights/hub'), isFalse);
    await tester.tap(find.byKey(const Key('nav-2')));
    await tester.pumpAndSettle();
    expect(paths.where((path) => path == '/api/flights/hub').length, 1);
    expect(find.text('আসন্ন ফ্লাইট নেই'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'receipt list opens the selected receipt and returns after approval',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var approved = false;
    final posts = <String>[];
    await tester.pumpWidget(_app(const PaymentReviewScreen(), (request) async {
      if (request.method == 'POST') {
        posts.add(request.url.path);
        approved = true;
        return _json({'ok': true});
      }
      return _json({
        'queue': [if (!approved) _receipt('SH-1'), _receipt('SH-2')],
        'statements': []
      });
    }));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('review-approve')), findsNothing);
    await tester.tap(find.text('Customer SH-2'));
    await tester.pumpAndSettle();
    expect(find.text('TX-SH-2'), findsOneWidget);
    await tester.tap(find.byTooltip('পিছনে'));
    await tester.pumpAndSettle();
    expect(find.text('যাচাইয়ের অপেক্ষায়'), findsOneWidget);
    await tester.tap(find.text('Customer SH-1'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('review-approve')));
    await tester.tap(find.byKey(const Key('review-approve')));
    await tester.pumpAndSettle();
    expect(posts, ['/api/shipments/SH-1/receipt/approve']);
    expect(find.text('যাচাইয়ের অপেক্ষায়'), findsOneWidget);
    expect(find.text('Customer SH-1'), findsNothing);
    expect(find.text('Customer SH-2'), findsOneWidget);
    expect(find.byKey(const Key('review-approve')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
