import 'support/screen_fixtures.dart';
import 'support/team_fixtures.dart';
import 'package:sbexpress/data/api/api_client.dart';
import 'package:sbexpress/data/models/workspace.dart';
import 'package:sbexpress/features/flyers/flyer_detail_screen.dart';
import 'package:sbexpress/features/flyers/flyer_form_screen.dart';
import 'package:sbexpress/features/flyers/flyers_screen.dart';
import 'package:sbexpress/features/admin/admin_shipment_screen.dart';
import 'package:sbexpress/features/flights/flight_detail_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:sbexpress/features/auth/login_screen.dart';
import 'package:sbexpress/features/auth/splash_screen.dart';
import 'package:sbexpress/features/hub/hub_home_screen.dart';
import 'package:sbexpress/features/flights/hub_flights_screen.dart';
import 'package:sbexpress/features/shipments/shipment_process_screen.dart';
import 'package:sbexpress/features/shipments/shipments_screen.dart';
import 'package:sbexpress/features/more/more_screen.dart';
import 'package:sbexpress/features/tasks/tasks_screen.dart';
import 'package:sbexpress/features/admin/payment_review_screen.dart';
import 'package:sbexpress/widgets/ui.dart';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:sbexpress/data/uploads/photo_upload.dart';
import 'package:sbexpress/data/uploads/quick_uploads.dart';
import 'package:sbexpress/features/intake/booking_done_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbexpress/app_scope.dart';
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
import 'package:sbexpress/features/customers/customer_credit_screen.dart';
import 'package:sbexpress/features/customers/customer_form_screen.dart';
import 'package:sbexpress/features/finance/ledger_screen.dart';
import 'package:sbexpress/features/finance/office_entry_screen.dart';
import 'package:sbexpress/features/customers/customers_screen.dart';
import 'package:sbexpress/features/customers/statement_screen.dart';
import 'package:sbexpress/features/finance/finance_screen.dart';
import 'package:sbexpress/features/finance/fund_account_screen.dart';
import 'package:sbexpress/features/finance/reconciliation_screen.dart';
import 'package:sbexpress/features/finance/transfer_screen.dart';
import 'package:sbexpress/features/finance/get_paid_screen.dart';
import 'package:sbexpress/features/flights/flight_form_screen.dart';
import 'package:sbexpress/features/flights/flight_money_screen.dart';
import 'package:sbexpress/features/flights/ticket_flyers_screen.dart';
import 'package:sbexpress/features/flights/flights_screen.dart';
import 'package:sbexpress/features/flights/ticket_import_screen.dart';
import 'package:sbexpress/features/settings/pay_method_form_screen.dart';
import 'package:sbexpress/features/settings/staff_screen.dart';
import 'package:sbexpress/features/settings/settings_screen.dart';
import 'package:sbexpress/features/intake/intake_screen.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'package:sbexpress/theme/app_theme.dart';

