import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sbexpress/data/api/api_client.dart';
import 'package:sbexpress/data/repositories/dashboard_repository.dart';
import 'package:sbexpress/data/session/session_store.dart';
import 'package:sbexpress/features/hub/hub_home_screen.dart';
import 'package:sbexpress/theme/app_colors.dart';
import 'package:sbexpress/theme/app_theme.dart';

Map<String, Object?> _row({
  required String code,
  required String status,
  double? weighedKg,
}) {
  return {
    'code': code,
    'supplierCode': 'C-9',
    'supplierName': 'Karim Store',
    'flightCode': 'BG-147',
    'flightDate': '2026-10-20',
    'bookedKg': 4.5,
    'weighedKg': weighedKg,
    'effectiveKg': weighedKg ?? 4.5,
    'weightDelta': null,
    'description': 'phones',
    'categories': ['mobile'],
    'status': status,
    'statusIndex': status == 'received_bd_hub' ? 5 : 6,
    'statusLabel': status,
    'exception': null,
    'exceptionReason': '',
    'date': '2026-10-18',
    'paymentTerms': 'cod',
    'freeOfCharge': true,
    'receiptStatus': 'pending',
    'charge': 1200,
    'billAmount': 1200,
    'dueAmount': 1100,
    'paidAmount': 100,
    'payStatus': 'partial',
    'payMethod': 'bKash',
  };
}

Map<String, Object?> _flight(String code, String date) => {
      'code': code,
      'date': date,
      'depTime': '10:40',
      'arrTime': '15:25',
      'via': 'Via KMG Kunming',
      'from': 'Chengdu',
      'to': 'Dhaka',
      'status': 'upcoming',
      'statusLabel': 'Upcoming',
      'scheduleNeedsConfirmation': false,
      'flyers': ['Arif Rahman'],
      'shipmentCount': 2,
      'kg': 18.4,
      'receivedCount': 0,
      // Even if a server leaked money, the hub model must not read or show it.
      'fare': 9000,
      'revenue': 64000,
    };

Future<void> _pumpHome(WidgetTester tester, List<Map<String, Object?>> rows,
    {List<Map<String, Object?>>? flights}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = ApiClient(
    baseUrl: 'http://localhost:3002',
    session: MemorySessionStore()..token = 'tok',
    httpClient: MockClient((request) async {
      expect(request.url.path, '/api/dashboard/hub');
      return http.Response.bytes(
        utf8.encode(jsonEncode({
          'todayLabel': 'Sun 18 Oct 2026',
          'atHubCount': rows.length,
          'incoming': {
            'kg': 12.5,
            'count': 2,
            'flightCode': 'BG-147',
            'flightDate': '2026-10-20'
          },
          'openTodoCount': 4,
          'notices': [
            {'tag': 'DUE', 'text': 'balance ৳900 outstanding'},
          ],
          'toProcess': rows,
          if (flights != null) 'upcomingFlights': flights,
        })),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    home: HubHomeScreen(dashboard: DashboardRepository(api)),
  ));
  await tester.pump();
  await tester.pump();
}

BoxDecoration _decoration(WidgetTester tester, Key key) =>
    tester.widget<Container>(find.byKey(key)).decoration! as BoxDecoration;

void main() {
  testWidgets(
      'hub home prioritizes current work without customer or money data',
      (tester) async {
    await _pumpHome(tester, [
      _row(code: 'SH-W', status: 'received_bd_hub'),
      _row(code: 'SH-P', status: 'received_bd_hub', weighedKg: 4.2),
      _row(code: 'SH-D', status: 'ready_for_last_mile', weighedKg: 4.2),
    ]);

    expect(find.byKey(const Key('hub-today-hero')), findsOneWidget);
    expect(find.text('আজকের কাজ'), findsOneWidget);
    expect(find.text('হোম'), findsNothing);
    expect(find.text('3টি বাকি'), findsOneWidget);
    expect(find.text('শুরু করুন — SH-W ওজন'), findsOneWidget);
    expect(find.text('ওজন বাকি'), findsOneWidget);
    expect(find.text('প্যাক বাকি'), findsOneWidget);
    expect(find.text('ডেলিভারি বাকি'), findsOneWidget);
    expect(find.text('Karim Store'), findsNothing);
    expect(find.textContaining('৳'), findsNothing);
    expect(find.textContaining('bKash'), findsNothing);
    expect(find.textContaining('1200'), findsNothing);

    final hero = _decoration(tester, const Key('hub-today-hero'));
    expect(hero.color, AppColors.card);
    expect(hero.borderRadius, BorderRadius.circular(heroRadius));

    expect(_decoration(tester, const Key('hub-count-weigh')).color,
        AppColors.accentSoft);
    expect(_decoration(tester, const Key('hub-count-pack')).color,
        isNot(AppColors.accentSoft));
    expect(_decoration(tester, const Key('hub-count-delivery')).color,
        isNot(AppColors.accentSoft));
    expect(tester.getSize(find.byKey(const Key('hub-count-weigh'))).height,
        greaterThanOrEqualTo(48));
  });

  testWidgets('a step tile filters the waiting list to that step',
      (tester) async {
    await _pumpHome(tester, [
      _row(code: 'SH-W', status: 'received_bd_hub'),
      _row(code: 'SH-P', status: 'received_bd_hub', weighedKg: 4.2),
    ]);
    await tester.tap(find.byKey(const Key('hub-count-pack')));
    await tester.pump();
    expect(find.text('প্যাক বাকি'), findsWidgets);
    expect(find.text('SH-P'), findsOneWidget);
    expect(find.text('SH-W'), findsNothing);
    await tester.tap(find.text('সব দেখান'));
    await tester.pump();
    expect(find.text('SH-W'), findsOneWidget);
  });

  testWidgets('a clear hub day leaves all workflow steps neutral',
      (tester) async {
    await _pumpHome(tester, const []);
    expect(find.text('আজকের কাজ'), findsOneWidget);
    expect(find.text('সব শেষ'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
    expect(find.text('আজ হাবে বাকি ধাপ নেই'), findsOneWidget);
    expect(find.byKey(const Key('hub-today-now')), findsNothing);
    expect(_decoration(tester, const Key('hub-count-weigh')).color,
        isNot(AppColors.accentSoft));
  });

  testWidgets('upcoming flights show on the hub home without money',
      (tester) async {
    await _pumpHome(tester, const [], flights: [
      _flight('BG147-20261020-ab12cd', '2026-10-20'),
      _flight('BG152-20261023-cd34ef', '2026-10-23'),
    ]);
    expect(find.text('আসন্ন ফ্লাইট'), findsOneWidget);
    expect(find.text('BG147'), findsOneWidget);
    expect(find.text('2টি শিপমেন্ট · 18.4 kg'), findsWidgets);
    expect(find.textContaining('9000'), findsNothing);
    expect(find.textContaining('64000'), findsNothing);
    expect(find.textContaining('৳'), findsNothing);
  });
}
