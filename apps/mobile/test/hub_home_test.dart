import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sbexpress/app_scope.dart';
import 'package:sbexpress/data/api/api_client.dart';
import 'package:sbexpress/data/models/session_user.dart';
import 'package:sbexpress/data/repositories/auth_repository.dart';
import 'package:sbexpress/data/repositories/dashboard_repository.dart';
import 'package:sbexpress/data/session/session_controller.dart';
import 'package:sbexpress/data/session/session_store.dart';
import 'package:sbexpress/features/flights/hub_flights_screen.dart';
import 'package:sbexpress/features/hub/hub_home_screen.dart';
import 'package:sbexpress/features/sorting/sort_customer_screen.dart';
import 'package:sbexpress/features/sorting/sort_flight_screen.dart';
import 'package:sbexpress/theme/app_theme.dart';

import 'support/screen_fixtures.dart';

Map<String, Object?> _row({
  required String code,
  required String status,
  double? weighedKg,
}) {
  return {
    'code': code,
    'supplierCode': 'C-9',
    'supplierName': 'Karim Store',
    'flightCode': 'BG-147',
    'flightDate': '2026-10-20',
    'bookedKg': 4.5,
    'weighedKg': weighedKg,
    'effectiveKg': weighedKg ?? 4.5,
    'weightDelta': null,
    'description': 'phones',
    'categories': ['mobile'],
    'status': status,
    'statusIndex': status == 'received_bd_hub' ? 5 : 6,
    'statusLabel': status,
    'exception': null,
    'exceptionReason': '',
    'date': '2026-10-18',
    'paymentTerms': 'cod',
    'freeOfCharge': true,
    'receiptStatus': 'pending',
    'charge': 1200,
    'billAmount': 1200,
    'dueAmount': 1100,
    'paidAmount': 100,
    'payStatus': 'partial',
    'payMethod': 'bKash',
  };
}

Map<String, Object?> _flight(String code, String date,
        {Map<String, Object?>? tracking}) =>
    {
      'code': code,
      'date': date,
      'depTime': '10:40',
      'arrTime': '15:25',
      'via': 'Via KMG Kunming',
      'from': 'Chengdu',
      'to': 'Dhaka',
      'status': tracking == null ? 'upcoming' : 'departed',
      'statusLabel': tracking == null ? 'Upcoming' : 'Departed',
      'scheduleNeedsConfirmation': false,
      'flyers': ['Arif Rahman'],
      'shipmentCount': 2,
      'kg': 18.4,
      'receivedCount': 0,
      if (tracking != null) 'tracking': tracking,
      // Even if a server leaked money, the hub model must not read or show it.
      'fare': 9000,
      'revenue': 64000,
    };

Map<String, Object?> _bucket(String flight, List<String> customers,
        {int orders = 2}) =>
    {
      'flightCode': flight,
      'number': flight.split('-').first,
      'date': '2026-10-20',
      'customers': customers,
      'orders': orders,
    };

Map<String, Object?> _summary({
  List<Map<String, Object?>> toSort = const [],
  List<Map<String, Object?>> sentBack = const [],
  List<Map<String, Object?>> waiting = const [],
  List<Map<String, Object?>> delivery = const [],
}) =>
    {
      'toSort': toSort,
      'sentBack': sentBack,
      'waiting': waiting,
      'delivery': delivery,
      'waitingAdmin':
          waiting.fold<int>(0, (n, b) => n + (b['customers']! as List).length),
      'inDelivery':
          delivery.fold<int>(0, (n, b) => n + (b['customers']! as List).length),
    };

http.Response _json(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});

Future<List<String>> _pumpHome(
    WidgetTester tester, List<Map<String, Object?>> rows,
    {List<Map<String, Object?>>? flights,
    Map<String, Object?>? summary}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final paths = <String>[];
  final api = ApiClient(
    baseUrl: 'http://localhost:3002',
    session: MemorySessionStore()..token = 'tok',
    httpClient: MockClient((request) async {
      final path = request.url.path;
      paths.add(path);
      if (path == '/api/dashboard/hub') {
        return _json({
          'todayLabel': 'Sun 18 Oct 2026',
          'atHubCount': rows.length,
          'incoming': {
            'kg': 12.5,
            'count': 2,
            'flightCode': 'BG-147',
            'flightDate': '2026-10-20'
          },
          'openTodoCount': 4,
          'notices': [
            {'tag': 'WEIGHT', 'text': 'SH-W weighs 1.2 kg more than booked'},
          ],
          'toProcess': rows,
          if (flights != null) 'upcomingFlights': flights,
        });
      }
      if (path == '/api/sorting/hub-summary') {
        return _json(summary ?? _summary());
      }
      if (path == '/api/notifications/unread') return _json({'unread': 2});
      if (path.startsWith('/api/flights/hub/')) {
        return _json(hubFlightDetailBody());
      }
      return http.Response('{"error":"not here"}', 404);
    }),
  );
  final session = SessionController(
      store: MemorySessionStore()..token = 'tok', auth: AuthRepository(api))
    ..user = const SessionUser(
        id: 'u2',
        name: 'Hub desk',
        email: 'hub@sbx.test',
        role: UserRole.hub,
        roleLabel: 'Hub')
    ..ready = true;
  await tester.pumpWidget(AppScope.wired(
      session: session,
      api: api,
      child: MaterialApp(
        theme: buildAppTheme(),
        home: HubHomeScreen(dashboard: DashboardRepository(api)),
      )));
  await tester.pump();
  await tester.pump();
  await tester.pump();
  return paths;
}