void main() {
  testWidgets('optional screenshot capture', (tester) async {
    if (Platform.environment['CAPTURE_SCREENSHOTS'] != '1') return;
    final previousLanguage = appLanguage.value;
    addTearDown(() => appLanguage.value = previousLanguage);
    appLanguage.value = Platform.environment['CAPTURE_LANGUAGE'] == 'bn'
        ? AppLanguage.bn
        : AppLanguage.en;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      final font = FontLoader('HindSiliguri');
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        font.addFont(rootBundle.load('assets/fonts/HindSiliguri-$weight.ttf'));
      }
      await font.load();
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
    });
    final api = screenFixtureApi();
    final session = SessionController(
        store: MemorySessionStore()..token = 'tok', auth: AuthRepository(api));
    session.user = const SessionUser(
        id: 'u1',
        name: 'Rafiq',
        email: 'rafiq@sbx.test',
        role: UserRole.admin,
        roleLabel: 'Administrator');
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

    // The splash's loading bar never settles, so pump a fixed time.
    await tester.pumpWidget(RepaintBoundary(
        key: const Key('capture'),
        child: _scoped(scope, const SplashScreen())));
    await tester.pump(const Duration(milliseconds: 800));
    await _saveShot(tester, '00-splash');
    await _shot(
        tester,
        _scoped(scope, LoginScreen(onSubmit: (email, password) async {})),
        '01-login',
        find.byType(LoginScreen));
    await _shot(
        tester,
        _scoped(scope, HubHomeScreen(dashboard: scope.dashboard), tab: 0),
        '02-hub-home',
        find.byType(HubHomeScreen));
    await _shot(
        tester,
        _scoped(scope,
            ShipmentsScreen(role: UserRole.hub, shipments: scope.shipments),
            tab: 1, hub: true),
        '02b-hub-shipments',
        find.byType(ShipmentsScreen));
    await _shot(
        tester,
        _scoped(scope, const HubFlightsScreen(root: true), tab: 2, hub: true),
        '02c-hub-flights',
        find.byType(HubFlightsScreen));
    await _shot(
        tester,
        _scoped(scope, const HubFlightDetailScreen(code: 'BG147-x')),
        '02d-hub-flight-detail',
        find.byType(HubFlightDetailScreen));
    await _shot(
        tester,
        _scoped(scope, const ShipmentProcessScreen(code: 'SH-18')),
        '02e-hub-process',
        find.byType(ShipmentProcessScreen));
    await _shot(
        tester,
        _scoped(scope,
            ShipmentsScreen(role: UserRole.admin, shipments: scope.shipments),
            tab: 1),
        '03-shipments',
        find.byType(ShipmentsScreen));
    await _shot(tester, _scoped(scope, const PaymentReviewScreen()),
        '04-review-queue', find.byType(PaymentReviewScreen));
    await tester.tap(find.text('SH-18 · bKash'));
    await tester.pumpAndSettle();
    await _saveShot(tester, '04b-review-detail');
    await tester.tap(find.byTooltip(tr('Back')));
    await tester.pumpAndSettle();
    expect(find.text(tr('Awaiting review')), findsOneWidget);
    expect(find.byKey(const Key('review-approve')), findsNothing);
    await _shot(
        tester,
        _scoped(scope, MoreScreen(user: session.user!, session: session),
            tab: 3),
        '19-workspace',
        find.byType(MoreScreen));
    await _shot(
        tester,
        _scoped(scope, TasksScreen(role: UserRole.admin, tasks: scope.tasks),
            tab: 3),
        '20-tasks',
        find.byType(TasksScreen));
    await _shot(
        tester,
        _scoped(scope, AdminHomeScreen(dashboard: scope.dashboard), tab: 0),
        '05-admin-home',
        find.byType(AdminHomeScreen));
    await _shot(tester, _scoped(scope, const FlightsScreen()), '06-flights',
        find.byType(FlightsScreen));
    await _shot(tester, _scoped(scope, const CustomersScreen()), '07-customers',
        find.byType(CustomersScreen));
    await _shot(tester, _scoped(scope, const FinanceScreen()), '08-finance',
        find.byType(FinanceScreen));
    await _shot(
        tester,
        _scoped(scope, const InvoiceEditorScreen(code: 'SH-18')),
        '09-invoice-editor',
        find.byType(InvoiceEditorScreen));
    await _shot(tester, _scoped(scope, const TransferScreen()), '10-transfer',
        find.byType(TransferScreen));
    await _shot(tester, _scoped(scope, const StaffScreen()), '11-staff',
        find.byType(StaffScreen));
    await _shot(
        tester,
        _scoped(scope, const FlightMoneyScreen(code: 'BG305-20261021-ab12cd')),
        '12-flight-money',
        find.byType(FlightMoneyScreen));
    await _scrollShot(tester, '12a-flight-money-ticket');
    await _shot(
        tester,
        _scoped(scope, const TicketSettleScreen(code: 'BG305-20261021-ab12cd')),
        '12b-ticket-settle',
        find.byType(TicketSettleScreen));
    await _shot(
        tester,
        _scoped(scope, const ContributionScreen(code: 'BG305-20261021-ab12cd')),
        '12c-contributions',
        find.byType(ContributionScreen));
    await _scrollShot(tester, '12d-contributions-flyers');
    await _shot(
        tester,
        _scoped(scope, const FlyerPaymentScreen(code: 'BG305-20261021-ab12cd')),
        '12e-flyer-payment',
        find.byType(FlyerPaymentScreen));
    await _shot(
        tester,
        _scoped(scope, const ShipmentCostsScreen(code: 'SH-18')),
        '13-costs',
        find.byType(ShipmentCostsScreen));
    await _shot(
        tester,
        _scoped(scope, const StatementScreen(code: 'C-14', name: 'Nila Store')),
        '14-statement',
        find.byType(StatementScreen));
    await _shot(tester, _scoped(scope, const PayMethodFormScreen()),
        '15-pay-method', find.byType(PayMethodFormScreen));
    await _shot(tester, _scoped(scope, const ReconciliationScreen()),
        '16-reconciliation', find.byType(ReconciliationScreen));
    await _shot(
        tester,
        _scoped(scope,
            const CustomerActivityScreen(code: 'C-14', name: 'Nila Store')),
        '17-activity',
        find.byType(CustomerActivityScreen));
    await _shot(tester, _scoped(scope, const FundAccountScreen()),
        '18-opening-balance', find.byType(FundAccountScreen));
    await _shot(tester, _scoped(scope, const SettingsScreen()), '21-settings',
        find.byType(SettingsScreen));
    await _shot(
        tester,
        _scoped(_bookingScope(scope),
            const IntakeScreen(pickPhotos: _samplePhotos)),
        '22-intake',
        find.byType(IntakeScreen));
    await tester.tap(find.text(tr('Choose a customer')));
    await tester.pumpAndSettle();
    await _saveShot(tester, '22b-customer-picker');
    await tester.tap(find.byTooltip(tr('Close')));
    await tester.pumpAndSettle();
    await _fillBooking(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await _saveShot(tester, '22c-intake-top');
    await _scrollShot(tester, '22d-intake-devices', dy: -560);
    await _scrollShot(tester, '22e-intake-laptop', dy: -560);
    await _scrollShot(tester, '22f-intake-charge', dy: -560);
    await _scrollShot(tester, '22g-intake-photos', dy: -800);
    await tester.tap(find.byKey(const Key('intake-create')));
    await tester.pumpAndSettle();
    await _decodeImages(tester);
    await _saveShot(tester, '22h-booking-done');
    await tester.tap(find.byKey(const Key('booking-share')));
    await tester.pumpAndSettle();
    await _saveShot(tester, '22i-booking-done-link');
    await _shot(tester, _scoped(scope, const FinanceScreen()),
        '23-finance-accounts', find.byType(FinanceScreen));
    await tester.tap(find.text(tr('Reports')));
    await tester.pumpAndSettle();
    await _saveShot(tester, '23b-finance-reports');
    await tester.tap(find.text(tr('Transactions')));
    await tester.pumpAndSettle();
    await _saveShot(tester, '23c-finance-actions');
    await _shot(
        tester,
        _scoped(scope, const AdminShipmentScreen(code: 'SH-18')),
        '24-shipment-detail',
        find.byType(AdminShipmentScreen));
    await _scrollShot(tester, '24a-shipment-detail-handling');
    await tester.tap(find.text(tr('Bill')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await _saveShot(tester, '24b-shipment-billing');
    await _scrollShot(tester, '24c-shipment-payment');
    await _scrollShot(tester, '24d-shipment-share');
    await tester.tap(find.text(tr('Photos')));
    await tester.pumpAndSettle();
    await _saveShot(tester, '24e-shipment-photos');
    await _shot(tester, _scoped(scope, const FlightDetailScreen(code: 'BG305')),
        '25-flight-detail', find.byType(FlightDetailScreen));
    await _shot(
        tester,
        _scoped(scope, const FlightDetailScreen(code: 'BG305-20261021-ab12cd')),
        '25b-flight-detail-bookings',
        find.byType(FlightDetailScreen));
    await _scrollShot(tester, '25c-flight-detail-bookings-list');
    await _flowShots(tester, scope);
    await _quickShots(tester, scope);
    await _shot(
        tester,
        _scoped(scope, const CustomerDetailScreen(code: 'C-14')),
        '26-customer-detail',
        find.byType(CustomerDetailScreen));
    await _shot(
        tester,
        _scoped(scope,
            TicketImportScreen(pickPdf: () async => utf8.encode('%PDF-1.4'))),
        '28-ticket-import',
        find.byType(TicketImportScreen));
    await tester.tap(find.byKey(const Key('ticket-pick')));
    await tester.pumpAndSettle();
    await _saveShot(tester, '28b-ticket-review');
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await _saveShot(tester, '28c-ticket-flights');
    // Customers and finance.
    await _shot(
        tester,
        _scoped(scope, const CustomerDetailScreen(code: 'C-14')),
        '26b-customer-shipments',
        find.byType(CustomerDetailScreen));
    await tester.tap(find.text(tr('Shipments · {n}', {'n': 1})));
    await tester.pumpAndSettle();
    await _saveShot(tester, '26b-customer-shipments');
    await tester.tap(find.text(tr('Transactions')));
    await tester.pumpAndSettle();
    await _saveShot(tester, '26c-customer-transactions');
    await _shot(
        tester,
        _scoped(
            scope,
            const CustomerCreditScreen(
                code: 'C-14', name: 'Nila Store', orders: [])),
        '26d-customer-credit',
        find.byType(CustomerCreditScreen));
    await _shot(tester, _scoped(scope, const CustomerFormScreen()),
        '26e-customer-form', find.byType(CustomerFormScreen));
    await _shot(tester, _scoped(scope, const LedgerScreen()), '29-ledger',
        find.byType(LedgerScreen));
    await _shot(
        tester,
        _scoped(scope, const OfficeEntryScreen(initialKind: 'expense')),
        '30-office-expense',
        find.byType(OfficeEntryScreen));
    await tester.tap(find.byKey(const Key('account-Dhaka cash')));
    await tester.enterText(find.byKey(const Key('office-amount')), '1850');
    await tester.pumpAndSettle();
    await _saveShot(tester, '30-office-expense');
    await tester.tap(find.byKey(const Key('office-kind-income')));
    await tester.pumpAndSettle();
    await _saveShot(tester, '30b-office-income');
    await _teamShots(tester, scope);
    tester.view.physicalSize = const Size(320, 700);
    _textScale = 1.3;
    for (final entry in <String, Widget>{
      'compact-home': AdminHomeScreen(dashboard: scope.dashboard),
      'compact-hub': HubHomeScreen(dashboard: scope.dashboard),
      'compact-shipments':
          ShipmentsScreen(role: UserRole.admin, shipments: scope.shipments),
      'compact-finance': const FinanceScreen(),
      'compact-settings': const SettingsScreen(),
      'compact-transfer': const TransferScreen(),
      'compact-customers': const CustomersScreen(),
      'compact-customer': const CustomerDetailScreen(code: 'C-14'),
      'compact-statement':
          const StatementScreen(code: 'C-14', name: 'Nila Store'),
      'compact-activity':
          const CustomerActivityScreen(code: 'C-14', name: 'Nila Store'),
      'compact-ledger': const LedgerScreen(),
      'compact-office': const OfficeEntryScreen(initialKind: 'expense'),
      'compact-reconciliation': const ReconciliationScreen(),
      'compact-workspace': MoreScreen(user: session.user!, session: session),
      'compact-login': LoginScreen(onSubmit: (email, password) async {}),
      'compact-flights': const FlightsScreen(),
      'compact-flight-detail':
          const FlightDetailScreen(code: 'BG305-20261021-ab12cd'),
      'compact-flight-money':
          const FlightMoneyScreen(code: 'BG305-20261021-ab12cd'),
      'compact-contributions':
          const ContributionScreen(code: 'BG305-20261021-ab12cd'),
      'compact-flyer-payment':
          const FlyerPaymentScreen(code: 'BG305-20261021-ab12cd'),
      'compact-shipment': const AdminShipmentScreen(code: 'SH-18'),
      'compact-shipment-bill':
          const AdminShipmentScreen(code: 'SH-18', initialTab: 1),
      'compact-get-paid': const GetPaidScreen(),
      'compact-get-paid-monthly': const GetPaidScreen(initialTab: 1),
      'compact-ticket-flyers': const TicketFlyersScreen(code: flowFlightCode),
      'compact-flight-profit': const FlightDetailScreen(code: flowFlightCode),
      'compact-flight-form': const FlightFormScreen(),
    }.entries) {
      await _shot(tester, _scoped(scope, entry.value), entry.key,
          find.byType(entry.value.runtimeType));
      final lists = find.byType(ListView);
      if (lists.evaluate().isNotEmpty) {
        await tester.drag(lists.first, const Offset(0, -1100));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '${entry.key} scrolled');
      }
    }
    await _flowCompactShots(tester, scope);
    await _teamCompactShots(tester, scope);
    await _shot(
        tester,
        _scoped(_bookingScope(scope),
            const IntakeScreen(pickPhotos: _samplePhotos)),
        '27-compact-booking',
        find.byType(IntakeScreen));
    await _fillBooking(tester);
    await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '27-compact-booking $i');
      await _saveShot(tester, '27b-compact-booking-$i');
    }
    await tester.tap(find.byKey(const Key('intake-create')));
    await tester.pumpAndSettle();
    await _saveShot(tester, '27c-compact-booking-done');
    _textScale = 1;
  });
}

