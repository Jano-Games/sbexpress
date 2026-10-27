import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sbexpress/data/models/flight.dart';
import 'package:sbexpress/data/repositories/flight_repository.dart';
import 'package:sbexpress/data/repositories/shipment_repository.dart';
import 'package:sbexpress/features/admin/admin_shipment_screen.dart';
import 'package:sbexpress/features/admin/money_format.dart';
import 'package:sbexpress/features/flights/flight_detail_screen.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'restructured_flow_test.dart' show app, phone;
import 'support/screen_fixtures.dart';

http.Response _ok(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

/// `METHOD path` of each request that changes something.
String _call(http.Request r) =>
    '${r.method} ${Uri.decodeComponent(r.url.path)}';

/// Answers SH-18 as a round 7 server does; [invoice] replaces the issued
/// invoice and [then] sees every request first.
Future<http.Response?> Function(http.Request) _round7(
        {Map<String, Object?>? invoice,
        Future<http.Response?> Function(http.Request)? then}) =>
    (r) async {
      final answer = await then?.call(r);
      if (answer != null) return answer;
      if (r.method != 'GET') return null;
      if (r.url.path == '/api/shipments/SH-18') {
        return _ok(round7ShipmentBody());
      }
      if (r.url.path == '/api/shipments/SH-18/invoice') {
        return _ok(invoice ?? round7InvoiceBody());
      }
      return null;
    };

Future<http.Response?> Function(http.Request) _flight(
        [Future<http.Response?> Function(http.Request)? then]) =>
    (r) async {
      final answer = await then?.call(r);
      if (answer != null) return answer;
      if (r.method == 'GET' && r.url.path == '/api/flights/$flowFlightCode') {
        return _ok(round7FlightBody());
      }
      return null;
    };

Future<void> _scrollTo(WidgetTester t, Finder finder, {double dy = 300}) async {
  await t.scrollUntilVisible(finder, dy,
      scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
}

Future<void> _payFrom(WidgetTester t, Key field, Key choice) async {
  await t.ensureVisible(find.byKey(field));
  await t.tap(find.byKey(field));
  await t.pumpAndSettle();
  await t.tap(find.byKey(choice));
  await t.pumpAndSettle();
}

void main() {
  group('models', () {
    test('flight costs, their breakdown and late days are read when sent', () {
      final detail = FlightDetail.fromJson(
          round7FlightBody()['flight']! as Map<String, Object?>);
      expect(
          detail.flightCosts!.map((cost) => cost.id), ['fc-3', 'fc-2', 'fc-1']);
      expect(detail.flightCosts!.last.paid, isFalse);
      expect(detail.flightCostTotal, 2150);
      expect(detail.profitBreakdown!.profit, 17650);
      expect(detail.bookings.firstWhere((row) => row.code == 'SH-21').lateDays,
          12);
      // An older server sends none of them.
      final older = FlightDetail.fromJson(
          flowFlightDetailBody()['flight']! as Map<String, Object?>);
      expect(older.flightCosts, isNull);
      expect(older.profitBreakdown, isNull);
      expect(older.bookings.first.lateDays, isNull);
    });

    test('a flight cost pays from one account or is saved unpaid', () {
      expect(
          flightCostBody(
              category: 'transport', amount: 900, accountName: 'Dhaka cash'),
          {
            'category': 'transport',
            'amount': 900.0,
            'accountName': 'Dhaka cash'
          });
      expect(
          flightCostBody(
              category: 'labour', label: 'Labour', amount: 50, payLater: true),
          {
            'category': 'others',
            'label': 'Labour',
            'amount': 50.0,
            'payLater': true
          });
      expect(() => flightCostBody(category: 'courier', amount: 10),
          throwsFormatException);
    });

    test('the newest active link with a url is the one shown', () {
      final links = [
        for (final row in trackLinksBody()['links']! as List)
          SavedTrackLink.fromJson(row as Map<String, Object?>)
      ];
      expect(newestActiveLink(links)?.id, 'link-2');
      expect(newestActiveLink(links)?.includesInvoice, isTrue);
      final off = [
        for (final row in trackLinksBody(active: false)['links']! as List)
          SavedTrackLink.fromJson(row as Map<String, Object?>)
      ];
      expect(newestActiveLink(off), isNull);
    });
  });

  group('one-page shipment', () {
    testWidgets('the overview follows the design order and has no Bill tab',
        (t) async {
      // Tall enough that every card is built at once.
      t.view.physicalSize = const Size(390, 5200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
          app(const AdminShipmentScreen(code: 'SH-18'), intercept: _round7()));
      await t.pumpAndSettle();
      expect(find.text(tr('Overview')), findsOneWidget);
      expect(find.text(tr('Photos · {n}', {'n': 0})), findsOneWidget);
      expect(find.text(tr('Summary')), findsNothing);
      double top(Finder finder) => t.getTopLeft(finder).dy;
      final order = [
        top(find.text(tr('Step {step} of {total}', {'step': 6, 'total': 9}))),
        top(find.byKey(const Key('shipment-bill'))),
        top(find.byKey(const Key('shipment-profit'))),
        top(find.text(tr('Handling and delivery'))),
        top(find.byKey(const Key('shipment-bill-costs'))),
        top(find.byKey(const Key('shipment-invoice'))),
        top(find.byKey(const Key('shipment-link'))),
        top(find.text(tr('Booking'))),
        top(find.byKey(const Key('shipment-delete'))),
      ];
      expect(order, [...order]..sort());
      // The bill: total, what it is made of, the terms, paid and due.
      expect(find.text(formatBdt(5100)), findsWidgets);
      expect(
          find.text(tr('Charge {charge} + costs on the bill {costs}',
              {'charge': formatBdt(4800), 'costs': formatBdt(300)})),
          findsOneWidget);
      expect(find.text(tr('Pays after delivery')), findsOneWidget);
      expect(find.text(formatBdt(2800)), findsOneWidget);
      expect(find.byKey(const Key('shipment-record-payment')), findsOneWidget);
      // The usual-four checklist is gone.
      expect(find.byKey(const ValueKey('cost-add-courier')), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('profit takes the share of the flight costs from the server',
        (t) async {
      phone(t);
      await t.pumpWidget(
          app(const AdminShipmentScreen(code: 'SH-18'), intercept: _round7()));
      await t.pumpAndSettle();
      await _scrollTo(t, find.byKey(const Key('shipment-profit')));
      expect(find.text(formatBdt(4562.37)), findsOneWidget);
      expect(find.text('−${formatBdt(237.63)}'), findsOneWidget);
      expect(
          find.text(tr('{kg} of {total} kg on {flight}',
              {'kg': '4.2', 'total': '38', 'flight': 'BG305'})),
          findsOneWidget);
      expect(
          find.text(
              tr('{amount} in, {amount} out', {'amount': formatBdt(300)})),
          findsOneWidget);
      expect(find.text(tr('Ticket and flyer money are counted on the flight.')),
          findsOneWidget);
    });

    testWidgets('older costs not on the bill come off the profit too',
        (t) async {
      phone(t);
      await t.pumpWidget(app(const AdminShipmentScreen(code: 'SH-18'),
          intercept: _round7(then: (r) async {
        if (r.method == 'GET' && r.url.path == '/api/shipments/SH-18') {
          final body = round7ShipmentBody();
          final shipment = body['shipment']! as Map<String, Object?>;
          shipment['profitBreakdown'] = {
            ...(shipment['profitBreakdown']! as Map<String, Object?>),
            'otherCosts': 150,
            'profit': 4412.37,
          };
          return _ok(body);
        }
        return null;
      })));
      await t.pumpAndSettle();
      await _scrollTo(t, find.byKey(const Key('shipment-profit')));
      expect(find.text(tr('Other costs (not on the bill)')), findsOneWidget);
      expect(find.text('−${formatBdt(150)}'), findsOneWidget);
      expect(find.text(formatBdt(4412.37)), findsOneWidget);
    });

    testWidgets('without older costs there is no such line', (t) async {
      phone(t);
      await t.pumpWidget(
          app(const AdminShipmentScreen(code: 'SH-18'), intercept: _round7()));
      await t.pumpAndSettle();
      await _scrollTo(t, find.byKey(const Key('shipment-profit')));
      expect(find.text(tr('Other costs (not on the bill)')), findsNothing);
    });

    testWidgets('an older server keeps the charge less costs as the profit',
        (t) async {
      phone(t);
      await t.pumpWidget(app(const AdminShipmentScreen(code: 'SH-18')));
      await t.pumpAndSettle();
      await _scrollTo(t, find.byKey(const Key('shipment-profit')));
      // 4,800 − 670 as the old server sums it.
      expect(find.text(formatBdt(4130)), findsOneWidget);
      expect(find.text('−${formatBdt(670)}'), findsOneWidget);
      expect(find.text(tr('Share of flight costs')), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('a cost on the bill is listed and the sheet previews the bill',
        (t) async {
      phone(t);
      Map<String, dynamic>? sent;
      await t.pumpWidget(app(const AdminShipmentScreen(code: 'SH-18'),
          intercept: _round7(then: (r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/expenses')) {
          sent = jsonDecode(r.body) as Map<String, dynamic>;
          return _ok({'ok': true, 'costId': 'c9'});
        }
        return null;
      })));
      await t.pumpAndSettle();
      await _scrollTo(t, find.byKey(const ValueKey('bill-cost-cost-7')));
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('bill-cost-cost-7')),
              matching: find.text('Courier to customer')),
          findsOneWidget);
      expect(
          find.text([
            tr('Courier'),
            tr('paid from {account}', {'account': 'Dhaka cash'})
          ].join(' · ')),
          findsOneWidget);
      await _scrollTo(t, find.byKey(const Key('bill-cost-add')), dy: -300);
      await t.tap(find.byKey(const Key('bill-cost-add')));
      await t.pumpAndSettle();
      expect(find.text(tr('Add cost to the bill')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('cost-customs')));
      await t.pumpAndSettle();
      expect(
          t
              .widget<TextField>(find.byKey(const Key('cost-name')))
              .controller!
              .text,
          'Customs');
      await t.enterText(find.byKey(const Key('cost-amount')), '250');
      await t.pumpAndSettle();
      expect(find.text(tr("Added to {name}'s bill", {'name': 'Nila Store'})),
          findsOneWidget);
      final preview = find.byKey(const Key('cost-preview'));
      expect(
          find.descendant(
              of: preview,
              matching: find.textContaining('${tr('Bill')} ${formatBdt(5100)}',
                  findRichText: true)),
          findsOneWidget);
      expect(
          find.descendant(
              of: preview,
              matching:
                  find.textContaining(formatBdt(5350), findRichText: true)),
          findsOneWidget);
      await _payFrom(t, const Key('cost-account'), const Key('pay-from-later'));
      await t.ensureVisible(find.byKey(const Key('cost-save')));
      await t.tap(find.byKey(const Key('cost-save')));
      await t.pumpAndSettle();
      expect(sent, {
        'category': 'customs',
        'amount': 250.0,
        'reason': 'Customs',
        'label': 'Customs',
        'paymentTiming': 'later',
      });
      expect(find.text(tr('Add cost to the bill')), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('an amount and a way to pay are needed before adding',
        (t) async {
      phone(t);
      final calls = <String>[];
      await t.pumpWidget(app(const AdminShipmentScreen(code: 'SH-18'),
          intercept: _round7(then: (r) async {
        if (r.method != 'GET') calls.add(_call(r));
        return null;
      })));
      await t.pumpAndSettle();
      await _scrollTo(t, find.byKey(const Key('bill-cost-add')));
      await t.tap(find.byKey(const Key('bill-cost-add')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('cost-save')));
      await t.pumpAndSettle();
      expect(find.text(tr('Enter the cost amount.')), findsOneWidget);
      await t.enterText(find.byKey(const Key('cost-amount')), '90');
      await t.ensureVisible(find.byKey(const Key('cost-save')));
      await t.tap(find.byKey(const Key('cost-save')));
      await t.pumpAndSettle();
      expect(
          find.text(tr('Choose the account it was paid from, or Pay later.')),
          findsOneWidget);
      expect(calls, isEmpty);
    });

    testWidgets('an issued invoice shows its lines and no Issue button',
        (t) async {
      phone(t);
      await t.pumpWidget(
          app(const AdminShipmentScreen(code: 'SH-18'), intercept: _round7()));
      await t.pumpAndSettle();
      await _scrollTo(t, find.byKey(const Key('invoice-edit')));
      expect(find.text('INV-2610-SH-18'), findsOneWidget);
      expect(find.text(tr('Issued')), findsOneWidget);
      expect(
          find.text(tr(
              'Made automatically · updates when the charge or costs change')),
          findsOneWidget);
      expect(find.text('Freight · 4.0 kg × ৳950'), findsOneWidget);
      expect(find.text(formatBdt(3800)), findsOneWidget);
      expect(find.text(trn(2, 'Paid · {n} payment', 'Paid · {n} payments')),
          findsOneWidget);
      expect(find.text('−${formatBdt(2800)}'), findsOneWidget);
      expect(find.text(tr('Balance due')), findsOneWidget);
      expect(find.byKey(const Key('invoice-issue')), findsNothing);
      expect(find.byKey(const Key('invoice-confirm')), findsNothing);
      expect(find.text(tr('Issue invoice')), findsNothing);
      expect(find.byKey(const Key('invoice-pdf')), findsOneWidget);
      expect(find.byKey(const Key('invoice-share')), findsOneWidget);
    });

    testWidgets('a draft from an older server gets one quiet Issue invoice',
        (t) async {
      phone(t);
      Map<String, dynamic>? issued;
      await t.pumpWidget(app(const AdminShipmentScreen(code: 'SH-18'),
          intercept: _round7(
              invoice: round7InvoiceBody(state: 'draft'),
              then: (r) async {
                if (r.method == 'POST' && r.url.path.endsWith('/invoice')) {
                  issued = jsonDecode(r.body) as Map<String, dynamic>;
                  return _ok({'ok': true, 'number': 'INV-2610-SH-18'});
                }
                return null;
              })));
      await t.pumpAndSettle();
      final issue = find.byKey(const Key('invoice-issue'));
      await _scrollTo(t, issue);
      expect(find.text(tr('Draft')), findsOneWidget);
      await t.tap(issue);
      await t.pumpAndSettle();
      expect(issued?['state'], 'issued');
      expect(issued?['pricingMode'], 'automatic');
      expect((issued?['lines'] as List).length, 3);
      expect(t.takeException(), isNull);
    });

    testWidgets('a bill that needs review is confirmed with a reason',
        (t) async {
      phone(t);
      Map<String, dynamic>? issued;
      await t.pumpWidget(app(const AdminShipmentScreen(code: 'SH-18'),
          intercept: _round7(
              invoice: round7InvoiceBody(needsReview: true),
              then: (r) async {
                if (r.method == 'POST' && r.url.path.endsWith('/invoice')) {
                  issued = jsonDecode(r.body) as Map<String, dynamic>;
                  return _ok({'ok': true, 'number': 'INV-2610-SH-18'});
                }
                return null;
              })));
      await t.pumpAndSettle();
      final confirm = find.byKey(const Key('invoice-confirm'));
      await _scrollTo(t, confirm);
      expect(find.text(tr('Needs review')), findsOneWidget);
      expect(find.byKey(const Key('invoice-issue')), findsNothing);
      await t.tap(confirm);
      await t.pumpAndSettle();
      expect(issued, isNull);
      expect(find.text(tr('Enter a reason when changing an issued invoice.')),
          findsOneWidget);
      await t.enterText(
          find.byKey(const Key('invoice-review-reason')), 'Rate agreed');
      await t.ensureVisible(confirm);
      await t.tap(confirm);
      await t.pumpAndSettle();
      expect(issued?['revisionReason'], 'Rate agreed');
      expect(issued?['state'], 'issued');
      expect(issued?['pricingMode'], 'manual');
    });

    testWidgets(
        'the saved link shows on open; a new link and turning it off call the server',
        (t) async {
      phone(t);
      final calls = <String>[];
      Map<String, dynamic>? made;
      var active = true;
      await t.pumpWidget(app(const AdminShipmentScreen(code: 'SH-18'),
          intercept: _round7(then: (r) async {
        if (r.method == 'GET' && r.url.path.endsWith('/track-links')) {
          return _ok(trackLinksBody(active: active));
        }
        if (r.method == 'GET') return null;
        calls.add(_call(r));
        if (r.method == 'POST' && r.url.path.endsWith('/track-link')) {
          made = jsonDecode(r.body) as Map<String, dynamic>;
          return _ok({
            'token': 'new',
            'url': 'https://api.sbexpress.jhotpot.app/t/new',
            'expiresAt': '2026-11-26T08:00:00.000Z'
          }, 201);
        }
        if (r.method == 'DELETE') {
          active = false;
          return _ok({'ok': true});
        }
        return null;
      })));
      await t.pumpAndSettle();
      await _scrollTo(t, find.byKey(const Key('link-copy')));
      expect(
          find.text(
              'https://api.sbexpress.jhotpot.app/t/q7Rm2xKd9TfA3LwPz0bV8c'),
          findsOneWidget);
      expect(
          find.text([
            tr('Tracking and bill'),
            tr('valid until {date}', {'date': '3 Nov'})
          ].join(' · ')),
          findsOneWidget);
      expect(find.byKey(const Key('link-create')), findsNothing);
      // A new link for 30 days; the invoice is issued, so it has the bill.
      await t.tap(find.byKey(const Key('link-new')));
      await t.pumpAndSettle();
      await t.tap(find.text(tr('30 days')));
      await t.tap(find.byKey(const Key('link-make')));
      await t.pumpAndSettle();
      expect(made, {'scope': 'invoice', 'days': 30});
      // Turning it off asks first.
      await _scrollTo(t, find.byKey(const Key('link-off')));
      await t.tap(find.byKey(const Key('link-off')));
      await t.pumpAndSettle();
      expect(find.text(tr('Turn off the customer link?')), findsOneWidget);
      await t.tap(find.byKey(const Key('remove-confirm')));
      await t.pumpAndSettle();
      expect(calls, [
        'POST /api/shipments/SH-18/track-link',
        'DELETE /api/shipments/SH-18/track-link',
      ]);
      expect(find.byKey(const Key('link-create')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('flight costs', () {
    testWidgets('the flight shows its costs, the profit and who is late',
        (t) async {
      phone(t);
      await t.pumpWidget(app(const FlightDetailScreen(code: flowFlightCode),
          intercept: _flight()));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('flight-profit')), findsOneWidget);
      expect(find.text(formatBdt(17650)), findsOneWidget);
      expect(find.text('+${formatBdt(30000)}'), findsOneWidget);
      expect(find.text('−${formatBdt(2150)}'), findsOneWidget);
      await _scrollTo(t, find.byKey(const Key('flight-cost-total')));
      expect(find.text(tr('Transport')), findsOneWidget);
      expect(find.text('Airport to Dhaka hub · Dhaka cash'), findsOneWidget);
      expect(find.text(tr('Pay later · unpaid')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('flight-cost-total'))).data,
          formatBdt(2150));
      // SH-18 carries 4 of the 31.5 kg: 2,150 × 4 / 31.5.
      await _scrollTo(
          t, find.text(tr('How the flight costs reach each shipment')));
      expect(
          find.textContaining(tr(
              '{code} carries {kg} of {total} kg, so its share is {share} of {costs}.',
              {
                'code': 'SH-18',
                'kg': '4.0',
                'total': '31.5',
                'share': formatBdt(273.02),
                'costs': formatBdt(2150)
              })),
          findsOneWidget);
      final late = find.byKey(const ValueKey('booking-chip-SH-21'));
      await _scrollTo(t, late);
      expect(
          find.descendant(
              of: late,
              matching: find.text(trn(12, '{n} day late', '{n} days late'))),
          findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('older shipment costs show on the flight profit when sent',
        (t) async {
      phone(t);
      await t.pumpWidget(app(const FlightDetailScreen(code: flowFlightCode),
          intercept: _flight((r) async {
        if (r.method == 'GET' && r.url.path == '/api/flights/$flowFlightCode') {
          final body = round7FlightBody();
          final flight = body['flight']! as Map<String, Object?>;
          flight['profitBreakdown'] = {
            ...(flight['profitBreakdown']! as Map<String, Object?>),
            'otherCosts': 1700,
            'profit': 15950,
          };
          return _ok(body);
        }
        return null;
      })));
      await t.pumpAndSettle();
      expect(find.text(tr('Older shipment costs')), findsOneWidget);
      expect(find.text('−${formatBdt(1700)}'), findsOneWidget);
      expect(find.text(formatBdt(15950)), findsOneWidget);
    });

    testWidgets('an unpaid flight cost is marked paid from an account',
        (t) async {
      phone(t);
      final calls = <String>[];
      Map<String, dynamic>? sent;
      await t.pumpWidget(app(const FlightDetailScreen(code: flowFlightCode),
          intercept: _flight((r) async {
        if (r.method == 'GET') return null;
        calls.add(_call(r));
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return _ok({'ok': true});
      })));
      await t.pumpAndSettle();
      // Only the pay-later courier cost offers it.
      expect(find.byKey(const ValueKey('flight-cost-pay-fc-3')), findsNothing);
      final pay = find.byKey(const ValueKey('flight-cost-pay-fc-1'));
      await _scrollTo(t, pay);
      await t.tap(pay);
      await t.pumpAndSettle();
      await t.tap(find.text('Dhaka cash').last);
      await t.pumpAndSettle();
      expect(calls, isEmpty);
      await t.tap(find.text(tr('Confirm')));
      await t.pumpAndSettle();
      expect(calls, ['POST /api/flights/$flowFlightCode/costs/fc-1/pay']);
      expect(sent, {'accountName': 'Dhaka cash'});
      expect(t.takeException(), isNull);
    });

    testWidgets('marking paid on an older server says it needs an update',
        (t) async {
      phone(t);
      await t.pumpWidget(app(const FlightDetailScreen(code: flowFlightCode),
          intercept: _flight((r) async {
        if (r.method == 'POST') return _ok({'error': 'Not found'}, 404);
        return null;
      })));
      await t.pumpAndSettle();
      final pay = find.byKey(const ValueKey('flight-cost-pay-fc-1'));
      await _scrollTo(t, pay);
      await t.tap(pay);
      await t.pumpAndSettle();
      await t.tap(find.text('Dhaka cash').last);
      await t.pumpAndSettle();
      await t.tap(find.text(tr('Confirm')));
      await t.pumpAndSettle();
      expect(
          find.text(tr(
              'The server needs an update before flight costs can be marked paid.')),
          findsOneWidget);
    });

    testWidgets('an older server keeps the old profit, costs card still shows',
        (t) async {
      phone(t);
      await t.pumpWidget(app(const FlightDetailScreen(code: flowFlightCode)));
      await t.pumpAndSettle();
      // Add stays reachable; on this server it says it needs an update.
      await t.scrollUntilVisible(find.byKey(const Key('flight-costs')), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const Key('flight-costs')), findsOneWidget);
      expect(find.text(tr('No flight costs yet.')), findsOneWidget);
      expect(find.byKey(const Key('flight-profit')), findsNothing);
      // The navy card: charges − shipment costs − our ticket share.
      expect(find.text(formatBdt(16180)), findsOneWidget);
      expect(find.text(tr('Still to come in')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('labour is saved as others with its label, paid later',
        (t) async {
      phone(t);
      Map<String, dynamic>? sent;
      await t.pumpWidget(app(const FlightDetailScreen(code: flowFlightCode),
          intercept: _flight((r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/costs')) {
          sent = jsonDecode(r.body) as Map<String, dynamic>;
          return _ok({
            'cost': {
              'id': 'fc-9',
              'category': 'others',
              'label': 'Labour',
              'amount': 500,
              'date': '2026-10-27T08:00:00.000Z',
              'paid': false,
              'accountName': null
            }
          }, 201);
        }
        return null;
      })));
      await t.pumpAndSettle();
      await _scrollTo(t, find.byKey(const Key('flight-cost-add')));
      await t.tap(find.byKey(const Key('flight-cost-add')));
      await t.pumpAndSettle();
      expect(
          find.text(tr('{flight} · flight costs so far {amount}',
              {'flight': 'BG305', 'amount': formatBdt(2150)})),
          findsOneWidget);
      await t.tap(find.byKey(const ValueKey('flight-cost-labour')));
      await t.enterText(find.byKey(const Key('flight-cost-amount')), '500');
      await t.pumpAndSettle();
      // Our cost only: the flight's profit drops, no bill changes.
      final preview = find.byKey(const Key('flight-cost-preview'));
      expect(
          find.descendant(
              of: preview,
              matching: find.text(tr("Not added to any customer's bill."))),
          findsOneWidget);
      expect(
          find.descendant(
              of: preview,
              matching: find.textContaining(
                  '${tr('Profit')} ${formatBdt(17650)}',
                  findRichText: true)),
          findsOneWidget);
      expect(
          find.descendant(
              of: preview,
              matching:
                  find.textContaining(formatBdt(17150), findRichText: true)),
          findsOneWidget);
      await _payFrom(
          t, const Key('flight-cost-account'), const Key('pay-from-later'));
      await t.ensureVisible(find.byKey(const Key('flight-cost-save')));
      await t.tap(find.byKey(const Key('flight-cost-save')));
      await t.pumpAndSettle();
      expect(sent, {
        'category': 'others',
        'label': 'Labour',
        'amount': 500.0,
        'payLater': true
      });
      expect(find.text(tr('Add flight cost')), findsNothing);
    });

    testWidgets('a new name is saved as others and paid from an account',
        (t) async {
      phone(t);
      Map<String, dynamic>? sent;
      await t.pumpWidget(app(const FlightDetailScreen(code: flowFlightCode),
          intercept: _flight((r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/costs')) {
          sent = jsonDecode(r.body) as Map<String, dynamic>;
          return _ok({
            'cost': {
              'id': 'fc-10',
              'category': 'others',
              'label': 'Loading crew',
              'amount': 120,
              'date': '2026-10-27T08:00:00.000Z',
              'paid': true,
              'accountName': 'Dhaka cash'
            }
          }, 201);
        }
        return null;
      })));
      await t.pumpAndSettle();
      await _scrollTo(t, find.byKey(const Key('flight-cost-add')));
      await t.tap(find.byKey(const Key('flight-cost-add')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('flight-cost-save')));
      await t.pumpAndSettle();
      expect(find.text(tr('Pick what the cost was for.')), findsOneWidget);
      await t.tap(find.byKey(const Key('flight-cost-new')));
      await t.pumpAndSettle();
      await t.enterText(
          find.byKey(const Key('flight-cost-label')), 'Loading crew');
      await t.enterText(find.byKey(const Key('flight-cost-amount')), '120');
      await t.pumpAndSettle();
      await _payFrom(t, const Key('flight-cost-account'),
          const ValueKey('pay-from-Dhaka cash'));
      await t.ensureVisible(find.byKey(const Key('flight-cost-save')));
      await t.tap(find.byKey(const Key('flight-cost-save')));
      await t.pumpAndSettle();
      await t.tap(find.text(tr('Confirm')));
      await t.pumpAndSettle();
      expect(sent, {
        'category': 'others',
        'label': 'Loading crew',
        'amount': 120.0,
        'accountName': 'Dhaka cash'
      });
    });

    testWidgets('a flight cost is removed only after the confirm', (t) async {
      phone(t);
      final calls = <String>[];
      await t.pumpWidget(app(const FlightDetailScreen(code: flowFlightCode),
          intercept: _flight((r) async {
        if (r.method == 'GET') return null;
        calls.add(_call(r));
        return _ok({'ok': true});
      })));
      await t.pumpAndSettle();
      final remove = find.byKey(const ValueKey('flight-cost-remove-fc-1'));
      await _scrollTo(t, remove);
      await t.tap(remove);
      await t.pumpAndSettle();
      expect(find.text(tr('Remove this flight cost?')), findsOneWidget);
      await t.tap(find.text(tr('Go back')));
      await t.pumpAndSettle();
      expect(calls, isEmpty);
      await t.tap(remove);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('remove-confirm')));
      await t.pumpAndSettle();
      expect(calls, ['DELETE /api/flights/$flowFlightCode/costs/fc-1']);
      expect(t.takeException(), isNull);
    });

    testWidgets('a server without flight costs says it needs an update',
        (t) async {
      phone(t);
      await t.pumpWidget(app(const FlightDetailScreen(code: flowFlightCode),
          intercept: _flight((r) async {
        if (r.method == 'POST' || r.method == 'DELETE') {
          return _ok({'error': 'Not found'}, 404);
        }
        return null;
      })));
      await t.pumpAndSettle();
      // Removing first.
      final remove = find.byKey(const ValueKey('flight-cost-remove-fc-2'));
      await _scrollTo(t, remove);
      await t.tap(remove);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('remove-confirm')));
      await t.pumpAndSettle();
      expect(
          find.text(tr(
              'The server needs an update before flight costs can be removed.')),
          findsOneWidget);
      await t.tap(find.text(tr('Close')));
      await t.pumpAndSettle();
      // Then adding.
      await _scrollTo(t, find.byKey(const Key('flight-cost-add')), dy: -300);
      await t.tap(find.byKey(const Key('flight-cost-add')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('flight-cost-transport')));
      await t.enterText(find.byKey(const Key('flight-cost-amount')), '900');
      await t.pumpAndSettle();
      await _payFrom(
          t, const Key('flight-cost-account'), const Key('pay-from-later'));
      await t.ensureVisible(find.byKey(const Key('flight-cost-save')));
      await t.tap(find.byKey(const Key('flight-cost-save')));
      await t.pumpAndSettle();
      expect(
          find.text(tr(
              'The server needs an update before flight costs can be added.')),
          findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });
}
