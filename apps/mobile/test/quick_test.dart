import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:sbexpress/app_scope.dart';
import 'package:sbexpress/data/models/session_user.dart';
import 'package:sbexpress/data/repositories/auth_repository.dart';
import 'package:sbexpress/data/session/session_controller.dart';
import 'package:sbexpress/data/session/session_store.dart';
import 'package:sbexpress/data/uploads/photo_upload.dart';
import 'package:sbexpress/data/uploads/quick_uploads.dart';
import 'package:sbexpress/features/admin/admin_home_screen.dart';
import 'package:sbexpress/features/customers/customer_form_screen.dart';
import 'package:sbexpress/features/flights/flight_form_screen.dart';
import 'package:sbexpress/features/flights/ticket_import_screen.dart';
import 'package:sbexpress/features/flyers/flyer_detail_screen.dart';
import 'package:sbexpress/features/flyers/flyer_form_screen.dart';
import 'package:sbexpress/features/intake/booking_done_screen.dart';
import 'package:sbexpress/features/intake/intake_screen.dart';
import 'package:sbexpress/features/more/destinations.dart';
import 'package:sbexpress/features/more/more_screen.dart';
import 'package:sbexpress/features/settings/staff_screen.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'package:sbexpress/theme/app_theme.dart';
import 'package:sbexpress/widgets/quick_parts.dart';
import 'restructured_flow_test.dart' show app, phone;
import 'support/screen_fixtures.dart';
import 'support/team_fixtures.dart';

