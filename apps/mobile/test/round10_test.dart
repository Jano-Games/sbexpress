import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:sbexpress/app_scope.dart';
import 'package:sbexpress/data/models/session_user.dart';
import 'package:sbexpress/data/models/workspace.dart';
import 'package:sbexpress/data/repositories/auth_repository.dart';
import 'package:sbexpress/data/repositories/photo_repository.dart';
import 'package:sbexpress/data/session/session_controller.dart';
import 'package:sbexpress/data/session/session_store.dart';
import 'package:sbexpress/data/uploads/photo_upload.dart';
import 'package:sbexpress/features/admin/admin_shipment_screen.dart';
import 'package:sbexpress/features/flights/flight_detail_screen.dart';
import 'package:sbexpress/features/flights/hub_flights_screen.dart';
import 'package:sbexpress/features/intake/booking_done_screen.dart';
import 'package:sbexpress/features/intake/intake_screen.dart';
import 'package:sbexpress/features/settings/staff_screen.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'package:sbexpress/theme/app_theme.dart';
import 'package:sbexpress/widgets/people_parts.dart';
import 'restructured_flow_test.dart' show app, phone;
import 'support/screen_fixtures.dart';

http.Response _ok(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

Uint8List _jpeg() =>
    Uint8List.fromList(img.encodeJpg(img.Image(width: 4, height: 3)));

PickedPhoto _photo() =>
    PickedPhoto(bytes: _jpeg(), name: 'piece.jpg', mime: 'image/jpeg');

/// `METHOD path` of a request.
String _call(http.Request r) =>
    '${r.method} ${Uri.decodeComponent(r.url.path)}';

/// Two customers: the order's own and one who ordered a piece.
Map<String, Object?> _customer(String code, String name, String phone) => {
      'code': code,
      'name': name,
      'phone': phone,
      'address': '',
      'terms': 'instant',
      'orderCount': 1,
      'deliveredCount': 0,
      'shippedKg': 0,
      'billed': 0,
      'paid': 0,
      'balance': 0,
      'creditBalance': 0,
      'pricingPending': 0,
      'discountTotal': 0,
    };

final _customers = {
  'suppliers': [
    _customer('C-14', 'Nila Store', '01700000000'),
    _customer('C-15', 'Rahman Traders', '01900000000'),
  ]
};

/// Answers an upload's reserve, signed PUT and complete calls and keeps
/// each reserve body with its path.
Future<http.Response?> _storage(
    http.Request r, List<(String, Map<String, Object?>)> reserved) async {
  final path = r.url.path;
  if (r.method == 'POST' &&
      (path.endsWith('/upload') || path.endsWith('/device-photo'))) {
    reserved.add((path, jsonDecode(r.body) as Map<String, Object?>));
    return _ok({
      'reference': 'ref-${reserved.length}',
      'uploadUrl': 'https://storage.test/put/${reserved.length}',
      'expiresAt': '2026-10-26T12:00:00.000Z',
    }, 201);
  }
  if (r.method == 'PUT' && r.url.host == 'storage.test') {
    return http.Response('', 200);
  }
  if (r.method == 'POST' && path.endsWith('/complete')) {
    return _ok({'ok': true});
  }
  return null;
}

/// Lets queued uploads run to the end.
Future<void> _settleUploads(WidgetTester t) async {
  for (var i = 0; i < 16; i++) {
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await t.pump(const Duration(milliseconds: 50));
  }
  await t.pumpAndSettle();
}

/// Scrolls up, then down, until [finder] is built and on screen.
Future<void> _reveal(WidgetTester t, Finder finder) async {
  for (final step in const [200.0, -200.0]) {
    if (finder.evaluate().isNotEmpty) break;
    try {
      await t.scrollUntilVisible(finder, step,
          scrollable: find.byType(Scrollable).first, maxScrolls: 40);
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

/// SH-18 with two iPhones: one for the order's customer, one ordered by
/// Rahman Traders, and a history by two people.
Map<String, Object?> _order() {
  final body = round7ShipmentBody();
  final shipment = Map<String, Object?>.from(body['shipment']! as Map);
  shipment['pcsItems'] = [
    {
      'category': 'Mobile',
      'count': 2,
      'rate': 500,
      'currency': 'BDT',
      'units': [
        {
          'model': 'iPhone 13',
          'serial': '',
          'serialPhotoRef': null,
          'photoRef': null,
          'customerCode': null,
        },
        {
          'model': 'iPhone 13',
          'serial': '',
          'serialPhotoRef': null,
          'photoRef': null,
          'customerCode': 'C-15',
          'customer': {
            'code': 'C-15',
            'name': 'Rahman Traders',
            'phone': '01900000000'
          },
        },
      ],
    }
  ];
  shipment['log'] = [
    {
      'actor': 'Hub desk',
      'message': 'Status → Received at BD Hub',
      'at': '2026-10-24T09:00:00.000Z',
      'actorRole': 'hub',
      'actorPhotoRef': null,
    },
    {
      'actor': 'Rafiq',
      'message': 'Order booked',
      'at': '2026-10-20T09:00:00.000Z',
      'actorRole': 'admin',
      'actorPhotoRef': null,
    },
  ];
  return {'shipment': shipment};
}

/// The hub flight, with [ready] orders through customs and [receivedBy].
Map<String, Object?> _hubFlight(
    {required int ready,
    int received = 0,
    List<Map<String, Object?>> receivedBy = const []}) {
  final body = hubFlightDetailBody();
  final flight = Map<String, Object?>.from(body['flight']! as Map);
  flight.addAll({
    'flyerDetails': [
      {
        'name': 'Arif Rahman',
        'bdPhone': '01800000000',
        'initial': 'A',
        'photoRef': null,
      },
    ],
    'readyToReceive': ready,
    'receivedCount': received,
    'receivedBy': receivedBy,
  });
  return {'flight': flight};
}

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

void main() {
  testWidgets(
      'a booked device records who ordered it and sends its own piece photo',
      (t) async {
    phone(t);
    Map<String, dynamic>? sent;
    final reserved = <(String, Map<String, Object?>)>[];
    await t.pumpWidget(
        app(IntakeScreen(pickPhotos: (source) async => [_photo()]),
            intercept: (r) async {
      if (r.method == 'GET' && r.url.path == '/api/suppliers') {
        return _ok(_customers);
      }
      if (r.method == 'POST' && r.url.path == '/api/shipments') {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return _ok({'code': 'SH-60'});
      }
      return _storage(r, reserved);
    }));
    await t.pumpAndSettle();
    await t.tap(find.text(tr('Choose a customer')));
    await t.pumpAndSettle();
    await t.tap(find.text('Nila Store').last);
    await t.pumpAndSettle();
    await _tap(t, find.text('Mobile'));
    await _reveal(t, find.byKey(const ValueKey('Mobile-model-0')));
    await t.enterText(
        find.byKey(const ValueKey('Mobile-model-0')), 'iPhone 13');
    await t.pumpAndSettle();

    // The piece is for the order's customer until another one is chosen.
    final owner = find.byKey(const ValueKey('Mobile-owner-0'));
    await _reveal(t, owner);
    expect(find.descendant(of: owner, matching: find.text(tr('This order'))),
        findsOneWidget);
    await t.tap(owner);
    await t.pumpAndSettle();
    expect(find.byKey(const Key('owner-picker')), findsOneWidget);
    expect(find.text(tr('Who ordered it?')), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const Key('owner-picker')),
            matching: find
                .text(tr("{code} · the order's customer", {'code': 'C-14'}))),
        findsOneWidget);
    await t.tap(find.text('Rahman Traders'));
    await t.pumpAndSettle();
    expect(find.descendant(of: owner, matching: find.text('Rahman Traders')),
        findsOneWidget);

    // Its own photo.
    await _tap(t, find.byKey(const ValueKey('Mobile-0-photo-0')));
    await t.tap(find.text(tr('Choose from gallery')));
    await t.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('Mobile-0-photo-0')),
            matching: find.byType(Image)),
        findsOneWidget);

    await _reveal(t, find.byKey(const Key('intake-kg')));
    await t.enterText(find.byKey(const Key('intake-kg')), '2');
    await t.enterText(find.byKey(const Key('intake-rate')), '950');
    await t.pumpAndSettle();
    await _tap(t, find.byKey(const Key('intake-terms-monthly')));
    await _tap(t, find.byKey(const Key('intake-create')));
    await _settleUploads(t);

    expect(sent?['supplierCode'], 'C-14');
    expect((sent?['pcsItems'] as List).single['units'], [
      {'model': 'iPhone 13', 'serial': '', 'customerCode': 'C-15'},
    ]);
    expect(find.byType(BookingDoneScreen), findsOneWidget);
    expect(reserved, hasLength(1));
    expect(reserved.single.$1, '/api/shipments/SH-60/device-photo');
    expect(reserved.single.$2,
        allOf(containsPair('kind', 'device'), containsPair('unitIndex', 0)));
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'the order page shows who ordered each piece, adds piece photos and '
      'shows who did each step', (t) async {
    phone(t);
    final calls = <String>[];
    final bodies = <String, Object?>{};
    final reserved = <(String, Map<String, Object?>)>[];
    await t.pumpWidget(app(
        AdminShipmentScreen(
            code: 'SH-18',
            pickPhotos: (source) async => [_photo()]), intercept: (r) async {
      if (r.method != 'GET') {
        calls.add(_call(r));
        if (r.method == 'PATCH') bodies[_call(r)] = jsonDecode(r.body);
      }
      if (r.method == 'GET' && r.url.path == '/api/shipments/SH-18') {
        return _ok(_order());
      }
      if (r.method == 'GET' && r.url.path == '/api/shipments/SH-18/invoice') {
        return _ok(round7InvoiceBody());
      }
      if (r.method == 'GET' && r.url.path == '/api/suppliers') {
        return _ok(_customers);
      }
      if (r.method == 'PATCH' && r.url.path.contains('/devices/')) {
        return _ok({'ok': true});
      }
      return _storage(r, reserved);
    }));
    await t.pumpAndSettle();

    final devices = find.byKey(const Key('order-devices'));
    await _reveal(t, devices);
    expect(find.descendant(of: devices, matching: find.text(tr('Devices'))),
        findsOneWidget);
    expect(
        find.descendant(
            of: devices, matching: find.text(tr("This order's customer"))),
        findsOneWidget);
    expect(
        find.descendant(
            of: devices,
            matching: find.text(tr('For {name}', {'name': 'Rahman Traders'}))),
        findsOneWidget);
    expect(
        find.descendant(
            of: devices,
            matching: find.textContaining(tr('{n} photos missing', {'n': 2}))),
        findsOneWidget);

    // A photo of Rahman's phone goes up at once, on its own piece.
    await _tap(t, find.byKey(const ValueKey('order-piece-photo-0:1')));
    await t.tap(find.text(tr('Choose from gallery')));
    await _settleUploads(t);
    expect(reserved.single.$1, '/api/shipments/SH-18/device-photo');
    expect(
        reserved.single.$2,
        allOf(containsPair('kind', 'device'), containsPair('itemIndex', 0),
            containsPair('unitIndex', 1)));
    expect(calls,
        contains('POST /api/shipments/SH-18/device-photo/ref-1/complete'));

    // The first phone was for Rahman Traders too.
    await _tap(t, find.byKey(const ValueKey('order-device-owner-0-0')));
    expect(find.byKey(const Key('owner-picker')), findsOneWidget);
    await t.tap(find.text('Rahman Traders'));
    await t.pumpAndSettle();
    expect(calls, contains('PATCH /api/shipments/SH-18/devices/0/0'));
    expect(bodies['PATCH /api/shipments/SH-18/devices/0/0'],
        {'customerCode': 'C-15'});

    // Who did each step, with their role.
    final history = find.byKey(const Key('order-history'));
    await _reveal(t, history);
    expect(
        find.descendant(
            of: history, matching: find.text(tr('Received at BD Hub'))),
        findsOneWidget);
    expect(
        find.descendant(of: history, matching: find.textContaining('Hub desk')),
        findsOneWidget);
    expect(
        find.descendant(
            of: history, matching: find.textContaining(tr('Hub manager'))),
        findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the flight page shows flyer photos and who received the orders',
      (t) async {
    phone(t);
    final bookings =
        ((flowFlightDetailBody()['flight']! as Map)['bookings']! as List)
            .length;
    await t.pumpWidget(app(const FlightDetailScreen(code: flowFlightCode),
        intercept: (r) async {
      if (r.method == 'GET' && r.url.path == '/api/flights/$flowFlightCode') {
        final body = flowFlightDetailBody();
        final flight = Map<String, Object?>.from(body['flight']! as Map);
        flight['receivedBy'] = [
          {
            'userId': 'u2',
            'name': 'Hub desk',
            'role': 'hub',
            'photoRef': null,
            'count': 1,
            'at': '2026-10-24T09:00:00.000Z',
          }
        ];
        return _ok({'flight': flight});
      }
      return null;
    }));
    await t.pumpAndSettle();

    final faces = find.byKey(const Key('flight-flyer-faces'));
    await _reveal(t, faces);
    expect(find.descendant(of: faces, matching: find.text(tr('No photo yet'))),
        findsNWidgets(2));
    expect(
        find.byKey(const ValueKey('flyer-photo-Arif Rahman')), findsOneWidget);

    final received = find.byKey(const Key('flight-received-by'));
    await _reveal(t, received);
    expect(
        find.descendant(
            of: received, matching: find.text(tr('Received at the BD hub'))),
        findsOneWidget);
    expect(
        find.descendant(
            of: received,
            matching: find.text(
                tr('{n} of {total} orders', {'n': 1, 'total': bookings}))),
        findsOneWidget);
    expect(find.descendant(of: received, matching: find.text('Hub desk')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('received-add-photo-u2')), findsOneWidget);

    // The photo sheet for a flyer with no photo has no Remove.
    await _tap(t, find.byKey(const ValueKey('flyer-photo-Arif Rahman')));
    expect(find.byKey(const Key('face-camera')), findsOneWidget);
    expect(find.byKey(const Key('face-gallery')), findsOneWidget);
    expect(find.byKey(const Key('face-remove')), findsNothing);
    expect(
        find.text(tr(
            'The hub uses it to find this flyer at the airport. Use a face photo, not the passport page.')),
        findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the hub sees who is coming and receives the orders as itself',
      (t) async {
    phone(t);
    final code = (hubFlightDetailBody()['flight']! as Map)['code'] as String;
    final calls = <String>[];
    var received = false;
    await t.pumpWidget(_hubApp(HubFlightDetailScreen(code: code), (r) async {
      if (r.method == 'POST' &&
          r.url.path == '/api/flights/hub/$code/receive') {
        calls.add(_call(r));
        received = true;
        return _ok({
          'received': ['SH-51', 'SH-53']
        });
      }
      if (r.method == 'GET' && r.url.path == '/api/flights/hub/$code') {
        return _ok(received
            ? _hubFlight(ready: 0, received: 2, receivedBy: [
                {
                  'userId': 'u2',
                  'name': 'Hub desk',
                  'role': 'hub',
                  'photoRef': null,
                  'count': 2,
                  'at': '2026-10-24T09:00:00.000Z',
                }
              ])
            : _hubFlight(ready: 2));
      }
      return null;
    }));
    await t.pumpAndSettle();

    final coming = find.byKey(const Key('hub-who-is-coming'));
    expect(coming, findsOneWidget);
    expect(find.descendant(of: coming, matching: find.text('Arif Rahman')),
        findsOneWidget);
    expect(find.descendant(of: coming, matching: find.text('01800000000')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('call-Arif Rahman')), findsOneWidget);

    final card = find.byKey(const Key('hub-receive-card'));
    await _reveal(t, card);
    expect(
        find.descendant(
            of: card,
            matching:
                find.text(tr('Receiving as {name}', {'name': 'Hub desk'}))),
        findsOneWidget);
    expect(find.text(tr('Receive {n} orders', {'n': 2})), findsOneWidget);
    await _tap(t, find.byKey(const Key('hub-receive')));
    expect(find.text(tr('Receive {n} orders?', {'n': 2})), findsOneWidget);
    await _tap(t, find.byKey(const Key('hub-receive-confirm')));
    expect(calls, ['POST /api/flights/hub/$code/receive']);
    expect(find.text(tr('{n} orders received', {'n': 2})), findsOneWidget);

    final by = find.byKey(const Key('flight-received-by'));
    await _reveal(t, by);
    expect(find.descendant(of: by, matching: find.text('Hub desk')),
        findsOneWidget);
    expect(find.text(tr('Nothing to receive yet')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a staff photo goes up for that person from their page',
      (t) async {
    phone(t);
    final reserved = <(String, Map<String, Object?>)>[];
    const person = StaffAccount(
        id: 'u3',
        name: 'Jamal Hossain',
        email: 'jamal@sbx.test',
        role: 'hub',
        active: true);
    await t.pumpWidget(app(
        Builder(
            builder: (context) => Scaffold(
                body: Center(
                    child: TextButton(
                        onPressed: () {
                          final photos = AppScope.of(context).photos;
                          changeFacePhoto(context,
                              photos: photos,
                              type: PhotoOwner.user,
                              owner: person.id,
                              name: person.name,
                              photoRef: null,
                              loader: photos.loader(),
                              pick: (source) async => [_photo()]);
                        },
                        child: const Text('photo'))))),
        intercept: (r) => _storage(r, reserved)));
    await t.pumpAndSettle();
    await t.tap(find.text('photo'));
    await t.pumpAndSettle();
    expect(find.text(tr('Photo of {name}', {'name': 'Jamal Hossain'})),
        findsOneWidget);
    expect(
        find.text(tr('Shown on the flights and orders this person receives.')),
        findsOneWidget);
    await t.tap(find.byKey(const Key('face-gallery')));
    await _settleUploads(t);
    expect(reserved.single.$1, '/api/photos/upload');
    expect(
        reserved.single.$2,
        allOf(containsPair('ownerType', 'user'), containsPair('owner', 'u3'),
            containsPair('contentType', 'image/jpeg')));
    expect(find.text(tr('Photo saved')), findsOneWidget);

    // The staff page opens the same sheet from the avatar.
    await t.pumpWidget(app(const StaffEditScreen(person: person, selfId: 'u')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('staff-photo')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('face-camera')), findsOneWidget);
    expect(find.byKey(const Key('face-remove')), findsNothing);
    expect(t.takeException(), isNull);
  });
}
