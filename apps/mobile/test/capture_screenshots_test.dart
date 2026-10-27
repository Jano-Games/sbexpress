import 'support/screen_fixtures.dart';
import 'support/team_fixtures.dart';
import 'package:sbexpress/data/api/api_client.dart';
import 'package:sbexpress/data/models/workspace.dart';
import 'package:sbexpress/features/flyers/flyer_detail_screen.dart';
import 'package:sbexpress/features/flyers/flyer_form_screen.dart';
import 'package:sbexpress/features/flyers/flyers_screen.dart';
import 'package:sbexpress/features/admin/admin_shipment_screen.dart';
import 'package:sbexpress/features/flights/flight_detail_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:sbexpress/features/auth/login_screen.dart';
import 'package:sbexpress/features/auth/splash_screen.dart';
import 'package:sbexpress/features/hub/hub_home_screen.dart';
import 'package:sbexpress/features/imei/imei_guide_screen.dart';
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
import 'package:sbexpress/data/scan/mrz.dart';
import 'package:sbexpress/data/scan/read_text.dart';
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
import 'package:sbexpress/features/settings/pay_methods_screen.dart';
import 'package:sbexpress/data/session/biometrics.dart' show FingerprintFailure;
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

    // CAPTURE_ONLY=photos renders just the photo tray, grid and viewer.
    if (Platform.environment['CAPTURE_ONLY'] == 'photos') {
      await _photoShots(tester, scope);
      tester.view.physicalSize = const Size(320, 700);
      _textScale = 1.3;
      await _photoShots(tester, scope, compact: true);
      _textScale = 1;
      return;
    }

    // The splash's loading bar never settles, so pump a fixed time.
    await tester.pumpWidget(RepaintBoundary(
        key: const Key('capture'),
        child: _scoped(scope, const SplashScreen())));
    await tester.pump(const Duration(milliseconds: 800));
    await _saveShot(tester, '00-splash');
    await _shot(
        tester,
        _scoped(
            scope, LoginScreen(onSubmit: (email, password, remember) async {})),
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
    await _shot(tester, _scoped(scope, const PayMethodsScreen()),
        '21-pay-methods', find.byType(PayMethodsScreen));
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
    await _scrollShot(tester, '24b-shipment-billing');
    await _scrollShot(tester, '24c-shipment-payment');
    await _scrollShot(tester, '24d-shipment-share');
    await tester.tap(find.text(tr('Photos · {n}', {'n': 0})));
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
    await _round5Shots(tester, scope);
    await _round6Shots(tester, scope);
    await _round7bShots(tester, scope);
    await _round7aShots(tester, scope);
    await _scanShots(tester, scope);
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
    await _photoShots(tester, scope);
    tester.view.physicalSize = const Size(320, 700);
    _textScale = 1.3;
    for (final entry in <String, Widget>{
      'compact-home': AdminHomeScreen(dashboard: scope.dashboard),
      'compact-hub': HubHomeScreen(dashboard: scope.dashboard),
      'compact-shipments':
          ShipmentsScreen(role: UserRole.admin, shipments: scope.shipments),
      'compact-finance': const FinanceScreen(),
      'compact-pay-methods': const PayMethodsScreen(),
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
      'compact-login':
          LoginScreen(onSubmit: (email, password, remember) async {}),
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
    await _round5Shots(tester, scope, compact: true);
    await _round6Shots(tester, scope, compact: true);
    await _round7bShots(tester, scope, compact: true);
    await _round7aShots(tester, scope, compact: true);
    await _scanShots(tester, scope, compact: true);
    await _photoShots(tester, scope, compact: true);
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

/// The same session on an API that answers [intercept] before the fixtures.
AppScope _interceptScope(AppScope source,
    Future<http.Response?> Function(http.Request request) intercept) {
  final ApiClient api = screenFixtureApi(intercept: intercept);
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

/// Scrolls the first list until [finder] shows, up or down.
Future<void> _revealBy(WidgetTester tester, Finder finder, double dy) async {
  await tester.scrollUntilVisible(finder, dy,
      scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// Opens the account dropdown with [key] and picks Dhaka cash.
Future<void> _receivedInDhaka(WidgetTester tester, Key key) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await _revealBy(tester, find.byKey(key), 150);
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Dhaka cash · BDT').last);
  await tester.pumpAndSettle();
}

/// Round 5: flyers paying when a flight is saved, adding a flyer where one
/// is needed, the ticket's passenger as a new flyer, flyers missing
/// documents and the booking's new category. [compact] saves the 320 px
/// versions and checks each for overflow.
Future<void> _round5Shots(WidgetTester tester, AppScope scope,
    {bool compact = false}) async {
  final prefix = compact ? 'compact-r5' : '60';
  Future<void> scrollShots(String name) async {
    await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -420));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$name $i');
      await _saveShot(tester, '$name-$i');
    }
  }

  // A new flight whose two flyers pay part, one of them already.
  await _shot(tester, _scoped(_teamScope(scope), const FlightFormScreen()),
      '$prefix-a-flight-form-paid', find.byType(FlightFormScreen));
  for (final name in ['Arif Rahman', 'Rakib Hasan']) {
    await _revealBy(tester, find.text(name), 150);
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }
  final cost = find.byWidgetPredicate((w) =>
      w is TextField &&
      w.decoration?.labelText == tr('Actual ticket cost (BDT)'));
  await _revealBy(tester, cost, 150);
  await tester.enterText(cost, '42000');
  await tester.pumpAndSettle();
  await _revealBy(tester, find.byKey(const Key('flight-flyers-pay')), 150);
  await tester.tap(find.byKey(const Key('flight-flyers-pay')));
  await tester.pumpAndSettle();
  for (final (key, value) in [
    ('flight-part-Arif Rahman', '15000'),
    ('flight-part-Rakib Hasan', '15000'),
    ('flight-paid-Arif Rahman', '5000'),
  ]) {
    if (key.startsWith('flight-paid-')) {
      // A part payment's amount opens from "Part paid" beside the tick.
      final open = find.byKey(ValueKey('part-paid-${key.substring(12)}'));
      await _revealBy(tester, open, 150);
      await tester.tap(open);
      await tester.pumpAndSettle();
    }
    await _revealBy(tester, find.byKey(ValueKey(key)), 150);
    await tester.enterText(find.byKey(ValueKey(key)), value);
    await tester.pumpAndSettle();
  }
  await _receivedInDhaka(tester, const Key('flight-received-in'));
  await _revealBy(
      tester, find.byKey(const ValueKey('flight-part-Arif Rahman')), -150);
  await _saveShot(tester, '$prefix-a-flight-form-paid');
  if (compact) await scrollShots('$prefix-a-flight-form-paid');

  // An existing flight: Rakib pays 4,000 more now.
  await _shot(
      tester,
      _scoped(scope, const TicketFlyersScreen(code: flowFlightCode)),
      '$prefix-b-ticket-flyers-paid',
      find.byType(TicketFlyersScreen));
  final rakibPart = find.byKey(const ValueKey('part-paid-Rakib Hasan'));
  await _revealBy(tester, rakibPart, 150);
  await tester.tap(rakibPart);
  await tester.pumpAndSettle();
  await _revealBy(tester, find.byKey(const ValueKey('paid-Rakib Hasan')), 150);
  await tester.enterText(
      find.byKey(const ValueKey('paid-Rakib Hasan')), '4000');
  await tester.pumpAndSettle();
  await _receivedInDhaka(tester, const Key('ticket-received-in'));
  await _revealBy(tester, find.byKey(const ValueKey('part-Arif Rahman')), -150);
  await _saveShot(tester, '$prefix-b-ticket-flyers-paid');
  await tester.tap(find.byKey(const Key('ticket-save')));
  await tester.pumpAndSettle();
  await _saveShot(tester, '$prefix-c-flyer-payments-confirm');
  await tester.tap(find.text(tr('Go back')));
  await tester.pumpAndSettle();

  // A ticket whose passenger is nobody yet.
  final unmatched = _interceptScope(scope, (request) async {
    if (request.url.path != '/api/flights/ticket') return null;
    final body = ticketImportBody();
    body['ticket'] = {
      ...(body['ticket'] as Map<String, Object?>),
      'passenger': 'SHAHRIAR / MD RIFAT SD',
    };
    body['flyerMatches'] = <Object>[];
    return http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});
  });
  await _shot(
      tester,
      _scoped(unmatched,
          TicketImportScreen(pickPdf: () async => utf8.encode('%PDF-1.4'))),
      '$prefix-d-ticket-new-flyer',
      find.byType(TicketImportScreen));
  await tester.tap(find.byKey(const Key('ticket-pick')));
  await tester.pumpAndSettle();
  await _revealBy(tester, find.byKey(const Key('ticket-add-flyer')), 150);
  await _saveShot(tester, '$prefix-d-ticket-new-flyer');
  await tester.tap(find.byKey(const Key('ticket-add-flyer')));
  await tester.pumpAndSettle();
  await _saveShot(tester, '$prefix-e-flyer-form-prefilled');

  // Flyers missing documents on Home.
  await _shot(
      tester,
      _scoped(scope, AdminHomeScreen(dashboard: scope.dashboard), tab: 0),
      '$prefix-f-home-documents',
      find.byType(AdminHomeScreen));
  await _revealBy(tester, find.byKey(const Key('attention-docs-more')), 150);
  await _saveShot(tester, '$prefix-f-home-documents');

  // The booking's categories: + New, then its input.
  await _shot(tester, _scoped(scope, const IntakeScreen()),
      '$prefix-g-booking-categories', find.byType(IntakeScreen));
  await _revealBy(tester, find.byKey(const Key('intake-cargo')), 150);
  await _saveShot(tester, '$prefix-g-booking-categories');
  await tester.tap(find.byKey(const Key('intake-new-category')));
  await tester.pumpAndSettle();
  await _saveShot(tester, '$prefix-h-booking-new-category');
}

