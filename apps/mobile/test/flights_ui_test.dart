import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sbexpress/data/models/flight.dart';
import 'package:sbexpress/features/admin/admin_shipment_screen.dart';
import 'package:sbexpress/features/admin/money_format.dart';
import 'package:sbexpress/features/flights/flight_detail_screen.dart';
import 'package:sbexpress/features/flights/flight_money_screen.dart';
import 'package:sbexpress/features/flights/flights_screen.dart';
import 'package:sbexpress/features/intake/intake_screen.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'restructured_flow_test.dart' show app, phone;

const _full = 'BG305-20261021-ab12cd';

Map<String, Object?> _summaryJson(Map<String, Object?> extra) => {
      'code': 'BG1-20261101-ab12cd',
      'date': '2026-11-01',
      'depTime': '10:40',
      'arrTime': '15:25',
      'via': 'Via KMG Kunming',
      'fare': 0,
      'actualCost': 0,
      'agencyShare': 0,
      'flyerDue': 0,
      'ticketPaid': 0,
      'ticketDue': 0,
      'spaceKg': 40,
      'mobiles': 0,
      'laptops': 0,
      'bookedKg': 0,
      'leftKg': 40,
      'status': 'upcoming',
      'statusLabel': 'Upcoming',
      'flyers': <String>[],
      'shipmentCount': 0,
      'revenue': 0,
      'scheduleNeedsConfirmation': false,
      'settlements': <Object>[],
      ...extra,
    };