double _top(WidgetTester tester, String key) =>
    tester.getTopLeft(find.byKey(Key(key))).dy;

void main() {
  testWidgets('hub home lists the day\'s sorting work, fixes first',
      (tester) async {
    final paths = await _pumpHome(
        tester,
        [
          _row(code: 'SH-W', status: 'received_bd_hub'),
        ],
        summary: _summary(
          sentBack: [
            _bucket('BG139-20261018-aa11bb', ['C-4'])
          ],
          toSort: [
            _bucket('BG147-20261020-ab12cd', ['C-9', 'C-12'], orders: 3)
          ],
          waiting: [
            _bucket('BG139-20261018-aa11bb', ['C-7'])
          ],
          delivery: [
            _bucket('BG139-20261018-aa11bb', ['C-2', 'C-5'])
          ],
        ));

    expect(paths, contains('/api/sorting/hub-summary'));
    expect(find.text('ঢাকা হাব'), findsOneWidget);
    expect(find.text('আজকের কাজ'), findsOneWidget);
    expect(find.byKey(const Key('notification-badge')), findsOneWidget);

    expect(find.text('ঠিক করে আবার পাঠান'), findsOneWidget);
    expect(find.text('C-4 · BG139 · অ্যাডমিন ফেরত পাঠিয়েছেন'), findsOneWidget);
    expect(find.text('BG147 সর্ট করুন'), findsOneWidget);
    expect(find.text('2 জন কাস্টমার · 3টি অর্ডার'), findsOneWidget);
    expect(find.text('অ্যাডমিনের অপেক্ষায়'), findsOneWidget);
    expect(find.text('ডেলিভারিতে'), findsOneWidget);

    const fix = 'hub-todo-fix-BG139-20261018-aa11bb';
    const sort = 'hub-todo-sort-BG147-20261020-ab12cd';
    const waiting = 'hub-todo-waiting-BG139-20261018-aa11bb';
    const delivery = 'hub-todo-delivery-BG139-20261018-aa11bb';
    expect(_top(tester, fix), lessThan(_top(tester, sort)));
    expect(_top(tester, sort), lessThan(_top(tester, waiting)));
    expect(_top(tester, waiting), lessThan(_top(tester, delivery)));

    // Codes only: no names, payment methods or money.
    expect(find.text('Karim Store'), findsNothing);
    expect(find.textContaining('৳'), findsNothing);
    expect(find.textContaining('bKash'), findsNothing);
    expect(find.textContaining('1200'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one sent-back customer opens its sort page, a flight its list',
      (tester) async {
    await _pumpHome(tester, const [],
        summary: _summary(sentBack: [
          _bucket('BG139-20261018-aa11bb', ['C-4'])
        ], toSort: [
          _bucket('BG147-20261020-ab12cd', ['C-9', 'C-12'])
        ]));

    await tester
        .tap(find.byKey(const Key('hub-todo-fix-BG139-20261018-aa11bb')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final customer =
        tester.widget<SortCustomerScreen>(find.byType(SortCustomerScreen));
    expect(customer.flightCode, 'BG139-20261018-aa11bb');
    expect(customer.customer, 'C-4');
    Navigator.of(tester.element(find.byType(SortCustomerScreen))).pop();
    await tester.pumpAndSettle();

    await tester
        .tap(find.byKey(const Key('hub-todo-sort-BG147-20261020-ab12cd')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
        tester
            .widget<SortFlightScreen>(find.byType(SortFlightScreen))
            .flightCode,
        'BG147-20261020-ab12cd');
  });

  testWidgets('a clear hub day says there is nothing to do', (tester) async {
    await _pumpHome(tester, const []);
    expect(find.text('আজকের কাজ'), findsOneWidget);
    expect(find.byKey(const Key('hub-todo-empty')), findsOneWidget);
    expect(find.text('এখন কোনো কাজ নেই'), findsOneWidget);
    expect(find.textContaining('hub-todo-sort'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a flight in the air shows its landing with Track and Open',
      (tester) async {
    await _pumpHome(tester, const [], flights: [
      _flight('BG305-20261020-ab12cd', '2026-10-20', tracking: r11OnTheWay()),
      _flight('BG152-20261023-cd34ef', '2026-10-23'),
    ]);
    expect(find.text('পরবর্তী ফ্লাইট · BG305'), findsOneWidget);
    expect(find.byKey(const Key('hub-home-track')), findsOneWidget);
    await tester.tap(find.byKey(const Key('hub-home-open-flight')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HubFlightDetailScreen), findsOneWidget);
  });

  testWidgets('upcoming flights show on the hub home without money',
      (tester) async {
    await _pumpHome(tester, const [], flights: [
      _flight('BG147-20261020-ab12cd', '2026-10-20'),
      _flight('BG152-20261023-cd34ef', '2026-10-23'),
    ]);
    expect(find.text('আসন্ন ফ্লাইট'), findsOneWidget);
    expect(find.text('BG147'), findsOneWidget);
    expect(find.text('2টি অর্ডার · 18.4 kg'), findsWidgets);
    expect(find.byKey(const Key('hub-home-track')), findsNothing);
    expect(find.textContaining('9000'), findsNothing);
    expect(find.textContaining('64000'), findsNothing);
    expect(find.textContaining('৳'), findsNothing);
  });
}
