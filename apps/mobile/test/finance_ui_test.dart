import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sbexpress/app_scope.dart';
import 'package:sbexpress/data/models/ledger_page.dart';
import 'package:sbexpress/data/models/session_user.dart';
import 'package:sbexpress/data/repositories/auth_repository.dart';
import 'package:sbexpress/data/session/session_controller.dart';
import 'package:sbexpress/data/session/session_store.dart';
import 'package:sbexpress/features/customers/customer_activity_screen.dart';
import 'package:sbexpress/features/customers/customer_credit_screen.dart';
import 'package:sbexpress/features/customers/customer_form_screen.dart';
import 'package:sbexpress/features/customers/customers_screen.dart';
import 'package:sbexpress/features/customers/statement_screen.dart';
import 'package:sbexpress/features/finance/ledger_screen.dart';
import 'package:sbexpress/features/finance/office_entry_screen.dart';
import 'package:sbexpress/features/finance/reconciliation_screen.dart';
import 'package:sbexpress/features/finance/transfer_screen.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'package:sbexpress/theme/app_theme.dart';
import 'package:sbexpress/widgets/finance_parts.dart';
import 'support/screen_fixtures.dart';

Widget _app(Widget home,
    {Future<http.Response?> Function(http.Request)? intercept,
    double textScale = 1}) {
  final api = screenFixtureApi(intercept: intercept);
  final session = SessionController(
      store: MemorySessionStore()..token = 'tok', auth: AuthRepository(api))
    ..user = const SessionUser(
        id: 'u',
        name: 'Tester',
        email: 'test@sbx.test',
        role: UserRole.admin,
        roleLabel: 'Administrator')
    ..ready = true;
  return AppScope.wired(
      session: session,
      api: api,
      child: MaterialApp(
          theme: buildAppTheme(),
          builder: textScale == 1
              ? null
              : (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!),
          home: home));
}

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

http.Response _json(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});

/// The screen's main list, not a text field or the filter row.
final _list = find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

Future<void> _confirmReason(WidgetTester t, String reason) async {
  await t.enterText(find.byType(TextField).last, reason);
  await t.tap(find.text(tr('Confirm')));
  await t.pumpAndSettle();
}