void main() {
  test('a flight reads its route ends from the legs', () {
    final flight = FlightSummary.fromJson(_summaryJson({
      'legs': [
        {'fromCity': 'Chengdu', 'fromIata': 'TFU', 'toIata': 'KMG'},
        {'fromIata': 'KMG', 'toCity': '', 'toIata': 'DAC'},
      ]
    }));
    expect(flight.from, 'Chengdu');
    expect(flight.to, 'DAC');
    expect(flight.stopLabel, 'KMG Kunming');
    final bare = FlightSummary.fromJson(_summaryJson({'via': 'Direct'}));
    expect(bare.from, isNull);
    expect(bare.stopLabel, isNull);
  });

  testWidgets('flights list marks the next flight and keeps ticket import',
      (t) async {
    phone(t);
    await t.pumpWidget(app(const FlightsScreen()));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('flights-import-ticket')), findsOneWidget);
    expect(find.text(trn(3, '{n} flight', '{n} flights')), findsOneWidget);
    expect(find.text(tr('{kg} kg booked in total', {'kg': '55.4'})),
        findsOneWidget);
    // Only the first upcoming flight is the next one.
    expect(find.textContaining(tr('Next · {when}', {'when': ''}).trim()),
        findsOneWidget);
    expect(find.text(tr('No flyer assigned')), findsOneWidget);
    await t.tap(find.text(tr('Completed')));
    await t.pumpAndSettle();
    expect(find.text('BG139'), findsOneWidget);
    expect(find.text('BG305'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('flight detail sums what is left to collect on its bookings',
      (t) async {
    phone(t);
    await t.pumpWidget(app(const FlightDetailScreen(code: _full)));
    await t.pumpAndSettle();
    expect(find.text(tr('Bookings · {n}', {'n': 4})), findsOneWidget);
    // 3,600 + 10,550 + 5,700; SH-21 is paid.
    expect(
        find.text(
            tr('{amount} still to collect', {'amount': formatBdt(19850)})),
        findsOneWidget);
    expect(find.textContaining('· ${tr('Paid')}'), findsOneWidget);
    await t.tap(find.text(tr('Ticket money')));
    await t.pumpAndSettle();
    expect(find.byType(FlightMoneyScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'ticket money shows the flyer share, what came in and the unassigned payment',
      (t) async {
    phone(t);
    await t.pumpWidget(app(const FlightMoneyScreen(code: _full)));
    await t.pumpAndSettle();
    // 42,000 cost less 12,000 agency share.
    expect(
        find.text(tr('Split the {amount} share, then record payments',
            {'amount': formatBdt(30000)})),
        findsOneWidget);
    // 15,000 + 6,000 split payments and 2,000 not yet assigned.
    expect(find.text(tr('{amount} received', {'amount': formatBdt(23000)})),
        findsOneWidget);
    expect(find.text(tr('Paid up')), findsOneWidget);
    expect(find.text(tr('{amount} due', {'amount': formatBdt(9000)})),
        findsOneWidget);
    expect(
        find.text(tr(
            '{amount} was received before the split and is not assigned to a flyer yet. Assign it once in the split.',
            {'amount': formatBdt(2000)})),
        findsOneWidget);
    await t.ensureVisible(find.text(tr('Split contributions')));
    await t.pumpAndSettle();
    await t.tap(find.text(tr('Split contributions')));
    await t.pumpAndSettle();
    expect(find.byType(ContributionScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('contributions show what is still left to split as you type',
      (t) async {
    phone(t);
    await t.pumpWidget(app(const ContributionScreen(code: _full)));
    await t.pumpAndSettle();
    expect(find.text(tr('Left to split')), findsOneWidget);
    final fields = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == tr('Contribution'));
    await t.enterText(fields.first, '10000');
    await t.pump();
    expect(find.text(formatBdt(5000)), findsOneWidget);
    await t.enterText(fields.first, '20000');
    await t.pump();
    expect(find.text(tr('Too much')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('shipment summary shows the pipeline step and opens the bill',
      (t) async {
    phone(t);
    await t.pumpWidget(app(const AdminShipmentScreen(code: 'SH-18')));
    await t.pumpAndSettle();
    expect(find.text(tr('Step {step} of {total}', {'step': 6, 'total': 9})),
        findsOneWidget);
    expect(find.text(tr('{amount} due', {'amount': formatBdt(3800)})),
        findsOneWidget);
    final billLink =
        find.text(tr('For a link with the invoice, open the Bill tab.'));
    await t.ensureVisible(billLink);
    await t.pumpAndSettle();
    await t.tap(billLink);
    await t.pumpAndSettle();
    expect(find.text(tr('Amount due')), findsOneWidget);
    // The due pill gives way to the hero on the Bill tab.
    expect(find.text(tr('{amount} due', {'amount': formatBdt(3800)})),
        findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'booking review estimates the charge and books a chosen flight and flyer',
      (t) async {
    phone(t);
    Map<String, dynamic>? sent;
    await t.pumpWidget(app(const IntakeScreen(), intercept: (r) async {
      if (r.method == 'GET' && r.url.path == '/api/flights') {
        return http.Response(
            jsonEncode({
              'flights': [
                _summaryJson({
                  'code': 'BG9-20261101-ab12cd',
                  'flyers': ['Arif Rahman', 'Rakib Hasan'],
                  'leftKg': 3.0,
                }),
              ]
            }),
            200);
      }
      if (r.method == 'POST' && r.url.path == '/api/shipments') {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return http.Response('{"code":"SH-18"}', 200);
      }
      return null;
    }));
    await t.pumpAndSettle();
    await t.tap(find.text(tr('Choose a customer')));
    await t.pumpAndSettle();
    await t.tap(find.text('Nila Store'));
    await t.pumpAndSettle();
    await t.tap(find.text('Mobile'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip(tr('One more')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('intake-next')));
    await t.pumpAndSettle();
    Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label);
    await t.enterText(field(tr('Booked kg')), '4');
    await t.enterText(field(tr('Rate per kg')), '950');
    await t.pump();
    expect(find.text(formatBdt(3800)), findsOneWidget);
    await t.tap(find.byKey(const Key('intake-next')));
    await t.pumpAndSettle();
    // 4 kg × 950 plus 2 mobiles × 2,000 from settings.
    expect(find.text(formatBdt(7800)), findsOneWidget);
    await t.drag(find.byType(ListView).first, const Offset(0, -500));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('BG9 · '));
    await t.pumpAndSettle();
    expect(find.text(tr('Over capacity')), findsOneWidget);
    await t.scrollUntilVisible(find.text('Rakib Hasan'), 200,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Rakib Hasan'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('intake-next')));
    await t.pumpAndSettle();
    expect(sent?['flightCode'], 'BG9-20261101-ab12cd');
    expect(sent?['flyerName'], 'Rakib Hasan');
    expect((sent?['pcsItems'] as List).single['count'], 2);
    expect(t.takeException(), isNull);
  });
}
