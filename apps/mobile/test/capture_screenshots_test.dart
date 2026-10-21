import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sbexpress/app_scope.dart';
import 'package:sbexpress/data/api/api_client.dart';
import 'package:sbexpress/data/models/session_user.dart';
import 'package:sbexpress/data/repositories/auth_repository.dart';
import 'package:sbexpress/data/repositories/customer_repository.dart';
import 'package:sbexpress/data/repositories/dashboard_repository.dart';
import 'package:sbexpress/data/repositories/finance_repository.dart';
import 'package:sbexpress/data/repositories/flight_repository.dart';
import 'package:sbexpress/data/repositories/flyer_repository.dart';
import 'package:sbexpress/data/repositories/media_repository.dart';
import 'package:sbexpress/data/repositories/review_repository.dart';
import 'package:sbexpress/data/repositories/settings_repository.dart';
import 'package:sbexpress/data/repositories/shipment_repository.dart';
import 'package:sbexpress/data/repositories/task_repository.dart';
import 'package:sbexpress/data/session/session_controller.dart';
import 'package:sbexpress/data/session/session_store.dart';
import 'package:sbexpress/features/admin/admin_home_screen.dart';
import 'package:sbexpress/features/admin/invoice_editor_screen.dart';
import 'package:sbexpress/features/admin/shipment_costs_screen.dart';
import 'package:sbexpress/features/customers/customer_activity_screen.dart';
import 'package:sbexpress/features/customers/customers_screen.dart';
import 'package:sbexpress/features/customers/statement_screen.dart';
import 'package:sbexpress/features/finance/finance_screen.dart';
import 'package:sbexpress/features/finance/fund_account_screen.dart';
import 'package:sbexpress/features/finance/reconciliation_screen.dart';
import 'package:sbexpress/features/finance/transfer_screen.dart';
import 'package:sbexpress/features/flights/flight_money_screen.dart';
import 'package:sbexpress/features/flights/flights_screen.dart';
import 'package:sbexpress/features/settings/pay_method_form_screen.dart';
import 'package:sbexpress/features/settings/staff_screen.dart';
import 'package:sbexpress/theme/app_theme.dart';

void main() {
  testWidgets('optional screenshot capture', (tester) async {
    if (Platform.environment['CAPTURE_SCREENSHOTS'] != '1') return;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _api();
    final session = SessionController(store: MemorySessionStore()..token = 'tok', auth: AuthRepository(api));
    session.user = const SessionUser(id: 'u1', name: 'Rafiq', email: 'rafiq@sbx.test', role: UserRole.admin, roleLabel: 'Administrator');
    session.ready = true;
    final scope = AppScope(
      session: session,
      shipments: ShipmentRepository(api),
      dashboard: DashboardRepository(api),
      tasks: TaskRepository(api),
      review: ReviewRepository(api),
      media: MediaRepository(api),
      flights: FlightRepository(api),
      flyers: FlyerRepository(api),
      customers: CustomerRepository(api),
      finance: FinanceRepository(api),
      settings: SettingsRepository(api),
      child: const SizedBox.shrink(),
    );

    await _shot(tester, _scoped(scope, AdminHomeScreen(dashboard: scope.dashboard)), '05-admin-home', find.byType(AdminHomeScreen));
    await _shot(tester, _scoped(scope, const FlightsScreen()), '06-flights', find.byType(FlightsScreen));
    await _shot(tester, _scoped(scope, const CustomersScreen()), '07-customers', find.byType(CustomersScreen));
    await _shot(tester, _scoped(scope, const FinanceScreen()), '08-finance', find.byType(FinanceScreen));
    await _shot(tester, _scoped(scope, const InvoiceEditorScreen(code: 'SH-18')), '09-invoice-editor', find.byType(InvoiceEditorScreen));
    await _shot(tester, _scoped(scope, const TransferScreen()), '10-transfer', find.byType(TransferScreen));
    await _shot(tester, _scoped(scope, const StaffScreen()), '11-staff', find.byType(StaffScreen));
    await _shot(tester, _scoped(scope, const FlightMoneyScreen(code: 'BG305-20261021-ab12cd')), '12-flight-money', find.byType(FlightMoneyScreen));
    await _shot(tester, _scoped(scope, const ShipmentCostsScreen(code: 'SH-18')), '13-costs', find.byType(ShipmentCostsScreen));
    await _shot(tester, _scoped(scope, const StatementScreen(code: 'C-14', name: 'Nila Store')), '14-statement', find.byType(StatementScreen));
    await _shot(tester, _scoped(scope, const PayMethodFormScreen()), '15-pay-method', find.byType(PayMethodFormScreen));
    await _shot(tester, _scoped(scope, const ReconciliationScreen()), '16-reconciliation', find.byType(ReconciliationScreen));
    await _shot(tester, _scoped(scope, const CustomerActivityScreen(code: 'C-14', name: 'Nila Store')), '17-activity', find.byType(CustomerActivityScreen));
    await _shot(tester, _scoped(scope, const FundAccountScreen()), '18-opening-balance', find.byType(FundAccountScreen));
  });
}