/// Round 7 part B: the one-page shipment (scrolled through), the cost on
/// the bill and new customer link sheets, the flight with its costs and the
/// add-flight-cost sheet, all on a round 7 server. [compact] saves the
/// 320 px versions and checks each for overflow.
Future<void> _round7bShots(WidgetTester tester, AppScope scope,
    {bool compact = false}) async {
  final prefix = compact ? 'compact-r7b' : '90';
  final r7 = _interceptScope(scope, (request) async {
    if (request.method != 'GET') return null;
    final body = switch (request.url.path) {
      '/api/shipments/SH-18' => round7ShipmentBody(),
      '/api/shipments/SH-18/invoice' => round7InvoiceBody(),
      '/api/flights/$flowFlightCode' => round7FlightBody(),
      _ => null,
    };
    return body == null
        ? null
        : http.Response.bytes(utf8.encode(jsonEncode(body)), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
  });

  /// Scrolls down the page [steps] times, saving each view.
  Future<void> scrollThrough(String name, int steps) async {
    for (var i = 0; i < steps; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -560));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$name $i');
      await _saveShot(tester, '$name-$i');
    }
  }

  /// Scrolls an open sheet to its end and saves it.
  Future<void> sheetEnd(String name) async {
    await tester.drag(
        find.byType(SingleChildScrollView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: name);
    await _saveShot(tester, name);
  }

  // The shipment, top to bottom.
  await _shot(tester, _scoped(r7, const AdminShipmentScreen(code: 'SH-18')),
      '$prefix-a-shipment', find.byType(AdminShipmentScreen));
  await scrollThrough('$prefix-a-shipment', compact ? 9 : 6);

  // Adding a cost to the bill.
  await _shot(tester, _scoped(r7, const AdminShipmentScreen(code: 'SH-18')),
      '$prefix-b-add-shipment-cost', find.byType(AdminShipmentScreen));
  await _revealBy(tester, find.byKey(const Key('bill-cost-add')), 300);
  await tester.tap(find.byKey(const Key('bill-cost-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('cost-courier')));
  await tester.enterText(find.byKey(const Key('cost-amount')), '300');
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('cost-account')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('pay-from-Dhaka cash')));
  await tester.pumpAndSettle();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await _saveShot(tester, '$prefix-b-add-shipment-cost');
  await sheetEnd('$prefix-b-add-shipment-cost-end');
  Navigator.of(tester.element(find.byKey(const Key('cost-save')))).pop();
  await tester.pumpAndSettle();

  // A new customer link.
  await _revealBy(tester, find.byKey(const Key('link-new')), 300);
  await tester.tap(find.byKey(const Key('link-new')));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: '$prefix-c-new-link');
  await _saveShot(tester, '$prefix-c-new-link');
  Navigator.of(tester.element(find.byKey(const Key('link-make')))).pop();
  await tester.pumpAndSettle();

  // The flight with its costs.
  await _shot(
      tester,
      _scoped(r7, const FlightDetailScreen(code: flowFlightCode)),
      '$prefix-d-flight',
      find.byType(FlightDetailScreen));
  await scrollThrough('$prefix-d-flight', compact ? 6 : 4);

  // Adding a flight cost: labour, paid from Dhaka cash; then a new name.
  await _shot(
      tester,
      _scoped(r7, const FlightDetailScreen(code: flowFlightCode)),
      '$prefix-e-add-flight-cost',
      find.byType(FlightDetailScreen));
  await _revealBy(tester, find.byKey(const Key('flight-cost-add')), 300);
  await tester.tap(find.byKey(const Key('flight-cost-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('flight-cost-transport')));
  await tester.enterText(find.byKey(const Key('flight-cost-amount')), '900');
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('flight-cost-account')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('pay-from-Dhaka cash')));
  await tester.pumpAndSettle();
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await _saveShot(tester, '$prefix-e-add-flight-cost');
  await sheetEnd('$prefix-e-add-flight-cost-end');
  await tester.ensureVisible(find.byKey(const Key('flight-cost-new')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('flight-cost-new')));
  await tester.pumpAndSettle();
  await tester.enterText(
      find.byKey(const Key('flight-cost-label')), 'Loading crew');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: '$prefix-f-flight-cost-new');
  await _saveShot(tester, '$prefix-f-flight-cost-new');
  Navigator.of(tester.element(find.byKey(const Key('flight-cost-save')))).pop();
  await tester.pumpAndSettle();
}