http.Response _ok(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

Future<void> _reveal(WidgetTester t, Finder finder, {double dy = 200}) async {
  await t.scrollUntilVisible(finder, dy,
      scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
}

/// Lets queued uploads run to the end. The signed PUT streams its body,
/// which needs a few turns of the real event loop.
Future<void> _settleUploads(WidgetTester t) async {
  for (var i = 0; i < 16; i++) {
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await t.pump(const Duration(milliseconds: 50));
  }
  await t.pumpAndSettle();
}

/// Closes the top screen; the back tooltip is in Bangla in these tests.
Future<void> _back(WidgetTester t) async {
  t.state<NavigatorState>(find.byType(Navigator).first).pop();
  await t.pumpAndSettle();
}

Uint8List _jpeg() =>
    Uint8List.fromList(img.encodeJpg(img.Image(width: 4, height: 3)));

/// Answers the reserve, signed PUT and complete calls of an upload and
/// remembers each reserve body.
Future<http.Response?> _storage(
    http.Request r, List<Map<String, Object?>> reserved) async {
  if (r.method == 'POST' && r.url.path.endsWith('/upload')) {
    reserved.add(jsonDecode(r.body) as Map<String, Object?>);
    return _ok({
      'reference': 'ref-${reserved.length}',
      'uploadUrl': 'https://storage.test/put/${reserved.length}',
      'expiresAt': '2026-10-26T12:00:00.000Z',
    }, 201);
  }
  if (r.method == 'PUT' && r.url.host == 'storage.test') {
    return http.Response('', 200);
  }
  if (r.method == 'POST' && r.url.path.endsWith('/complete')) {
    return _ok({'ok': true});
  }
  return null;
}

Widget _admin(Widget home,
    {Future<http.Response?> Function(http.Request)? intercept,
    UserRole role = UserRole.admin}) {
  final api = screenFixtureApi(intercept: intercept);
  final session = SessionController(
      store: MemorySessionStore()..token = 'tok', auth: AuthRepository(api))
    ..user = SessionUser(
        id: 'u',
        name: 'Tester',
        email: 'test@sbx.test',
        role: role,
        roleLabel: role == UserRole.admin ? 'Administrator' : 'Hub')
    ..ready = true;
  return AppScope.wired(
      session: session,
      api: api,
      child: MaterialApp(theme: buildAppTheme(), home: home));
}

void main() {
  group('customer form', () {
    testWidgets('the code is prefilled from next-code and left to the server',
        (t) async {
      phone(t);
      Map<String, dynamic>? sent;
      await t.pumpWidget(app(const CustomerFormScreen(), intercept: (r) async {
        if (r.method == 'POST' && r.url.path == '/api/suppliers') {
          sent = jsonDecode(r.body) as Map<String, dynamic>;
          return _ok({'code': 'C-15'}, 201);
        }
        return null;
      }));
      await t.pumpAndSettle();
      final code = t.widget<TextField>(find.byKey(const Key('customer-code')));
      expect(code.controller!.text, 'C-15');
      expect(find.text(tr('Auto')), findsOneWidget);
      await t.enterText(find.byKey(const Key('customer-name')), 'Mou Store');
      await t.tap(find.byKey(const Key('customer-terms-monthly')));
      await t.tap(find.byKey(const Key('customer-save')));
      await t.pumpAndSettle();
      // The suggested code is not sent, so the server can never clash on it.
      expect(sent, {'name': 'Mou Store', 'terms': 'monthly'});
    });

    testWidgets(
        'an old server without next-code leaves the field empty with a hint',
        (t) async {
      phone(t);
      Map<String, dynamic>? sent;
      await t.pumpWidget(app(const CustomerFormScreen(), intercept: (r) async {
        if (r.url.path == '/api/suppliers/next-code') {
          return _ok({'error': 'Customer not found'}, 404);
        }
        if (r.method == 'POST' && r.url.path == '/api/suppliers') {
          sent = jsonDecode(r.body) as Map<String, dynamic>;
          return _ok({'code': 'C-16'}, 201);
        }
        return null;
      }));
      await t.pumpAndSettle();
      final code = t.widget<TextField>(find.byKey(const Key('customer-code')));
      expect(code.controller!.text, isEmpty);
      expect(find.text(tr('Auto')), findsNothing);
      expect(find.text(tr('Leave empty for an automatic code')), findsWidgets);
      await t.enterText(find.byKey(const Key('customer-name')), 'Mou Store');
      await t.tap(find.byKey(const Key('customer-save')));
      await t.pumpAndSettle();
      expect(sent, {'name': 'Mou Store', 'terms': 'instant'});
      expect(t.takeException(), isNull);
    });

    testWidgets('a code already in use is shown on the code field', (t) async {
      phone(t);
      Map<String, dynamic>? sent;
      await t.pumpWidget(app(const CustomerFormScreen(), intercept: (r) async {
        if (r.method == 'POST' && r.url.path == '/api/suppliers') {
          sent = jsonDecode(r.body) as Map<String, dynamic>;
          return _ok({'error': 'Customer C-14 already exists'}, 400);
        }
        return null;
      }));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('customer-code')), 'C-14');
      await t.enterText(find.byKey(const Key('customer-name')), 'Mou Store');
      await t.tap(find.byKey(const Key('customer-save')));
      await t.pumpAndSettle();
      expect(sent?['code'], 'C-14');
      final code = t.widget<TextField>(find.byKey(const Key('customer-code')));
      expect(code.decoration?.errorText,
          tr('{code} is already used by another customer.', {'code': 'C-14'}));
      expect(find.byType(CustomerFormScreen), findsOneWidget);
    });
  });

  testWidgets(
      'a booking sends model-only units, the chosen way to pay and then the photos',
      (t) async {
    phone(t);
    Map<String, dynamic>? sent;
    final reserved = <Map<String, Object?>>[];
    final photo =
        PickedPhoto(bytes: _jpeg(), name: 'box.jpg', mime: 'image/jpeg');
    await t.pumpWidget(app(IntakeScreen(pickPhotos: (source) async => [photo]),
        intercept: (r) async {
      if (r.method == 'POST' && r.url.path == '/api/shipments') {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return _ok({'code': 'SH-54'});
      }
      return _storage(r, reserved);
    }));
    await t.pumpAndSettle();
    expect(find.text(tr('{n} of 5 done', {'n': 0})), findsOneWidget);
    await t.tap(find.text(tr('Choose a customer')));
    await t.pumpAndSettle();
    await t.tap(find.text('Nila Store'));
    await t.pumpAndSettle();
    await _reveal(t, find.text('Mobile'));
    await t.tap(find.text('Mobile'));
    await t.pumpAndSettle();
    await _reveal(t, find.byKey(const ValueKey('Mobile-model-0')));
    await t.enterText(
        find.byKey(const ValueKey('Mobile-model-0')), 'iPhone 13');
    await t.tap(find.byTooltip(tr('One more')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('Mobile-add-model')));
    await t.pumpAndSettle();
    await t.enterText(
        find.byKey(const ValueKey('Mobile-model-1')), 'Redmi Note 12');
    await t.pumpAndSettle();
    // A photo of the phones.
    final addMobile =
        find.byTooltip(tr('Add {name} photos', {'name': 'Mobile'}));
    await _reveal(t, addMobile);
    await t.tap(addMobile);
    await t.pumpAndSettle();
    await t.tap(find.text(tr('Choose from gallery')));
    await t.pumpAndSettle();
    await _reveal(t, find.byKey(const Key('intake-kg')));
    await t.enterText(find.byKey(const Key('intake-kg')), '2');
    await t.enterText(find.byKey(const Key('intake-rate')), '950');
    await t.pumpAndSettle();
    // 2 kg × 950 + 3 phones × 2,000.
    expect(t.widget<Text>(find.byKey(const Key('intake-charge'))).data,
        wholeBdt(7900));
    await _reveal(t, find.byKey(const Key('intake-terms-monthly')));
    await t.tap(find.byKey(const Key('intake-terms-monthly')));
    await t.pumpAndSettle();
    // And one of the parcel.
    final addParcel = find.byTooltip(tr('Add parcel photos'));
    await _reveal(t, addParcel);
    await t.tap(addParcel);
    await t.pumpAndSettle();
    await t.tap(find.text(tr('Choose from gallery')));
    await t.pumpAndSettle();
    expect(find.text(tr('{n} of 5 done', {'n': 4})), findsOneWidget);
    await t.tap(find.byKey(const Key('intake-create')));
    await _settleUploads(t);
    expect(sent?['paymentTerms'], 'monthly');
    expect(sent?['pcsItems'], [
      {
        'category': 'Mobile',
        'count': 3,
        'rate': 2000.0,
        'currency': 'BDT',
        'units': [
          {'model': 'iPhone 13', 'serial': ''},
          {'model': 'iPhone 13', 'serial': ''},
          {'model': 'Redmi Note 12', 'serial': ''},
        ],
      }
    ]);
    expect(find.byType(BookingDoneScreen), findsOneWidget);
    expect(
        find.text(tr('{code} is booked', {'code': 'SH-54'})), findsOneWidget);
    // The phone photo is marked with its category; the parcel photo is not.
    expect(reserved, hasLength(2));
    expect(reserved[0]['deviceCategory'], 'Mobile');
    expect(reserved[1].containsKey('deviceCategory'), isFalse);
    expect(find.text(tr('Photos uploaded')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a failed photo can be sent again from the booked screen',
      (t) async {
    phone(t);
    final reserved = <Map<String, Object?>>[];
    var failPut = true;
    final photo =
        PickedPhoto(bytes: _jpeg(), name: 'box.jpg', mime: 'image/jpeg');
    await t.pumpWidget(app(IntakeScreen(pickPhotos: (source) async => [photo]),
        intercept: (r) async {
      if (r.method == 'POST' && r.url.path == '/api/shipments') {
        return _ok({'code': 'SH-55'});
      }
      if (r.method == 'PUT' && failPut) {
        return http.Response('{"error":"Bad request"}', 400);
      }
      return _storage(r, reserved);
    }));
    await t.pumpAndSettle();
    await t.tap(find.text(tr('Choose a customer')));
    await t.pumpAndSettle();
    await t.tap(find.text('Nila Store'));
    await t.pumpAndSettle();
    await _reveal(t, find.text('General'));
    await t.tap(find.text('General'));
    await t.pumpAndSettle();
    final addParcel = find.byTooltip(tr('Add parcel photos'));
    await _reveal(t, addParcel);
    await t.tap(addParcel);
    await t.pumpAndSettle();
    await t.tap(find.text(tr('Take a photo')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('intake-create')));
    await _settleUploads(t);
    expect(
        find.text(
            trn(1, '{n} photo did not upload', '{n} photos did not upload')),
        findsOneWidget);
    failPut = false;
    await t.tap(find.byKey(const Key('upload-retry')));
    await _settleUploads(t);
    expect(find.text(tr('Photos uploaded')), findsOneWidget);
  });

  testWidgets('a new flyer is saved first, then its documents are uploaded',
      (t) async {
    phone(t);
    final calls = <String>[];
    final reserved = <Map<String, Object?>>[];
    Future<PickedPhoto?> pick(FileSource source) async =>
        source == FileSource.pdf
            ? PickedPhoto(
                bytes: Uint8List.fromList(utf8.encode('%PDF-1.4 visa')),
                name: 'visa.pdf',
                mime: 'application/pdf')
            : PickedPhoto(
                bytes: _jpeg(), name: 'student-id.jpg', mime: 'image/jpeg');
    await t
        .pumpWidget(app(FlyerFormScreen(pickFile: pick), intercept: (r) async {
      if (r.method == 'POST' && r.url.path == '/api/flyers') {
        calls.add('create');
        return _ok({'name': 'Arif Rahman'}, 201);
      }
      if (r.method == 'POST' && r.url.path.endsWith('/documents/upload')) {
        calls.add('upload ${(jsonDecode(r.body) as Map)['kind']}');
      }
      return await _storage(r, reserved) ?? await teamFixtures(r);
    }));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Arif');
    Finder slot(String kind, String label) => find.descendant(
        of: find.byKey(ValueKey('flyer-doc-$kind')),
        matching: find.text(label));
    await _reveal(t, slot('student_id', tr('Camera')));
    await t.tap(slot('student_id', tr('Camera')));
    await t.pumpAndSettle();
    await _reveal(t, slot('visa', 'PDF'));
    await t.tap(slot('visa', 'PDF'));
    await t.pumpAndSettle();
    // Student ID, passport, visa and admission letter.
    expect(find.text(tr('{n} of {total} added', {'n': 2, 'total': 4})),
        findsOneWidget);
    expect(
        find.text(trn(2, 'Save flyer and upload {n} file',
            'Save flyer and upload {n} files')),
        findsOneWidget);
    await t.tap(find.byKey(const Key('flyer-save')));
    await _settleUploads(t);
    expect(calls, ['create', 'upload student_id', 'upload visa']);
    expect(reserved.map((row) => row['contentType']),
        ['image/jpeg', 'application/pdf']);
    expect(find.byType(FlyerDetailScreen), findsOneWidget);
    // Everything arrived, so nothing waits on the flyer page.
    expect(find.text(tr('Files still to upload')), findsNothing);
    expect(t.takeException(), isNull);
  });

  group('home', () {
    testWidgets('shows money, who owes, attention, stages and flights',
        (t) async {
      phone(t);
      await t.pumpWidget(_admin(Builder(
          builder: (context) =>
              AdminHomeScreen(dashboard: AppScope.of(context).dashboard))));
      await t.pumpAndSettle();
      expect(find.text(wholeBdt(105250)), findsOneWidget);
      expect(find.text(tr('Flyers owe us')), findsOneWidget);
      expect(find.text(wholeBdt(14200)), findsOneWidget);
      await _reveal(
          t,
          find.text(tr('{code} weighed {kg} kg more than booked',
              {'code': 'SH-48', 'kg': '0.6'})));
      await _reveal(
          t,
          find.text(tr('Monthly bill: {name} owes {amount}',
              {'name': 'Nila Store', 'amount': '৳15,400'})));
      // The flight notice is left to the flight card below.
      expect(find.textContaining(' departs '), findsNothing);
      await _reveal(t, find.byKey(const Key('home-stages')));
      // China hub 2, on a flight 1, Dhaka hub 2, delivery 2.
      expect(
          find.descendant(
              of: find.byKey(const Key('home-stages')),
              matching: find.text('2')),
          findsNWidgets(3));
      await _reveal(t, find.byKey(const Key('home-next-flight')));
      expect(find.text(tr('Charges {amount}', {'amount': wholeBdt(31800)})),
          findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets(
        'an old server without the optional fields still shows the rest',
        (t) async {
      phone(t);
      final old = {
        'weekLabel': '19 Oct – 20 Oct',
        'todayLabel': 'Tuesday 20 Oct 2026',
        'rate': 17.5,
        'cash': {'bdt': 84250, 'cny': 0, 'worth': 84250},
        'received': 0,
        'expenses': 0,
        'net': 0,
        'profit': 0,
        'unpaid': 0,
        'reviewCount': 0,
        'openTodoCount': 0,
        'nextFlight': null,
        'notices': [
          {'tag': 'DUE', 'text': 'Something the app cannot read'},
        ],
        'flights': <Object>[],
        'activeShipmentCount': 0,
        'activeShipments': <Object>[],
      };
      await t.pumpWidget(_admin(
          Builder(
              builder: (context) =>
                  AdminHomeScreen(dashboard: AppScope.of(context).dashboard)),
          intercept: (r) async =>
              r.url.path == '/api/dashboard/overview' ? _ok(old) : null));
      await t.pumpAndSettle();
      expect(find.text(wholeBdt(84250)), findsOneWidget);
      expect(find.text(tr('Flyers owe us')), findsNothing);
      expect(find.text(tr('We owe')), findsNothing);
      expect(find.byKey(const Key('home-stages')), findsNothing);
      // A notice it cannot read is shown as sent.
      expect(find.text('Something the app cannot read'), findsOneWidget);
      await _reveal(t, find.text(tr('No upcoming flight')));
      expect(t.takeException(), isNull);
    });

    testWidgets('Add opens each form', (t) async {
      phone(t);
      final forms = <String, Type>{
        'add-shipment': IntakeScreen,
        'add-flight': FlightFormScreen,
        'add-customer': CustomerFormScreen,
        'add-flyer': FlyerFormScreen,
        'add-ticket': TicketImportScreen,
      };
      await t.pumpWidget(_admin(Builder(
          builder: (context) =>
              AdminHomeScreen(dashboard: AppScope.of(context).dashboard))));
      await t.pumpAndSettle();
      for (final MapEntry(key: key, value: type) in forms.entries) {
        await t.tap(find.byKey(const Key('home-add')));
        await t.pumpAndSettle();
        expect(find.text(tr('Add new')), findsOneWidget);
        await t.tap(find.byKey(Key(key)));
        await t.pumpAndSettle();
        expect(find.byWidgetPredicate((w) => w.runtimeType == type),
            findsOneWidget,
            reason: key);
        await _back(t);
        expect(find.byType(AdminHomeScreen), findsOneWidget);
      }
      expect(t.takeException(), isNull);
    });
  });

  group('More', () {
    testWidgets('admins can add an admin or hub manager and open the staff',
        (t) async {
      phone(t);
      const user = SessionUser(
          id: 'u',
          name: 'Tester',
          email: 'test@sbx.test',
          role: UserRole.admin,
          roleLabel: 'Administrator');
      await t.pumpWidget(_admin(Builder(
          builder: (context) =>
              MoreScreen(user: user, session: AppScope.of(context).session))));
      await t.pumpAndSettle();
      final add = find.text(tr('Add admin or hub manager'));
      await _reveal(t, add);
      expect(find.text(tr('Team')), findsOneWidget);
      await t.tap(add);
      await t.pumpAndSettle();
      expect(find.byType(StaffCreateScreen), findsOneWidget);
      expect(find.text(tr('Admin')), findsWidgets);
      expect(find.text(tr('Hub')), findsWidgets);
      await _back(t);
      await _reveal(t, find.text(tr('Staff')));
      await t.tap(find.text(tr('Staff')));
      await t.pumpAndSettle();
      expect(find.byType(StaffScreen), findsOneWidget);
    });

    test('the hub More has no team entries', () {
      final hub = {
        for (final group in moreGroups(UserRole.hub)) ...group.ids,
        for (final item in moreDestinations(UserRole.hub)) item.id,
      };
      expect(hub.contains('staff-add'), isFalse);
      expect(hub.contains('staff'), isFalse);
      final admin = {
        for (final group in moreGroups(UserRole.admin)) ...group.ids
      };
      expect(admin.containsAll(['staff-add', 'staff']), isTrue);
    });

    testWidgets('the hub More screen shows no Team group', (t) async {
      phone(t);
      const user = SessionUser(
          id: 'h',
          name: 'Hub desk',
          email: 'hub@sbx.test',
          role: UserRole.hub,
          roleLabel: 'Hub manager');
      await t.pumpWidget(_admin(
          Builder(
              builder: (context) => MoreScreen(
                  user: user, session: AppScope.of(context).session)),
          role: UserRole.hub));
      await t.pumpAndSettle();
      expect(find.text(tr('Team')), findsNothing);
      expect(find.text(tr('Add admin or hub manager')), findsNothing);
    });
  });
}
