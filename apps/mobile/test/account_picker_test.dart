import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbexpress/data/models/finance_snapshot.dart';
import 'package:sbexpress/theme/app_theme.dart';
import 'package:sbexpress/widgets/account_picker.dart';

void main() {
  const accounts = [
    FinanceAccount(
        name: 'Dhaka cash', kind: 'cash', currency: 'BDT', balance: 1000),
    FinanceAccount(
        name: 'China wallet', kind: 'wallet', currency: 'CNY', balance: 500),
  ];
  testWidgets(
      'account selector requires an explicit choice and preserves its currency',
      (tester) async {
    FinanceAccount? chosen;
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, setState) => AccountPicker(
                      accounts: accounts,
                      selected: chosen?.name,
                      onSelected: (account) => setState(() => chosen = account),
                    )))));
    expect(chosen, isNull);
    expect(find.text('অ্যাকাউন্ট বেছে নিন'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('China wallet · CNY').last);
    await tester.pumpAndSettle();
    expect(chosen?.name, 'China wallet');
    expect(chosen?.currency, 'CNY');
    expect(chosen?.balance, 500);
    expect(tester.takeException(), isNull);
  });
  testWidgets('an account removed during refresh clears the displayed choice',
      (tester) async {
    var available = accounts;
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
          update = setState;
          return AccountPicker(
              accounts: available,
              selected: 'China wallet',
              onSelected: (_) {});
        }))));
    expect(
        tester
            .widget<DropdownButtonFormField<String>>(
                find.byType(DropdownButtonFormField<String>))
            .initialValue,
        'China wallet');
    update(() => available = [accounts.first]);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<DropdownButtonFormField<String>>(
                find.byType(DropdownButtonFormField<String>))
            .initialValue,
        isNull);
    expect(find.text('অ্যাকাউন্ট বেছে নিন'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
