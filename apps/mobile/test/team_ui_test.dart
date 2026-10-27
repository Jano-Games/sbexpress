import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sbexpress/app_scope.dart';
import 'package:sbexpress/data/models/session_user.dart';
import 'package:sbexpress/data/repositories/auth_repository.dart';
import 'package:sbexpress/data/repositories/task_repository.dart';
import 'package:sbexpress/data/session/session_controller.dart';
import 'package:sbexpress/data/session/session_store.dart';
import 'package:sbexpress/features/admin/invoice_editor_screen.dart';
import 'package:sbexpress/features/admin/money_format.dart';
import 'package:sbexpress/features/finance/fund_account_screen.dart';
import 'package:sbexpress/features/flyers/flyer_detail_screen.dart';
import 'package:sbexpress/features/flyers/flyers_screen.dart';
import 'package:sbexpress/features/settings/pay_method_form_screen.dart';
import 'package:sbexpress/features/more/more_screen.dart';
import 'package:sbexpress/features/settings/pay_methods_screen.dart';
import 'package:sbexpress/features/settings/staff_screen.dart';
import 'package:sbexpress/features/tasks/tasks_screen.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'package:sbexpress/theme/app_theme.dart';
import 'package:sbexpress/widgets/ui.dart';

import 'support/screen_fixtures.dart';
import 'support/team_fixtures.dart';

/// Writes the app sent, as `METHOD path` with the decoded JSON body.
typedef _Sent = List<({String call, Object? body})>;

Widget _app(Widget Function(TaskRepository tasks) home, _Sent sent,
    {UserRole role = UserRole.admin,
    String invoiceState = 'draft',
    bool cleanupEnabled = false}) {
  final api = screenFixtureApi(intercept: (request) async {
    if (request.method != 'GET') {
      sent.add((
        call: '${request.method} ${Uri.decodeComponent(request.url.path)}',
        body: request.body.isEmpty ? null : jsonDecode(request.body)
      ));
      final path = request.url.path;
      final reply = path.endsWith('/toggle')
          ? {'done': true}
          : path.contains('/settings/users/')
              ? {
                  'user': {
                    'id': 'u3',
                    'name': 'Jamal Hossain',
                    'email': 'jamal@sbx.test',
                    'role': 'hub',
                    'active': true
                  }
                }
              : {'ok': true};
      return http.Response(jsonEncode(reply), 200,
          headers: {'content-type': 'application/json'});
    }
    return teamFixtures(request,
        invoiceState: invoiceState, cleanupEnabled: cleanupEnabled);
  });
  final session = SessionController(
      store: MemorySessionStore()..token = 'tok', auth: AuthRepository(api))
    ..user = SessionUser(
        id: 'u1',
        name: 'Rafiq',
        email: 'rafiq@sbx.test',
        role: role,
        roleLabel: role.name)
    ..ready = true;
  return AppScope.wired(
      session: session,
      api: api,
      child:
          MaterialApp(theme: buildAppTheme(), home: home(TaskRepository(api))));
}

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Future<void> _tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

