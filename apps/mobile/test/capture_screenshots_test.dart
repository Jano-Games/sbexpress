import 'support/screen_fixtures.dart';
import 'package:sbexpress/features/admin/admin_shipment_screen.dart';
import 'package:sbexpress/features/flights/flight_detail_screen.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:sbexpress/features/auth/login_screen.dart';
import 'package:sbexpress/features/hub/hub_home_screen.dart';
import 'package:sbexpress/features/flights/hub_flights_screen.dart';
import 'package:sbexpress/features/shipments/shipment_process_screen.dart';
import 'package:sbexpress/features/shipments/shipments_screen.dart';
import 'package:sbexpress/features/more/more_screen.dart';
import 'package:sbexpress/features/tasks/tasks_screen.dart';
import 'package:sbexpress/features/admin/payment_review_screen.dart';
import 'package:sbexpress/widgets/ui.dart';

import 'package:flutter/material.dart';
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
import 'package:sbexpress/features/settings/settings_screen.dart';
import 'package:sbexpress/features/intake/intake_screen.dart';
import 'package:sbexpress/theme/app_theme.dart';

void main() {
  testWidgets('optional screenshot capture', (tester) async {
    if (Platform.environment['CAPTURE_SCREENSHOTS'] != '1') return;
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
    await tester.tap(find.byTooltip('পিছনে'));
    await tester.pumpAndSettle();
    expect(find.text('যাচাইয়ের অপেক্ষায়'), findsOneWidget);
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
    await _shot(tester, _scoped(scope, const IntakeScreen()), '22-intake',
        find.byType(IntakeScreen));
    await tester.tap(find.text('কাস্টমার বেছে নিন'));
    await tester.pumpAndSettle();
    await _saveShot(tester, '22b-customer-picker');
    await tester.tap(find.byTooltip('বন্ধ করুন'));
    await tester.pumpAndSettle();
    await _shot(tester, _scoped(scope, const FinanceScreen()),
        '23-finance-accounts', find.byType(FinanceScreen));
    await tester.tap(find.text('রিপোর্ট'));
    await tester.pumpAndSettle();
    await _saveShot(tester, '23b-finance-reports');
    await tester.tap(find.text('লেনদেন'));
    await tester.pumpAndSettle();
    await _saveShot(tester, '23c-finance-actions');
    await _shot(
        tester,
        _scoped(scope, const AdminShipmentScreen(code: 'SH-18')),
        '24-shipment-detail',
        find.byType(AdminShipmentScreen));
    await tester.tap(find.text('বিল'));
    await tester.pumpAndSettle();
    await _saveShot(tester, '24b-shipment-billing');
    await tester.ensureVisible(find.text('পেমেন্ট'));
    await tester.tap(find.text('পেমেন্ট'));
    await tester.pumpAndSettle();
    await _saveShot(tester, '24c-shipment-payment');
    await tester.tap(find.text('শেয়ার লিংক'));
    await tester.pumpAndSettle();
    await _saveShot(tester, '24d-shipment-share');
    await _shot(tester, _scoped(scope, const FlightDetailScreen(code: 'BG305')),
        '25-flight-detail', find.byType(FlightDetailScreen));
    await _shot(
        tester,
        _scoped(scope, const CustomerDetailScreen(code: 'C-14')),
        '26-customer-detail',
        find.byType(CustomerDetailScreen));
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
      'compact-workspace': MoreScreen(user: session.user!, session: session),
      'compact-login': LoginScreen(onSubmit: (email, password) async {}),
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
    await _shot(tester, _scoped(scope, const IntakeScreen()),
        '27-compact-booking', find.byType(IntakeScreen));
    await tester.tap(find.text('কাস্টমার বেছে নিন'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nila Store'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('General'));
    await tester.tap(find.byKey(const Key('intake-next')));
    await tester.pumpAndSettle();
    await _saveShot(tester, '27b-compact-pricing');
    await tester.tap(find.byKey(const Key('intake-next')));
    await tester.pumpAndSettle();
    await _saveShot(tester, '27c-compact-confirmation');
    _textScale = 1;
  });
}

double _textScale = 1;

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
                    admin: !hub &&
                        home is! HubHomeScreen &&
                        home is! TasksScreen,
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
