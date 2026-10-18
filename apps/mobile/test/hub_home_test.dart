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

Future<void> _pumpHome(WidgetTester tester, List<Map<String, Object?>> rows) async {
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
          'incoming': {'kg': 12.5, 'count': 2, 'flightCode': 'BG-147', 'flightDate': '2026-10-20'},
          'openTodoCount': 4,
          'notices': [
            {'tag': 'DUE', 'text': 'balance ৳900 outstanding'},
          ],
          'toProcess': rows,
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

void main() {
  testWidgets('hub home leads with the teal today hero and no money', (tester) async {
    await _pumpHome(tester, [
      _row(code: 'SH-W', status: 'received_bd_hub'),
      _row(code: 'SH-P', status: 'received_bd_hub', weighedKg: 4.2),
      _row(code: 'SH-D', status: 'ready_for_last_mile', weighedKg: 4.2),
    ]);

    expect(find.byKey(const Key('hub-today-hero')), findsOneWidget);
    expect(find.text('আজকের বাকি কাজ'), findsOneWidget);
    expect(find.text('হোম'), findsNothing);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('এখন করুন: ওজন'), findsOneWidget);
    expect(find.text('courier → dispatch → handover'), findsWidgets);
    expect(find.text('Karim Store'), findsNothing);
    expect(find.textContaining('৳'), findsNothing);
    expect(find.textContaining('bKash'), findsNothing);
    expect(find.textContaining('1200'), findsNothing);

    final hero = tester.widget<Container>(find.byKey(const Key('hub-today-hero')));
    final decoration = hero.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.teal);
    expect(decoration.borderRadius, BorderRadius.circular(18));

    BoxDecoration statDecoration(Key key) {
      return tester.widget<Container>(find.byKey(key)).decoration! as BoxDecoration;
    }

    expect(statDecoration(const Key('hub-count-weigh')).color, AppColors.amber);
    expect(statDecoration(const Key('hub-count-pack')).color, isNot(AppColors.amber));
    expect(statDecoration(const Key('hub-count-delivery')).color, isNot(AppColors.amber));
    expect(tester.getSize(find.byKey(const Key('hub-count-weigh'))).height, greaterThanOrEqualTo(48));
  });

  testWidgets('a clear hub day leaves the hero without an amber action', (tester) async {
    await _pumpHome(tester, const []);
    expect(find.text('আজকের বাকি কাজ'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
    expect(find.text('আজ হাবে বাকি ধাপ নেই'), findsOneWidget);
    expect(find.byKey(const Key('hub-today-now')), findsNothing);
    expect(tester.widget<Container>(find.byKey(const Key('hub-count-weigh'))).decoration, isA<BoxDecoration>());
    final weigh = tester.widget<Container>(find.byKey(const Key('hub-count-weigh'))).decoration! as BoxDecoration;
    expect(weigh.color, isNot(AppColors.amber));
  });
}
