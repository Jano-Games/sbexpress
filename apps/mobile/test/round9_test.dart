import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sbexpress/data/models/flight.dart';
import 'package:sbexpress/features/flights/flight_detail_screen.dart';
import 'package:sbexpress/features/flights/flight_edit_screen.dart';
import 'package:sbexpress/features/flights/flight_form_screen.dart';
import 'package:sbexpress/features/flights/itinerary_parts.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'package:sbexpress/widgets/quick_parts.dart' show plainKg;
import 'restructured_flow_test.dart' show app, phone;
import 'support/screen_fixtures.dart';

http.Response _ok(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

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

Map<String, Object?> _flyer(String name, String phone) => {
      'name': name,
      'firstName': name.split(' ').first,
      'lastName': name.split(' ').skip(1).join(' '),
      'cnPhone': '',
      'bdPhone': phone,
      'university': '',
      'batch': '',
      'program': '',
      'wechat': '',
      'docStudentId': true,
      'docVisa': true,
      'docAdmission': true,
      'documentCount': 0,
      'verifiedDocumentCount': 0,
      'archivedAt': null,
    };

final _flyers = [
  _flyer('Arif Rahman', '01800000000'),
  _flyer('Rakib Hasan', '01811000000'),
  _flyer('Sumon Ahmed', '01722000000'),
];

/// Scrolls up, then down, until [finder] is built and on screen.
Future<void> _reveal(WidgetTester t, Finder finder) async {
  for (final step in const [-200.0, 200.0]) {
    if (finder.evaluate().isNotEmpty) break;
    try {
      await t.scrollUntilVisible(finder, step,
          scrollable: find.byType(Scrollable).first, maxScrolls: 20);
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

Future<void> _type(WidgetTester t, Key key, String text) async {
  await _reveal(t, find.byKey(key));
  await t.enterText(find.byKey(key), text);
  await t.pumpAndSettle();
}

/// Today in the date picker, as the form saves it.
String _today() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

String _nextDay(String iso) {
  final day = DateTime.parse(iso).add(const Duration(days: 1));
  return '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}

Future<void> _pickToday(WidgetTester t) async {
  await _tap(t, find.byKey(const Key('flight-date')));
  await t.tap(find.text('OK'));
  await t.pumpAndSettle();
}

Future<void> _chooseFlyer(WidgetTester t, String name) async {
  await _tap(t, find.byKey(const Key('flight-flyers')));
  await t.tap(find.byKey(ValueKey('flyer-pick-$name')));
  await t.pumpAndSettle();
  await t.tap(find.byKey(const Key('flyer-picker-done')));
  await t.pumpAndSettle();
}

/// The schedule for MU5842 today and MU2035 the next morning.
Map<String, Object?> _found(String date) => {
      'configured': true,
      'found': true,
      'missing': <String>[],
      'depTime': '09:40',
      'arrTime': '11:25',
      'via': 'Via PVG Shanghai',
      'legs': [
        {
          'code': 'MU5842',
          'date': date,
          'found': true,
          'airline': 'China Eastern',
          'fromIata': 'PEK',
          'fromCity': 'Beijing',
          'toIata': 'PVG',
          'toCity': 'Shanghai',
          'depTime': '09:40',
          'arrTime': '11:55',
        },
        {
          'code': 'MU2035',
          'date': _nextDay(date),
          'found': true,
          'airline': 'China Eastern',
          'fromIata': 'PVG',
          'fromCity': 'Shanghai',
          'toIata': 'DAC',
          'toCity': 'Dhaka',
          'depTime': '08:10',
          'arrTime': '11:25',
        },
      ],
    };

/// The flight page's flight, with one ticket leg that matches its number.
Map<String, Object?> _flightBody({String? code}) {
  final body = round7FlightBody();
  final flight = Map<String, Object?>.from(body['flight']! as Map);
  flight['legs'] = [
    {
      'source': 'ticket',
      'code': 'BG305',
      'date': flight['date'],
      'fromIata': 'TFU',
      'fromCity': 'Chengdu',
      'toIata': 'DAC',
      'toCity': 'Dhaka',
      'depTime': '09:40',
      'arrTime': '12:10',
    }
  ];
  if (code != null) flight['code'] = code;
  return {...body, 'flight': flight};
}

void main() {
  group('flight numbers and legs', () {
    test('a connection splits into its flights', () {
      expect(flightNumbers('mu5842 + MU2035'), ['MU5842', 'MU2035']);
      expect(flightNumbers('MU5842, MU2035'), ['MU5842', 'MU2035']);
      expect(badFlightNumber(['MU5842', '12']), '12');
      expect(badFlightNumber(['BG305', '9W123']), isNull);
      expect(flightNumberOf('MU5842+MU2035-20261120-0f0f0f'), 'MU5842+MU2035');
      expect(flightNumberOf('BG305'), 'BG305');
    });

    test('hand-entered legs carry the times and the stop', () {
      final legs = buildLegs(
          numbers: ['MU5842', 'MU2035'],
          date: '2026-11-20',
          depTime: '09:40',
          arrTime: '17:25',
          stops: 'PVG Shanghai');
      expect([
        for (final leg in legs) leg.toJson()
      ], [
        {
          'source': 'manual',
          'code': 'MU5842',
          'date': '2026-11-20',
          'fromIata': '',
          'fromCity': '',
          'toIata': 'PVG',
          'toCity': 'Shanghai',
          'depTime': '09:40',
          'arrTime': '—',
        },
        {
          'source': 'manual',
          'code': 'MU2035',
          'date': '2026-11-20',
          'fromIata': 'PVG',
          'fromCity': 'Shanghai',
          'toIata': '',
          'toCity': '',
          'depTime': '—',
          'arrTime': '17:25',
        },
      ]);
    });

    test('the same flights keep their airports and move with the date', () {
      const base = [
        FlightLeg(
            source: 'ticket',
            code: 'MU5842',
            date: '2026-11-20',
            fromIata: 'PEK',
            toIata: 'PVG',
            depTime: '09:40',
            arrTime: '11:55'),
        FlightLeg(
            source: 'ticket',
            code: 'MU2035',
            date: '2026-11-21',
            fromIata: 'PVG',
            toIata: 'DAC',
            depTime: '08:10',
            arrTime: '11:25'),
      ];
      final legs = buildLegs(
          numbers: ['MU5842', 'MU2035'],
          date: '2026-11-27',
          depTime: '10:05',
          arrTime: '11:40',
          stops: '',
          base: base);
      expect([for (final leg in legs) leg.date], ['2026-11-27', '2026-11-28']);
      expect([for (final leg in legs) leg.source], ['ticket', 'ticket']);
      expect(legs.first.toIata, 'PVG');
      expect(legs.first.depTime, '10:05');
      expect(legs.first.arrTime, '11:55');
      expect(legs.last.arrTime, '11:40');
    });

    test('a time is typed as 4 digits', () {
      final format = ClockTimeFormatter();
      String typed(String text) => format
          .formatEditUpdate(
              TextEditingValue.empty, TextEditingValue(text: text))
          .text;
      expect(typed('0940'), '09:40');
      expect(typed('09:4'), '09:4');
      expect(typed('12345'), '12:34');
    });
  });

  group('new flight', () {
    testWidgets('needs both times, and keeps a connection with its stop',
        (t) async {
      phone(t);
      final posts = <Map<String, dynamic>>[];
      final lookups = <String>[];
      await t.pumpWidget(
          app(const _Host(FlightFormScreen()), intercept: (r) async {
        final path = r.url.path;
        if (path == '/api/flyers') return _ok({'flyers': _flyers});
        if (path == '/api/flights/lookup-route') {
          lookups.add(r.url.queryParameters['code']!);
          return _ok({
            'configured': false,
            'found': false,
            'legs': <Object>[],
            'missing': <String>[],
          });
        }
        if (path == '/api/flights' && r.method == 'POST') {
          posts.add(jsonDecode(r.body) as Map<String, dynamic>);
          return _ok({'code': 'MU5842+MU2035-20261120-ab12cd'}, 201);
        }
        return null;
      }));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();

      expect(
          find.text(tr(
              'e.g. BG305. A connection: join both with +, like MU5842+MU2035')),
          findsOneWidget);
      await t.enterText(
          find.byKey(const Key('flight-number')), 'mu5842+mu2035');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('flight-legs')), findsOneWidget);
      expect(find.byKey(const Key('flight-stop')), findsOneWidget);
      await _pickToday(t);
      expect(lookups, ['MU5842+MU2035']);
      expect(find.text(tr('Automatic times are not set up')), findsOneWidget);
      await _chooseFlyer(t, 'Arif Rahman');

      await _tap(t, find.byKey(const Key('flight-save')));
      expect(posts, isEmpty);
      expect(find.text(tr('Choose the departure time.')), findsOneWidget);
      await _type(t, const Key('flight-dep'), '0940');
      await _tap(t, find.byKey(const Key('flight-save')));
      expect(posts, isEmpty);
      expect(find.text(tr('Choose the landing time.')), findsOneWidget);

      await _type(t, const Key('flight-arr'), '1725');
      await _type(t, const Key('flight-stop'), 'PVG Shanghai');
      await _tap(t, find.byKey(const Key('flight-save')));
      expect(posts, hasLength(1));
      final body = posts.single;
      expect(body['code'], 'MU5842+MU2035');
      expect(body['date'], _today());
      expect(body['depTime'], '09:40');
      expect(body['arrTime'], '17:25');
      expect(body['flyerNames'], ['Arif Rahman']);
      final legs = (body['legs'] as List).cast<Map<String, dynamic>>();
      expect([for (final leg in legs) leg['code']], ['MU5842', 'MU2035']);
      expect(legs.first['toIata'], 'PVG');
      expect(legs.last['fromCity'], 'Shanghai');
      expect(find.byType(FlightFormScreen), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('fills the times from the airline schedule', (t) async {
      phone(t);
      final posts = <Map<String, dynamic>>[];
      await t.pumpWidget(
          app(const _Host(FlightFormScreen()), intercept: (r) async {
        final path = r.url.path;
        if (path == '/api/flyers') return _ok({'flyers': _flyers});
        if (path == '/api/flights/lookup-route') {
          return _ok(_found(r.url.queryParameters['date']!));
        }
        if (path == '/api/flights' && r.method == 'POST') {
          posts.add(jsonDecode(r.body) as Map<String, dynamic>);
          return _ok({'code': 'MU5842+MU2035-20261120-ab12cd'}, 201);
        }
        return null;
      }));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.enterText(
          find.byKey(const Key('flight-number')), 'MU5842+MU2035');
      await _pickToday(t);

      expect(find.text(tr('Found on the airline schedule')), findsOneWidget);
      expect(find.textContaining('MU5842 · PEK 09:40'), findsOneWidget);
      String text(String key) =>
          t.widget<TextField>(find.byKey(Key(key))).controller!.text;
      expect(text('flight-dep'), '09:40');
      expect(text('flight-arr'), '11:25');
      expect(text('flight-stop'), 'PVG Shanghai');

      // A typed time stays until the schedule's is asked for.
      await _type(t, const Key('flight-dep'), '1000');
      expect(find.byKey(const Key('schedule-use')), findsOneWidget);
      await _tap(t, find.byKey(const Key('schedule-use')));
      expect(text('flight-dep'), '09:40');

      await _chooseFlyer(t, 'Rakib Hasan');
      await _tap(t, find.byKey(const Key('flight-save')));
      final legs = (posts.single['legs'] as List).cast<Map<String, dynamic>>();
      expect([for (final leg in legs) leg['source']], ['schedule', 'schedule']);
      expect([for (final leg in legs) leg['date']],
          [_today(), _nextDay(_today())]);
      expect(legs.first['fromIata'], 'PEK');
      expect(legs.last['toIata'], 'DAC');
      expect(t.takeException(), isNull);
    });

    testWidgets('a busy schedule says so, and Look again finds the times',
        (t) async {
      phone(t);
      var lookups = 0;
      await t.pumpWidget(
          app(const _Host(FlightFormScreen()), intercept: (r) async {
        final path = r.url.path;
        if (path == '/api/flyers') return _ok({'flyers': _flyers});
        if (path == '/api/flights/lookup-route') {
          return ++lookups == 1
              ? _ok({
                  'error': 'The flight schedule service is busy. '
                      'Try again in a few seconds.'
                }, 503)
              : _ok(_found(r.url.queryParameters['date']!));
        }
        return null;
      }));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.enterText(
          find.byKey(const Key('flight-number')), 'MU5842+MU2035');
      await _pickToday(t);

      expect(find.text(tr('Could not look up the times')), findsOneWidget);
      expect(
          find.text(tr('The flight schedule is busy. '
              'Wait a few seconds, then tap Look again.')),
          findsOneWidget);
      await _tap(t, find.byKey(const Key('schedule-find')));
      expect(lookups, 2);
      expect(find.text(tr('Found on the airline schedule')), findsOneWidget);
      expect(
          t
              .widget<TextField>(find.byKey(const Key('flight-dep')))
              .controller!
              .text,
          '09:40');
      expect(t.takeException(), isNull);
    });

    testWidgets('flyers are chosen from a list with search', (t) async {
      phone(t);
      await t.pumpWidget(app(const FlightFormScreen(), intercept: (r) async {
        if (r.url.path == '/api/flyers') return _ok({'flyers': _flyers});
        return null;
      }));
      await t.pumpAndSettle();
      await _tap(t, find.byKey(const Key('flight-flyers')));
      expect(find.text(tr('Choose flyers')), findsOneWidget);
      await t.enterText(find.byKey(const Key('flyer-search')), '01722');
      await t.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('flyer-pick-Sumon Ahmed')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('flyer-pick-Arif Rahman')), findsNothing);
      await t.tap(find.byKey(const ValueKey('flyer-pick-Sumon Ahmed')));
      await t.pumpAndSettle();
      expect(find.text(trn(1, 'Done · {n} chosen', 'Done · {n} chosen')),
          findsOneWidget);
      await t.tap(find.byKey(const Key('flyer-picker-done')));
      await t.pumpAndSettle();
      final chip = find.byKey(const ValueKey('flight-flyer-Sumon Ahmed'));
      expect(chip, findsOneWidget);
      await t.tap(find.descendant(
          of: chip, matching: find.byIcon(Icons.close_rounded)));
      await t.pumpAndSettle();
      expect(chip, findsNothing);
      expect(t.takeException(), isNull);
    });
  });

  group('edit flight', () {
    testWidgets('a new number saves and the page follows the new reference',
        (t) async {
      phone(t);
      const renamed = 'BG306-20261021-ef56gh';
      Map<String, dynamic>? sent;
      final pages = <String>[];
      await t.pumpWidget(app(const FlightDetailScreen(code: flowFlightCode),
          intercept: (r) async {
        final path = Uri.decodeComponent(r.url.path);
        if (r.method == 'PATCH') {
          sent = jsonDecode(r.body) as Map<String, dynamic>;
          return _ok({'code': renamed});
        }
        if (path == '/api/flights/$flowFlightCode' ||
            path == '/api/flights/$renamed') {
          pages.add(path);
          return _ok(_flightBody(
              code: path.endsWith(renamed) ? renamed : flowFlightCode));
        }
        return null;
      }));
      await t.pumpAndSettle();
      await _tap(t, find.byKey(const Key('flight-edit')));
      expect(find.byType(FlightEditScreen), findsOneWidget);
      String text(String key) =>
          t.widget<TextField>(find.byKey(Key(key))).controller!.text;
      expect(text('flight-number'), 'BG305');
      expect(text('flight-dep'), '09:40');
      expect(text('flight-arr'), '12:10');

      await t.enterText(find.byKey(const Key('flight-number')), 'BG306');
      await _tap(t, find.byKey(const Key('flight-edit-save')));
      expect(sent!['legs'], [
        {
          'source': 'manual',
          'code': 'BG306',
          'date': sent!['date'],
          'fromIata': '',
          'fromCity': '',
          'toIata': '',
          'toCity': '',
          'depTime': '09:40',
          'arrTime': '12:10',
        }
      ]);
      expect(find.byType(FlightEditScreen), findsNothing);
      expect(find.text(tr('Flight saved')), findsOneWidget);
      expect(pages.last, '/api/flights/$renamed');
      expect(find.text('BG306'), findsWidgets);
      expect(t.takeException(), isNull);
    });

    testWidgets(
        'the same number keeps the ticket legs; space stays above booked',
        (t) async {
      phone(t);
      Map<String, dynamic>? sent;
      final body = _flightBody();
      final booked =
          FlightSummary.fromJson(body['flight']! as Map<String, Object?>)
              .bookedKg;
      await t.pumpWidget(app(const FlightDetailScreen(code: flowFlightCode),
          intercept: (r) async {
        if (r.method == 'PATCH') {
          sent = jsonDecode(r.body) as Map<String, dynamic>;
          return _ok({'code': flowFlightCode});
        }
        if (Uri.decodeComponent(r.url.path) == '/api/flights/$flowFlightCode') {
          return _ok(body);
        }
        return null;
      }));
      await t.pumpAndSettle();
      await _tap(t, find.byKey(const Key('flight-edit')));

      await _type(t, const Key('flight-edit-space'), '${(booked - 1).floor()}');
      await _tap(t, find.byKey(const Key('flight-edit-save')));
      expect(sent, isNull);
      expect(
          find.textContaining(tr(
              '{kg} kg is already booked on this flight. The capacity cannot be less than that.',
              {'kg': plainKg(booked)})),
          findsOneWidget);

      await _type(t, const Key('flight-edit-space'), '52');
      await _type(t, const Key('flight-arr'), '1235');
      await _tap(t, find.byKey(const Key('flight-edit-save')));
      final legs = (sent!['legs'] as List).cast<Map<String, dynamic>>();
      expect(legs.single['source'], 'ticket');
      expect(legs.single['fromIata'], 'TFU');
      expect(legs.single['arrTime'], '12:35');
      expect(sent!['spaceKg'], 52);
      expect(t.takeException(), isNull);
    });
  });

  test('the edit form reads the numbers in a reference', () {
    expect(flightNumberOf(flowFlightCode), 'BG305');
    expect(isClock('09:40'), isTrue);
    expect(isClock('9:40'), isFalse);
  });
}