void main() {
  testWidgets('flyer list counts pending documents and searches universities',
      (t) async {
    _phone(t);
    final sent = <({String call, Object? body})>[];
    await t.pumpWidget(_app((_) => const FlyersScreen(), sent));
    await t.pumpAndSettle();
    expect(find.text(tr('Active flyers')), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(
        find.text(tr('{verified} of {total} verified · visa waiting',
            {'verified': 1, 'total': 2})),
        findsOneWidget);
    expect(find.text(tr('No documents uploaded yet')), findsOneWidget);
    expect(find.text(trn(4, '{n} profile', '{n} profiles')), findsOneWidget);

    await t.enterText(find.byType(TextField), 'chengdu');
    await t.pumpAndSettle();
    expect(find.text('Sumi Akter'), findsOneWidget);
    expect(find.text('Arif Rahman'), findsNothing);
    expect(find.text(trn(1, '{n} profile', '{n} profiles')), findsOneWidget);

    await t.enterText(find.byType(TextField), 'nobody');
    await t.pumpAndSettle();
    expect(find.text(tr('No flyers match')), findsOneWidget);
    expect(sent, isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('flyer profile verifies, unverifies and archives in one scroll',
      (t) async {
    _phone(t);
    final sent = <({String call, Object? body})>[];
    await t.pumpWidget(
        _app((_) => const FlyerDetailScreen(name: 'Arif Rahman'), sent));
    await t.pumpAndSettle();
    expect(find.byType(ScreenTabs), findsNothing);
    expect(find.text(tr('Contact')), findsOneWidget);
    expect(find.text('Father · 01711000000'), findsOneWidget);
    expect(find.text(tr('Verified by {name}', {'name': 'Rafiq'})),
        findsNWidgets(2));

    await _tap(t, find.text(tr('Mark verified')));
    expect(sent.last.call,
        'PATCH /api/flyers/Arif Rahman/documents/doc-3/verification');
    expect(sent.last.body, {'verified': true});

    await _tap(t, find.text(tr('Remove verification')).first);
    expect(sent.last.call,
        'PATCH /api/flyers/Arif Rahman/documents/doc-1/verification');
    expect(sent.last.body, {'verified': false});

    await t.scrollUntilVisible(
        find.text(trn(2, '{n} flight', '{n} flights')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('BG147'), findsOneWidget);
    await _tap(t, find.text(tr('Archive flyer')));
    // Archiving asks first and says what it does.
    expect(sent.last.call, isNot('POST /api/flyers/Arif Rahman/archive'));
    expect(find.text(tr('Archive {name}?', {'name': 'Arif Rahman'})),
        findsOneWidget);
    await t.tap(find.byKey(const Key('remove-confirm')));
    await t.pumpAndSettle();
    expect(sent.last.call, 'POST /api/flyers/Arif Rahman/archive');
    expect(sent.last.body, {'archived': true});
    expect(t.takeException(), isNull);
  });

  testWidgets('admin tasks group automatic work apart from notes', (t) async {
    _phone(t);
    final sent = <({String call, Object? body})>[];
    await t.pumpWidget(
        _app((tasks) => TasksScreen(role: UserRole.admin, tasks: tasks), sent));
    await t.pumpAndSettle();
    for (final title in [
      'Payment reviews',
      'Shipment steps',
      'Your notes',
      'Completed'
    ]) {
      await t.scrollUntilVisible(find.text(tr(title)), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(tr(title)), findsOneWidget);
    }
    await _tap(t, find.byTooltip(tr('Mark note done')));
    expect(sent.single.call, 'POST /api/todos/t3/toggle');

    await t.tap(find.byTooltip(tr('New note')));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Call the courier');
    await _tap(t, find.text(tr('Assign to hub')));
    await _tap(t, find.text(tr('Add note')));
    expect(sent.last.call, 'POST /api/todos');
    expect(sent.last.body, {'text': 'Call the courier', 'assignTo': 'hub'});
    expect(t.takeException(), isNull);
  });

  testWidgets('hub tasks have no assignment choice and show no money',
      (t) async {
    _phone(t);
    final sent = <({String call, Object? body})>[];
    await t.pumpWidget(_app(
        (tasks) => TasksScreen(role: UserRole.hub, tasks: tasks), sent,
        role: UserRole.hub));
    await t.pumpAndSettle();
    expect(find.text(tr('Hub tasks')), findsOneWidget);
    await t.tap(find.byTooltip(tr('New note')));
    await t.pumpAndSettle();
    expect(find.text(tr('Who does it')), findsNothing);
    expect(find.textContaining('৳'), findsNothing);
    await t.enterText(find.byType(TextField), 'Pack SH-19 tonight');
    await _tap(t, find.text(tr('Add note')));
    expect(sent.single.body, {'text': 'Pack SH-19 tonight'});
    expect(t.takeException(), isNull);
  });

  testWidgets('payment methods show a hidden one and switch it back on',
      (t) async {
    _phone(t);
    final sent = <({String call, Object? body})>[];
    await t.pumpWidget(_app((_) => const PayMethodsScreen(), sent));
    await t.pumpAndSettle();
    expect(find.textContaining(tr('hidden')), findsOneWidget);

    await _tap(t, find.byType(Switch).at(1));
    expect(sent.single.call, 'PATCH /api/settings/pay-methods/m2');
    expect(sent.single.body, {'enabled': true});
    expect(t.takeException(), isNull);
  });

  testWidgets('More shows the rate and opens the system check', (t) async {
    _phone(t);
    final sent = <({String call, Object? body})>[];
    await t.pumpWidget(_app(
        (_) => Builder(
            builder: (context) => MoreScreen(
                user: AppScope.of(context).session.user!,
                session: AppScope.of(context).session)),
        sent));
    await t.pumpAndSettle();
    expect(
        find.text('${tr('{rate} per ¥1', {'rate': '৳17.50'})} · '
            '${tr('Confirmed')}'),
        findsOneWidget);
    final system = find.text(tr('System check'));
    await t.scrollUntilVisible(system, 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('5 / 6'), findsOneWidget);
    expect(find.text(tr('Media cleanup')), findsNothing);
    await _tap(t, system);
    expect(find.text(tr('Media cleanup')), findsOneWidget);
    expect(find.text(tr('Off')), findsOneWidget);
    expect(sent, isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('payment method preview follows the form; bank fields validate',
      (t) async {
    _phone(t);
    final sent = <({String call, Object? body})>[];
    await t.pumpWidget(_app((_) => const PayMethodFormScreen(), sent));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).at(1), '01900000000');
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text(tr('Payment number')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('01900000000'), findsNWidgets(2));
    await t.scrollUntilVisible(find.textContaining('bKash · 01900000000'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('bKash · 01900000000'), findsOneWidget);

    await t.drag(find.byType(ListView), const Offset(0, 3000));
    await t.pumpAndSettle();
    await _tap(t, find.text(tr('Bank')));
    await _tap(t, find.text(tr('Save method')));
    expect(
        find.text(
            tr('Enter the bank, account number and account holder name.')),
        findsOneWidget);
    expect(sent, isEmpty);

    await t.enterText(find.byType(TextField).at(0), 'City Bank');
    await t.enterText(find.byType(TextField).at(1), '1234567890');
    await t.enterText(find.byType(TextField).at(2), 'SB Express');
    await _tap(t, find.text(tr('Save method')));
    await t.tap(find.text(tr('Confirm')));
    await t.pumpAndSettle();
    expect(sent.single.call, 'POST /api/settings/pay-methods');
    final body = sent.single.body as Map;
    expect(body['kind'], 'bank_account');
    expect(body['bankName'], 'City Bank');
    expect(body['accountNumber'], '1234567890');
    expect(body['currency'], 'BDT');
    expect(t.takeException(), isNull);
  });

  testWidgets('invoice editor totals lines and holds a zero invoice back',
      (t) async {
    _phone(t);
    final sent = <({String call, Object? body})>[];
    await t.pumpWidget(
        _app((_) => const InvoiceEditorScreen(code: 'SH-18'), sent));
    await t.pumpAndSettle();
    expect(find.text(tr('Draft')), findsWidgets);
    expect(find.text(formatBdt(4250)), findsOneWidget);
    expect(find.text(formatBdt(4000)), findsOneWidget);
    expect(
        find.text(tr('Issue {amount}', {'amount': '৳4,000'})), findsOneWidget);

    await t.enterText(find.byType(TextField).at(6), '4250');
    await t.pumpAndSettle();
    expect(find.text(formatBdt(0)), findsOneWidget);
    await t.scrollUntilVisible(
        find.text(tr('This shipment is free of charge')), 200,
        scrollable: find.byType(Scrollable).first);
    await t.tap(find.text(tr('Issue {amount}', {'amount': '৳0'})));
    await t.pumpAndSettle();
    expect(find.text(tr('Confirm free of charge to issue a zero invoice.')),
        findsOneWidget);
    expect(sent, isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('an issued invoice asks for a revision instead of a draft',
      (t) async {
    _phone(t);
    final sent = <({String call, Object? body})>[];
    await t.pumpWidget(_app(
        (_) => const InvoiceEditorScreen(code: 'SH-18'), sent,
        invoiceState: 'issued'));
    await t.pumpAndSettle();
    expect(find.text(tr('Issue revision')), findsOneWidget);
    expect(find.text(tr('Save draft')), findsNothing);
    await t.scrollUntilVisible(find.text(tr('Revision reason')), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(tr('Revision reason')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('new fund preview shows the opening capital', (t) async {
    _phone(t);
    final sent = <({String call, Object? body})>[];
    await t.pumpWidget(_app((_) => const FundAccountScreen(), sent));
    await t.pumpAndSettle();
    expect(find.text(tr('New account')), findsOneWidget);
    expect(
        find.text(
            tr('No ledger line. Add money later with income or a transfer.')),
        findsOneWidget);
    await t.enterText(find.byType(TextField).at(0), 'Office petty cash');
    await t.enterText(find.byType(TextField).at(1), '5000');
    await t.pumpAndSettle();
    expect(find.text('Office petty cash'), findsNWidgets(2));
    expect(find.text(formatMoney(5000, 'BDT')), findsOneWidget);
    expect(find.text(tr('Goes to the ledger as capital. It is not income.')),
        findsOneWidget);
    await _tap(t, find.text('¥ CNY'));
    expect(find.text(formatMoney(5000, 'CNY')), findsOneWidget);
    expect(sent, isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('staff are grouped by role and switched on from their page',
      (t) async {
    _phone(t);
    final sent = <({String call, Object? body})>[];
    await t.pumpWidget(_app((_) => const StaffScreen(), sent));
    await t.pumpAndSettle();
    expect(find.text(tr('Admins')), findsWidgets);
    expect(find.text(tr('You')), findsOneWidget);
    expect(find.text(tr('{n} active', {'n': 2})), findsOneWidget);
    expect(find.textContaining(tr("can't sign in")), findsOneWidget);

    await _tap(t, find.text('Jamal Hossain'));
    expect(find.byType(StaffEditScreen), findsOneWidget);
    await _tap(t, find.byType(Switch));
    await _tap(t, find.text(tr('Save profile')));
    expect(sent.single.call, 'PATCH /api/settings/users/u3');
    expect(sent.single.body, {
      'name': 'Jamal Hossain',
      'email': 'jamal@sbx.test',
      'role': 'hub',
      'active': true
    });
    expect(find.byType(StaffEditScreen), findsNothing);
    expect(t.takeException(), isNull);
  });
}
