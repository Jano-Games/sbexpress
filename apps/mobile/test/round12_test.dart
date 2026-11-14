import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sbexpress/app_scope.dart';
import 'package:sbexpress/data/models/session_user.dart';
import 'package:sbexpress/data/repositories/auth_repository.dart';
import 'package:sbexpress/data/session/session_controller.dart';
import 'package:sbexpress/data/session/session_store.dart';
import 'package:sbexpress/features/flights/track_screen.dart';
import 'package:sbexpress/features/notifications/notifications_screen.dart';
import 'package:sbexpress/features/settings/partners_screen.dart';
import 'package:sbexpress/features/shipments/shipment_process_screen.dart';
import 'package:sbexpress/features/sorting/approvals_screen.dart';
import 'package:sbexpress/features/sorting/approve_customer_screen.dart';
import 'package:sbexpress/features/sorting/sort_customer_screen.dart';
import 'package:sbexpress/theme/app_theme.dart';
import 'restructured_flow_test.dart' show app, phone;
import 'support/screen_fixtures.dart';

const _flight = 'BG305-20261021-ab12cd';

http.Response _ok(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

String _call(http.Request r) =>
    '${r.method} ${r.url.path}${r.url.hasQuery ? '?${r.url.query}' : ''}';

Map<String, Object?> _body(http.Request r) =>
    jsonDecode(r.body) as Map<String, Object?>;

Widget _hubApp(Widget home, Future<http.Response?> Function(http.Request) on) {
  final api = screenFixtureApi(intercept: on);
  final session = SessionController(
      store: MemorySessionStore()..token = 'tok', auth: AuthRepository(api))
    ..user = const SessionUser(
        id: 'u2',
        name: 'Hub desk',
        email: 'hub@sbx.test',
        role: UserRole.hub,
        roleLabel: 'Hub Manager')
    ..ready = true;
  return AppScope.wired(
      session: session,
      api: api,
      child: MaterialApp(theme: buildAppTheme(), home: home));
}

/// Scrolls up, then down, until [finder] is built and on screen.
Future<void> _reveal(WidgetTester t, Finder finder) async {
  for (final step in const [-200.0, 200.0]) {
    if (finder.evaluate().isNotEmpty) break;
    try {
      await t.scrollUntilVisible(finder, step,
          scrollable: find.byType(Scrollable).first, maxScrolls: 30);
    } on StateError {
      // Not that way.
    }
  }
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
}

Future<void> _tap(WidgetTester t, Finder finder) async {
  await _reveal(t, finder);
  await t.tap(finder);
  await t.pumpAndSettle();
}

Future<void> _type(WidgetTester t, String key, String text) async {
  final field = find.byKey(Key(key));
  await _reveal(t, field);
  await t.enterText(field, text);
  await t.pumpAndSettle();
}

Map<String, Object?> _order(String code, String state,
        {double booked = 4, double? weighed, String arrived = ''}) =>
    {
      'code': code,
      'state': state,
      'statusLabel': state,
      'description': 'phones',
      'categories': ['Mobile'],
      'bookedKg': booked,
      'weighedKg': weighed,
      'weightDelta': weighed == null ? null : weighed - booked,
      'arrivedNote': arrived,
      'goodsPhotos': <String>[],
      'devicePhotos': <Object>[],
      'flyerName': 'Arif Rahman',
    };

Map<String, Object?> _group(
        String customer, String state, List<Map<String, Object?>> orders,
        {bool needsLook = false,
        String? partner,
        String? name,
        bool money = false}) =>
    {
      'customerCode': customer,
      if (name != null) 'customerName': name,
      'state': state,
      'orders': orders,
      'bookedKg': orders.fold<double>(
          0, (n, o) => n + (o['bookedKg']! as num).toDouble()),
      'measuredKg': orders.fold<double>(0,
          (n, o) => n + ((o['weighedKg'] ?? o['bookedKg'])! as num).toDouble()),
      'needsLook': needsLook,
      'packages': partner == null ? 0 : 1,
      'packingPhotos': <Object>[],
      'hubNote': '',
      'sentBackNote': '',
      if (partner != null) 'partner': partner,
      if (partner != null) 'sortedAt': '2026-10-21T10:30:00.000Z',
      if (partner != null) 'sortedBy': 'Hub desk',
      if (money)
        'money': {'bill': 9100, 'paid': 2000, 'due': 7100, 'bookedBill': 8200},
    };

Map<String, Object?> _board(List<Map<String, Object?>> groups) => {
      'flight': {
        'code': _flight,
        'number': 'BG305',
        'date': '2026-10-21',
        'arrTime': '15:25',
        'status': 'landed'
      },
      'partners': ['Steadfast', 'Pathao', 'Hub pickup'],
      'groups': groups,
    };

void main() {
  testWidgets('notifications read one by one or all, and open their page',
      (t) async {
    phone(t);
    final calls = <String>[];
    final now = DateTime.now().toUtc();
    await t.pumpWidget(app(const NotificationsScreen(), intercept: (r) async {
      final path = r.url.path;
      if (path == '/api/notifications') {
        return _ok({
          'unread': 2,
          'notifications': [
            {
              'id': 'n1',
              'event': 'flight_new',
              'params': {
                'flight': 'BG147',
                'date': '2026-10-20',
                'arrTime': '15:25',
                'days': 2,
                'orders': 3,
                'flyers': 'Arif Rahman',
              },
              'read': false,
              'createdAt': now.toIso8601String(),
              'flightCode': 'BG147-20261020-ab12cd',
            },
            {
              'id': 'n2',
              'event': 'sort_waiting',
              'params': {
                'flight': 'BG305',
                'customer': 'C-14',
                'by': 'Hub desk',
                'orders': 2,
                'kg': '9.1',
              },
              'read': false,
              'createdAt': now.toIso8601String(),
              'flightCode': _flight,
              'customerCode': 'C-14',
            },
            {
              'id': 'n3',
              'event': 'flight_landed',
              'params': {'flight': 'BG139', 'arrTime': '15:30', 'orders': 4},
              'read': true,
              'createdAt':
                  now.subtract(const Duration(days: 1)).toIso8601String(),
              'flightCode': 'BG139-20261020-ab12cd',
            },
          ],
        });
      }
      if (r.method == 'POST' && path.startsWith('/api/notifications/')) {
        calls.add(_call(r));
        return _ok({'ok': true});
      }
      if (path == '/api/sorting/flights/$_flight') {
        return _ok(_board([
          _group('C-14', 'waiting_admin',
              [_order('SH-51', 'waiting_admin', weighed: 4.2)],
              partner: 'Pathao', name: 'Nila Store', money: true)
        ]));
      }
      return null;
    }));
    await t.pumpAndSettle();

    expect(find.textContaining('নতুন ফ্লাইট BG147।'), findsOneWidget);
    expect(
        find.textContaining(
            'Hub desk BG305 থেকে C-14 সর্ট করেছেন: 2টি অর্ডার, 9.1 kg।'),
        findsOneWidget);
    expect(find.textContaining('BG139 ঢাকায় নেমেছে 15:30-এ।'), findsOneWidget);

    // A tap reads one and opens its page.
    await _tap(t, find.byKey(const Key('notification-n2')));
    expect(calls, ['POST /api/notifications/n2/read']);
    final page =
        t.widget<ApproveCustomerScreen>(find.byType(ApproveCustomerScreen));
    expect(page.flightCode, _flight);
    expect(page.customer, 'C-14');
    Navigator.of(t.element(find.byType(ApproveCustomerScreen))).pop();
    await t.pumpAndSettle();

    await _tap(t, find.byKey(const Key('notifications-read-all')));
    expect(calls.last, 'POST /api/notifications/read-all');
    // Reading the rest leaves nothing to mark.
    expect(find.byKey(const Key('notifications-read-all')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('the bell shows the unread count', (t) async {
    phone(t);
    await t.pumpWidget(app(
        Scaffold(appBar: AppBar(actions: const [NotificationBell()])),
        intercept: (r) async => r.url.path == '/api/notifications/unread'
            ? _ok({'unread': 3})
            : null));
    await t.pump();
    await t.pump();
    final badge = find.byKey(const Key('notification-badge'));
    expect(badge, findsOneWidget);
    expect(
        find.descendant(of: badge, matching: find.text('3')), findsOneWidget);
  });

  testWidgets('the hub sorts a customer and sends it to the admin', (t) async {
    phone(t);
    final posts = <(String, Map<String, Object?>)>[];
    var sent = false;
    await t.pumpWidget(
        _hubApp(const SortCustomerScreen(flightCode: _flight, customer: 'C-14'),
            (r) async {
      final path = r.url.path;
      if (r.method == 'GET' && path == '/api/sorting/flights/$_flight') {
        return _ok(_board([
          sent
              ? _group(
                  'C-14',
                  'waiting_admin',
                  [
                    _order('SH-51', 'waiting_admin', weighed: 4.2),
                    _order('SH-53', 'waiting_admin', booked: 5, weighed: 4.9),
                  ],
                  partner: 'Pathao')
              : _group('C-14', 'to_sort', [
                  _order('SH-51', 'to_sort'),
                  _order('SH-53', 'to_sort', booked: 5),
                ]),
        ]));
      }
      if (r.method == 'POST' && path.startsWith('/api/sorting/')) {
        posts.add((path, _body(r)));
        sent = true;
        return _ok({'ok': true});
      }
      return null;
    }));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('sort-order-SH-51')), findsOneWidget);
    expect(find.text('Nila Store'), findsNothing);

    // Nothing goes out until every order has a weight and what arrived.
    await _tap(t, find.byKey(const Key('sort-send')));
    expect(posts, isEmpty);
    expect(find.text('প্রতিটি অর্ডারের ওজন আর কী এসেছে লিখুন'), findsWidgets);

    await _type(t, 'sort-kg-SH-51', '4.2');
    await _type(t, 'sort-arrived-SH-51', '2 cartons of phones');
    await _type(t, 'sort-kg-SH-53', '4.9');
    await _type(t, 'sort-arrived-SH-53', '1 carton of cases');
    await _tap(t, find.text('Pathao'));
    await _type(t, 'sort-courier', 'PT-889');
    await _type(t, 'sort-note', 'Call before delivery');
    await _tap(t, find.byKey(const Key('sort-send')));

    expect(posts, hasLength(1));
    expect(
        posts.single.$1, '/api/sorting/flights/$_flight/customers/C-14/sort');
    expect(posts.single.$2, {
      'orders': [
        {'code': 'SH-51', 'kg': 4.2, 'arrived': '2 cartons of phones'},
        {'code': 'SH-53', 'kg': 4.9, 'arrived': '1 carton of cases'},
      ],
      'packages': 2,
      'partner': 'Pathao',
      'courierRef': 'PT-889',
      'note': 'Call before delivery',
    });
    expect(find.text('অ্যাডমিনের কাছে পাঠানো হয়েছে'), findsOneWidget);
    expect(find.byKey(const Key('sort-send')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('the admin sends a customer back with a reason', (t) async {
    phone(t);
    final posts = <(String, Map<String, Object?>)>[];
    await t.pumpWidget(
        app(const ApproveCustomerScreen(flightCode: _flight, customer: 'C-14'),
            intercept: (r) async {
      final path = r.url.path;
      if (r.method == 'GET' && path == '/api/sorting/flights/$_flight') {
        return _ok(_board([
          _group('C-14', 'waiting_admin',
              [_order('SH-51', 'waiting_admin', weighed: 5.6)],
              needsLook: true,
              partner: 'Pathao',
              name: 'Nila Store',
              money: true)
        ]));
      }
      if (r.method == 'POST') {
        posts.add((path, _body(r)));
        return _ok({'ok': true});
      }
      return null;
    }));
    await t.pumpAndSettle();

    expect(find.text('Nila Store'), findsWidgets);
    await _tap(t, find.byKey(const Key('approve-send-back')));
    await _tap(t, find.text('ওজন ঠিক মনে হচ্ছে না'));
    await t.enterText(
        find.byKey(const Key('send-back-note')), 'Weigh SH-51 again');
    await t.pumpAndSettle();
    await _tap(t, find.byKey(const Key('send-back-confirm')));

    expect(posts, hasLength(1));
    expect(posts.single.$1,
        '/api/sorting/flights/$_flight/customers/C-14/send-back');
    expect(
        posts.single.$2, {'note': 'ওজন ঠিক মনে হচ্ছে না. Weigh SH-51 again'});
    expect(find.text('হাবে ফেরত পাঠানো হয়েছে'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the admin approves a sorted customer', (t) async {
    phone(t);
    final posts = <String>[];
    await t.pumpWidget(
        app(const ApproveCustomerScreen(flightCode: _flight, customer: 'C-14'),
            intercept: (r) async {
      final path = r.url.path;
      if (r.method == 'GET' && path == '/api/sorting/flights/$_flight') {
        return _ok(_board([
          _group('C-14', 'waiting_admin',
              [_order('SH-51', 'waiting_admin', weighed: 4)],
              partner: 'Pathao', name: 'Nila Store', money: true)
        ]));
      }
      if (r.method == 'POST') {
        posts.add(_call(r));
        return _ok({'ok': true});
      }
      return null;
    }));
    await t.pumpAndSettle();
    await _tap(t, find.byKey(const Key('approve-approve')));
    expect(
        posts, ['POST /api/sorting/flights/$_flight/customers/C-14/approve']);
    expect(find.text('অ্যাপ্রুভ হয়েছে। Pathao-এর সাথে ডেলিভারিতে।'),
        findsOneWidget);
  });

  testWidgets('approve all waits while a customer needs a look', (t) async {
    phone(t);
    const clean = 'BG152-20261023-cd34ef';
    final posts = <String>[];
    Map<String, Object?> flight(
            String code, String number, List<Map<String, Object?>> groups) =>
        {
          'flight': {
            'code': code,
            'number': number,
            'date': '2026-10-21',
            'arrTime': '15:25',
            'status': 'landed'
          },
          'groups': groups,
        };
    await t.pumpWidget(app(const ApprovalsScreen(), intercept: (r) async {
      if (r.method == 'GET' && r.url.path == '/api/sorting/approvals') {
        return _ok({
          'count': 3,
          'flights': [
            flight(_flight, 'BG305', [
              _group('C-14', 'waiting_admin',
                  [_order('SH-51', 'waiting_admin', weighed: 5.6)],
                  needsLook: true, partner: 'Pathao', name: 'Nila Store'),
              _group('C-9', 'waiting_admin',
                  [_order('SH-52', 'waiting_admin', weighed: 4)],
                  partner: 'Hub pickup', name: 'Karim Store'),
            ]),
            flight(clean, 'BG152', [
              _group('C-12', 'waiting_admin',
                  [_order('SH-60', 'waiting_admin', weighed: 4)],
                  partner: 'Steadfast', name: 'Rafi Traders'),
            ]),
          ],
        });
      }
      if (r.method == 'POST') {
        posts.add(_call(r));
        return _ok({
          'approved': ['SH-60'],
          'skipped': <String>[]
        });
      }
      return null;
    }));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('approval-C-14')), findsOneWidget);
    final blocked =
        t.widget<FilledButton>(find.byKey(const Key('approve-all-$_flight')));
    expect(blocked.onPressed, isNull);

    await _tap(t, find.byKey(const Key('approve-all-$clean')));
    await _tap(t, find.byKey(const Key('approve-all-confirm')));
    expect(posts, ['POST /api/sorting/flights/$clean/approve-all']);
    expect(t.takeException(), isNull);
  });

  testWidgets('delivery partners are added, removed and saved at once',
      (t) async {
    phone(t);
    final saved = <List<Object?>>[];
    var partners = <String>['Steadfast', 'Pathao'];
    await t.pumpWidget(app(const PartnersScreen(), intercept: (r) async {
      if (r.url.path != '/api/settings') return null;
      if (r.method == 'PATCH') {
        partners = [
          for (final p in _body(r)['deliveryPartners']! as List) p as String
        ];
        saved.add(partners);
      }
      return _ok({
        'settings': {'deliveryPartners': partners}
      });
    }));
    await t.pumpAndSettle();

    expect(find.text('Steadfast'), findsOneWidget);
    expect(find.text('সবসময় চালু'), findsOneWidget);
    await _type(t, 'partner-name', 'RedX');
    await _tap(t, find.byKey(const Key('partner-add')));
    expect(saved.last, ['Steadfast', 'Pathao', 'RedX']);

    // Hub pickup is always there and cannot be added twice.
    await _type(t, 'partner-name', 'hub pickup');
    await _tap(t, find.byKey(const Key('partner-add')));
    expect(saved, hasLength(1));

    await _tap(t, find.byKey(const Key('partner-remove-Pathao')));
    await _tap(t, find.byKey(const Key('partner-remove-confirm')));
    expect(saved.last, ['Steadfast', 'RedX']);
    expect(find.text('Pathao'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('Track shows the plane and spends a refresh only on a tap',
      (t) async {
    phone(t);
    final calls = <String>[];
    final now = DateTime.now().toUtc();
    Map<String, Object?> answer({required int left, DateTime? next}) => {
          'inAir': true,
          'refreshesLeft': left,
          'nextRefreshAt': next?.toIso8601String(),
          'track': {
            'legCode': 'BG306',
            'from': {
              'iata': 'KMG',
              'city': 'Kunming',
              'lat': 24.99,
              'lon': 102.74
            },
            'to': {'iata': 'DAC', 'city': 'Dhaka', 'lat': 23.84, 'lon': 90.4},
            'route': [
              {'iata': 'CTU', 'city': 'Chengdu', 'lat': 30.58, 'lon': 103.95},
              {'iata': 'KMG', 'city': 'Kunming', 'lat': 24.99, 'lon': 102.74},
              {'iata': 'DAC', 'city': 'Dhaka', 'lat': 23.84, 'lon': 90.4},
            ],
            'position': {
              'lat': 24.4,
              'lon': 96.2,
              'altitudeM': 10668,
              'speedKmh': 812,
              'headingDeg': 250,
              'reportedAt': now.toIso8601String(),
            },
            'landsAt': '15:40',
            'arrLateMin': 15,
            'progress': 55,
            'checkedAt': now.toIso8601String(),
            'sample': false,
          },
        };
    await t.pumpWidget(
        _hubApp(const TrackScreen(code: _flight, title: 'BG305', tiles: false),
            (r) async {
      if (r.url.path == '/api/flights/hub/$_flight/position') {
        calls.add(_call(r));
        return _ok(r.url.queryParameters['refresh'] == '1'
            ? answer(left: 3, next: now.add(const Duration(minutes: 15)))
            : answer(left: 4));
      }
      return null;
    }));
    await t.pumpAndSettle();

    expect(calls, ['GET /api/flights/hub/$_flight/position']);
    expect(find.byKey(const Key('track-map')), findsOneWidget);
    expect(find.byKey(const Key('track-card')), findsOneWidget);
    expect(find.text('উচ্চতা'), findsOneWidget);
    expect(find.text('গতি'), findsOneWidget);

    await _tap(t, find.byKey(const Key('track-refresh')));
    expect(calls.last, 'GET /api/flights/hub/$_flight/position?refresh=1');
    final refresh = find.byKey(const Key('track-refresh'));
    await _reveal(t, refresh);
    final button = t.widget<ButtonStyleButton>(find.descendant(
        of: refresh,
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));
    expect(button.onPressed, isNull);
    expect(find.textContaining('আবার রিফ্রেশ করা যাবে'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Track says so when the flight is not in the air', (t) async {
    phone(t);
    await t.pumpWidget(_hubApp(
        const TrackScreen(code: _flight, title: 'BG305', tiles: false),
        (r) async => r.url.path == '/api/flights/hub/$_flight/position'
            ? _ok({'inAir': false, 'refreshesLeft': 6})
            : null));
    await t.pumpAndSettle();
    expect(find.text('ফ্লাইটটি এখন আকাশে নেই'), findsOneWidget);
    expect(find.byKey(const Key('track-map')), findsNothing);
  });

  testWidgets('a hub order on a flight points to sorting, not old steps',
      (t) async {
    phone(t);
    await t.pumpWidget(
        _hubApp(const ShipmentProcessScreen(code: 'SH-18'), (_) async => null));
    await t.pumpAndSettle();

    final open = find.byKey(const Key('process-open-sort'));
    await _reveal(t, open);
    expect(open, findsOneWidget);
    expect(find.text('Nila Store'), findsNothing);
    await t.tap(open);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    final sort = t.widget<SortCustomerScreen>(find.byType(SortCustomerScreen));
    expect(sort.flightCode, 'BG305-20261021-ab12cd');
    expect(sort.customer, 'C-14');
  });
}