/// Round 6: the quiet delete on flights, shipments, flyers and customers,
/// its confirm and the server's refusal (with "Archive instead" for
/// profiles), archived profiles with Restore, the Active / Archived lists and
/// an older server that cannot archive customers. [compact] saves the 320 px
/// versions and checks each for overflow.
Future<void> _round6Shots(WidgetTester tester, AppScope scope,
    {bool compact = false}) async {
  final prefix = compact ? 'compact-r6' : '70';
  final r6 = _round6Scope(scope);

  /// Scrolls to the end, checking nothing overflows on the way.
  Future<void> toEnd(String name) async {
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$name $i');
    }
    await _saveShot(tester, name);
  }

  Future<void> tapShot(Key key, String name) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: name);
    await _saveShot(tester, name);
  }

  /// "Go back" or "Close" in the open dialog.
  Future<void> closeDialog() async {
    await tester.tap(find
        .descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextButton))
        .first);
    await tester.pumpAndSettle();
  }

  // A flight: the delete at the end, its confirm and the refusal.
  await _shot(
      tester,
      _scoped(r6, const FlightDetailScreen(code: 'BG305-20261021-ab12cd')),
      '$prefix-a-flight-delete',
      find.byType(FlightDetailScreen));
  await toEnd('$prefix-a-flight-delete');
  await tapShot(const Key('flight-delete'), '$prefix-b-flight-delete-confirm');
  await tapShot(const Key('remove-confirm'), '$prefix-c-flight-delete-refused');
  await closeDialog();

  // A shipment: the delete at the end of Summary.
  await _shot(tester, _scoped(r6, const AdminShipmentScreen(code: 'SH-18')),
      '$prefix-d-shipment-delete', find.byType(AdminShipmentScreen));
  await toEnd('$prefix-d-shipment-delete');
  await tapShot(
      const Key('shipment-delete'), '$prefix-e-shipment-delete-confirm');
  await closeDialog();

  // A flyer: archive and delete; a refused delete offers to archive.
  await _shot(tester, _scoped(r6, const FlyerDetailScreen(name: 'Arif Rahman')),
      '$prefix-f-flyer-end', find.byType(FlyerDetailScreen));
  await toEnd('$prefix-f-flyer-end');
  await tapShot(
      const Key('profile-archive'), '$prefix-g-flyer-archive-confirm');
  await closeDialog();
  await tapShot(const Key('profile-delete'), '$prefix-h-flyer-delete-confirm');
  await tapShot(const Key('remove-confirm'), '$prefix-i-flyer-delete-refused');
  await closeDialog();

  // An archived flyer: the chip and Restore.
  await _shot(tester, _scoped(r6, const FlyerDetailScreen(name: 'Nadia Islam')),
      '$prefix-j-flyer-archived', find.byType(FlyerDetailScreen));
  await toEnd('$prefix-j-flyer-archived-end');

  // The flyers list: Active, then Archived.
  await _shot(tester, _scoped(r6, const FlyersScreen()),
      '$prefix-k-flyers-active', find.byType(FlyersScreen));
  await tester.tap(find.text(tr('Archived · {n}', {'n': 1})));
  await tester.pumpAndSettle();
  await _saveShot(tester, '$prefix-l-flyers-archived');

  // A customer: archive and delete at the end of Summary.
  await _shot(tester, _scoped(r6, const CustomerDetailScreen(code: 'C-14')),
      '$prefix-m-customer-end', find.byType(CustomerDetailScreen));
  await toEnd('$prefix-m-customer-end');
  await tapShot(
      const Key('profile-archive'), '$prefix-n-customer-archive-confirm');
  await closeDialog();
  await tapShot(
      const Key('profile-delete'), '$prefix-o-customer-delete-confirm');
  await tapShot(
      const Key('remove-confirm'), '$prefix-p-customer-delete-refused');
  await closeDialog();

  // An archived customer: the chip in the header and Restore.
  await _shot(tester, _scoped(r6, const CustomerDetailScreen(code: 'C-31')),
      '$prefix-q-customer-archived', find.byType(CustomerDetailScreen));
  await toEnd('$prefix-q-customer-archived-end');

  // The customers list: Active, then Archived.
  await _shot(tester, _scoped(r6, const CustomersScreen()),
      '$prefix-r-customers-active', find.byType(CustomersScreen));
  await tester.tap(find.text(tr('Archived · {n}', {'n': 1})));
  await tester.pumpAndSettle();
  await _saveShot(tester, '$prefix-s-customers-archived');

  // An older server answers 404 to the customer archive.
  await _shot(
      tester,
      _scoped(_round6Scope(scope, outdated: true),
          const CustomerDetailScreen(code: 'C-14')),
      '$prefix-t-customer-archive-outdated',
      find.byType(CustomerDetailScreen));
  await toEnd('$prefix-t-customer-archive-outdated');
  await tester.tap(find.byKey(const Key('profile-archive')));
  await tester.pumpAndSettle();
  await tapShot(
      const Key('remove-confirm'), '$prefix-t-customer-archive-outdated');
  await closeDialog();
}

