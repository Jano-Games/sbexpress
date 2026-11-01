import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sbexpress/app_scope.dart';
import 'package:sbexpress/data/models/flight.dart';
import 'package:sbexpress/data/models/session_user.dart';
import 'package:sbexpress/data/models/workspace.dart';
import 'package:sbexpress/features/flights/flight_detail_screen.dart';
import 'package:sbexpress/features/flights/flight_form_screen.dart';
import 'package:sbexpress/features/flights/ticket_import_screen.dart';
import 'package:sbexpress/features/more/more_screen.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'package:sbexpress/widgets/quick_parts.dart' show plainKg;
import 'restructured_flow_test.dart' show app, field, phone;
import 'support/screen_fixtures.dart';

http.Response _ok(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

/// The round 8 settings with a default capacity; null leaves it out, as an
/// older server does.
Map<String, Object?> _settings({int? space = 52}) => {
      ...round8Settings(),
      if (space != null) 'defaultSpaceKg': space,
    };

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

Future<void> _scrollTo(WidgetTester t, Finder finder) async {
  await t.scrollUntilVisible(finder, 300,
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

Widget _more() => Builder(
    builder: (context) => MoreScreen(
        user: const SessionUser(
            id: 'u',
            name: 'Tester',
            email: 'test@sbx.test',
            role: UserRole.admin,
            roleLabel: 'Administrator'),
        session: AppScope.of(context).session));

void main() {
  test('the default capacity is read when the server sends it', () {
    expect(SettingsSnapshot.fromJson(_settings()).defaultSpaceKg, 52);
    expect(SettingsSnapshot.fromJson(_settings(space: null)).defaultSpaceKg,
        isNull);
  });

  testWidgets('More shows the default capacity and saves a new one', (t) async {
    phone(t);
    Map<String, dynamic>? sent;
    await t.pumpWidget(app(_more(), intercept: (r) async {
      if (r.url.path != '/api/settings') return null;
      if (r.method == 'PATCH') {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return _ok({
          'settings': {..._settings(), ...sent!}
        });
      }
      return _ok({'settings': _settings()});
    }));
    await t.pumpAndSettle();

    final tile = find.byKey(const ValueKey('more-capacity'));
    await _scrollTo(t, tile);
    expect(
        find.descendant(
            of: tile,
            matching:
                find.text(tr('New flights start with {kg} kg', {'kg': 52}))),
        findsOneWidget);
    await t.tap(tile);
    await t.pumpAndSettle();
    expect(
        t
            .widget<TextField>(find.byKey(const Key('capacity-field')))
            .controller!
            .text,
        '52');
    await _tap(t, find.byKey(const ValueKey('capacity-44')));
    await _tap(t, find.byKey(const Key('capacity-save')));
    expect(sent, {'defaultSpaceKg': 44});
    expect(find.byKey(const Key('capacity-field')), findsNothing);
  });

  testWidgets('an older server says it cannot keep the default', (t) async {
    phone(t);
    await t.pumpWidget(app(_more(), intercept: (r) async {
      if (r.url.path != '/api/settings') return null;
      return _ok({'settings': _settings(space: null)});
    }));
    await t.pumpAndSettle();
    final tile = find.byKey(const ValueKey('more-capacity'));
    await _scrollTo(t, tile);
    await t.tap(tile);
    await t.pumpAndSettle();
    // It starts from 44 kg when the server has no default.
    expect(
        t
            .widget<TextField>(find.byKey(const Key('capacity-field')))
            .controller!
            .text,
        '44');
    await _tap(t, find.byKey(const ValueKey('capacity-52')));
    await _tap(t, find.byKey(const Key('capacity-save')));
    expect(
        find.text(
            tr('The server needs an update to keep the default capacity.')),
        findsOneWidget);
  });

  testWidgets('a new flight starts with the default capacity', (t) async {
    phone(t);
    await t.pumpWidget(app(const FlightFormScreen(), intercept: (r) async {
      if (r.url.path == '/api/settings') return _ok({'settings': _settings()});
      return null;
    }));
    await t.pumpAndSettle();
    final capacity = field(tr('Capacity kg'));
    await _scrollTo(t, capacity);
    expect(t.widget<TextField>(capacity).controller!.text, '52');
  });

  testWidgets('a ticket\'s flights start with the default capacity', (t) async {
    phone(t);
    final flights = <Map<String, Object?>>[];
    final body = ticketImportBody();
    body['journeys'] = [(body['journeys'] as List).first];
    await t.pumpWidget(app(
        _Host(TicketImportScreen(
            pickPdf: () async => utf8.encode('%PDF-1.4 test'))),
        intercept: (r) async {
      final path = r.url.path;
      if (path == '/api/settings') return _ok({'settings': _settings()});
      if (path == '/api/flights/ticket') return _ok(body);
      if (path == '/api/flights' && r.method == 'POST') {
        flights.add(jsonDecode(r.body) as Map<String, Object?>);
        return _ok({'code': 'MU5842-x'}, 201);
      }
      return null;
    }));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('ticket-pick')));
    await t.pumpAndSettle();
    final cargo = find.widgetWithText(TextFormField, tr('Cargo kg'));
    await _scrollTo(t, cargo);
    expect(
        find.descendant(of: cargo, matching: find.text('52')), findsOneWidget);
    await _tap(t, find.byKey(const Key('ticket-save')));
    expect(flights.single['spaceKg'], 52);
  });

  testWidgets(
      'a flight\'s capacity changes on its page, never below what is booked',
      (t) async {
    phone(t);
    final summary = FlightSummary.fromJson(
        round7FlightBody()['flight']! as Map<String, Object?>);
    final booked = summary.bookedKg;
    final calls = <String>[];
    Map<String, dynamic>? sent;
    await t.pumpWidget(app(const FlightDetailScreen(code: flowFlightCode),
        intercept: (r) async {
      if (r.method == 'PATCH') {
        calls.add('PATCH ${Uri.decodeComponent(r.url.path)}');
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return _ok({'flight': round7FlightBody()['flight']});
      }
      if (r.url.path == '/api/flights/$flowFlightCode') {
        return _ok(round7FlightBody());
      }
      return null;
    }));
    await t.pumpAndSettle();

    await _tap(t, find.byKey(const Key('flight-capacity-edit')));
    expect(find.text(tr('{kg} kg booked so far', {'kg': plainKg(booked)})),
        findsOneWidget);

    final below = (booked - 1).floor();
    await t.enterText(find.byKey(const Key('capacity-field')), '$below');
    await t.pumpAndSettle();
    expect(find.text(tr('{kg} kg over', {'kg': plainKg(booked - below)})),
        findsOneWidget);
    await _tap(t, find.byKey(const Key('capacity-save')));
    expect(
        find.text(tr(
            '{kg} kg is already booked on this flight. The capacity cannot be less than that.',
            {'kg': plainKg(booked)})),
        findsOneWidget);
    expect(calls, isEmpty);

    await t.enterText(find.byKey(const Key('capacity-field')), '50');
    await t.pumpAndSettle();
    expect(find.text(tr('{kg} kg free', {'kg': plainKg(50 - booked)})),
        findsOneWidget);
    await _tap(t, find.byKey(const Key('capacity-save')));
    expect(calls, ['PATCH /api/flights/$flowFlightCode']);
    expect(sent, {'spaceKg': 50});
    expect(find.text(tr('Capacity saved')), findsOneWidget);
  });
}
