import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sbexpress/app_scope.dart';
import 'package:sbexpress/data/models/flight.dart';
import 'package:sbexpress/data/models/session_user.dart';
import 'package:sbexpress/data/models/workspace.dart';
import 'package:sbexpress/data/rates.dart';
import 'package:sbexpress/features/admin/admin_shipment_screen.dart';
import 'package:sbexpress/features/flights/flight_detail_screen.dart';
import 'package:sbexpress/features/intake/intake_screen.dart';
import 'package:sbexpress/features/more/more_screen.dart';
import 'package:sbexpress/features/settings/rates_screen.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'package:sbexpress/widgets/quick_parts.dart' show plainKg, wholeMoney;
import 'restructured_flow_test.dart' show app, phone;
import 'support/screen_fixtures.dart';

http.Response _ok(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

/// `METHOD path` of each request.
String _call(http.Request r) =>
    '${r.method} ${Uri.decodeComponent(r.url.path)}';

Future<void> _scrollTo(WidgetTester t, Finder finder, {double dy = 300}) async {
  await t.scrollUntilVisible(finder, dy,
      scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
}

Future<void> _tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

Future<void> _type(WidgetTester t, Finder finder, String text) async {
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.enterText(finder, text);
  await t.pumpAndSettle();
}

/// The text in the field inside [finder].
String _text(WidgetTester t, Finder finder) => t
    .widget<EditableText>(
        find.descendant(of: finder, matching: find.byType(EditableText)).first)
    .controller
    .text;

void main() {
  group('models', () {
    test('a rate per kg of 0 or none is no rate, and an old server says so',
        () {
      final set = SettingsSnapshot.fromJson(round8Settings());
      expect(set.kgRate, 1200);
      expect(set.ratesKnown, isTrue);
      expect(
          SettingsSnapshot.fromJson(round8Settings(kgRate: 0)).kgRate, isNull);
      final old = SettingsSnapshot.fromJson(round8Settings(kgRate: null));
      expect(old.kgRate, isNull);
      expect(old.ratesKnown, isFalse);
    });

    test('a flight with its own rates overrides the default, piece by piece',
        () {
      final settings = SettingsSnapshot.fromJson(round8Settings());
      final own = FlightSummary.fromJson(
          round8FlightBody(round8OwnRates)['flight']! as Map<String, Object?>);
      final rates = orderRates(settings, own);
      expect(rates.kgRate, 1300);
      expect(rates.flight, 'BG305');
      // "mobile" from the flight wins over "Mobile" from the default.
      expect(rates.piece('Mobile'), 1800);
      expect(rates.piece('laptop'), 3500);
      expect(rates.pieces.length, 2);

      final plain = FlightSummary.fromJson(
          round8FlightBody(round8NoOwnRates)['flight']!
              as Map<String, Object?>);
      expect(plain.ownRates, isNull);
      expect(plain.ratesKnown, isTrue);
      final fallback = orderRates(settings, plain);
      expect(fallback.kgRate, 1200);
      expect(fallback.flight, isNull);
      expect(fallback.piece('Mobile'), 2000);
    });
  });

  testWidgets(
      'More shows the default rates and the Rates screen saves them in one go',
      (t) async {
    phone(t);
    final calls = <String>[];
    Map<String, dynamic>? sent;
    await t.pumpWidget(app(
        Builder(
            builder: (context) => MoreScreen(
                user: const SessionUser(
                    id: 'u',
                    name: 'Tester',
                    email: 'test@sbx.test',
                    role: UserRole.admin,
                    roleLabel: 'Administrator'),
                session: AppScope.of(context).session)), intercept: (r) async {
      calls.add(_call(r));
      if (r.url.path != '/api/settings') return null;
      if (r.method == 'PATCH') {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return _ok({
          'settings': {...round8Settings(), ...sent!}
        });
      }
      return _ok({'settings': round8Settings()});
    }));
    await t.pumpAndSettle();

    final tile = find.byKey(const ValueKey('more-prices'));
    await _scrollTo(t, tile);
    expect(
        find.descendant(
            of: tile,
            matching: find.text([
              tr('{rate} per kg', {'rate': wholeMoney(1200, 'BDT')}),
              trn(2, '{n} piece price', '{n} piece prices'),
            ].join(' · '))),
        findsOneWidget);
    await t.tap(tile);
    await t.pumpAndSettle();
    expect(find.byType(RatesScreen), findsOneWidget);
    expect(_text(t, find.byKey(const Key('rates-kg'))), '1200');
    expect(_text(t, find.byKey(const ValueKey('piece-price-Laptop'))), '3500');
    // Every device category is priced, so none is offered.
    expect(find.byKey(const ValueKey('rates-add-Mobile')), findsNothing);

    await _type(t, find.byKey(const Key('rates-kg')), '1250');
    await _type(t, find.byKey(const ValueKey('piece-price-Laptop')), '3600');
    await _tap(t, find.byKey(const ValueKey('piece-remove-Mobile')));
    // Mobile is a device category without a price now.
    expect(find.byKey(const ValueKey('rates-add-Mobile')), findsOneWidget);
    await _tap(t, find.byKey(const Key('rates-add-new')));
    await _type(t, find.byKey(const Key('rates-new-name')), 'Drone');
    await _tap(t, find.byKey(const Key('rates-new-add')));
    await _type(t, find.byKey(const ValueKey('piece-price-Drone')), '5000');
    expect(sent, isNull);

    await _tap(t, find.byKey(const Key('rates-save')));
    expect(calls, contains('PATCH /api/settings'));
    expect(sent, {
      'kgRate': 1250,
      'kgRateCurrency': 'BDT',
      'pcsRates': {'Laptop': 3600, 'Drone': 5000},
    });
    expect(find.byType(RatesScreen), findsNothing);
    expect(find.text(tr('Rates saved')), findsOneWidget);
  });

  testWidgets('an older server keeps the piece prices and says why', (t) async {
    phone(t);
    await t.pumpWidget(app(const RatesScreen(), intercept: (r) async {
      if (r.url.path != '/api/settings') return null;
      // It drops the rate per kg it does not know.
      return _ok({'settings': round8Settings(kgRate: null)});
    }));
    await t.pumpAndSettle();
    expect(_text(t, find.byKey(const Key('rates-kg'))), '');
    await _type(t, find.byKey(const Key('rates-kg')), '1250');
    await _tap(t, find.byKey(const Key('rates-save')));
    expect(
        find.text(tr(
            'Piece prices are saved. The server needs an update to keep the rate per kg.')),
        findsOneWidget);
    expect(find.byType(RatesScreen), findsOneWidget);
  });

  testWidgets(
      'a flight gets its own rates and moves the orders still on the old ones',
      (t) async {
    phone(t);
    Map<String, dynamic>? sent;
    String? put;
    var own = false;
    await t.pumpWidget(app(const FlightDetailScreen(code: flowFlightCode),
        intercept: (r) async {
      if (r.url.path == '/api/settings') {
        return _ok({'settings': round8Settings()});
      }
      if (r.method == 'PUT') {
        put = _call(r);
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        own = true;
        return _ok({
          'flight': (round8FlightBody(round8OwnRates)['flight']! as Map),
          'updated': 2
        });
      }
      if (r.method == 'GET' && r.url.path == '/api/flights/$flowFlightCode') {
        return _ok(own
            ? round8FlightBody(round8OwnRates)
            : round8FlightBody(round8NoOwnRates, followers: 3));
      }
      return null;
    }));
    await t.pumpAndSettle();

    final card = find.byKey(const Key('flight-rates'));
    await _scrollTo(t, find.byKey(const Key('flight-rates-edit')));
    final kgLine = find.byKey(const Key('flight-rates-kg-line'));
    expect(
        find.descendant(
            of: kgLine, matching: find.text(wholeMoney(1200, 'BDT'))),
        findsOneWidget);
    expect(find.descendant(of: card, matching: find.text(tr('Own rate'))),
        findsNothing);

    await t.tap(find.byKey(const Key('flight-rates-edit')));
    await t.pumpAndSettle();
    expect(
        find.text(
            tr('Default is {rate} per kg', {'rate': wholeMoney(1200, 'BDT')})),
        findsOneWidget);
    await _tap(t, find.byKey(const Key('flight-rates-own')));
    await _type(t, find.byKey(const Key('flight-rates-kg')), '1300');
    await _type(t, find.byKey(const ValueKey('piece-price-Mobile')), '1800');
    expect(
        find.text(
            tr('Also change the {n} orders already on this flight', {'n': 3})),
        findsOneWidget);
    await _tap(t, find.byKey(const Key('flight-rates-save')));

    expect(put, 'PUT /api/flights/$flowFlightCode/rates');
    expect(sent, {
      'own': true,
      'kgRate': 1300,
      'kgRateCurrency': 'BDT',
      'pcsRates': {'Mobile': 1800, 'Laptop': 3500},
      'applyToOrders': true,
    });
    expect(
        find.text(trn(2, 'Rates saved · {n} order updated',
            'Rates saved · {n} orders updated')),
        findsOneWidget);
    // The card reloads with the flight's own rate.
    await _scrollTo(t, find.byKey(const Key('flight-rates-edit')));
    expect(
        find.descendant(
            of: kgLine, matching: find.text(wholeMoney(1300, 'BDT'))),
        findsOneWidget);
    expect(find.descendant(of: card, matching: find.text(tr('Own rate'))),
        findsWidgets);
  });

  testWidgets('a server without flight rates says it needs an update',
      (t) async {
    phone(t);
    await t.pumpWidget(app(const FlightDetailScreen(code: flowFlightCode),
        intercept: (r) async {
      if (r.url.path == '/api/settings') {
        return _ok({'settings': round8Settings()});
      }
      if (r.method == 'PUT') return _ok({'error': 'Not found'}, 404);
      if (r.method == 'GET' && r.url.path == '/api/flights/$flowFlightCode') {
        return _ok(round7FlightBody());
      }
      return null;
    }));
    await t.pumpAndSettle();
    await _scrollTo(t, find.byKey(const Key('flight-rates-edit')));
    await t.tap(find.byKey(const Key('flight-rates-edit')));
    await t.pumpAndSettle();
    await _tap(t, find.byKey(const Key('flight-rates-own')));
    await _type(t, find.byKey(const Key('flight-rates-kg')), '1300');
    // No orders follow on an older server, so nothing to apply.
    expect(find.byKey(const Key('flight-rates-apply')), findsNothing);
    await _tap(t, find.byKey(const Key('flight-rates-save')));
    expect(
        find.text(
            tr('The server needs an update before flight rates can be saved.')),
        findsOneWidget);
  });

  testWidgets(
      'a new order fills in the default rate, then the flight\'s, but never over a typed one',
      (t) async {
    phone(t);
    await t.pumpWidget(app(const IntakeScreen(), intercept: (r) async {
      if (r.method != 'GET') return null;
      if (r.url.path == '/api/settings') {
        return _ok({'settings': round8Settings()});
      }
      if (r.url.path == '/api/flights') {
        return _ok({
          'flights': [round8FlightBody(round8OwnRates)['flight']]
        });
      }
      return null;
    }));
    await t.pumpAndSettle();

    final rate = find.byKey(const Key('intake-rate'));
    expect(t.widget<TextField>(rate).controller!.text, '1200');
    expect(find.text(tr('Default rate')), findsOneWidget);

    await _tap(t, find.byKey(const ValueKey('intake-flight-$flowFlightCode')));
    expect(t.widget<TextField>(rate).controller!.text, '1300');
    expect(
        find.text(tr("{flight}'s rate", {'flight': 'BG305'})), findsOneWidget);

    await _scrollTo(t, find.text('Mobile'));
    await t.tap(find.text('Mobile'));
    await t.pumpAndSettle();
    final device = find.byKey(const ValueKey('intake-device-Mobile'));
    expect(
        t
            .widgetList<TextField>(
                find.descendant(of: device, matching: find.byType(TextField)))
            .map((field) => field.controller?.text),
        contains('1800'));

    await _type(t, rate, '1400');
    expect(find.text(tr("{flight}'s rate", {'flight': 'BG305'})), findsNothing);
    final flight = find.byKey(const ValueKey('intake-flight-$flowFlightCode'));
    await _scrollTo(t, flight, dy: -300);
    await _tap(t, flight);
    await _scrollTo(t, rate);
    expect(t.widget<TextField>(rate).controller!.text, '1400');
  });

  group('an order\'s weight and rate', () {
    const shipmentFlight = 'BG305-20261021-ab12cd';

    Future<http.Response?> Function(http.Request) server(
            void Function(Map<String, dynamic>) onPatch) =>
        (r) async {
          final path = r.url.path;
          if (r.method == 'PATCH' && path == '/api/shipments/SH-18') {
            onPatch(jsonDecode(r.body) as Map<String, dynamic>);
            return _ok(round7ShipmentBody());
          }
          if (r.method != 'GET') return null;
          if (path == '/api/shipments/SH-18') return _ok(round7ShipmentBody());
          if (path == '/api/shipments/SH-18/invoice') {
            return _ok(round7InvoiceBody());
          }
          if (path == '/api/settings') {
            return _ok({'settings': round8Settings()});
          }
          if (path == '/api/flights/$shipmentFlight') {
            return _ok(round8FlightBody(round8OwnRates));
          }
          return null;
        };

    testWidgets(
        'the bill lists the charge parts and the sheet sends the new kg, rate and pieces',
        (t) async {
      phone(t);
      Map<String, dynamic>? sent;
      await t.pumpWidget(app(const AdminShipmentScreen(code: 'SH-18'),
          intercept: server((body) => sent = body)));
      await t.pumpAndSettle();

      final lines = find.byKey(const Key('order-weight-rate'));
      await _scrollTo(t, lines);
      expect(
          find.descendant(
              of: lines,
              matching: find.text(tr('{kg} kg weighed × {rate}',
                  {'kg': plainKg(4.2), 'rate': wholeMoney(950, 'BDT')}))),
          findsOneWidget);
      expect(
          find.descendant(
              of: lines,
              matching: find.text('2 Mobile × ${wholeMoney(500, 'BDT')}')),
          findsOneWidget);

      await t.tap(lines);
      await t.pumpAndSettle();
      expect(_text(t, find.byKey(const Key('order-kg'))), '4');
      expect(_text(t, find.byKey(const Key('order-rate'))), '950');
      expect(find.byKey(const Key('order-rate-default')), findsOneWidget);

      await _tap(t, find.byKey(const Key('order-rate-flight')));
      expect(_text(t, find.byKey(const Key('order-rate'))), '1300');
      await _type(t, find.byKey(const Key('order-kg')), '5');
      await _tap(t, find.byKey(const ValueKey('count-plus-Mobile')));
      // Weighed 4.2 kg × ৳1,300 + 3 × ৳500.
      expect(
          find.descendant(
              of: find.byKey(const Key('order-charge-preview')),
              matching: find.text(wholeMoney(6960, 'BDT'))),
          findsOneWidget);
      expect(sent, isNull);

      await _tap(t, find.byKey(const Key('order-charge-save')));
      expect(sent, {
        'bookedKg': 5,
        'chargeRate': 1300,
        'chargeCurrency': 'BDT',
        'pcsItems': [
          {
            'category': 'Mobile',
            'count': 3,
            'rate': 500,
            'currency': 'BDT',
            'units': [
              for (var i = 0; i < 3; i++) {'model': '', 'serial': ''}
            ],
          }
        ],
      });
      expect(find.text(tr('Weight and rate saved')), findsOneWidget);
    });

    testWidgets('pieces left alone are not sent', (t) async {
      phone(t);
      Map<String, dynamic>? sent;
      await t.pumpWidget(app(const AdminShipmentScreen(code: 'SH-18'),
          intercept: server((body) => sent = body)));
      await t.pumpAndSettle();
      final lines = find.byKey(const Key('order-weight-rate'));
      await _scrollTo(t, lines);
      await t.tap(lines);
      await t.pumpAndSettle();
      await _type(t, find.byKey(const Key('order-rate')), '1000');
      await _tap(t, find.byKey(const Key('order-charge-save')));
      expect(
          sent, {'bookedKg': 4, 'chargeRate': 1000, 'chargeCurrency': 'BDT'});
    });
  });
}