void main() {
  group('ledger', () {
    testWidgets('asks for this month and shows the backend totals', (t) async {
      _phone(t);
      final queries = <Map<String, String>>[];
      await t.pumpWidget(_app(const LedgerScreen(), intercept: (r) async {
        if (r.url.path == '/api/finance/ledger') {
          queries.add(r.url.queryParameters);
        }
        return null;
      }));
      await t.pumpAndSettle();
      expect(queries.single, {
        'period': currentMonthKey(),
        'type': 'all',
        'page': '1',
        'limit': '25',
      });
      expect(
          find.descendant(
              of: find.byKey(const Key('ledger-money-in')),
              matching: find.text('৳64,200.00')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('ledger-money-out')),
              matching: find.text('+ ¥400.00')),
          findsOneWidget);
      expect(find.text(trn(64, '{n} line', '{n} lines')), findsOneWidget);
      // Both sides of the transfer share one card and one reverse action.
      expect(find.text(tr('Reverse both')), findsOneWidget);
      expect(find.text('−৳17,500.00'), findsOneWidget);
      expect(find.text('+¥1000.00'), findsOneWidget);
      // A reversal line cannot be reversed again.
      expect(find.text(tr('Reversal')), findsOneWidget);
      expect(find.text(tr('Reverse')), findsNWidgets(2));
      expect(t.takeException(), isNull);
    });

    testWidgets('filters, search and paging go to the backend', (t) async {
      _phone(t);
      final queries = <Map<String, String>>[];
      await t.pumpWidget(_app(const LedgerScreen(), intercept: (r) async {
        if (r.url.path == '/api/finance/ledger') {
          queries.add(r.url.queryParameters);
        }
        return null;
      }));
      await t.pumpAndSettle();

      await t.ensureVisible(find.byKey(const Key('ledger-type')));
      await t.tap(find.byKey(const Key('ledger-type')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('choice-expense')));
      await t.tap(find.byKey(const ValueKey('choice-expense')));
      await t.pumpAndSettle();
      expect(queries.last['type'], 'expense');

      await t.ensureVisible(find.byKey(const Key('ledger-account')));
      await t.tap(find.byKey(const Key('ledger-account')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('choice-Chengdu cash')));
      await t.tap(find.byKey(const ValueKey('choice-Chengdu cash')));
      await t.pumpAndSettle();
      expect(queries.last['account'], 'Chengdu cash');
      expect(queries.last['type'], 'expense');

      await t.ensureVisible(find.byKey(const Key('ledger-period')));
      await t.tap(find.byKey(const Key('ledger-period')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('choice-all')));
      await t.tap(find.byKey(const ValueKey('choice-all')));
      await t.pumpAndSettle();
      expect(queries.last['period'], 'all');

      final before = queries.length;
      await t.enterText(find.byKey(const Key('ledger-search')), 'van');
      await t.pump(const Duration(milliseconds: 100));
      expect(queries.length, before, reason: 'search waits for typing to stop');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      expect(queries.length, before + 1);
      expect(queries.last['search'], 'van');
      expect(queries.last['page'], '1');

      await t.scrollUntilVisible(find.byKey(const Key('page-next')), 300,
          scrollable: _list);
      await t.tap(find.byKey(const Key('page-next')));
      await t.pumpAndSettle();
      expect(queries.last, {
        'period': 'all',
        'account': 'Chengdu cash',
        'type': 'expense',
        'search': 'van',
        'page': '2',
        'limit': '25',
      });
      expect(t.takeException(), isNull);
    });

    testWidgets('reversing a transfer sends one request for both sides',
        (t) async {
      _phone(t);
      final reversals = <Map<String, dynamic>>[];
      await t.pumpWidget(_app(const LedgerScreen(), intercept: (r) async {
        if (r.method == 'POST' && r.url.path == '/api/finance/reverse') {
          reversals.add(jsonDecode(r.body) as Map<String, dynamic>);
          return _json({'ok': true});
        }
        return null;
      }));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text(tr('Reverse both')));
      await t.tap(find.text(tr('Reverse both')));
      await t.pumpAndSettle();
      await _confirmReason(t, 'Wrong account');
      expect(find.textContaining('Dhaka cash'), findsWidgets);
      await t.tap(find.text(tr('Confirm')));
      await t.pumpAndSettle();
      expect(reversals, [
        {'kind': 'transfer', 'id': 't1', 'reason': 'Wrong account'}
      ]);
      expect(t.takeException(), isNull);
    });

    test('ledger page reads totals and counts pages', () {
      final page = LedgerPage.fromJson(ledgerBody());
      expect(page.pages, 3);
      expect(page.hasNext, isTrue);
      expect(page.hasPrevious, isFalse);
      expect(page.totalFor('CNY').moneyIn, 1400);
      expect(page.entries.where((line) => line.isTransfer).length, 2);
      expect(page.entries.last.isReversal, isTrue);
      expect(const LedgerFilter(search: '  ').query.containsKey('search'),
          isFalse);
    });
  });

  group('statement', () {
    testWidgets('the month stepper asks for the chosen month', (t) async {
      _phone(t);
      final months = <String>[];
      await t.pumpWidget(
          _app(const StatementScreen(code: 'C-14', name: 'Nila Store'),
              intercept: (r) async {
        if (r.url.path.endsWith('/statement-links')) {
          months.add(r.url.queryParameters['month']!);
        }
        return null;
      }));
      await t.pumpAndSettle();
      final now = currentMonthKey();
      expect(months, [now]);
      expect(find.text(monthTitle(now)), findsOneWidget);
      final next = t.widget<IconButton>(find.descendant(
          of: find.byKey(const Key('statement-next')),
          matching: find.byType(IconButton)));
      expect(next.onPressed, isNull, reason: 'no statements for future months');
      await t.tap(find.byKey(const Key('statement-previous')));
      await t.pumpAndSettle();
      expect(months.last, shiftMonth(now, -1));
      expect(find.text(monthTitle(shiftMonth(now, -1))), findsOneWidget);
      await t.tap(find.byKey(const Key('statement-next')));
      await t.pumpAndSettle();
      expect(months.last, now);
      expect(t.takeException(), isNull);
    });

    testWidgets('a pending receipt can be accepted', (t) async {
      _phone(t);
      final approved = <String>[];
      await t.pumpWidget(
          _app(const StatementScreen(code: 'C-14', name: 'Nila Store'),
              intercept: (r) async {
        if (r.method == 'POST' && r.url.path.endsWith('/approve')) {
          approved.add(r.url.path);
          return _json({'ok': true});
        }
        return null;
      }));
      await t.pumpAndSettle();
      expect(find.text(tr('{n} to review', {'n': 1})), findsOneWidget);
      await t.tap(find.byKey(const Key('receipt-accept-rcpt-1')));
      await t.pumpAndSettle();
      await t.tap(find.text(tr('Confirm')));
      await t.pumpAndSettle();
      expect(
          approved, ['/api/suppliers/C-14/statement-receipts/rcpt-1/approve']);
      expect(t.takeException(), isNull);
    });
  });

  testWidgets('customers are split into owing and settled', (t) async {
    _phone(t);
    Map<String, Object?> customer(String code, String name, double balance) => {
          'code': code,
          'name': name,
          'phone': '0170000$code',
          'address': '',
          'terms': 'monthly',
          'orderCount': 2,
          'deliveredCount': 1,
          'shippedKg': 9.5,
          'billed': 5000,
          'paid': 5000 - balance,
          'balance': balance,
          'creditBalance': balance > 0 ? 0 : 1200,
          'pricingPending': 0,
          'discountTotal': 0,
        };
    await t.pumpWidget(_app(const CustomersScreen(), intercept: (r) async {
      if (r.url.path == '/api/suppliers') {
        return _json({
          'suppliers': [
            customer('C-14', 'Nila Store', 15400),
            customer('C-31', 'Sky Mobile', 0),
            customer('C-15', 'Rahman Traders', 0),
          ]
        });
      }
      return null;
    }));
    await t.pumpAndSettle();
    expect(find.text(tr('Owe money')), findsNWidgets(2));
    // The section title and each settled row's caption.
    expect(find.text(tr('Settled')), findsNWidgets(3));
    expect(find.text(tr('Credit {amount}', {'amount': '৳1,200.00'})),
        findsNWidgets(2));
    expect(find.text('৳15,400.00'), findsNWidgets(2));
    await t.enterText(find.byType(TextField), 'sky');
    await t.pumpAndSettle();
    expect(find.text('Sky Mobile'), findsOneWidget);
    expect(find.text('Nila Store'), findsNothing);
    expect(find.text('Rahman Traders'), findsNothing);
    await t.enterText(find.byType(TextField), 'nobody');
    await t.pumpAndSettle();
    expect(find.text(tr('No matching customers')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('an office expense keeps its category and account', (t) async {
    _phone(t);
    Map<String, dynamic>? sent;
    await t.pumpWidget(_app(const OfficeEntryScreen(), intercept: (r) async {
      if (r.method == 'POST' && r.url.path == '/api/finance/expenses') {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return _json({'ok': true});
      }
      return null;
    }));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('office-kind-expense')));
    await t.pumpAndSettle();
    expect(find.text(tr('Save expense')), findsOneWidget);
    await t.ensureVisible(find.text(tr('Transport')));
    await t.tap(find.text(tr('Transport')));
    await t.ensureVisible(find.byKey(const Key('account-Chengdu cash')));
    await t.tap(find.byKey(const Key('account-Chengdu cash')));
    await t.pumpAndSettle();
    expect(find.text(tr('Amount ({currency})', {'currency': 'CNY'})),
        findsOneWidget);
    await t.ensureVisible(find.byKey(const Key('office-amount')));
    await t.enterText(find.byKey(const Key('office-amount')), '40');
    await t.ensureVisible(find.byKey(const Key('office-note')));
    await t.enterText(find.byKey(const Key('office-note')), 'Tape and cartons');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('office-save')));
    await t.pumpAndSettle();
    await t.tap(find.text(tr('Confirm')));
    await t.pumpAndSettle();
    expect(sent, {
      'amount': 40.0,
      'money': {'currency': 'CNY'},
      'category': 'transport',
      'reason': 'Tape and cartons',
      'accountName': 'Chengdu cash',
    });
    expect(t.takeException(), isNull);
  });

  testWidgets('a cross-currency transfer asks what arrives and previews it',
      (t) async {
    _phone(t);
    Map<String, dynamic>? sent;
    await t.pumpWidget(_app(const TransferScreen(), intercept: (r) async {
      if (r.method == 'POST' && r.url.path == '/api/finance/transfers') {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return _json({'ok': true});
      }
      return null;
    }));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('transfer-from')));
    await t.pumpAndSettle();
    await t.tap(find.text('Dhaka cash').last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('transfer-to')));
    await t.pumpAndSettle();
    await t.tap(find.text('Chengdu cash').last);
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('transfer-amount')), '17500');
    await t.ensureVisible(find.byKey(const Key('transfer-received')));
    await t.enterText(find.byKey(const Key('transfer-received')), '1000');
    await t.ensureVisible(find.byKey(const Key('transfer-note')));
    await t.enterText(find.byKey(const Key('transfer-note')), 'Hub float');
    await t.pumpAndSettle();
    expect(find.text('BDT → CNY'), findsOneWidget);
    expect(find.textContaining('৳17.50'), findsOneWidget);
    expect(find.text(tr('After this transfer')), findsOneWidget);
    expect(find.text('৳66,750.00'), findsOneWidget);
    expect(find.text('¥2200.00'), findsOneWidget);
    await t.tap(find.byKey(const Key('transfer-save')));
    await t.pumpAndSettle();
    await t.tap(find.text(tr('Confirm')));
    await t.pumpAndSettle();
    expect(sent?['from'], 'Dhaka cash');
    expect(sent?['to'], 'Chengdu cash');
    expect(sent?['amount'], 17500.0);
    expect(sent?['receivedAmount'], 1000.0);
    expect(sent?['note'], 'Hub float');
    expect(t.takeException(), isNull);
  });

  testWidgets('reconciliation lists what does not add up', (t) async {
    _phone(t);
    await t.pumpWidget(_app(const ReconciliationScreen()));
    await t.pumpAndSettle();
    expect(find.text(tr('{n} to check', {'n': 2})), findsOneWidget);
    expect(
        find.text(
            trn(2, "{n} thing doesn't add up", "{n} things don't add up")),
        findsOneWidget);
    expect(find.text(tr('Has opening balance')), findsOneWidget);
    expect(find.text(tr('All in ledger')), findsOneWidget);
    final difference =
        find.text(tr('Difference {amount}', {'amount': '+৳200.00'}));
    await t.scrollUntilVisible(difference, 300, scrollable: _list);
    expect(difference, findsOneWidget);
    expect(t.takeException(), isNull);
  });

  group('a 320 px screen with 1.3x text', () {
    final screens = <String, Widget>{
      'customers': const CustomersScreen(),
      'customer': const CustomerDetailScreen(code: 'C-14'),
      'statement': const StatementScreen(code: 'C-14', name: 'Nila Store'),
      'activity':
          const CustomerActivityScreen(code: 'C-14', name: 'Nila Store'),
      'credit': const CustomerCreditScreen(
          code: 'C-14', name: 'Nila Store', orders: []),
      'new customer': const CustomerFormScreen(),
      'ledger': const LedgerScreen(),
      'expense': const OfficeEntryScreen(initialKind: 'expense'),
      'reconciliation': const ReconciliationScreen(),
      'transfer': const TransferScreen(),
    };
    for (final entry in screens.entries) {
      testWidgets('${entry.key} fits without overflow', (t) async {
        t.view.physicalSize = const Size(320, 700);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(_app(entry.value, textScale: 1.3));
        await t.pumpAndSettle();
        for (var i = 0; i < 6; i++) {
          await t.drag(_list, const Offset(0, -300));
          await t.pumpAndSettle();
        }
        expect(t.takeException(), isNull);
      });
    }
  });

  test('month helpers step across years', () {
    expect(shiftMonth('2026-01', -1), '2025-12');
    expect(shiftMonth('2026-12', 1), '2027-01');
    expect(monthKey(2026, 3), '2026-03');
    expect(signedMoney(-800, 'BDT'), '−৳800.00');
    expect(signedMoney(400, 'CNY'), '+¥400.00');
  });
}
