import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbexpress/data/money_payload.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'package:sbexpress/widgets/flow_parts.dart';

void main() {
  late TextEditingController part, paid;

  setUp(() {
    part = TextEditingController(text: '15000');
    paid = TextEditingController();
  });

  Future<void> pump(WidgetTester t, {double recorded = 0}) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, setState) => FlyerPartRow(
                    name: 'Arif Rahman',
                    part: part,
                    paid: paid,
                    paidLabel: tr('Already paid'),
                    payable: () =>
                        (readOptionalMoney(part.text) ?? 0) - recorded,
                    partKey: const ValueKey('part'),
                    paidKey: const ValueKey('paid'),
                    onChanged: (_) => setState(() {}))))));
  }

  testWidgets('ticking Paid fills the whole part; unticking clears it',
      (t) async {
    await pump(t);
    expect(find.byKey(const ValueKey('paid')), findsNothing);
    await t.tap(find.byKey(const ValueKey('paid-tick-Arif Rahman')));
    await t.pump();
    expect(paid.text, '15000');
    await t.tap(find.byKey(const ValueKey('paid-tick-Arif Rahman')));
    await t.pump();
    expect(paid.text, '');
  });

  testWidgets('a ticked flyer follows a changed part', (t) async {
    await pump(t);
    await t.tap(find.byKey(const ValueKey('paid-tick-Arif Rahman')));
    await t.pump();
    await t.enterText(find.byKey(const ValueKey('part')), '12000');
    await t.pump();
    expect(paid.text, '12000');
  });

  testWidgets('Part paid opens the amount field for a part payment', (t) async {
    await pump(t);
    await t.tap(find.byKey(const ValueKey('part-paid-Arif Rahman')));
    await t.pump();
    await t.enterText(find.byKey(const ValueKey('paid')), '5000');
    await t.pump();
    expect(paid.text, '5000');
    final box = t.widget<Checkbox>(find.byType(Checkbox));
    expect(box.value, isFalse);
  });

  testWidgets('on a saved flight the tick pays only what is left', (t) async {
    await pump(t, recorded: 6000);
    await t.tap(find.byKey(const ValueKey('paid-tick-Arif Rahman')));
    await t.pump();
    expect(paid.text, '9000');
  });
}
