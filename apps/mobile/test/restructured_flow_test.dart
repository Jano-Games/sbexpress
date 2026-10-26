import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sbexpress/app_scope.dart';
import 'package:sbexpress/data/models/session_user.dart';
import 'package:sbexpress/data/repositories/auth_repository.dart';
import 'package:sbexpress/data/session/session_controller.dart';
import 'package:sbexpress/data/session/session_store.dart';
import 'package:sbexpress/features/admin/admin_shipment_screen.dart';
import 'package:sbexpress/features/customers/customers_screen.dart';
import 'package:sbexpress/features/finance/finance_screen.dart';
import 'package:sbexpress/features/finance/transfer_screen.dart';
import 'package:sbexpress/features/flights/flight_detail_screen.dart';
import 'package:sbexpress/features/intake/booking_done_screen.dart';
import 'package:sbexpress/features/intake/intake_screen.dart';
import 'package:sbexpress/features/shell/main_shell.dart';
import 'package:sbexpress/features/tasks/tasks_screen.dart';
import 'package:sbexpress/theme/app_theme.dart';
import 'package:sbexpress/widgets/ui.dart';
import 'support/screen_fixtures.dart';

Widget app(Widget home,
    {Future<http.Response?> Function(http.Request)? intercept}) {
  final api = screenFixtureApi(intercept: intercept);
  final session = SessionController(
      store: MemorySessionStore()..token = 'tok', auth: AuthRepository(api))
    ..user = const SessionUser(
        id: 'u',
        name: 'Tester',
        email: 'test@sbx.test',
        role: UserRole.admin,
        roleLabel: 'Administrator')
    ..ready = true;
  return AppScope.wired(
      session: session,
      api: api,
      child: MaterialApp(theme: buildAppTheme(), home: home));
}

Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label);
Future<void> enter(WidgetTester t, String label, String value) async {
  await t.ensureVisible(field(label));
  await t.enterText(field(label), value);
}

