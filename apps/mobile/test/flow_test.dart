import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sbexpress/data/models/shipment.dart';
import 'package:sbexpress/data/models/workspace.dart';
import 'package:sbexpress/data/repositories/dashboard_repository.dart';
import 'package:sbexpress/features/admin/admin_home_screen.dart';
import 'package:sbexpress/features/admin/admin_shipment_screen.dart';
import 'package:sbexpress/features/admin/money_format.dart';
import 'package:sbexpress/features/finance/get_paid_screen.dart';
import 'package:sbexpress/features/flights/ticket_flyers_screen.dart';
import 'package:sbexpress/features/intake/intake_screen.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'package:sbexpress/widgets/quick_parts.dart' show wholeBdt;
import 'package:sbexpress/app_scope.dart';
import 'restructured_flow_test.dart' show app, phone;
import 'support/screen_fixtures.dart';

http.Response _ok(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

/// A first screen that opens [screen], so the screen can pop back to it.
class _Host extends StatelessWidget {
  const _Host(this.screen);
  final Widget screen;

  @override
  Widget build(BuildContext context) => Scaffold(
      body: Center(
          child: TextButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => screen)),
              child: const Text('open'))));
}

Future<void> _open(WidgetTester t) async {
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester t, Finder finder, {double dy = 200}) async {
  await t.scrollUntilVisible(finder, dy,
      scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
}

Future<void> _confirm(WidgetTester t) async {
  await t.tap(find.text(tr('Confirm')));
  await t.pumpAndSettle();
}

void main() {
  test('old servers leave the new fields out instead of failing', () {
    final row = AdminShipment.fromJson({
      'code': 'SH-1',
      'supplierCode': 'C-1',
      'flightCode': null,
      'flightDate': null,
      'bookedKg': 1,
      'weighedKg': null,
      'effectiveKg': 1,
      'weightDelta': null,
      'description': '',
      'categories': <String>[],
      'status': 'pending',
      'statusIndex': 0,
      'statusLabel': 'Pending',
      'exception': null,
      'date': '2026-10-18',
      'supplierName': 'A',
      'charge': 100,
      'billAmount': 100,
      'discountAmount': 0,
      'paidAmount': 0,
      'dueAmount': 100,
      'payStatus': 'unpaid',
      'payMethod': null,
      'paymentTerms': 'cod',
      'freeOfCharge': false,
      'receiptStatus': null,
    });
    expect(row.usualCosts, isNull);
    expect(row.costTotal, isNull);
    expect(row.monthly, isFalse);
    expect(paymentTermsLabel('cod'), tr('After delivery'));
    final settings = SettingsSnapshot.fromJson(
        {'rate': 17.5, 'threshold': 1, 'pcsRates': <String, Object?>{}});
    expect(settings.costDefaults, isNull);
  });

  testWidgets('an old overview without collect or flight profit still renders',
      (t) async {
    phone(t);
    final old = {
      'weekLabel': '19 Oct – 20 Oct',
      'todayLabel': 'Tuesday 20 Oct 2026',
      'rate': 17.5,
      'cash': {'bdt': 100, 'cny': 0, 'worth': 100},
      'received': 0,
      'expenses': 0,
      'net': 0,
      'profit': 0,
      'unpaid': 15400,
      'reviewCount': 1,
      'openTodoCount': 0,
      'nextFlight': null,
      'notices': <Object>[],
      'flights': [
        {
          'code': 'BG305-20261021-ab12cd',
          'date': DateTime.now()
              .add(const Duration(days: 3))
              .toIso8601String()
              .substring(0, 10),
          'flyers': ['Arif Rahman'],
          'bookedKg': 31.5,
          'spaceKg': 44,
          'status': 'upcoming',
          'shipmentCount': 4,
        },
      ],
      'activeShipmentCount': 0,
      'activeShipments': <Object>[],
    };
    await t.pumpWidget(app(
        Builder(
            builder: (context) =>
                AdminHomeScreen(dashboard: AppScope.of(context).dashboard)),
        intercept: (r) async =>
            r.url.path == '/api/dashboard/overview' ? _ok(old) : null));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('BG305'), findsOneWidget);
    // Without the collect summary what customers owe leads to Finance, and
    // the profit chips and stage strip stay out.
    expect(find.text('${tr('Get paid')} ›'), findsNothing);
    expect(find.text('${tr('Finance')} ›'), findsOneWidget);
    expect(find.text(wholeBdt(15400)), findsOneWidget);
    expect(find.textContaining(tr('Profit so far {amount}', {'amount': ''})),
        findsNothing);
    expect(find.byKey(const Key('home-stages')), findsNothing);
  });

  testWidgets('home leads with what is left to collect and opens Get paid',
      (t) async {
    phone(t);
    await t.pumpWidget(app(Builder(
        builder: (context) =>
            AdminHomeScreen(dashboard: AppScope.of(context).dashboard))));
    await t.pumpAndSettle();
    // The overdue after-delivery bill comes first: 17,550 waits.
    expect(
        find.text(trn(1, '{n} bill is overdue after delivery',
            '{n} bills are overdue after delivery')),
        findsOneWidget);
    expect(
        find.text(tr('{amount} to collect from handed-over shipments',
            {'amount': wholeBdt(17550)})),
        findsOneWidget);
    await _scrollTo(t, find.byKey(const Key('home-next-flight')));
    expect(find.text(tr('Profit so far {amount}', {'amount': wholeBdt(16180)})),
        findsOneWidget);
    // Shipment costs are optional now: no missing-cost chip or row.
    expect(
        find.text(trn(
            2, '{n} shipment missing costs', '{n} shipments missing costs')),
        findsNothing);
    expect(
        find.text(trn(2, '{n} shipment is missing costs',
            '{n} shipments are missing costs')),
        findsNothing);
    await t.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('home-owed')));
    await t.pumpAndSettle();
    expect(find.byType(GetPaidScreen), findsOneWidget);
  });

  testWidgets('Get paid lists handed-over bills oldest first and monthly bills',
      (t) async {
    phone(t);
    await t.pumpWidget(app(const GetPaidScreen()));
    await t.pumpAndSettle();
    expect(find.text(tr('After delivery · {n}', {'n': 2})), findsOneWidget);
    expect(find.text(formatBdt(17550)), findsOneWidget);
    final first = t.getTopLeft(find.text('Bismillah Telecom')).dy;
    final second = t.getTopLeft(find.text('Rahman Traders')).dy;
    expect(first, lessThan(second));
    expect(find.text(tr('{n} days since delivery', {'n': 9})), findsOneWidget);
    expect(find.text(tr('Delivered yesterday')), findsOneWidget);
    await _scrollTo(t, find.text(tr('Coming soon')));
    expect(find.text('Sky Mobile'), findsOneWidget);
    await _scrollTo(t, find.text(tr('Send bill link')));
    expect(find.text(tr('Link not sent')), findsOneWidget);
    await t.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await t.pumpAndSettle();
    await t.tap(find.text(tr('Monthly · {n}', {'n': 2})));
    await t.pumpAndSettle();
    expect(find.text(formatBdt(19600)), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Get paid asks for a server update when the list is missing',
      (t) async {
    phone(t);
    await t.pumpWidget(app(const GetPaidScreen(),
        intercept: (r) async => r.url.path == '/api/dashboard/collect'
            ? http.Response('{"error":"Not found"}', 404)
            : null));
    await t.pumpAndSettle();
    expect(find.text(tr('The server needs an update')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('recording a payment posts the full due to the chosen account',
      (t) async {
    phone(t);
    Map<String, dynamic>? sent;
    String? path;
    await t.pumpWidget(app(const GetPaidScreen(), intercept: (r) async {
      if (r.method == 'POST' && r.url.path.endsWith('/payments')) {
        path = r.url.path;
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return _ok({'ok': true});
      }
      return null;
    }));
    await t.pumpAndSettle();
    await _scrollTo(t, find.byKey(const ValueKey('record-SH-21')));
    await t.tap(find.byKey(const ValueKey('record-SH-21')));
    await t.pumpAndSettle();
    expect(find.text(tr('Full due')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('received-Dhaka cash')));
    await t.pumpAndSettle();
    expect(find.text(tr('{code} becomes Paid', {'code': 'SH-21'})),
        findsOneWidget);
    await t.ensureVisible(find.byKey(const Key('record-save')));
    await t.tap(find.byKey(const Key('record-save')));
    await t.pumpAndSettle();
    await _confirm(t);
    expect(path, '/api/shipments/SH-21/payments');
    expect(sent, {'amount': 11250.0, 'method': 'Dhaka cash'});
    expect(t.takeException(), isNull);
  });

  testWidgets('saving the ticket split patches the flight then the parts',
      (t) async {
    phone(t);
    final calls = <String>[];
    final bodies = <Object?>[];
    await t.pumpWidget(
        app(const _Host(TicketFlyersScreen(code: flowFlightCode)),
            intercept: (r) async {
      if (r.method == 'PATCH' || r.method == 'POST') {
        calls.add('${r.method} ${r.url.path}');
        bodies.add(jsonDecode(r.body));
        return _ok({'ok': true, 'code': flowFlightCode});
      }
      return null;
    }));
    await _open(t);
    // 42,000 less 15,000 + 15,000 from the flyers.
    expect(find.textContaining(formatBdt(12000)), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('part-Rakib Hasan')), '12000');
    await t.pump();
    expect(find.textContaining(formatBdt(12000)), findsNothing);
    await t.tap(find.byKey(const Key('ticket-save')));
    await t.pumpAndSettle();
    expect(calls, [
      'PATCH /api/flights/$flowFlightCode',
      'POST /api/flights/$flowFlightCode/settlements',
    ]);
    expect(bodies.first, {'actualCost': 42000.0, 'agencyShare': 15000.0});
    expect(bodies.last, {
      'allocations': [
        {'name': 'Arif Rahman', 'contribution': 15000.0, 'legacyPaid': 0.0},
        {'name': 'Rakib Hasan', 'contribution': 12000.0, 'legacyPaid': 0.0},
      ]
    });
    expect(find.byType(TicketFlyersScreen), findsNothing);
  });

  testWidgets('we pay all is refused while a flyer has already paid',
      (t) async {
    phone(t);
    final calls = <String>[];
    await t.pumpWidget(
        app(const _Host(TicketFlyersScreen(code: flowFlightCode)),
            intercept: (r) async {
      if (r.method != 'GET') calls.add(r.method);
      return null;
    }));
    await _open(t);
    await t.tap(find.byKey(const Key('ticket-we-pay')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('ticket-save')));
    await t.pumpAndSettle();
    expect(calls, isEmpty);
    expect(
        find.text(tr(
            '{name} has already paid {amount}, so their part cannot be lower.',
            {'name': 'Arif Rahman', 'amount': formatBdt(15000)})),
        findsOneWidget);
  });

  Future<void> openAddCost(WidgetTester t) async {
    final add = find.byKey(const Key('bill-cost-add'));
    await _scrollTo(t, add);
    await t.tap(add);
    await t.pumpAndSettle();
  }

  Future<void> payFrom(WidgetTester t, Key choice) async {
    await t.ensureVisible(find.byKey(const Key('cost-account')));
    await t.tap(find.byKey(const Key('cost-account')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(choice));
    await t.pumpAndSettle();
  }

  testWidgets(
      'a cost on the bill posts its category, bill name, amount and account',
      (t) async {
    phone(t);
    Map<String, dynamic>? sent;
    await t.pumpWidget(
        app(const AdminShipmentScreen(code: 'SH-18'), intercept: (r) async {
      if (r.method == 'POST' && r.url.path.endsWith('/expenses')) {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return _ok({'ok': true, 'costId': 'c1'});
      }
      return null;
    }));
    await t.pumpAndSettle();
    await openAddCost(t);
    // The Courier chip fills in the name the customer reads on the bill.
    await t.tap(find.byKey(const ValueKey('cost-courier')));
    await t.pumpAndSettle();
    expect(
        t
            .widget<TextField>(find.byKey(const Key('cost-name')))
            .controller!
            .text,
        'Courier to customer');
    await t.enterText(find.byKey(const Key('cost-amount')), '300');
    await t.pumpAndSettle();
    final preview = find.byKey(const Key('cost-preview'));
    expect(
        find.descendant(
            of: preview,
            matching: find.textContaining('${tr('Bill')} ${formatBdt(4800)}',
                findRichText: true)),
        findsOneWidget);
    expect(
        find.descendant(
            of: preview,
            matching: find.textContaining(formatBdt(5100), findRichText: true)),
        findsOneWidget);
    await payFrom(t, const ValueKey('pay-from-Dhaka cash'));
    await t.ensureVisible(find.byKey(const Key('cost-save')));
    await t.tap(find.byKey(const Key('cost-save')));
    await t.pumpAndSettle();
    await _confirm(t);
    expect(sent, {
      'category': 'courier',
      'amount': 300.0,
      'reason': 'Courier to customer',
      'label': 'Courier to customer',
      'accountName': 'Dhaka cash',
      'paymentTiming': 'now',
    });
    expect(t.takeException(), isNull);
  });

  testWidgets('a cost on the bill paid later moves no money', (t) async {
    phone(t);
    Map<String, dynamic>? sent;
    await t.pumpWidget(
        app(const AdminShipmentScreen(code: 'SH-18'), intercept: (r) async {
      if (r.method == 'POST' && r.url.path.endsWith('/expenses')) {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return _ok({'ok': true});
      }
      return null;
    }));
    await t.pumpAndSettle();
    await openAddCost(t);
    await t.enterText(find.byKey(const Key('cost-name')), 'Extra tape');
    await t.enterText(find.byKey(const Key('cost-amount')), '80');
    await t.pumpAndSettle();
    await payFrom(t, const Key('pay-from-later'));
    await t.ensureVisible(find.byKey(const Key('cost-save')));
    await t.tap(find.byKey(const Key('cost-save')));
    await t.pumpAndSettle();
    // Nothing leaves an account, so there is no money confirm.
    expect(sent, {
      'category': 'others',
      'amount': 80.0,
      'reason': 'Extra tape',
      'label': 'Extra tape',
      'paymentTiming': 'later',
    });
  });

  Future<Map<String, dynamic>?> book(WidgetTester t,
      {required String customerTerms, String? tap}) async {
    Map<String, dynamic>? sent;
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpWidget(app(const IntakeScreen(), intercept: (r) async {
      if (r.method == 'GET' && r.url.path == '/api/suppliers') {
        return _ok({
          'suppliers': [
            {
              'code': 'C-14',
              'name': 'Nila Store',
              'phone': '01700000000',
              'address': '',
              'terms': customerTerms,
              'orderCount': 0,
              'deliveredCount': 0,
              'shippedKg': 0,
              'billed': 0,
              'paid': 0,
              'balance': 0,
              'creditBalance': 0,
              'pricingPending': 0,
              'discountTotal': 0,
            }
          ]
        });
      }
      if (r.method == 'POST' && r.url.path == '/api/shipments') {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return _ok({'code': 'SH-18'});
      }
      return null;
    }));
    await t.pumpAndSettle();
    await t.tap(find.text(tr('Choose a customer')));
    await t.pumpAndSettle();
    await t.tap(find.text('Nila Store'));
    await t.pumpAndSettle();
    await _scrollTo(t, find.text('General'));
    await t.tap(find.text('General'));
    await t.pumpAndSettle();
    if (tap != null) {
      await _scrollTo(t, find.byKey(Key(tap)));
      await t.tap(find.byKey(Key(tap)));
      await t.pumpAndSettle();
    }
    await t.tap(find.byKey(const Key('intake-create')));
    await t.pumpAndSettle();
    return sent;
  }

  testWidgets('a booking takes the customer\'s usual way to pay', (t) async {
    phone(t);
    expect(
        (await book(t, customerTerms: 'monthly'))?['paymentTerms'], 'monthly');
    expect(
        (await book(t, customerTerms: 'instant'))?['paymentTerms'], 'invoice');
  });

  testWidgets('the billing step can switch this booking to after delivery',
      (t) async {
    phone(t);
    final sent =
        await book(t, customerTerms: 'monthly', tap: 'intake-terms-after');
    expect(sent?['paymentTerms'], 'invoice');
    expect(t.takeException(), isNull);
  });

  test('the overview reads the collect summary', () async {
    final overview = await DashboardRepository(screenFixtureApi()).overview();
    expect(overview.collect?.total, 37150);
    expect(overview.flights.first.missingCostCount, 2);
  });
}