const _r6ArchivedAt = '2026-10-20T08:00:00.000Z';

/// The fixtures plus an archived flyer (Nadia Islam) and customer (Sky
/// Mobile, C-31). Every delete is refused as the server would; [outdated]
/// answers archive calls with 404 like an older server.
AppScope _round6Scope(AppScope source, {bool outdated = false}) {
  Map<String, Object?> customer(String code, String name,
      {bool settled = true, String? archivedAt}) {
    final row = Map<String, Object?>.from(
        customerDetailBody()['supplier'] as Map<String, Object?>)
      ..remove('orders')
      ..remove('payments')
      ..remove('invoices');
    return {
      ...row,
      'code': code,
      'name': name,
      if (settled) ...{
        'balance': 0,
        'billed': row['paid'],
        'pricingPending': 0,
      },
      'archivedAt': archivedAt,
    };
  }

  final ApiClient api = screenFixtureApi(intercept: (request) async {
    final path = Uri.decodeComponent(request.url.path);
    Object? body;
    var status = 200;
    if (request.method == 'DELETE') {
      status = 400;
      body = {
        'error': path.startsWith('/api/flights/')
            ? 'BG305-20261021-ab12cd has 2 booking(s) — move or delete them first'
            : path.startsWith('/api/shipments/')
                ? 'Financial history exists; this shipment cannot be deleted'
                : path.startsWith('/api/flyers/')
                    ? 'This flyer has shipment or settlement history. Archive the profile instead.'
                    : 'C-14 has 4 shipment(s) — delete or reassign them first'
      };
    } else if (request.method == 'POST' && path.endsWith('/archive')) {
      if (outdated) return http.Response('404 Not Found', 404);
      body = {'ok': true};
    } else if (path == '/api/flyers') {
      body = {
        'flyers': [
          ...teamFlyers(),
          {
            ...teamFlyers().last,
            'name': 'Nadia Islam',
            'firstName': 'Nadia',
            'lastName': 'Islam',
            'archivedAt': _r6ArchivedAt,
          },
        ]
      };
    } else if (path == '/api/flyers/Nadia Islam') {
      body = {
        'flyer': {
          ...teamFlyerDetail(),
          'name': 'Nadia Islam',
          'firstName': 'Nadia',
          'lastName': 'Islam',
          'archivedAt': _r6ArchivedAt,
        }
      };
    } else if (path == '/api/suppliers') {
      body = {
        'suppliers': [
          customer('C-14', 'Nila Store', settled: false),
          customer('C-15', 'Rahman Traders'),
          customer('C-31', 'Sky Mobile', archivedAt: _r6ArchivedAt),
        ]
      };
    } else if (path == '/api/suppliers/C-31') {
      final detail = customerDetailBody(archivedAt: _r6ArchivedAt);
      body = {
        'supplier': {
          ...detail['supplier'] as Map<String, Object?>,
          'code': 'C-31',
          'name': 'Sky Mobile',
        }
      };
    }
    if (body == null) return teamFixtures(request);
    return http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json; charset=utf-8'});
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
  await _scrollShot(tester, '46b-shipment-costs-bill', dy: -420);
  await _scrollShot(tester, '46c-shipment-costs-profit', dy: -420);
  await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
  await tester.pumpAndSettle();
  await _reveal(tester, find.byKey(const Key('bill-cost-add')));
  await tester.tap(find.byKey(const Key('bill-cost-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('cost-courier')));
  await tester.enterText(find.byKey(const Key('cost-amount')), '300');
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('cost-account')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('pay-from-Dhaka cash')));
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
  await _reveal(tester, find.byKey(const Key('bill-cost-add')));
  await tester.tap(find.byKey(const Key('bill-cost-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('cost-courier')));
  await tester.enterText(find.byKey(const Key('cost-amount')), '300');
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

/// The passport and visa scan on the new flyer form: filled from the
/// passport, the photo in Documents, Reading…, unreadable and the question
/// before a typed name is replaced.
Future<void> _scanShots(WidgetTester tester, AppScope scope,
    {bool compact = false}) async {
  final prefix = compact ? 'compact-scan' : '80';
  final team = _teamScope(scope);
  const page = [
    'Passport',
    "PEOPLE'S REPUBLIC OF BANGLADESH",
    'P<BGDSHAHRIAR<<MD<RIFAT<<<<<<<<<<<<<<<<<<<<<',
    'A012345678BGD0102030M3001019<<<<<<<<<<<<<<08',
  ];
  Future<PickedPhoto?> pick(FileSource source) async => PickedPhoto(
      bytes: Uint8List.fromList(img.encodeJpg(img.Image(width: 4, height: 3))),
      name: 'passport.jpg',
      mime: 'image/jpeg');
  Widget form(ScanTravelDocument scan) =>
      FlyerFormScreen(pickFile: pick, scanDocument: scan);
  Future<void> tapScan() async {
    await tester.tap(find.byKey(const Key('scan-camera')));
    await tester.pumpAndSettle();
  }

  Future<void> scrollChecks(String name) async {
    if (!compact) return;
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$name scrolled');
    }
  }

  await _shot(
      tester,
      _scoped(team, form((photo) async => readMrz(page.join('\n')))),
      '$prefix-a-flyer-scan',
      find.byType(FlyerFormScreen));
  await tapScan();
  await _saveShot(tester, '$prefix-a-flyer-scan');
  await _reveal(tester, find.byKey(const ValueKey('flyer-doc-passport')));
  await _saveShot(tester, '$prefix-b-flyer-scan-documents');
  await scrollChecks('$prefix-b-flyer-scan-documents');

  final reading = Completer<MrzReading?>();
  await _shot(tester, _scoped(team, form((photo) => reading.future)),
      '$prefix-c-flyer-scan-reading', find.byType(FlyerFormScreen));
  await tester.tap(find.byKey(const Key('scan-camera')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await _saveShot(tester, '$prefix-c-flyer-scan-reading');
  reading.complete(null);
  await tester.pumpAndSettle();
  await _saveShot(tester, '$prefix-d-flyer-scan-unreadable');
  await scrollChecks('$prefix-d-flyer-scan-unreadable');

  await _shot(
      tester,
      _scoped(team, form((photo) async => readMrz(page.join('\n')))),
      '$prefix-e-flyer-scan-replace',
      find.byType(FlyerFormScreen));
  await tester.enterText(find.byType(TextField).at(0), 'Rifat');
  await tapScan();
  await _saveShot(tester, '$prefix-e-flyer-scan-replace');
  await tester.tap(find.byKey(const Key('scan-replace')));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: '$prefix-e replaced');
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
  await _shot(tester, _scoped(team, const PayMethodsScreen()), '35-pay-methods',
      find.byType(PayMethodsScreen));
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
    'compact-team-pay-methods': const PayMethodsScreen(),
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

/// Round 7, part A: sign-in with remember me and fingerprint, the one-list
/// More with its rate and weight sheets, and late payments in Home → Needs
/// attention. Nothing may overflow, also at 320 px with 1.3× text.
Future<void> _round7aShots(WidgetTester tester, AppScope scope,
    {bool compact = false}) async {
  final prefix = compact ? 'compact-r7a' : 'r7a';
  final session = scope.session;
  final admin = session.user!;

  Future<void> toEnd(String name) async {
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$name $i');
    }
    await _saveShot(tester, name);
  }

  Future<void> toTop() async {
    await tester.drag(find.byType(ListView).first, const Offset(0, 4000));
    await tester.pumpAndSettle();
  }

  // Sign-in without a fingerprint key, then with one.
  await _shot(
      tester,
      _scoped(
          scope, LoginScreen(onSubmit: (email, password, remember) async {})),
      '$prefix-a-login',
      find.byType(LoginScreen));
  await toEnd('$prefix-a-login-end');
  await _shot(
      tester,
      _scoped(
          scope,
          LoginScreen(
              onSubmit: (email, password, remember) async {},
              fingerprint: FingerprintLogin(
                  firstName: 'Sadia',
                  email: 'sadia@sbexpress.com',
                  signIn: () async => throw FingerprintFailure(tr(
                      'Fingerprint sign-in was turned off. Sign in with your password.'))))),
      '$prefix-b-login-fingerprint',
      find.byType(LoginScreen));
  await toEnd('$prefix-b-login-fingerprint-end');
  await toTop();
  await tester.ensureVisible(find.byKey(const Key('login-fingerprint')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('login-fingerprint')));
  await tester.pumpAndSettle();
  await toEnd('$prefix-c-login-fingerprint-error');

  // More with fingerprint sign-in on, the system check and both sheets.
  session.fingerprint =
      FingerprintOwner(id: admin.id, name: admin.name, email: admin.email);
  await _shot(
      tester,
      _scoped(scope, MoreScreen(user: admin, session: session), tab: 4),
      '$prefix-d-more',
      find.byType(MoreScreen));
  await toEnd('$prefix-d-more-end');
  final system = find.text(tr('System check'));
  await _revealBy(tester, system, -150);
  await tester.tap(system);
  await tester.pumpAndSettle();
  await toEnd('$prefix-e-more-system');
  await toTop();
  final change = find.text(tr('Change'));
  await _revealBy(tester, change, 150);
  await tester.tap(change);
  await tester.pumpAndSettle();
  await _saveShot(tester, '$prefix-f-rate-sheet');
  await tester.tap(find.byTooltip(tr('Close')));
  await tester.pumpAndSettle();
  final weight = find.text('0.5 kg');
  await _revealBy(tester, weight, 150);
  await tester.tap(weight);
  await tester.pumpAndSettle();
  await _saveShot(tester, '$prefix-g-weight-sheet');
  await tester.tap(find.byTooltip(tr('Close')));
  await tester.pumpAndSettle();
  session.fingerprint = null;
  await _shot(
      tester,
      _scoped(
          scope,
          MoreScreen(
              user: const SessionUser(
                  id: 'h1',
                  name: 'Mina Akter',
                  email: 'mina@sbx.test',
                  role: UserRole.hub,
                  roleLabel: 'Hub Manager · Dhaka'),
              session: session),
          tab: 4,
          hub: true),
      '$prefix-h-more-hub',
      find.byType(MoreScreen));
  await toEnd('$prefix-h-more-hub-end');

  // Home → Needs attention with both kinds of late payment.
  final late = _interceptScope(scope, (request) async {
    if (request.url.path != '/api/dashboard/overview') return null;
    return http.Response(jsonEncode(_lateOverview()), 200,
        headers: {'content-type': 'application/json'});
  });
  await _shot(
      tester,
      _scoped(late, AdminHomeScreen(dashboard: late.dashboard), tab: 0),
      '$prefix-i-home',
      find.byType(AdminHomeScreen));
  final attention = find.text(tr('Needs attention'));
  await _revealBy(tester, attention, 150);
  await tester.runAsync(() =>
      Scrollable.ensureVisible(tester.element(attention), alignment: 0.05));
  await tester.pumpAndSettle();
  await _saveShot(tester, '$prefix-i-home-attention');
  await toEnd('$prefix-j-home-end');
}

/// The overview with late payments of both kinds, three in all.
Map<String, Object?> _lateOverview() => {
      ...overviewBody(),
      'latePayments': [
        {
          'kind': 'after_delivery',
          'customerCode': 'C-21',
          'customerName': 'Bismillah Telecom',
          'shipmentCode': 'SH-14',
          'amount': 6300,
          'days': 12,
          'since': '2026-10-15',
        },
        {
          'kind': 'monthly',
          'customerCode': 'C-15',
          'customerName': 'Rahman Traders',
          'month': '2026-09',
          'monthLabel': 'September 2026',
          'amount': 15400,
          'days': 27,
        },
      ],
      'latePaymentsCount': 3,
    };

/// A stored photo for the photo shots.
Map<String, Object?> _shotMedia(String reference, String name,
        {bool shared = false, String? category}) =>
    {
      'reference': reference,
      'name': name,
      'contentType': 'image/jpeg',
      'size': 182000,
      'shared': shared,
      'deviceCategory': category,
    };

/// A plain coloured picture with a lighter box, standing in for a parcel
/// or device photo; [seed] picks the colours.
Uint8List _shotPicture(String seed, {int width = 360, int height = 270}) {
  const palettes = [
    ((0xB9, 0x8E, 0x62), (0xD9, 0xBC, 0x94)),
    ((0x5E, 0x78, 0x9C), (0x9F, 0xB4, 0xD0)),
    ((0x6F, 0x8F, 0x6A), (0xB2, 0xC9, 0xA6)),
    ((0x8C, 0x6A, 0x9C), (0xC7, 0xB0, 0xD4)),
    ((0x4E, 0x55, 0x60), (0x9A, 0xA2, 0xAE)),
  ];
  final (back, box) =
      palettes[seed.codeUnits.fold<int>(0, (a, b) => a + b) % palettes.length];
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(back.$1, back.$2, back.$3));
  img.fillRect(image,
      x1: width ~/ 5,
      y1: height ~/ 4,
      x2: width * 4 ~/ 5,
      y2: height * 4 ~/ 5,
      color: img.ColorRgb8(box.$1, box.$2, box.$3),
      radius: 10);
  return Uint8List.fromList(img.encodeJpg(image, quality: 85));
}

/// Uploads close their request stream outside the fake clock; give each
/// one a moment of real time.
Future<void> _settleShotUploads(WidgetTester tester) async {
  for (var i = 0;
      i < 40 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Photos: picked photos waiting in the tray, one that did not upload, the
/// grid of uploaded photos from signed links grouped by device, the
/// full-screen viewer with "Show to customer", the discard question, hub's
/// view, the IMEI photo and an older server without photo links. [compact]
/// saves the 320 px versions; nothing may overflow.
Future<void> _photoShots(WidgetTester tester, AppScope scope,
    {bool compact = false}) async {
  final prefix = compact ? 'compact-photos' : 'photos';
  var links = true;
  final failing = <String>{};
  final reserved = <String>[];
  final media = [
    _shotMedia('p-1', 'parcel-1.jpg', shared: true),
    _shotMedia('p-2', 'parcel-2.jpg'),
    _shotMedia('m-1', 'mobile-1.jpg', category: 'Mobile'),
    _shotMedia('m-2', 'mobile-2.jpg', category: 'Mobile', shared: true),
    _shotMedia('l-1', 'laptop-1.jpg', category: 'Laptop'),
  ];
  http.Response json(Object body, [int status = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), status,
          headers: {'content-type': 'application/json; charset=utf-8'});
  // A new scope starts with no signed links cached.
  AppScope server() => _interceptScope(scope, (request) async {
        final path = Uri.decodeComponent(request.url.path);
        final parts = path.split('/');
        if (request.url.host == 'storage.test') {
          if (request.method == 'PUT') {
            final refused =
                failing.contains(reserved[int.parse(parts.last) - 1]);
            return http.Response(refused ? 'refused' : '', refused ? 500 : 200);
          }
          return http.Response.bytes(_shotPicture(parts.last), 200,
              headers: {'content-type': 'image/jpeg'});
        }
        if (request.method == 'GET' && path == '/api/shipments/SH-18/media') {
          return json({'configured': true, 'media': media});
        }
        if (request.method == 'GET' && path.endsWith('/url')) {
          if (!links) return http.Response('404 Not Found', 404);
          return json(
              {'url': 'https://storage.test/get/${parts[parts.length - 2]}'});
        }
        if (request.method == 'POST' &&
            (path.endsWith('/media/upload') ||
                path.endsWith('/device-photo'))) {
          final body = jsonDecode(request.body) as Map<String, Object?>;
          reserved.add(body['name']! as String);
          return json({
            'reference': 'new-${reserved.length}',
            'uploadUrl': 'https://storage.test/put/${reserved.length}',
            'expiresAt': '2026-10-27T12:00:00.000Z'
          }, 201);
        }
        if (request.method == 'POST' && path.endsWith('/complete')) {
          return json({'ok': true, 'reference': parts[parts.length - 2]});
        }
        return null;
      });
  final photos = server();
  var picks = 0;
  Future<List<PickedPhoto>> pick(FileSource source) async => [
        for (var i = 0; i < (source == FileSource.camera ? 1 : 3); i++)
          PickedPhoto(
              bytes: _shotPicture('tray-${picks++}', width: 300, height: 400),
              name: 'tray-$picks.jpg',
              mime: 'image/jpeg')
      ];
  Future<void> reveal(Finder finder, [double dy = 200]) async {
    await _revealBy(tester, finder, dy);
    await _decodeImages(tester);
  }

  // Picked photos wait in the tray; nothing is sent yet.
  await _shot(
      tester,
      _scoped(photos,
          AdminShipmentScreen(code: 'SH-18', initialTab: 2, pickPhotos: pick)),
      '$prefix-a-tray',
      find.byType(AdminShipmentScreen));
  await tester.tap(find.byKey(const Key('photo-gallery')));
  await tester.pumpAndSettle();
  await _decodeImages(tester);
  await _saveShot(tester, '$prefix-a-tray');
  await reveal(find.byKey(const Key('tray-clear')));
  await _saveShot(tester, '$prefix-a-tray-end');

  // The uploaded photos below, grouped.
  await reveal(find.byKey(const ValueKey('photo-tile-l-1')));
  await _saveShot(tester, '$prefix-b-grid');

  // Leaving with photos in the tray asks first.
  await tester.tap(find.byTooltip(tr('Back')));
  await tester.pumpAndSettle();
  await _saveShot(tester, '$prefix-c-discard');
  await tester.tap(find.byKey(const Key('tray-discard-cancel')));
  await tester.pumpAndSettle();

  // One photo storage refuses stays with its reason and Try again.
  failing.add('tray-2.jpg');
  await _revealBy(tester, find.byKey(const Key('tray-upload')), -200);
  await tester.tap(find.byKey(const Key('tray-upload')));
  await tester.pump();
  await _settleShotUploads(tester);
  final problem = find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('tray-error-');
  });
  await _revealBy(tester, problem, -200);
  await tester.runAsync(
      () => Scrollable.ensureVisible(tester.element(problem), alignment: 0.6));
  await tester.pumpAndSettle();
  await _decodeImages(tester);
  await _saveShot(tester, '$prefix-d-tray-failed');

  // The viewer: swipe, the group, and the customer switch.
  await reveal(find.byKey(const ValueKey('photo-tile-p-1')));
  await tester.tap(find.byKey(const ValueKey('photo-tile-p-1')));
  await tester.pumpAndSettle();
  await _decodeImages(tester);
  await _saveShot(tester, '$prefix-e-viewer');
  await tester.fling(
      find.byKey(const Key('viewer-pages')), const Offset(-300, 0), 1000);
  await tester.pumpAndSettle();
  await tester.fling(
      find.byKey(const Key('viewer-pages')), const Offset(-300, 0), 1000);
  await tester.pumpAndSettle();
  await _decodeImages(tester);
  await _saveShot(tester, '$prefix-e-viewer-mobile');

  // Hub staff see the same grid, without the switch.
  await _shot(
      tester,
      _scoped(photos, const ShipmentProcessScreen(code: 'SH-18')),
      '$prefix-f-hub',
      find.byType(ShipmentProcessScreen));
  await reveal(find.byKey(const ValueKey('photo-tile-l-1')), 300);
  await _saveShot(tester, '$prefix-f-hub');

  // The IMEI photo of a unit, and a new one waiting for Upload.
  await _shot(
      tester,
      _scoped(
          photos,
          ImeiGuideScreen(
              code: 'SH-18',
              unit: const DeviceUnitRef(
                  itemIndex: 0,
                  unitIndex: 0,
                  category: 'Mobile',
                  model: 'Galaxy A15',
                  serial: '356938035643809',
                  hasPhoto: true,
                  photoRef: 'imei-1'),
              pickPhotos: pick)),
      '$prefix-g-imei',
      find.byType(ImeiGuideScreen));
  await _decodeImages(tester);
  await _saveShot(tester, '$prefix-g-imei');
  await reveal(find.byKey(const Key('photo-camera')));
  await tester.tap(find.byKey(const Key('photo-camera')));
  await tester.pumpAndSettle();
  await reveal(find.byKey(const Key('tray-clear')));
  await _saveShot(tester, '$prefix-g-imei-tray');

  // An older server without photo links keeps the list.
  links = false;
  await _shot(
      tester,
      _scoped(
          server(), const AdminShipmentScreen(code: 'SH-18', initialTab: 2)),
      '$prefix-h-old-server',
      find.byType(AdminShipmentScreen));
  await reveal(find.byKey(const Key('photos-need-update')));
  await _saveShot(tester, '$prefix-h-old-server');
  links = true;
}
