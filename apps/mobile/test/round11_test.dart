import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sbexpress/data/models/flight.dart';
import 'package:sbexpress/data/models/flight_route.dart';
import 'package:sbexpress/features/flights/confirm_status_sheet.dart';
import 'package:sbexpress/features/flights/flight_detail_screen.dart';
import 'package:sbexpress/features/flights/flight_edit_screen.dart';
import 'package:sbexpress/features/flights/flights_screen.dart';
import 'package:sbexpress/features/flights/hub_flights_screen.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'package:sbexpress/widgets/flight_status_parts.dart';
import 'restructured_flow_test.dart' show app, phone;
import 'support/screen_fixtures.dart';

http.Response _ok(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

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

/// The flight page's flight with [extra] on top.
Map<String, Object?> _flightPage(Map<String, Object?> extra) {
  final body = round7FlightBody();
  final flight = Map<String, Object?>.from(body['flight']! as Map)
    ..addAll(extra);
  return {...body, 'flight': flight};
}

Future<void> _openPage(WidgetTester t, Map<String, Object?> body,
    {List<Map<String, dynamic>>? patches,
    Map<String, Object?> Function()? answer}) async {
  await t.pumpWidget(
      app(const FlightDetailScreen(code: flowFlightCode), intercept: (r) async {
    if (r.method == 'PATCH') {
      patches?.add(jsonDecode(r.body) as Map<String, dynamic>);
      return _ok(answer?.call() ?? {'code': flowFlightCode, 'moved': []});
    }
    if (Uri.decodeComponent(r.url.path) == '/api/flights/$flowFlightCode') {
      return _ok(body);
    }
    return null;
  }));
  await t.pumpAndSettle();
}

void main() {
  group('late and early', () {
    test('a few minutes off the plan is on time', () {
      expect(lateText(3), tr('on time'));
      expect(lateText(15), tr('{n} min late', {'n': 15}));
      expect(lateText(95), tr('{h} h {m} min late', {'h': 1, 'm': 35}));
      expect(lateText(-120), tr('{h} h early', {'h': 2}));
      expect(isOffPlan(-5), isTrue);
      expect(isOffPlan(null), isFalse);
    });

    test('the airline cancelling only counts while it is upcoming', () {
      final cancelled = FlightTracking.fromJson(r11Cancelled());
      expect(flightCancelled('upcoming', cancelled), isTrue);
      expect(flightCancelled('departed', cancelled), isFalse);
      expect(flightCancelled('upcoming', null), isFalse);
      expect(FlightTracking.fromJson({'state': 'none'}), isNull);
    });

    test('the snackbar names the orders that moved', () {
      const saved = FlightSaved(code: 'x', moved: ['SH-41', 'SH-42']);
      expect(
          confirmedMessage('BG305', const StatusConfirmed('departed', saved)),
          '${tr('{code} is on the way.', {'code': 'BG305'})} '
          '${trn(2, '{n} order moved to In transit.', '{n} orders moved to In transit.')}');
      expect(
          confirmedMessage('BG305',
              const StatusConfirmed('completed', FlightSaved(code: 'x'))),
          tr('{code} has landed.', {'code': 'BG305'}));
    });
  });

  testWidgets(
      'flights list asks to confirm a passed date and saves it as Departed',
      (t) async {
    phone(t);
    final past = r11FlightRow('BG305', -1, needsConfirmation: true);
    final rows = [
      past,
      r11FlightRow('BG147', 2, tracking: r11Cancelled()),
      r11FlightRow('BG152', 0, status: 'departed', tracking: r11OnTheWay()),
    ];
    final patches = <(String, Map<String, dynamic>)>[];
    await t.pumpWidget(app(const FlightsScreen(), intercept: (r) async {
      final path = Uri.decodeComponent(r.url.path);
      if (r.method == 'PATCH') {
        patches.add((path, jsonDecode(r.body) as Map<String, dynamic>));
        return _ok({
          'code': past['code'],
          'moved': ['SH-41', 'SH-42']
        });
      }
      if (path == '/api/flights') return _ok({'flights': rows});
      return null;
    }));
    await t.pumpAndSettle();

    expect(find.text(tr('Date has passed')), findsOneWidget);
    expect(find.text(tr('No update from the airline. Confirm what happened.')),
        findsOneWidget);
    expect(find.text(tr('Cancelled by airline')), findsOneWidget);
    expect(find.text(tr('Nothing changed here. Move it to the new date.')),
        findsOneWidget);
    expect(find.text(tr('Date has passed · Confirm the status')), findsNothing);

    await _tap(t, find.byKey(ValueKey('confirm-status-${past['code']}')));
    expect(find.byType(ConfirmStatusSheet), findsOneWidget);
    expect(find.text(tr('What happened to {code}?', {'code': 'BG305'})),
        findsOneWidget);
    await _tap(t, find.byKey(const Key('confirm-save')));
    expect(patches, hasLength(1));
    expect(patches.single.$1, '/api/flights/${past['code']}');
    expect(patches.single.$2, {'status': 'departed'});
    expect(find.byType(ConfirmStatusSheet), findsNothing);
    expect(find.textContaining(tr('{code} is on the way.', {'code': 'BG305'})),
        findsOneWidget);

    await t.tap(find.text(tr('On the way')));
    await t.pumpAndSettle();
    expect(find.text('BG152'), findsOneWidget);
    expect(
        find.text([
          tr('Left {time}', {'time': '10:52'}),
          tr('lands {time}, {late}', {'time': '15:40', 'late': lateText(15)}),
          tr('from the airline'),
        ].join(' · ')),
        findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'a flight that left shows the airline legs and which orders moved',
      (t) async {
    phone(t);
    await _openPage(
        t,
        _flightPage({
          'status': 'departed',
          'statusLabel': 'Departed',
          'tracking': r11OnTheWay(),
          'movedOrders': {
            'at': DateTime.now().toUtc().toIso8601String(),
            'by': 'airline',
            'codes': ['SH-51', 'SH-18'],
          },
          'notMoved': [
            {
              'code': 'SH-53',
              'customer': 'Nila Store',
              'status': 'ready_for_shipment',
              'reason': 'no_flyer',
            }
          ],
        }));

    expect(find.byKey(const Key('flight-date-passed')), findsNothing);
    await _reveal(t, find.byKey(const Key('flight-tracking')));
    expect(find.text(tr('In the air')), findsOneWidget);
    expect(
        find.text(
            tr('Left {dep} · landed {arr}', {'dep': '10:52', 'arr': '12:18'})),
        findsOneWidget);
    expect(
        find.text(tr(
            'Updated from the airline by itself. Next check soon after it lands. You can still change the status in Edit.')),
        findsOneWidget);

    await _reveal(t, find.byKey(const Key('orders-moved')));
    expect(
        find.text(trn(2, '{n} order moved to In transit',
            '{n} orders moved to In transit')),
        findsOneWidget);
    expect(
        find.text(tr(
            'They moved when the flight left at {time}.', {'time': '10:52'})),
        findsOneWidget);
    await _reveal(t, find.byKey(const ValueKey('not-moved-SH-53')));
    expect(
        find.text(tr(
            'It has no carrying flyer. Pick the flyer on the order to move it.')),
        findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a cancelled flight goes to Edit flight from Change date',
      (t) async {
    phone(t);
    final patches = <Map<String, dynamic>>[];
    await _openPage(t, _flightPage({'tracking': r11Cancelled()}),
        patches: patches);

    expect(find.byKey(const Key('flight-cancelled')), findsOneWidget);
    expect(find.text(tr('Cancelled by airline')), findsOneWidget);
    await _tap(t, find.byKey(const Key('flight-change-date')));
    expect(find.byType(FlightEditScreen), findsOneWidget);
    await _reveal(t, find.byKey(const Key('flight-edit-airline')));
    expect(find.byKey(const Key('flight-edit-status')), findsOneWidget);
    expect(patches, isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('a passed date can also fly on another day', (t) async {
    phone(t);
    final patches = <Map<String, dynamic>>[];
    await _openPage(
        t,
        _flightPage({
          'date': r11Day(-1),
          'scheduleNeedsConfirmation': true,
        }),
        patches: patches);

    expect(find.byKey(const Key('flight-date-passed')), findsOneWidget);
    await _tap(t, find.byKey(const Key('flight-confirm-status')));
    // SH-53 is the one order ready for shipment.
    expect(
        find.text(trn(
            1,
            'Status becomes Departed. The {n} order ready for shipment moves to In transit.',
            'Status becomes Departed. The {n} orders ready for shipment move to In transit.')),
        findsOneWidget);
    await _tap(t, find.byKey(const Key('confirm-another-day')));
    expect(find.text(tr('Change date')), findsOneWidget);
    await _tap(t, find.byKey(const Key('confirm-save')));
    expect(find.byType(FlightEditScreen), findsOneWidget);
    expect(patches, isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('Edit flight sets Landed and counts the orders that moved',
      (t) async {
    phone(t);
    final patches = <Map<String, dynamic>>[];
    await _openPage(t, _flightPage({}),
        patches: patches,
        answer: () => {
              'code': flowFlightCode,
              'moved': ['SH-53']
            });

    await _tap(t, find.byKey(const Key('flight-edit')));
    await _tap(t, find.byKey(const Key('flight-status-completed')));
    await _tap(t, find.byKey(const Key('flight-edit-save')));
    expect(patches, hasLength(1));
    expect(patches.single['status'], 'completed');
    expect(find.byType(FlightEditScreen), findsNothing);
    expect(
        find.text(trn(1, 'Flight saved · {n} order moved to In transit',
            'Flight saved · {n} orders moved to In transit')),
        findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Edit flight leaves the status out when it did not change',
      (t) async {
    phone(t);
    final patches = <Map<String, dynamic>>[];
    await _openPage(t, _flightPage({}), patches: patches);

    await _tap(t, find.byKey(const Key('flight-edit')));
    await _tap(t, find.byKey(const Key('flight-edit-save')));
    expect(patches, hasLength(1));
    expect(patches.single.containsKey('status'), isFalse);
    expect(find.text(tr('Flight saved')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  group('hub', () {
    Map<String, Object?> hubDetail(Map<String, Object?> extra) {
      final body = hubFlightDetailBody();
      return {
        'flight': {...body['flight']! as Map<String, Object?>, ...extra}
      };
    }

    testWidgets('a flight that left shows when it lands', (t) async {
      phone(t);
      await t.pumpWidget(app(const HubFlightDetailScreen(code: 'BG147-x'),
          intercept: (r) async {
        if (r.url.path.startsWith('/api/flights/hub/')) {
          return _ok(hubDetail({
            'status': 'departed',
            'statusLabel': 'Departed',
            'tracking': r11OnTheWay(),
          }));
        }
        return null;
      }));
      await t.pumpAndSettle();

      expect(find.byKey(const Key('hub-landing')), findsOneWidget);
      expect(find.text('15:40'), findsOneWidget);
      expect(find.text(lateLabel(15)), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('an upcoming flight keeps the usual route card', (t) async {
      phone(t);
      await t.pumpWidget(app(const HubFlightDetailScreen(code: 'BG147-x')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('hub-landing')), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('the list says what the airline said', (t) async {
      phone(t);
      final schedule = hubScheduleBody();
      final upcoming = [
        for (final row in schedule['upcoming']! as List)
          Map<String, Object?>.from(row as Map)
      ];
      upcoming[0].addAll({
        'status': 'departed',
        'statusLabel': 'Departed',
        'tracking': r11OnTheWay(),
      });
      upcoming[1]['tracking'] = r11Cancelled();
      await t.pumpWidget(
          app(const HubFlightsScreen(root: true), intercept: (r) async {
        if (r.url.path == '/api/flights/hub') {
          return _ok({...schedule, 'upcoming': upcoming});
        }
        return null;
      }));
      await t.pumpAndSettle();

      expect(
          find.text(
              tr('The airline cancelled it. The admin sets the new date.')),
          findsOneWidget);
      expect(find.text(tr('Cancelled by airline')), findsWidgets);
      await _reveal(
          t,
          find.textContaining(tr('Left {time}', {'time': '10:52'}),
              findRichText: true));
      expect(t.takeException(), isNull);
    });
  });
}
