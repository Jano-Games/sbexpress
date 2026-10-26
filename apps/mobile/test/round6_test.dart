import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sbexpress/app_scope.dart';
import 'package:sbexpress/features/admin/admin_home_screen.dart';
import 'package:sbexpress/features/admin/admin_shipment_screen.dart';
import 'package:sbexpress/features/customers/customers_screen.dart';
import 'package:sbexpress/features/flights/flight_detail_screen.dart';
import 'package:sbexpress/features/flights/flight_form_screen.dart';
import 'package:sbexpress/features/flyers/flyer_detail_screen.dart';
import 'package:sbexpress/features/flyers/flyers_screen.dart';
import 'package:sbexpress/features/intake/intake_screen.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'restructured_flow_test.dart' show app, phone;
import 'support/screen_fixtures.dart';
import 'support/team_fixtures.dart';

http.Response _ok(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

/// A first screen that opens [screen], so a delete can pop back to it.
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

/// Scrolls to [key] at the end of the page and taps it.
Future<void> _tapEnd(WidgetTester t, Key key) async {
  await t.scrollUntilVisible(find.byKey(key), 300,
      scrollable: find.byType(Scrollable).first);
  await t.pumpAndSettle();
  await t.tap(find.byKey(key));
  await t.pumpAndSettle();
}

/// `METHOD path` of each request that changes something.
String _call(http.Request r) =>
    '${r.method} ${Uri.decodeComponent(r.url.path)}';

const _flightCode = 'BG305-20261021-ab12cd';

Map<String, Object?> _customer(String code, String name,
        {String? archivedAt, bool older = false}) =>
    {
      'code': code,
      'name': name,
      'phone': '01700000000',
      'address': '',
      'terms': 'instant',
      'orderCount': 1,
      'deliveredCount': 0,
      'shippedKg': 4,
      'billed': 0,
      'paid': 0,
      'balance': 0,
      'creditBalance': 0,
      'pricingPending': 0,
      'discountTotal': 0,
      if (!older) 'archivedAt': archivedAt,
    };

Map<String, Object?> _flyerRow(String name, {String? archivedAt}) => {
      ...teamFlyers().first,
      'name': name,
      'firstName': name.split(' ').first,
      'lastName': name.split(' ').last,
      'archivedAt': archivedAt,
    };

void main() {
  group('delete', () {
    testWidgets('a flight is deleted only after the confirm and pops back',
        (t) async {
      phone(t);
      final calls = <String>[];
      await t.pumpWidget(app(const _Host(FlightDetailScreen(code: _flightCode)),
          intercept: (r) async {
        if (r.method == 'GET') return null;
        calls.add(_call(r));
        return _ok({'ok': true});
      }));
      await _open(t);
      await _tapEnd(t, const Key('flight-delete'));
      expect(
          find.text(tr('Delete flight {code}? This cannot be undone.',
              {'code': 'BG305'})),
          findsOneWidget);
      // Going back keeps the flight.
      await t.tap(find.text(tr('Go back')));
      await t.pumpAndSettle();
      expect(calls, isEmpty);
      await t.tap(find.byKey(const Key('flight-delete')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('remove-confirm')));
      await t.pumpAndSettle();
      expect(calls, ['DELETE /api/flights/$_flightCode']);
      expect(find.byType(FlightDetailScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('a shipment is deleted after the confirm and pops back',
        (t) async {
      phone(t);
      final calls = <String>[];
      await t.pumpWidget(app(const _Host(AdminShipmentScreen(code: 'SH-18')),
          intercept: (r) async {
        if (r.method == 'GET') return null;
        calls.add(_call(r));
        return _ok({'ok': true});
      }));
      await _open(t);
      await _tapEnd(t, const Key('shipment-delete'));
      expect(
          find.text(tr('Delete shipment {code}? This cannot be undone.',
              {'code': 'SH-18'})),
          findsOneWidget);
      expect(calls, isEmpty);
      await t.tap(find.byKey(const Key('remove-confirm')));
      await t.pumpAndSettle();
      expect(calls, ['DELETE /api/shipments/SH-18']);
      expect(find.byType(AdminShipmentScreen), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('a flyer is deleted after the confirm and pops back',
        (t) async {
      phone(t);
      final calls = <String>[];
      await t.pumpWidget(
          app(const _Host(FlyerDetailScreen(name: 'Arif Rahman')),
              intercept: (r) async {
        if (r.method == 'GET') return teamFixtures(r);
        calls.add(_call(r));
        return _ok({'ok': true});
      }));
      await _open(t);
      await _tapEnd(t, const Key('profile-delete'));
      expect(
          find.text(tr('Delete flyer {name}? This cannot be undone.',
              {'name': 'Arif Rahman'})),
          findsOneWidget);
      await t.tap(find.byKey(const Key('remove-confirm')));
      await t.pumpAndSettle();
      expect(calls, ['DELETE /api/flyers/Arif Rahman']);
      expect(find.byType(FlyerDetailScreen), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('a customer is deleted after the confirm and pops back',
        (t) async {
      phone(t);
      final calls = <String>[];
      await t.pumpWidget(app(const _Host(CustomerDetailScreen(code: 'C-14')),
          intercept: (r) async {
        if (r.method == 'GET') return null;
        calls.add(_call(r));
        return _ok({'ok': true});
      }));
      await _open(t);
      await _tapEnd(t, const Key('profile-delete'));
      expect(
          find.text(tr('Delete customer {name}? This cannot be undone.',
              {'name': 'Nila Store'})),
          findsOneWidget);
      await t.tap(find.byKey(const Key('remove-confirm')));
      await t.pumpAndSettle();
      expect(calls, ['DELETE /api/suppliers/C-14']);
      expect(find.byType(CustomerDetailScreen), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('Home reloads after a flight is deleted on top of it',
        (t) async {
      phone(t);
      var overviews = 0;
      await t.pumpWidget(app(
          Builder(
              builder: (context) =>
                  AdminHomeScreen(dashboard: AppScope.of(context).dashboard)),
          intercept: (r) async {
        if (r.url.path == '/api/dashboard/overview') overviews++;
        if (r.method == 'DELETE') return _ok({'ok': true});
        return null;
      }));
      await t.pumpAndSettle();
      final before = overviews;
      t.state<NavigatorState>(find.byType(Navigator)).push(
          MaterialPageRoute<void>(
              builder: (_) => const FlightDetailScreen(code: _flightCode)));
      await t.pumpAndSettle();
      await _tapEnd(t, const Key('flight-delete'));
      await t.tap(find.byKey(const Key('remove-confirm')));
      await t.pumpAndSettle();
      expect(find.byType(AdminHomeScreen), findsOneWidget);
      expect(overviews, greaterThan(before));
      expect(t.takeException(), isNull);
    });
  });

  group('a refused delete', () {
    testWidgets('shows the server reason for a flight, with no archive',
        (t) async {
      phone(t);
      const reason =
          '$_flightCode has 2 booking(s) — move or delete them first';
      await t.pumpWidget(app(const _Host(FlightDetailScreen(code: _flightCode)),
          intercept: (r) async {
        if (r.method == 'DELETE') return _ok({'error': reason}, 400);
        return null;
      }));
      await _open(t);
      await _tapEnd(t, const Key('flight-delete'));
      await t.tap(find.byKey(const Key('remove-confirm')));
      await t.pumpAndSettle();
      expect(find.text(tr('This flight cannot be deleted')), findsOneWidget);
      expect(find.text(reason), findsOneWidget);
      expect(find.byKey(const Key('remove-archive-instead')), findsNothing);
      await t.tap(find.text(tr('Close')));
      await t.pumpAndSettle();
      expect(find.byType(FlightDetailScreen), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('offers to archive a flyer instead', (t) async {
      phone(t);
      const reason =
          'This flyer has shipment or settlement history. Archive the profile instead.';
      final sent = <({String call, Object? body})>[];
      await t.pumpWidget(
          app(const _Host(FlyerDetailScreen(name: 'Arif Rahman')),
              intercept: (r) async {
        if (r.method == 'GET') return teamFixtures(r);
        sent.add(
            (call: _call(r), body: r.body.isEmpty ? null : jsonDecode(r.body)));
        if (r.method == 'DELETE') return _ok({'error': reason}, 400);
        return _ok({'ok': true});
      }));
      await _open(t);
      await _tapEnd(t, const Key('profile-delete'));
      await t.tap(find.byKey(const Key('remove-confirm')));
      await t.pumpAndSettle();
      expect(find.text(tr('This flyer cannot be deleted')), findsOneWidget);
      expect(find.text(reason), findsOneWidget);
      await t.tap(find.byKey(const Key('remove-archive-instead')));
      await t.pumpAndSettle();
      expect(sent.map((s) => s.call), [
        'DELETE /api/flyers/Arif Rahman',
        'POST /api/flyers/Arif Rahman/archive',
      ]);
      expect(sent.last.body, {'archived': true});
      // The profile stays open; it was archived, not deleted.
      expect(find.byType(FlyerDetailScreen), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('offers to archive a customer instead', (t) async {
      phone(t);
      const reason = 'C-14 has 1 shipment(s) — delete or reassign them first';
      final sent = <({String call, Object? body})>[];
      await t.pumpWidget(app(const _Host(CustomerDetailScreen(code: 'C-14')),
          intercept: (r) async {
        if (r.method == 'GET') return null;
        sent.add(
            (call: _call(r), body: r.body.isEmpty ? null : jsonDecode(r.body)));
        if (r.method == 'DELETE') return _ok({'error': reason}, 400);
        return _ok({'ok': true, 'archived': true});
      }));
      await _open(t);
      await _tapEnd(t, const Key('profile-delete'));
      await t.tap(find.byKey(const Key('remove-confirm')));
      await t.pumpAndSettle();
      expect(find.text(tr('This customer cannot be deleted')), findsOneWidget);
      expect(find.text(reason), findsOneWidget);
      await t.tap(find.byKey(const Key('remove-archive-instead')));
      await t.pumpAndSettle();
      expect(sent.map((s) => s.call), [
        'DELETE /api/suppliers/C-14',
        'POST /api/suppliers/C-14/archive',
      ]);
      expect(sent.last.body, {'archived': true});
      expect(find.byType(CustomerDetailScreen), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('customer archive', () {
    testWidgets('archives after the confirm', (t) async {
      phone(t);
      final sent = <({String call, Object? body})>[];
      await t.pumpWidget(
          app(const CustomerDetailScreen(code: 'C-14'), intercept: (r) async {
        if (r.method == 'GET') return null;
        sent.add((call: _call(r), body: jsonDecode(r.body)));
        return _ok({'ok': true, 'archived': true});
      }));
      await t.pumpAndSettle();
      await _tapEnd(t, const Key('profile-archive'));
      expect(find.text(tr('Archive {name}?', {'name': 'Nila Store'})),
          findsOneWidget);
      expect(
          find.text(tr('Hidden from lists and new bookings; history stays.')),
          findsWidgets);
      expect(sent, isEmpty);
      await t.tap(find.byKey(const Key('remove-confirm')));
      await t.pumpAndSettle();
      expect(sent.single.call, 'POST /api/suppliers/C-14/archive');
      expect(sent.single.body, {'archived': true});
      expect(t.takeException(), isNull);
    });

    testWidgets('an archived customer shows the chip and restores at once',
        (t) async {
      phone(t);
      final sent = <({String call, Object? body})>[];
      await t.pumpWidget(
          app(const CustomerDetailScreen(code: 'C-14'), intercept: (r) async {
        if (r.method == 'GET' && r.url.path == '/api/suppliers/C-14') {
          return _ok(
              customerDetailBody(archivedAt: '2026-10-20T08:00:00.000Z'));
        }
        if (r.method == 'GET') return null;
        sent.add((call: _call(r), body: jsonDecode(r.body)));
        return _ok({'ok': true, 'archived': false});
      }));
      await t.pumpAndSettle();
      // The header chip says Archived instead of the terms.
      expect(find.text(tr('Archived')), findsOneWidget);
      expect(find.text(tr('Instant terms')), findsNothing);
      expect(find.byKey(const Key('profile-archive')), findsNothing);
      await t.tap(find.byKey(const Key('profile-restore')));
      await t.pumpAndSettle();
      expect(sent.single.call, 'POST /api/suppliers/C-14/archive');
      expect(sent.single.body, {'archived': false});
      expect(t.takeException(), isNull);
    });

    testWidgets('an older server answering 404 asks for an update', (t) async {
      phone(t);
      await t.pumpWidget(
          app(const CustomerDetailScreen(code: 'C-14'), intercept: (r) async {
        if (r.method == 'POST') return http.Response('404 Not Found', 404);
        return null;
      }));
      await t.pumpAndSettle();
      await _tapEnd(t, const Key('profile-archive'));
      await t.tap(find.byKey(const Key('remove-confirm')));
      await t.pumpAndSettle();
      expect(
          find.text(tr(
              'The server needs an update before customers can be archived.')),
          findsOneWidget);
      expect(find.text('404 Not Found'), findsNothing);
      expect(t.takeException(), isNull);
    });
  });

  group('archived lists', () {
    testWidgets('flyers split into Active and Archived', (t) async {
      phone(t);
      final queries = <String>[];
      await t.pumpWidget(app(const FlyersScreen(), intercept: (r) async {
        if (r.url.path != '/api/flyers') return null;
        queries.add(r.url.query);
        return _ok({
          'flyers': [
            _flyerRow('Arif Rahman'),
            _flyerRow('Rakib Hasan'),
            _flyerRow('Nadia Islam', archivedAt: '2026-10-20T08:00:00.000Z'),
          ]
        });
      }));
      await t.pumpAndSettle();
      expect(queries, ['includeArchived=1']);
      expect(find.text(tr('Active · {n}', {'n': 2})), findsOneWidget);
      expect(find.text(tr('Archived · {n}', {'n': 1})), findsOneWidget);
      expect(find.text('Arif Rahman'), findsOneWidget);
      expect(find.text('Nadia Islam'), findsNothing);

      await t.tap(find.text(tr('Archived · {n}', {'n': 1})));
      await t.pumpAndSettle();
      expect(find.text('Nadia Islam'), findsOneWidget);
      expect(find.text('Arif Rahman'), findsNothing);
      expect(find.text('Rakib Hasan'), findsNothing);
      expect(find.text(tr('Archived')), findsOneWidget);
      expect(find.text(tr('Archived flyers')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('customers split into Active and Archived', (t) async {
      phone(t);
      final queries = <String>[];
      await t.pumpWidget(app(const CustomersScreen(), intercept: (r) async {
        if (r.url.path != '/api/suppliers') return null;
        queries.add(r.url.query);
        return _ok({
          'suppliers': [
            _customer('C-14', 'Nila Store'),
            _customer('C-20', 'Old Corner Shop',
                archivedAt: '2026-10-20T08:00:00.000Z'),
          ]
        });
      }));
      await t.pumpAndSettle();
      expect(queries, ['includeArchived=1']);
      expect(find.text('Nila Store'), findsOneWidget);
      expect(find.text('Old Corner Shop'), findsNothing);

      await t.tap(find.text(tr('Archived · {n}', {'n': 1})));
      await t.pumpAndSettle();
      expect(find.text('Old Corner Shop'), findsOneWidget);
      expect(find.text('Nila Store'), findsNothing);
      expect(find.text(tr('Archived')), findsOneWidget);
      expect(find.text(tr('Archived customers')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('an older server has no archived customers', (t) async {
      phone(t);
      await t.pumpWidget(app(const CustomersScreen(), intercept: (r) async {
        if (r.url.path != '/api/suppliers') return null;
        return _ok({
          'suppliers': [_customer('C-14', 'Nila Store', older: true)]
        });
      }));
      await t.pumpAndSettle();
      expect(find.text('Nila Store'), findsOneWidget);
      await t.tap(find.text(tr('Archived · {n}', {'n': 0})));
      await t.pumpAndSettle();
      expect(find.text(tr('No archived customers')), findsOneWidget);
      expect(find.text('Nila Store'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('booking and flight pickers keep asking for active ones only',
        (t) async {
      phone(t);
      final lists = <String>[];
      Future<http.Response?> record(http.Request r) async {
        if (r.url.path == '/api/suppliers' || r.url.path == '/api/flyers') {
          lists.add(r.url.toString());
        }
        return null;
      }

      await t.pumpWidget(app(const IntakeScreen(), intercept: record));
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpWidget(app(const FlightFormScreen(), intercept: record));
      await t.pumpAndSettle();
      expect(lists.where((url) => url.endsWith('/api/suppliers')), isNotEmpty);
      expect(lists.where((url) => url.endsWith('/api/flyers')), isNotEmpty);
      expect(lists.where((url) => url.contains('includeArchived')), isEmpty);
      expect(t.takeException(), isNull);
    });
  });
}