Widget _scoped(AppScope source, Widget home) {
  return AppScope(
    session: source.session,
    shipments: source.shipments,
    dashboard: source.dashboard,
    tasks: source.tasks,
    review: source.review,
    media: source.media,
    flights: source.flights,
    flyers: source.flyers,
    customers: source.customers,
    finance: source.finance,
    settings: source.settings,
    child: MaterialApp(theme: buildAppTheme(), home: home),
  );
}

Future<void> _shot(WidgetTester tester, Widget app, String name, Finder finder) async {
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump();
  await expectLater(finder, matchesGoldenFile('$name.png'));
  final bytes = File('test/$name.png').readAsBytesSync();
  for (final dir in ['docs/screenshots', '/opt/cursor/artifacts/screenshots']) {
    final file = File('$dir/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
  }
  File('test/$name.png').deleteSync();
}

ApiClient _api() {
  return ApiClient(
    baseUrl: 'http://localhost:3002',
    session: MemorySessionStore()..token = 'tok',
    httpClient: MockClient((request) async {
      final path = request.url.path;
      final body = path.contains('/invoice')
          ? _invoiceBody()
          : path.contains('statement-links')
              ? _statementLinks()
              : path.contains('statement-receipts')
                  ? _statementReceipts()
                  : path.endsWith('/users')
                      ? _usersBody()
                      : path.contains('/reconciliation')
                          ? _reconciliationBody()
                          : path.contains('/activity')
                              ? _activityBody()
                              : path.contains('/shipments/')
                                  ? _costBody()
                                  : path.contains('/flights/')
                                      ? _flightDetail()
                                      : path.endsWith('/hub')
                                          ? _hubBody()
                                          : path.endsWith('/overview')
                                              ? _overviewBody()
                                              : path.endsWith('/flights')
                                                  ? _flightsBody()
                                                  : path.endsWith('/suppliers')
                                                      ? _customersBody()
                                                      : _financeBody();
      return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
    }),
  );
}

Map<String, Object?> _hubBody() => {
      'todayLabel': 'Tue 20 Oct 2026',
      'atHubCount': 2,
      'incoming': {'kg': 12.5, 'count': 2, 'flightCode': 'BG305-20261020-ab12cd', 'flightDate': '2026-10-21'},
      'openTodoCount': 3,
      'notices': [
        {'tag': 'FLIGHT', 'text': 'BG305 arrives this evening'},
      ],
      'toProcess': [
        _shipment(code: 'SH-18', status: 'received_bd_hub', statusIndex: 5),
        _shipment(code: 'SH-19', status: 'ready_for_last_mile', statusIndex: 6, weighed: 4.2),
      ],
    };

Map<String, Object?> _overviewBody() => {
      'weekLabel': '19 Oct – 20 Oct',
      'todayLabel': 'Tuesday 20 Oct 2026',
      'rate': 17.5,
      'cash': {'bdt': 84250, 'cny': 1200, 'worth': 105250},
      'received': 18000,
      'expenses': 6400,
      'net': 11600,
      'profit': 22000,
      'unpaid': 15400,
      'reviewCount': 2,
      'openTodoCount': 4,
      'nextFlight': {'code': 'BG305-20261020-ab12cd', 'date': '2026-10-21', 'bookedKg': 31.5, 'spaceKg': 44},
      'notices': [
        {'tag': 'WEIGHT', 'text': 'SH-18 weighed 1.4 kg over the booking'},
      ],
      'flights': [],
      'activeShipmentCount': 1,
      'activeShipments': [
        {
          ..._shipment(code: 'SH-18', status: 'received_bd_hub', statusIndex: 5),
          'supplierName': 'Nila Store',
          'charge': 4800,
          'billAmount': 4800,
          'discountAmount': 0,
          'paidAmount': 1000,
          'dueAmount': 3800,
          'payStatus': 'partial',
          'payMethod': null,
          'paymentTerms': 'invoice',
          'freeOfCharge': false,
          'receiptStatus': null,
        },
      ],
    };

Map<String, Object?> _flightsBody() => {
      'flights': [
        {
          'code': 'BG305-20261021-ab12cd',
          'date': '2026-10-21',
          'depTime': '09:40',
          'arrTime': '12:10',
          'via': 'Direct',
          'fare': 8000,
          'actualCost': 42000,
          'agencyShare': 8000,
          'flyerDue': 34000,
          'ticketPaid': 42000,
          'ticketDue': 0,
          'spaceKg': 44,
          'mobiles': 2,
          'laptops': 1,
          'bookedKg': 31.5,
          'leftKg': 12.5,
          'status': 'upcoming',
          'statusLabel': 'Upcoming',
          'flyers': ['Arif Rahman'],
          'shipmentCount': 3,
          'revenue': 64000,
          'scheduleNeedsConfirmation': false,
          'settlements': [
            {'name': 'Arif Rahman', 'contribution': 34000, 'paidAmount': 0},
          ],
        },
      ],
    };

Map<String, Object?> _customersBody() => {
      'suppliers': [
        {
          'code': 'C-14',
          'name': 'Nila Store',
          'phone': '01700000000',
          'address': 'Bashundhara',
          'terms': 'instant',
          'orderCount': 4,
          'deliveredCount': 2,
          'shippedKg': 18.5,
          'billed': 24000,
          'paid': 8600,
          'balance': 15400,
          'creditBalance': 0,
          'pricingPending': 1,
          'discountTotal': 200,
        },
      ],
    };

Map<String, Object?> _reconciliationBody() => {
      'accounts': [
        {'name': 'Dhaka cash', 'currency': 'BDT', 'balance': 84250, 'recordedNetMovement': 18000, 'impliedOpeningBalance': 66250},
        {'name': 'Chengdu cash', 'currency': 'CNY', 'balance': 1200, 'recordedNetMovement': 1200, 'impliedOpeningBalance': 0},
      ],
      'missingPostings': [
        {'kind': 'payment', 'reference': 'Legacy deposit', 'amount': 50},
      ],
      'shipmentDifferences': [
        {'code': 'SH-18', 'allocatedPaid': 1000, 'ledgerPaid': 800, 'difference': 200},
      ],
      'note': 'Implied opening balances are derived from current balances and recorded movements.',
    };

Map<String, Object?> _activityBody() => {
      'page': 1,
      'total': 2,
      'limit': 25,
      'entries': [
        {
          'id': 'p1',
          'label': 'Payment',
          'kind': 'customer',
          'amount': 1000,
          'sourceCurrency': 'BDT',
          'sourceAmount': 1000,
          'sourceFxRate': 1,
          'at': '2026-10-20T09:30:00.000Z',
          'reference': 'SH-18 / bkash',
          'shipmentCode': 'SH-18',
          'accountName': 'Dhaka cash',
          'reason': '',
          'canReverse': true,
          'reversalKind': 'payment',
        },
        {
          'id': 'c1',
          'label': 'Credit applied',
          'kind': 'applied',
          'amount': -200,
          'sourceCurrency': 'CNY',
          'sourceAmount': 11.43,
          'sourceFxRate': 17.5,
          'at': '2026-10-19T04:00:00.000Z',
          'reference': 'advance',
          'shipmentCode': null,
          'accountName': null,
          'reason': 'Applied to bill',
          'canReverse': false,
          'reversalKind': 'credit',
        },
      ],
    };

Map<String, Object?> _financeBody() => {
      'period': 'week',
      'periodLabel': 'This week',
      'rate': 17.5,
      'cash': {'bdt': 84250, 'cny': 1200, 'worth': 105250},
      'received': 18000,
      'expenses': 6400,
      'net': 11600,
      'receivables': {'total': 15400, 'count': 3},
      'results': {'shipmentCount': 6, 'billing': 64000, 'costs': 22000, 'profit': 42000, 'marginPct': 65},
      'accounts': [
        {'name': 'Dhaka cash', 'kind': 'cash', 'currency': 'BDT', 'balance': 84250},
        {'name': 'Chengdu cash', 'kind': 'cash', 'currency': 'CNY', 'balance': 1200},
      ],
      'ticketPayables': 0,
      'costPayables': 1400,
      'flyerReceivables': 34000,
    };

Map<String, Object?> _shipment({required String code, required String status, required int statusIndex, double? weighed}) => {
      'code': code,
      'supplierCode': 'C-14',
      'flightCode': 'BG305-20261021-ab12cd',
      'flightDate': '2026-10-21',
      'bookedKg': 4,
      'weighedKg': weighed,
      'effectiveKg': weighed ?? 4,
      'weightDelta': null,
      'description': 'phones',
      'categories': ['mobile'],
      'status': status,
      'statusIndex': statusIndex,
      'statusLabel': status,
      'exception': null,
      'exceptionReason': '',
      'date': '2026-10-18',
    };

Map<String, Object?> _invoiceBody() => {
      'saved': true,
      'invoice': {
        'state': 'draft',
        'needsReview': false,
        'pricingMode': 'automatic',
        'number': 'INV-18',
        'lines': [
          {'label': 'Freight', 'amount': 4800},
          {'label': 'Packing', 'amount': 200},
        ],
        'discount': 200,
        'note': '',
        'total': 4800,
        'paidAmount': 1000,
        'dueAmount': 3800,
      },
    };

Map<String, Object?> _costBody() => {
      'costs': {
        'items': [
          {
            'id': 'cost-1',
            'name': 'Courier',
            'category': 'courier',
            'amount': 350,
            'paidAmount': 0,
            'dueAmount': 350,
            'costField': null,
            'voidedAt': null,
          },
        ],
        'total': 350,
        'unpaidCosts': {'cnFare': 0, 'bdFare': 0, 'customsTax': 0},
      },
    };

Map<String, Object?> _usersBody() => {
      'users': [
        {'id': 'u1', 'name': 'Rafiq', 'email': 'rafiq@sbx.test', 'role': 'admin', 'active': true},
        {'id': 'u2', 'name': 'Hub desk', 'email': 'hub@sbx.test', 'role': 'hub', 'active': true},
      ],
    };

Map<String, Object?> _statementLinks() => {
      'links': [
        {
          'id': 'link-1',
          'url': 'https://track.example/s/demo',
          'status': 'active',
          'expiresAt': '2026-10-28T00:00:00.000Z',
        },
      ],
      'balance': {'billed': 4800, 'paid': 1000, 'due': 3800},
    };

Map<String, Object?> _statementReceipts() => {
      'receipts': [
        {
          'reference': 'rcpt-1',
          'amount': 500,
          'method': 'bKash',
          'status': 'pending',
          'reason': '',
          'month': '2026-10',
        },
      ],
    };

Map<String, Object?> _flightDetail() {
  final flight = Map<String, Object?>.from((_flightsBody()['flights'] as List).first as Map);
  flight['ticketDue'] = 1200;
  flight['ticketRefundDue'] = 0;
  flight['unallocatedFlyerPaid'] = 500;
  flight['flyerDetails'] = [
    {'name': 'Arif Rahman', 'bdPhone': '01800000000', 'initial': 'A'},
  ];
  flight['bookings'] = <Map<String, Object?>>[];
  return {'flight': flight};
}
