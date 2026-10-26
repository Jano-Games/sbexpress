import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sbexpress/app_scope.dart';
import 'package:sbexpress/data/models/ticket_import.dart';
import 'package:sbexpress/features/admin/admin_home_screen.dart';
import 'package:sbexpress/features/admin/money_format.dart';
import 'package:sbexpress/features/flights/flight_form_screen.dart';
import 'package:sbexpress/features/flights/ticket_flyers_screen.dart';
import 'package:sbexpress/features/flights/ticket_import_screen.dart';
import 'package:sbexpress/features/flyers/flyer_detail_screen.dart';
import 'package:sbexpress/features/flyers/flyer_form_screen.dart';
import 'package:sbexpress/features/flyers/flyers_screen.dart';
import 'package:sbexpress/features/intake/intake_screen.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'package:sbexpress/widgets/quick_parts.dart' show wholeBdt;
import 'restructured_flow_test.dart' show app, field, phone;
import 'support/screen_fixtures.dart';

http.Response _ok(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
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

Future<void> _reveal(WidgetTester t, Finder finder, {double dy = 200}) async {
  await t.scrollUntilVisible(finder, dy,
      scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
}

Future<void> _type(WidgetTester t, Key key, String value) async {
  await _reveal(t, find.byKey(key));
  await t.enterText(find.byKey(key), value);
  await t.pumpAndSettle();
}

/// Opens the account dropdown with [key] and picks [account].
Future<void> _chooseAccount(WidgetTester t, Key key, String account) async {
  await _reveal(t, find.byKey(key));
  await t.tap(find.byKey(key));
  await t.pumpAndSettle();
  await t.tap(find.text('$account · BDT').last);
  await t.pumpAndSettle();
}

Map<String, Object?> _flyer(String name) => {
      'name': name,
      'firstName': name.split(' ').first,
      'lastName': name.split(' ').skip(1).join(' '),
      'cnPhone': '',
      'bdPhone': '01800000000',
      'university': '',
      'batch': '',
      'program': '',
      'wechat': '',
      'docStudentId': true,
      'docVisa': true,
      'docAdmission': true,
      'documentCount': 3,
      'verifiedDocumentCount': 3,
      'archivedAt': null,
    };

/// The flow flight with [changes] on top.
Map<String, Object?> _flight(Map<String, Object?> changes) {
  final body = flowFlightDetailBody();
  return {
    'flight': {...(body['flight'] as Map<String, Object?>), ...changes}
  };
}

void main() {
  group('flyers paying their part', () {
    testWidgets(
        'paid-now amounts are recorded after the ticket and split are saved',
        (t) async {
      phone(t);
      final calls = <String>[];
      final bodies = <Object?>[];
      final flight = _flight({
        'flyerPaidAmount': 11000,
        'flyerDue': 19000,
        'settlements': [
          {'name': 'Arif Rahman', 'contribution': 15000, 'paidAmount': 5000},
          {'name': 'Rakib Hasan', 'contribution': 15000, 'paidAmount': 6000},
        ],
      });
      await t.pumpWidget(
          app(const _Host(TicketFlyersScreen(code: flowFlightCode)),
              intercept: (r) async {
        if (r.method == 'GET' && r.url.path == '/api/flights/$flowFlightCode') {
          return _ok(flight);
        }
        if (r.method == 'PATCH' || r.method == 'POST') {
          calls.add('${r.method} ${r.url.path}');
          bodies.add(jsonDecode(r.body));
          return _ok({'ok': true});
        }
        return null;
      }));
      await _open(t);
      // What is already recorded is said, so it is not entered twice.
      expect(
          find.text(
              tr('{amount} already recorded', {'amount': wholeBdt(6000)})),
          findsOneWidget);
      expect(find.text(tr('Paid now, in addition')), findsNWidgets(2));
      expect(find.byKey(const Key('ticket-received-in')), findsNothing);
      await _type(t, const ValueKey('paid-Arif Rahman'), '5000');
      await _type(t, const ValueKey('paid-Rakib Hasan'), '4000');
      await _chooseAccount(t, const Key('ticket-received-in'), 'Dhaka cash');
      await t.tap(find.byKey(const Key('ticket-save')));
      await t.pumpAndSettle();
      // Nothing moves before the money is confirmed.
      expect(calls, isEmpty);
      expect(
          find.textContaining(tr('{amount} from {flyer} goes into {account}.', {
            'amount': wholeBdt(4000),
            'flyer': 'Rakib Hasan',
            'account': 'Dhaka cash'
          })),
          findsOneWidget);
      await t.tap(find.text(tr('Confirm')));
      await t.pumpAndSettle();
      expect(calls, [
        'PATCH /api/flights/$flowFlightCode',
        'POST /api/flights/$flowFlightCode/settlements',
        'POST /api/flights/$flowFlightCode/payments',
        'POST /api/flights/$flowFlightCode/payments',
      ]);
      expect(bodies[2], {
        'amount': 5000.0,
        'method': 'Dhaka cash',
        'flyerName': 'Arif Rahman'
      });
      expect(bodies[3], {
        'amount': 4000.0,
        'method': 'Dhaka cash',
        'flyerName': 'Rakib Hasan'
      });
      expect(find.byType(TicketFlyersScreen), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('more than the part left is refused before anything is sent',
        (t) async {
      phone(t);
      final calls = <String>[];
      await t.pumpWidget(
          app(const _Host(TicketFlyersScreen(code: flowFlightCode)),
              intercept: (r) async {
        if (r.method != 'GET') calls.add('${r.method} ${r.url.path}');
        return null;
      }));
      await _open(t);
      // Arif has paid his whole part, so there is nothing to enter for him.
      expect(find.byKey(const ValueKey('paid-Arif Rahman')), findsNothing);
      // Rakib's part is 15,000 and 6,000 of it is recorded.
      await _type(t, const ValueKey('paid-Rakib Hasan'), '9500');
      await _chooseAccount(t, const Key('ticket-received-in'), 'Dhaka cash');
      await t.tap(find.byKey(const Key('ticket-save')));
      await t.pumpAndSettle();
      expect(calls, isEmpty);
      expect(
          find.text(tr('{name} can pay at most {amount} now.',
              {'name': 'Rakib Hasan', 'amount': formatBdt(9000)})),
          findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('a failed payment leaves the ticket saved and says so',
        (t) async {
      phone(t);
      final calls = <String>[];
      await t.pumpWidget(
          app(const _Host(TicketFlyersScreen(code: flowFlightCode)),
              intercept: (r) async {
        if (r.method == 'GET') return null;
        calls.add('${r.method} ${r.url.path}');
        if (r.url.path.endsWith('/payments')) {
          return _ok({'error': 'Amount exceeds flyer balance'}, 400);
        }
        return _ok({'ok': true});
      }));
      await _open(t);
      await _type(t, const ValueKey('paid-Rakib Hasan'), '3000');
      await _chooseAccount(t, const Key('ticket-received-in'), 'Dhaka cash');
      await t.tap(find.byKey(const Key('ticket-save')));
      await t.pumpAndSettle();
      await t.tap(find.text(tr('Confirm')));
      await t.pumpAndSettle();
      expect(calls.last, 'POST /api/flights/$flowFlightCode/payments');
      // Still on the screen, with the ticket saved and the payment named.
      expect(find.byType(TicketFlyersScreen), findsOneWidget);
      expect(
          find.textContaining(tr(
              'The ticket is saved, but these payments were not recorded: {list}. Record them from Payments so far.',
              {'list': 'Rakib Hasan ${wholeBdt(3000)}'})),
          findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('a new flight records what the flyers already paid', (t) async {
      phone(t);
      const created = 'BG305-20261101-ab12cd';
      final calls = <String>[];
      final bodies = <Object?>[];
      await t.pumpWidget(
          app(const _Host(FlightFormScreen()), intercept: (r) async {
        if (r.url.path == '/api/flyers') {
          return _ok({
            'flyers': [_flyer('Arif Rahman'), _flyer('Rakib Hasan')]
          });
        }
        if (r.method == 'POST') {
          calls.add(r.url.path);
          bodies.add(jsonDecode(r.body));
          return _ok({'ok': true, 'code': created}, 201);
        }
        return null;
      }));
      await _open(t);
      await t.enterText(field(tr('Airline flight number')), 'bg305');
      await t.tap(find.text(tr('Choose date')));
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      await t.tap(find.text('Arif Rahman'));
      await t.tap(find.text('Rakib Hasan'));
      await t.pumpAndSettle();
      await _reveal(t, field(tr('Actual ticket cost (BDT)')));
      await t.enterText(field(tr('Actual ticket cost (BDT)')), '42000');
      await t.pumpAndSettle();
      await _reveal(t, find.byKey(const Key('flight-flyers-pay')));
      await t.tap(find.byKey(const Key('flight-flyers-pay')));
      await t.pumpAndSettle();
      expect(find.text(tr('Already paid')), findsNWidgets(2));
      await _type(t, const ValueKey('flight-part-Arif Rahman'), '15000');
      await _type(t, const ValueKey('flight-part-Rakib Hasan'), '15000');
      // More than the part is refused first.
      await _type(t, const ValueKey('flight-paid-Arif Rahman'), '16000');
      await _chooseAccount(t, const Key('flight-received-in'), 'Dhaka cash');
      await t.tap(find.byKey(const Key('flight-save')));
      await t.pumpAndSettle();
      expect(calls, isEmpty);
      expect(
          find.text(tr('{name} can pay at most {amount} now.',
              {'name': 'Arif Rahman', 'amount': formatBdt(15000)})),
          findsOneWidget);
      await _type(t, const ValueKey('flight-paid-Arif Rahman'), '5000');
      await t.tap(find.byKey(const Key('flight-save')));
      await t.pumpAndSettle();
      expect(
          find.textContaining(tr('{amount} from {flyer} goes into {account}.', {
            'amount': wholeBdt(5000),
            'flyer': 'Arif Rahman',
            'account': 'Dhaka cash'
          })),
          findsOneWidget);
      await t.tap(find.text(tr('Confirm')));
      await t.pumpAndSettle();
      expect(calls, [
        '/api/flights',
        '/api/flights/$created/settlements',
        '/api/flights/$created/payments',
      ]);
      expect((bodies[0] as Map)['flyerNames'], ['Arif Rahman', 'Rakib Hasan']);
      expect((bodies[0] as Map)['agencyShare'], 12000);
      expect(bodies[2], {
        'amount': 5000.0,
        'method': 'Dhaka cash',
        'flyerName': 'Arif Rahman'
      });
      expect(find.byType(FlightFormScreen), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('payments say what to enter until there is a split', (t) async {
      phone(t);
      final flight = _flight({
        'actualCost': 0,
        'agencyShare': 0,
        'flyerPaidAmount': 0,
        'flyerDue': 0,
        'ticketPaid': 0,
        'ticketDue': 0,
        'settlements': [
          {'name': 'Arif Rahman', 'contribution': 0, 'paidAmount': 0},
          {'name': 'Rakib Hasan', 'contribution': 0, 'paidAmount': 0},
        ],
      });
      await t.pumpWidget(app(const TicketFlyersScreen(code: flowFlightCode),
          intercept: (r) async => r.url.path == '/api/flights/$flowFlightCode'
              ? _ok(flight)
              : null));
      await t.pumpAndSettle();
      final wePay = find.text(tr('We pay the whole ticket, so no flyer pays.'));
      final enterFirst =
          find.text(tr("Enter the ticket cost and each flyer's part first."));
      await _reveal(t, wePay);
      expect(enterFirst, findsNothing);
      await _reveal(t, find.byKey(const Key('ticket-flyers-pay')), dy: -200);
      await t.tap(find.byKey(const Key('ticket-flyers-pay')));
      await t.pumpAndSettle();
      expect(wePay, findsNothing);
      await _reveal(t, enterFirst);
      expect(enterFirst, findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('adding a flyer where one is needed', () {
    test('ticket names lose the airline title and are title-cased', () {
      expect(passengerName('SHAHRIAR / MD RIFAT SD'), (
        passenger: 'SHAHRIAR / MD RIFAT',
        firstName: 'Md Rifat',
        lastName: 'Shahriar'
      ));
      expect(passengerName('BEGUM / MST NASRIN  MRS'), (
        passenger: 'BEGUM / MST NASRIN',
        firstName: 'Mst Nasrin',
        lastName: 'Begum'
      ));
      expect(passengerName("O'NEIL / MARY-JANE CHD INF"), (
        passenger: "O'NEIL / MARY-JANE",
        firstName: "Mary-Jane",
        lastName: "O'Neil"
      ));
      // A lone given name stays even when it looks like a title.
      expect(passengerName('KHAN / DR').passenger, 'KHAN / DR');
      expect(passengerName('KHAN'),
          (passenger: 'KHAN', firstName: null, lastName: 'Khan'));
      expect(passengerName(null),
          (passenger: null, firstName: null, lastName: null));

      Map<String, Object?> ticket(Map<String, Object?> names) => {
            'ticket': {
              'agency': null,
              'pnr': null,
              'ticketNumber': null,
              'issuedOn': null,
              ...names,
            },
            'flyerMatches': [],
            'journeys': [],
          };
      // An older server sends the name as printed.
      final old = TicketImport.fromJson(
          ticket({'passenger': 'SHAHRIAR / MD RIFAT SD'}));
      expect(old.passenger, 'SHAHRIAR / MD RIFAT');
      expect([old.firstName, old.lastName], ['Md Rifat', 'Shahriar']);
      // A newer one splits the name itself.
      final fresh = TicketImport.fromJson(ticket({
        'passenger': 'SHAHRIAR / MD RIFAT',
        'firstName': 'Md. Rifat',
        'lastName': 'Shahriar'
      }));
      expect([fresh.firstName, fresh.lastName], ['Md. Rifat', 'Shahriar']);
    });

    testWidgets(
        'an unmatched passenger is added as a flyer and chosen for the ticket',
        (t) async {
      phone(t);
      var flyers = <Map<String, Object?>>[];
      Map<String, Object?>? newFlyer;
      final flights = <Map<String, Object?>>[];
      final body = ticketImportBody();
      body['ticket'] = {
        ...(body['ticket'] as Map<String, Object?>),
        'passenger': 'SHAHRIAR / MD RIFAT SD',
      };
      body['flyerMatches'] = <Object>[];
      body['journeys'] = [(body['journeys'] as List).first];
      await t.pumpWidget(app(
          _Host(TicketImportScreen(
              pickPdf: () async => utf8.encode('%PDF-1.4 test'))),
          intercept: (r) async {
        final path = r.url.path;
        if (path == '/api/flights/ticket') return _ok(body);
        if (path == '/api/flyers' && r.method == 'GET') {
          return _ok({'flyers': flyers});
        }
        if (path == '/api/flyers' && r.method == 'POST') {
          newFlyer = jsonDecode(r.body) as Map<String, Object?>;
          flyers = [_flyer('Md Rifat Shahriar')];
          return _ok({'name': 'Md Rifat Shahriar'}, 201);
        }
        if (path == '/api/flights' && r.method == 'POST') {
          flights.add(jsonDecode(r.body) as Map<String, Object?>);
          return _ok({'code': 'MU5842+MU2035-x'}, 201);
        }
        return null;
      }));
      await _open(t);
      await t.tap(find.byKey(const Key('ticket-pick')));
      await t.pumpAndSettle();
      expect(find.text('SHAHRIAR / MD RIFAT'), findsOneWidget);
      final add =
          find.text(tr('Add {name} as a flyer', {'name': 'Md Rifat Shahriar'}));
      await _reveal(t, add);
      await t.tap(add);
      await t.pumpAndSettle();
      // The form opens with the names from the ticket.
      expect(find.byType(FlyerFormScreen), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Md Rifat'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Shahriar'), findsOneWidget);
      await t.tap(find.byKey(const Key('flyer-save')));
      await t.pumpAndSettle();
      expect(newFlyer, {'firstName': 'Md Rifat', 'lastName': 'Shahriar'});
      // Back on the ticket with the new flyer chosen.
      expect(find.byType(FlyerFormScreen), findsNothing);
      expect(find.byType(FlyerDetailScreen), findsNothing);
      expect(find.byKey(const Key('ticket-add-flyer')), findsNothing);
      expect(
          t
              .widget<DropdownButtonFormField<String>>(
                  find.byType(DropdownButtonFormField<String>))
              .initialValue,
          'Md Rifat Shahriar');
      await t.tap(find.byKey(const Key('ticket-save')));
      await t.pumpAndSettle();
      expect(flights.single['flyerNames'], ['Md Rifat Shahriar']);
      expect(find.byType(TicketImportScreen), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('a new flight with no flyers adds one and picks it', (t) async {
      phone(t);
      var flyers = <Map<String, Object?>>[];
      await t.pumpWidget(
          app(const _Host(FlightFormScreen()), intercept: (r) async {
        if (r.url.path != '/api/flyers') return null;
        if (r.method == 'POST') {
          flyers = [_flyer('Sumi Akter')];
          return _ok({'name': 'Sumi Akter'}, 201);
        }
        return _ok({'flyers': flyers});
      }));
      await _open(t);
      expect(find.text(tr('Create a flyer profile first.')), findsOneWidget);
      await _reveal(t, find.byKey(const Key('flight-add-flyer')));
      await t.tap(find.byKey(const Key('flight-add-flyer')));
      await t.pumpAndSettle();
      await t.enterText(
          find
              .descendant(
                  of: find.byType(FlyerFormScreen),
                  matching: find.byType(TextField))
              .first,
          'Sumi');
      await t.tap(find.byKey(const Key('flyer-save')));
      await t.pumpAndSettle();
      expect(find.byType(FlightFormScreen), findsOneWidget);
      expect(find.text(tr('Create a flyer profile first.')), findsNothing);
      expect(
          t
              .widget<CheckboxListTile>(
                  find.widgetWithText(CheckboxListTile, 'Sumi Akter'))
              .value,
          isTrue);
      expect(t.takeException(), isNull);
    });
  });

  group('needs attention', () {
    testWidgets('lists flyers missing documents, then how many more',
        (t) async {
      phone(t);
      await t.pumpWidget(app(Builder(
          builder: (context) =>
              AdminHomeScreen(dashboard: AppScope.of(context).dashboard))));
      await t.pumpAndSettle();
      final rifat =
          find.byKey(const ValueKey('attention-docs-Md Rifat Shahriar'));
      await _reveal(t, rifat);
      expect(
          find.text(tr('{name} is missing {documents}', {
            'name': 'Md Rifat Shahriar',
            'documents': tr('{list} and {last}',
                {'list': tr('visa'), 'last': tr('admission letter')})
          })),
          findsOneWidget);
      expect(
          find.text(tr('{name} is missing {documents}', {
            'name': 'Tanvir Ahmed',
            'documents': tr('{list} and {last}', {
              'list': '${tr('student ID')}, ${tr('visa')}',
              'last': tr('admission letter')
            })
          })),
          findsOneWidget);
      // Three are listed; the fourth and fifth are counted.
      expect(find.byKey(const ValueKey('attention-docs-Farhan Kabir')),
          findsNothing);
      expect(
          find.text(trn(2, '{n} more flyer is missing documents',
              '{n} more flyers are missing documents')),
          findsOneWidget);
      await t.tap(rifat);
      await t.pumpAndSettle();
      expect(t.widget<FlyerDetailScreen>(find.byType(FlyerDetailScreen)).name,
          'Md Rifat Shahriar');
      t.state<NavigatorState>(find.byType(Navigator).first).pop();
      await t.pumpAndSettle();
      await _reveal(t, find.byKey(const Key('attention-docs-more')));
      await t.tap(find.byKey(const Key('attention-docs-more')));
      await t.pumpAndSettle();
      expect(find.byType(FlyersScreen), findsOneWidget);
    });

    testWidgets('an older server without the fields shows no flyer rows',
        (t) async {
      phone(t);
      final old = overviewBody()
        ..remove('flyersMissingDocs')
        ..remove('flyersMissingDocsCount');
      await t.pumpWidget(app(
          Builder(
              builder: (context) =>
                  AdminHomeScreen(dashboard: AppScope.of(context).dashboard)),
          intercept: (r) async =>
              r.url.path == '/api/dashboard/overview' ? _ok(old) : null));
      await t.pumpAndSettle();
      await _reveal(t, find.byKey(const Key('home-next-flight')));
      expect(find.byKey(const ValueKey('attention-docs-Md Rifat Shahriar')),
          findsNothing);
      expect(find.byKey(const Key('attention-docs-more')), findsNothing);
      expect(t.takeException(), isNull);
    });
  });

  group('booking: what is inside', () {
    testWidgets('the new category input stays hidden until + New is tapped',
        (t) async {
      phone(t);
      final added = <Object?>[];
      await t.pumpWidget(app(const IntakeScreen(), intercept: (r) async {
        if (r.method == 'POST' && r.url.path == '/api/categories') {
          added.add(jsonDecode(r.body));
          return _ok({'ok': true}, 201);
        }
        return null;
      }));
      await t.pumpAndSettle();
      final newChip = find.byKey(const Key('intake-new-category'));
      final input = find.byKey(const Key('intake-category-name'));
      await _reveal(t, newChip);
      expect(input, findsNothing);
      expect(find.byKey(const Key('intake-category-add')), findsNothing);
      await t.tap(newChip);
      await t.pumpAndSettle();
      expect(input, findsOneWidget);
      expect(newChip, findsNothing);
      expect(
          t
              .widget<EditableText>(find.descendant(
                  of: input, matching: find.byType(EditableText)))
              .focusNode
              .hasFocus,
          isTrue);
      await t.tap(find.byKey(const Key('intake-category-cancel')));
      await t.pumpAndSettle();
      expect(input, findsNothing);
      expect(newChip, findsOneWidget);
      // Adding one hides the input again and picks the new chip.
      await t.tap(newChip);
      await t.pumpAndSettle();
      await t.enterText(input, 'Shoes');
      await t.tap(find.byKey(const Key('intake-category-add')));
      await t.pumpAndSettle();
      expect(added, [
        {'name': 'Shoes'}
      ]);
      expect(input, findsNothing);
      expect(newChip, findsOneWidget);
      expect(find.text('Shoes'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('lowercase device categories open their device blocks',
        (t) async {
      phone(t);
      await t.pumpWidget(app(const IntakeScreen(),
          intercept: (r) async => r.url.path == '/api/categories'
              ? _ok({
                  'categories': ['mobile', 'laptop', 'mixed']
                })
              : null));
      await t.pumpAndSettle();
      // Shown as the server sends them.
      await _reveal(t, find.text('mobile'));
      await t.tap(find.text('mobile'));
      await t.pumpAndSettle();
      await _reveal(t, find.byKey(const ValueKey('intake-device-mobile')));
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('intake-device-mobile')),
              matching: find.byIcon(Icons.smartphone_rounded)),
          findsOneWidget);
      // The "Mobile" piece rate applies to "mobile".
      expect(
          t
              .widget<TextField>(find.byKey(const ValueKey('mobile-rate')))
              .controller!
              .text,
          '2000');
      await _reveal(t, find.text('laptop'), dy: -200);
      await t.tap(find.text('laptop'));
      await t.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('intake-device-laptop')), findsOneWidget);
      expect(
          t
              .widget<TextField>(find.byKey(const ValueKey('laptop-rate')))
              .controller!
              .text,
          '3500');
      await _reveal(t, find.text('mixed'), dy: -200);
      await t.tap(find.text('mixed'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('intake-device-mixed')), findsNothing);
      expect(t.takeException(), isNull);
    });
  });
}
