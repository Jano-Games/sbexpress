import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbexpress/app_scope.dart';
import 'package:sbexpress/data/models/hub_flight.dart';
import 'package:sbexpress/data/models/session_user.dart';
import 'package:sbexpress/data/repositories/auth_repository.dart';
import 'package:sbexpress/data/session/session_controller.dart';
import 'package:sbexpress/data/session/session_store.dart';
import 'package:sbexpress/features/flights/hub_flights_screen.dart';
import 'package:sbexpress/theme/app_theme.dart';
import 'support/screen_fixtures.dart';

Widget _app(Widget home, List<String> paths) {
  final api = screenFixtureApi(intercept: (request) async {
    paths.add(request.url.path);
    return null;
  });
  final session = SessionController(
      store: MemorySessionStore()..token = 'tok', auth: AuthRepository(api))
    ..user = const SessionUser(
        id: 'h',
        name: 'Hub desk',
        email: 'hub@sbx.test',
        role: UserRole.hub,
        roleLabel: 'Hub Manager')
    ..ready = true;
  return AppScope.wired(
      session: session,
      api: api,
      child: MaterialApp(theme: buildAppTheme(), home: home));
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  test('hub flight rows read schedule fields and ignore money', () {
    final flight = HubFlight.fromJson({
      ...Map<String, Object?>.from(
          (hubScheduleBody()['upcoming'] as List).first as Map),
      'fare': 9000,
      'actualCost': 12000,
      'revenue': 64000,
    });
    expect(flight.displayCode, 'BG147');
    expect(flight.stopLabel, 'KMG Kunming');
    expect(flight.timesKnown, isTrue);
    expect(flight.kg, 18.4);
    final unknown = HubFlight.fromJson(Map<String, Object?>.from(
        (hubScheduleBody()['upcoming'] as List).last as Map));
    expect(unknown.timesKnown, isFalse);
  });

  test('flight days read relative to today', () {
    final today = DateTime(2026, 10, 18);
    expect(FlightDay.parse('2026-10-18', today: today)!.relativeLabel, 'আজ');
    expect(
        FlightDay.parse('2026-10-19', today: today)!.relativeLabel, 'আগামীকাল');
    final tuesday = FlightDay.parse('2026-10-20', today: today)!;
    expect(tuesday.relativeLabel, '2 দিন পর');
    expect(tuesday.shortLabel, 'মঙ্গল, 20 Oct');
    expect(FlightDay.parse('2026-10-16', today: today)!.relativeLabel,
        '2 দিন আগে');
  });

  testWidgets('hub flights list the schedule and open a manifest',
      (tester) async {
    _phone(tester);
    final paths = <String>[];
    await tester.pumpWidget(_app(const HubFlightsScreen(root: true), paths));
    await tester.pumpAndSettle();
    expect(paths, ['/api/flights/hub']);
    expect(find.text('আসন্ন · 3'), findsOneWidget);
    expect(find.text('BG147'), findsOneWidget);
    expect(find.text('পরের ফ্লাইট · 2 দিন পর'), findsOneWidget);
    expect(find.textContaining('৳'), findsNothing);

    await tester.tap(find.text('BG147'));
    await tester.pumpAndSettle();
    expect(paths.last, startsWith('/api/flights/hub/BG147-'));
    expect(find.byType(HubFlightDetailScreen), findsOneWidget);
    expect(find.text('এই ফ্লাইটে আসছে'), findsOneWidget);
    expect(find.text('SH-51'), findsOneWidget);
    expect(find.text('SH-53'), findsOneWidget);
    expect(find.text('Arif Rahman'), findsOneWidget);
    expect(find.textContaining('৳'), findsNothing);
    await tester.tap(find.byTooltip('পিছনে'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(find.text('সময় নিশ্চিত নয়'),
        find.byType(ListView), const Offset(0, -200));
    expect(find.text('সময় নিশ্চিত নয়'), findsOneWidget);

    await tester.tap(find.text('এসে গেছে'));
    await tester.pumpAndSettle();
    expect(find.text('BG139'), findsOneWidget);
    expect(find.text('হাবে 3/3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hub flights fit a narrow screen with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final paths = <String>[];
    await tester.pumpWidget(_app(
        Builder(
            builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.3)),
                child: const HubFlightsScreen(root: true))),
        paths));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(jsonEncode(paths), contains('/api/flights/hub'));
  });
}