double _textScale = 1;

/// The same session on an API that also answers with the team fixtures.
AppScope _teamScope(AppScope source,
    {String invoiceState = 'draft',
    bool needsReview = false,
    bool cleanupEnabled = false}) {
  final ApiClient api = screenFixtureApi(
      intercept: (request) => teamFixtures(request,
          invoiceState: invoiceState,
          needsReview: needsReview,
          cleanupEnabled: cleanupEnabled));
  return AppScope(
    session: source.session,
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
}

const _jamal = StaffAccount(
    id: 'u3',
    name: 'Jamal Hossain',
    email: 'jamal@sbx.test',
    role: 'hub',
    active: false);
const _rafiq = StaffAccount(
    id: 'u1',
    name: 'Rafiq',
    email: 'rafiq@sbx.test',
    role: 'admin',
    active: true);

/// Scrolls the first list further down and saves what is shown.
Future<void> _scrollShot(WidgetTester tester, String name,
    {double dy = -600}) async {
  await tester.drag(find.byType(ListView).first, Offset(0, dy));
  await tester.pumpAndSettle();
  await _saveShot(tester, name);
}

/// The core business flow: Get paid, ticket and flyers, flight profit,
/// booking onto a flight, shipment costs and the add-cost sheet.
Future<void> _flowShots(WidgetTester tester, AppScope scope) async {
  await _shot(
      tester,
      _scoped(scope, AdminHomeScreen(dashboard: scope.dashboard), tab: 0),
      '41-flow-home',
      find.byType(AdminHomeScreen));
  await _scrollShot(tester, '41b-flow-home-end', dy: -500);
  await _shot(tester, _scoped(scope, const GetPaidScreen()), '42-get-paid',
      find.byType(GetPaidScreen));
  await _scrollShot(tester, '42b-get-paid-soon');
  await _scrollShot(tester, '42c-get-paid-monthly-list');
  await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
  await tester.pumpAndSettle();
  await _reveal(tester, find.byKey(const ValueKey('record-SH-21')));
  await tester.tap(find.byKey(const ValueKey('record-SH-21')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('received-Dhaka cash')));
  await tester.pumpAndSettle();
  await _saveShot(tester, '42d-record-payment');
  await _shot(tester, _scoped(scope, const GetPaidScreen(initialTab: 1)),
      '42e-get-paid-monthly', find.byType(GetPaidScreen));
  await _shot(
      tester,
      _scoped(scope, const TicketFlyersScreen(code: flowFlightCode)),
      '43-ticket-flyers',
      find.byType(TicketFlyersScreen));
  await _scrollShot(tester, '43b-ticket-flyers-split');
  await _scrollShot(tester, '43c-ticket-flyers-payments');
  await _shot(
      tester,
      _scoped(scope, const FlightDetailScreen(code: flowFlightCode)),
      '44-flight-profit',
      find.byType(FlightDetailScreen));
  await _scrollShot(tester, '44b-flight-profit-shipments');
  await _shot(
      tester,
      _scoped(
          scope, const IntakeScreen(lockedFlightCode: 'BG305-20261021-ab12cd')),
      '45-booking',
      find.byType(IntakeScreen));
  await tester.tap(find.text(tr('Choose a customer')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Nila Store'));
  await tester.pumpAndSettle();
  await _reveal(tester, find.text('General'));
  await tester.tap(find.text('General'));
  await tester.pumpAndSettle();
  await _reveal(tester, find.byKey(const Key('intake-kg')));
  await tester.enterText(find.byKey(const Key('intake-kg')), '6');
  await tester.enterText(find.byKey(const Key('intake-rate')), '950');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await _saveShot(tester, '45b-booking-charge');
  await _scrollShot(tester, '45c-booking-terms');
  await _shot(tester, _scoped(scope, const AdminShipmentScreen(code: 'SH-18')),
      '46-shipment-costs', find.byType(AdminShipmentScreen));
  await _scrollShot(tester, '46b-shipment-costs-checklist', dy: -420);
  await _scrollShot(tester, '46c-shipment-costs-profit', dy: -420);
  await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
  await tester.pumpAndSettle();
  await _reveal(tester, find.byKey(const ValueKey('cost-add-courier')));
  await tester.tap(find.byKey(const ValueKey('cost-add-courier')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('cost-account')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Dhaka cash').last);
  await tester.pumpAndSettle();
  await _saveShot(tester, '46d-add-cost');
  await _shot(tester, _scoped(scope, const FlightFormScreen()),
      '47-flight-form', find.byType(FlightFormScreen));
  await _reveal(tester, find.byKey(const Key('flight-flyers-pay')));
  await tester.tap(find.byKey(const Key('flight-flyers-pay')));
  await tester.pumpAndSettle();
  await _saveShot(tester, '47b-flight-form-who-pays');
}

/// The flow sheets and the booking at 320 px with 1.3× text.
Future<void> _flowCompactShots(WidgetTester tester, AppScope scope) async {
  await _shot(tester, _scoped(scope, const GetPaidScreen()),
      'compact-record-payment', find.byType(GetPaidScreen));
  await _reveal(tester, find.byKey(const ValueKey('record-SH-14')));
  await tester.tap(find.byKey(const ValueKey('record-SH-14')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('received-Dhaka cash')));
  await tester.pumpAndSettle();
  await _saveShot(tester, 'compact-record-payment');
  await _shot(tester, _scoped(scope, const AdminShipmentScreen(code: 'SH-18')),
      'compact-add-cost', find.byType(AdminShipmentScreen));
  await _reveal(tester, find.byKey(const ValueKey('cost-add-courier')));
  await tester.tap(find.byKey(const ValueKey('cost-add-courier')));
  await tester.pumpAndSettle();
  await _saveShot(tester, 'compact-add-cost');
  await tester.drag(
      find.byType(SingleChildScrollView).last, const Offset(0, -600));
  await tester.pumpAndSettle();
  await _saveShot(tester, 'compact-add-cost-end');
  await _shot(
      tester,
      _scoped(
          scope, const IntakeScreen(lockedFlightCode: 'BG305-20261021-ab12cd')),
      'compact-booking',
      find.byType(IntakeScreen));
  await tester.tap(find.text(tr('Choose a customer')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Nila Store'));
  await tester.pumpAndSettle();
  await _reveal(tester, find.text('Mobile'));
  await tester.tap(find.text('Mobile'));
  await tester.pumpAndSettle();
  await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
  await tester.pumpAndSettle();
  for (var i = 0; i < 5; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'compact-booking $i');
    await _saveShot(tester, 'compact-booking-$i');
  }
  await _saveShot(tester, 'compact-booking-end');
  await _shot(
      tester,
      _scoped(
          scope,
          const BookingDoneScreen(
              booking: BookedShipment(
                  code: 'SH-54',
                  customer: 'Nila Store',
                  kg: 6,
                  pieces: [('Mobile', 3), ('Laptop', 1)],
                  terms: 'monthly',
                  charge: 8400,
                  currency: 'BDT',
                  flightCode: 'BG305-20261021-ab12cd',
                  spaceLeftKg: 12.5))),
      'compact-booking-done',
      find.byType(BookingDoneScreen));
  await _shot(tester, _scoped(scope, const CustomerFormScreen()),
      'compact-customer-form', find.byType(CustomerFormScreen));
  await _scrollShot(tester, 'compact-customer-form-end');
  await _shot(
      tester,
      _scoped(scope, AdminHomeScreen(dashboard: scope.dashboard)),
      'compact-add-menu',
      find.byType(AdminHomeScreen));
  await tester.tap(find.byKey(const Key('home-add')));
  await tester.pumpAndSettle();
  await _saveShot(tester, 'compact-add-menu');
}

/// The same session on an API that books SH-54 and takes photo uploads.
AppScope _bookingScope(AppScope source) {
  var reservations = 0;
  final ApiClient api = screenFixtureApi(intercept: (request) async {
    final path = request.url.path;
    if (request.method == 'POST' && path == '/api/shipments') {
      return http.Response(jsonEncode({'code': 'SH-54'}), 200,
          headers: {'content-type': 'application/json'});
    }
    if (request.method == 'POST' && path.endsWith('/media/upload')) {
      reservations++;
      return http.Response(
          jsonEncode({
            'reference': 'ref-$reservations',
            'uploadUrl': 'https://storage.test/put/$reservations',
            'expiresAt': '2026-10-26T12:00:00.000Z'
          }),
          201,
          headers: {'content-type': 'application/json'});
    }
    if (request.method == 'POST' && path.endsWith('/track-link')) {
      return http.Response(
          jsonEncode({
            'url': 'https://track.example/t/sh54',
            'expiresAt': '2026-11-02T00:00:00.000Z'
          }),
          200,
          headers: {'content-type': 'application/json'});
    }
    if (request.method == 'PUT') return http.Response('', 200);
    if (path.endsWith('/complete')) return http.Response('{}', 200);
    return null;
  });
  return AppScope(
    session: source.session,
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
}

var _photoCount = 0;

/// Small coloured squares standing in for camera photos.
Future<List<PickedPhoto>> _samplePhotos(FileSource source) async {
  const colors = [(0xDD, 0xE5, 0xF2), (0xE4, 0xE0, 0xF2), (0xF2, 0xE7, 0xDC)];
  final pick = colors[_photoCount++ % colors.length];
  final image = img.Image(width: 96, height: 96);
  img.fill(image, color: img.ColorRgb8(pick.$1, pick.$2, pick.$3));
  return [
    PickedPhoto(
        bytes: Uint8List.fromList(img.encodeJpg(image)),
        name: 'photo-$_photoCount.jpg',
        mime: 'image/jpeg')
  ];
}

/// Decodes the thumbnails so they show in the screenshot.
Future<void> _decodeImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump();
}

/// Adds one sample photo with the add square [finder].
Future<void> _addPhoto(WidgetTester tester, Finder finder) async {
  await _reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(tr('Choose from gallery')));
  await tester.pumpAndSettle();
  await _decodeImages(tester);
}

/// Fills the one-page booking as drawn in the design: Nila Store, phones
/// and a laptop with photos, 6 kg at 950, monthly and a parcel photo.
Future<void> _fillBooking(WidgetTester tester) async {
  await tester.tap(find.text(tr('Choose a customer')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Nila Store'));
  await tester.pumpAndSettle();
  await _reveal(tester, find.text('General'));
  await tester.tap(find.text('General'));
  await tester.tap(find.text('Mobile'));
  await tester.tap(find.text('Laptop'));
  await tester.pumpAndSettle();
  await _reveal(tester, find.byKey(const ValueKey('Mobile-model-0')));
  await tester.enterText(
      find.byKey(const ValueKey('Mobile-model-0')), 'iPhone 13');
  await tester.tap(find.byTooltip(tr('One more')).first);
  await tester.pumpAndSettle();
  await _reveal(tester, find.byKey(const ValueKey('Mobile-add-model')));
  await tester.tap(find.byKey(const ValueKey('Mobile-add-model')));
  await tester.pumpAndSettle();
  await tester.enterText(
      find.byKey(const ValueKey('Mobile-model-1')), 'Redmi Note 12');
  await _addPhoto(
      tester, find.byTooltip(tr('Add {name} photos', {'name': 'Mobile'})));
  await _addPhoto(
      tester, find.byTooltip(tr('Add {name} photos', {'name': 'Mobile'})));
  await _reveal(tester, find.byKey(const ValueKey('Laptop-model-0')));
  await tester.enterText(
      find.byKey(const ValueKey('Laptop-model-0')), 'MacBook Air M2');
  await _addPhoto(
      tester, find.byTooltip(tr('Add {name} photos', {'name': 'Laptop'})));
  await _reveal(tester, find.byKey(const Key('intake-kg')));
  await tester.enterText(find.byKey(const Key('intake-kg')), '6');
  await tester.enterText(find.byKey(const Key('intake-rate')), '950');
  await tester.pumpAndSettle();
  await _reveal(tester, find.byKey(const Key('intake-terms-monthly')));
  await tester.tap(find.byKey(const Key('intake-terms-monthly')));
  await tester.pumpAndSettle();
  await _addPhoto(tester, find.byTooltip(tr('Add parcel photos')));
  await _reveal(tester, find.byKey(const Key('intake-description')));
  await tester.enterText(find.byKey(const Key('intake-description')),
      'Phones, a laptop and chargers');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

/// The overview, the Add menu, the customer and flyer forms and the team
/// entries in More.
Future<void> _quickShots(WidgetTester tester, AppScope scope) async {
  await _shot(
      tester,
      _scoped(scope, AdminHomeScreen(dashboard: scope.dashboard), tab: 0),
      '48-home',
      find.byType(AdminHomeScreen));
  await _scrollShot(tester, '48b-home-attention', dy: -520);
  await _scrollShot(tester, '48c-home-stages', dy: -520);
  await _scrollShot(tester, '48d-home-flights', dy: -520);
  await _shot(
      tester,
      _scoped(scope, AdminHomeScreen(dashboard: scope.dashboard), tab: 0),
      '49-add-menu',
      find.byType(AdminHomeScreen));
  await tester.tap(find.byKey(const Key('home-add')));
  await tester.pumpAndSettle();
  await _saveShot(tester, '49-add-menu');
  await _shot(tester, _scoped(scope, const CustomerFormScreen()),
      '50-customer-form', find.byType(CustomerFormScreen));
  final team = _teamScope(scope);
  await _shot(
      tester,
      _scoped(
          team,
          FlyerFormScreen(
              pickFile: (source) async => PickedPhoto(
                  bytes: Uint8List.fromList(utf8.encode('%PDF-1.4')),
                  name: 'student-id.pdf',
                  mime: 'application/pdf'))),
      '51-flyer-form',
      find.byType(FlyerFormScreen));
  final camera = find.descendant(
      of: find.byKey(const ValueKey('flyer-doc-student_id')),
      matching: find.text(tr('Camera')));
  await _reveal(tester, camera);
  await tester.tap(camera);
  await tester.pumpAndSettle();
  await _saveShot(tester, '51b-flyer-form-documents');
  await _shot(
      tester,
      _scoped(
          scope, MoreScreen(user: scope.session.user!, session: scope.session),
          tab: 4),
      '52-more-team',
      find.byType(MoreScreen));
  await _scrollShot(tester, '52-more-team', dy: -700);
}

/// Scrolls the first list until [finder] is built, then fully on screen.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 150,
      scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// Flyers, tasks, settings, staff, payment method, invoice and fund forms.
Future<void> _teamShots(WidgetTester tester, AppScope base) async {
  final team = _teamScope(base);
  await _shot(tester, _scoped(team, const FlyersScreen()), '30-flyers',
      find.byType(FlyersScreen));
  await _shot(
      tester,
      _scoped(team, const FlyerDetailScreen(name: 'Arif Rahman')),
      '31-flyer-detail',
      find.byType(FlyerDetailScreen));
  await _scrollShot(tester, '31b-flyer-documents', dy: -560);
  await _scrollShot(tester, '31c-flyer-flights', dy: -600);
  await _shot(tester, _scoped(team, const FlyerFormScreen()), '32-flyer-form',
      find.byType(FlyerFormScreen));
  await _shot(
      tester,
      _scoped(team, TasksScreen(role: UserRole.admin, tasks: team.tasks)),
      '33-tasks',
      find.byType(TasksScreen));
  await tester.tap(find.byTooltip(tr('New note')));
  await tester.pumpAndSettle();
  await _saveShot(tester, '33b-tasks-compose');
  await _shot(
      tester,
      _scoped(team, TasksScreen(role: UserRole.hub, tasks: team.tasks),
          tab: 3, hub: true),
      '34-hub-tasks',
      find.byType(TasksScreen));
  await _shot(tester, _scoped(team, const SettingsScreen()), '35-settings',
      find.byType(SettingsScreen));
  await _scrollShot(tester, '35b-settings-setup', dy: -600);
  await _shot(tester, _scoped(team, const StaffScreen()), '36-staff',
      find.byType(StaffScreen));
  await _shot(tester, _scoped(team, const StaffCreateScreen()),
      '37-staff-create', find.byType(StaffCreateScreen));
  await _shot(
      tester,
      _scoped(team, const StaffEditScreen(person: _jamal, selfId: 'u1')),
      '37b-staff-edit',
      find.byType(StaffEditScreen));
  await _shot(
      tester,
      _scoped(team, const StaffEditScreen(person: _rafiq, selfId: 'u1')),
      '37c-staff-edit-self',
      find.byType(StaffEditScreen));
  await _shot(tester, _scoped(team, const PayMethodFormScreen()),
      '38-pay-method', find.byType(PayMethodFormScreen));
  await tester.enterText(find.byType(TextField).at(1), '01900000000');
  await tester.enterText(find.byType(TextField).at(2), 'Business');
  await tester.enterText(find.byType(TextField).at(3),
      'Send Money only. Write your shipment code as the reference.');
  await tester.pumpAndSettle();
  await _scrollShot(tester, '38b-pay-method-preview', dy: -520);
  await _shot(
      tester,
      _scoped(team, const PayMethodFormScreen(initialKind: 'bank_account')),
      '38c-pay-method-bank',
      find.byType(PayMethodFormScreen));
  await _shot(tester, _scoped(team, const InvoiceEditorScreen(code: 'SH-18')),
      '39-invoice-draft', find.byType(InvoiceEditorScreen));
  await _scrollShot(tester, '39b-invoice-draft-end', dy: -600);
  await _shot(
      tester,
      _scoped(_teamScope(base, invoiceState: 'issued'),
          const InvoiceEditorScreen(code: 'SH-18')),
      '39c-invoice-issued',
      find.byType(InvoiceEditorScreen));
  await _shot(
      tester,
      _scoped(_teamScope(base, invoiceState: 'issued', needsReview: true),
          const InvoiceEditorScreen(code: 'SH-18')),
      '39d-invoice-review',
      find.byType(InvoiceEditorScreen));
  await tester.enterText(find.byType(TextField).at(6), '4250');
  await tester.pumpAndSettle();
  await _scrollShot(tester, '39e-invoice-free', dy: -420);
  await _shot(tester, _scoped(team, const FundAccountScreen()), '40-new-fund',
      find.byType(FundAccountScreen));
  await tester.enterText(find.byType(TextField).at(0), 'Office petty cash');
  await tester.enterText(find.byType(TextField).at(1), '5000');
  await tester.pumpAndSettle();
  await _saveShot(tester, '40b-new-fund-filled');
}

/// The same screens at 320 px with 1.3× text; nothing may overflow.
Future<void> _teamCompactShots(WidgetTester tester, AppScope base) async {
  final team = _teamScope(base);
  for (final entry in <String, Widget>{
    'compact-flyers': const FlyersScreen(),
    'compact-flyer-detail': const FlyerDetailScreen(name: 'Arif Rahman'),
    'compact-flyer-form': const FlyerFormScreen(),
    'compact-tasks': TasksScreen(role: UserRole.admin, tasks: team.tasks),
    'compact-team-settings': const SettingsScreen(),
    'compact-staff': const StaffScreen(),
    'compact-staff-edit': const StaffEditScreen(person: _jamal, selfId: 'u1'),
    'compact-pay-method': const PayMethodFormScreen(),
    'compact-pay-bank': const PayMethodFormScreen(initialKind: 'bank_account'),
    'compact-invoice': const InvoiceEditorScreen(code: 'SH-18'),
    'compact-new-fund': const FundAccountScreen(),
  }.entries) {
    await _shot(tester, _scoped(team, entry.value), entry.key,
        find.byType(entry.value.runtimeType));
    if (entry.value is TasksScreen) {
      await tester.tap(find.byTooltip(tr('New note')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '${entry.key} compose');
    }
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '${entry.key} scrolled');
    }
    await _saveShot(tester, '${entry.key}-end');
  }
}

Widget _scoped(AppScope source, Widget home, {int? tab, bool hub = false}) {
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
    child: MaterialApp(
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(_textScale)),
            child: child!),
        home: tab == null
            ? home
            : Scaffold(
                body: home,
                bottomNavigationBar: AppBottomNav(
                    index: home is MoreScreen ? 4 : tab,
                    admin:
                        !hub && home is! HubHomeScreen && home is! TasksScreen,
                    onChanged: (_) {}))),
  );
}

Future<void> _shot(
    WidgetTester tester, Widget app, String name, Finder finder) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester
      .pumpWidget(RepaintBoundary(key: const Key('capture'), child: app));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: name);
  expect(finder, findsOneWidget);
  await _saveShot(tester, name);
}

Future<void> _saveShot(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull, reason: name);
  final boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(const Key('capture')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory =
        Platform.environment['MOBILE_SCREENSHOT_DIR'] ?? 'docs/screenshots';
    final file = File('$directory/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