/// Scrolls down to the field with [key] and types [value] into it.
Future<void> enterKey(WidgetTester t, String key, String value) async {
  final field = find.byKey(Key(key));
  await t.scrollUntilVisible(field, 200,
      scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(field);
  await t.enterText(field, value);
  // Let the focused field finish scrolling itself into view.
  await t.pumpAndSettle();
}

void phone(WidgetTester t) {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
      'admin navigation loads each destination lazily and keeps tasks reachable',
      (t) async {
    phone(t);
    final paths = <String>[];
    await t.pumpWidget(app(const MainShell(), intercept: (r) async {
      paths.add(r.url.path);
      return null;
    }));
    await t.pumpAndSettle();
    expect(paths, ['/api/dashboard/overview']);
    expect(find.byKey(const Key('nav-4')), findsOneWidget);
    await t.tap(find.byKey(const Key('nav-2')));
    await t.pumpAndSettle();
    expect(paths.where((p) => p == '/api/flights').length, 1);
    expect(find.text('BG305'), findsOneWidget);
    await t.tap(find.byKey(const Key('nav-3')));
    await t.pumpAndSettle();
    expect(find.text('Dhaka cash'), findsOneWidget);
    await t.tap(find.byKey(const Key('nav-4')));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('কাজ ও নোট'));
    await t.tap(find.text('কাজ ও নোট'));
    await t.pumpAndSettle();
    expect(find.byType(TasksScreen), findsOneWidget);
    await t.tap(find.byTooltip('পিছনে'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('nav-2')));
    await t.pumpAndSettle();
    expect(paths.where((p) => p == '/api/flights').length, 1);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'finance tabs preserve currencies, reporting period and transaction entry points',
      (t) async {
    phone(t);
    final queries = <String>[];
    await t.pumpWidget(app(const FinanceScreen(), intercept: (r) async {
      queries.add(r.url.toString());
      return null;
    }));
    await t.pumpAndSettle();
    expect(find.text('Dhaka cash'), findsOneWidget);
    expect(find.text('Chengdu cash'), findsOneWidget);
    await t.tap(find.text('রিপোর্ট'));
    await t.pumpAndSettle();
    await t.tap(find.text('সর্বমোট'));
    await t.pumpAndSettle();
    expect(queries.any((q) => q.contains('period=all')), isTrue);
    await t.tap(find.text('লেনদেন'));
    await t.pumpAndSettle();
    for (final name in [
      'অ্যাকাউন্ট ট্রান্সফার',
      'জমা বা খরচ',
      'পেমেন্ট যাচাই',
      'লেনদেনের লেজার'
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    await t.tap(find.text('অ্যাকাউন্ট ট্রান্সফার'));
    await t.pumpAndSettle();
    expect(find.byType(TransferScreen), findsOneWidget);
    expect(find.text('ট্রান্সফার সেভ'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'one-page booking validates, keeps what was typed and sends the original CNY amount',
      (t) async {
    phone(t);
    Map<String, dynamic>? sent;
    await t.pumpWidget(app(const IntakeScreen(), intercept: (r) async {
      if (r.method == 'POST' && r.url.path == '/api/shipments') {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return http.Response('{"code":"SH-18"}', 200);
      }
      return null;
    }));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('intake-create')));
    await t.pumpAndSettle();
    expect(find.text('কাস্টমার বেছে নিন।'), findsOneWidget);
    expect(sent, isNull);
    await t.tap(find.text('কাস্টমার বেছে নিন'));
    await t.pumpAndSettle();
    await t.tap(find.text('Nila Store'));
    await t.pumpAndSettle();
    await enterKey(t, 'intake-kg', '2.5');
    await enterKey(t, 'intake-rate', '80');
    await t.ensureVisible(find.text('CNY'));
    await t.pumpAndSettle();
    await t.tap(find.text('CNY'));
    await enterKey(t, 'intake-description', 'Test parcel');
    await t.ensureVisible(find.byKey(const Key('intake-terms-monthly')));
    await t.tap(find.byKey(const Key('intake-terms-monthly')));
    await t.pumpAndSettle();
    // No category yet: nothing is sent and what was typed stays.
    await t.tap(find.byKey(const Key('intake-create')));
    await t.pumpAndSettle();
    expect(find.text('অন্তত একটি ক্যাটাগরি বেছে নিন।'), findsOneWidget);
    expect(sent, isNull);
    expect(
        t
            .widget<TextField>(find.byKey(const Key('intake-rate')))
            .controller!
            .text,
        '80');
    expect(
        t
            .widget<TextField>(find.byKey(const Key('intake-description')))
            .controller!
            .text,
        'Test parcel');
    expect(t.widget<Text>(find.byKey(const Key('intake-charge'))).data, '¥200');
    await t.scrollUntilVisible(find.text('General'), -200,
        scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(find.text('General'));
    await t.pumpAndSettle();
    await t.tap(find.text('General'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('intake-create')));
    await t.pumpAndSettle();
    expect(sent, {
      'supplierCode': 'C-14',
      'categories': ['General'],
      'bookedKg': 2.5,
      'chargeRate': 80.0,
      'chargeCurrency': 'CNY',
      'description': 'Test parcel',
      'paymentTerms': 'monthly',
      'pcsItems': []
    });
    expect(find.byType(BookingDoneScreen), findsOneWidget);
    expect(find.text('SH-18 বুক হয়েছে'), findsOneWidget);
    await t.tap(find.byKey(const Key('booking-open')));
    await t.pumpAndSettle();
    expect(find.byType(AdminShipmentScreen), findsOneWidget);
    expect(find.text('Nila Store'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('customer tabs retain statement, credit and shipment access',
      (t) async {
    phone(t);
    await t.pumpWidget(app(const CustomerDetailScreen(code: 'C-14')));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('মাসিক স্টেটমেন্ট'));
    expect(find.text('মাসিক স্টেটমেন্ট'), findsOneWidget);
    // The tab shows the shipment count, as in the design.
    await t.ensureVisible(find.text('শিপমেন্ট · 1'));
    await t.tap(find.text('শিপমেন্ট · 1'));
    await t.pumpAndSettle();
    expect(find.text('SH-18'), findsOneWidget);
    await t.tap(find.text('লেনদেন'));
    await t.pumpAndSettle();
    expect(find.text('সাম্প্রতিক পেমেন্ট'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('flight detail retains travelers and settlement actions',
      (t) async {
    phone(t);
    await t.pumpWidget(app(const FlightDetailScreen(code: 'BG305')));
    await t.pumpAndSettle();
    final scroll = find.byType(Scrollable).first;
    // The ticket row names the flyer; bookings follow below.
    expect(find.text('Arif Rahman'), findsOneWidget);
    await t.scrollUntilVisible(find.text('বুকিং নেই'), 200, scrollable: scroll);
    expect(find.text('বুকিং নেই'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('flight-ticket')), -200,
        scrollable: scroll);
    await t.ensureVisible(find.byKey(const Key('flight-ticket')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('flight-ticket')));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('টিকিটের টাকা দিন'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('ফ্লায়ারের জমা লিখুন'), findsOneWidget);
    expect(find.text('টিকিটের টাকা দিন'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('billing separates payment from customer link options',
      (t) async {
    phone(t);
    final scopes = <String>[];
    final payments = <String>[];
    await t.pumpWidget(
        app(const AdminShipmentScreen(code: 'SH-18', initialTab: 1),
            intercept: (r) async {
      if (r.method == 'POST' && r.url.path.endsWith('/track-link')) {
        scopes.add((jsonDecode(r.body) as Map)['scope'] as String);
        return http.Response(
            jsonEncode({
              'url': 'http://localhost:5178/t/opaque-customer-token',
              'expiresAt': '2026-11-01'
            }),
            200);
      }
      if (r.method == 'POST' && r.url.path.endsWith('/payments')) {
        payments.add(r.url.path);
      }
      return null;
    }));
    await t.pumpAndSettle();
    // One scroll: the payment form and the link options are separate cards,
    // each with its own button.
    await t.ensureVisible(find.text('জমা সেভ করুন'));
    expect(find.text('টাকা জমা'), findsOneWidget);
    expect(find.text('জমা সেভ করুন'), findsOneWidget);
    final toggle = find.byType(SwitchListTile);
    await t.ensureVisible(toggle);
    await t.pumpAndSettle();
    await t.tap(toggle);
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('শেয়ার লিংক তৈরি করুন'));
    await t.pumpAndSettle();
    await t.tap(find.text('শেয়ার লিংক তৈরি করুন'));
    await t.pumpAndSettle();
    expect(scopes, ['invoice']);
    expect(payments, isEmpty);
    expect(find.text('লিংক কপি'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('five admin destinations fit a narrow display with enlarged text',
      (t) async {
    t.view.physicalSize = const Size(320, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
                bottomNavigationBar:
                    AppBottomNav(index: 3, admin: true, onChanged: (_) {})))));
    for (var i = 0; i < 5; i++) {
      final size = t.getSize(find.byKey(Key('nav-$i')));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(t.takeException(), isNull);
  });
}
