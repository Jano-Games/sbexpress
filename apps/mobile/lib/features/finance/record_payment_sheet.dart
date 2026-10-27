import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/flow.dart';
import '../../data/money_payload.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/finance_parts.dart' show accountIcon;
import '../../widgets/flight_parts.dart' show dayMonth;
import '../../widgets/flow_parts.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/ui.dart';
import '../admin/money_format.dart';

/// Records money a customer paid on a shipment. True once it is saved.
/// [monthly] is for a shipment on a monthly bill; an empty
/// `deliveredOn` means it is not handed over yet.
Future<bool?> showRecordPaymentSheet(BuildContext context,
        {required HandedOverBill bill, bool monthly = false}) =>
    showFlowSheet<bool>(
        context, (_) => RecordPaymentSheet(bill: bill, monthly: monthly));

class RecordPaymentSheet extends StatefulWidget {
  const RecordPaymentSheet(
      {super.key, required this.bill, this.monthly = false});

  final HandedOverBill bill;
  final bool monthly;

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  late final _amount = TextEditingController(text: _plain(widget.bill.amount));
  List<FinanceAccount> _accounts = const [];
  String? _account;
  String? _error;
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final finance = await AppScope.of(context).finance.snapshot();
      if (!mounted) return;
      setState(() => _accounts = finance.accounts);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  FinanceAccount? get _chosen {
    for (final account in _accounts) {
      if (account.name == _account) return account;
    }
    return null;
  }

  Future<void> _save() async {
    final amount = parseMoney(_amount.text);
    final account = _chosen;
    final due = widget.bill.amount;
    if (amount == null || amount <= 0) {
      setState(() => _error = tr('Enter the amount received.'));
      return;
    }
    if (amount > due + 0.001) {
      setState(() => _error = tr(
          'Enter no more than the {amount} due.', {'amount': formatBdt(due)}));
      return;
    }
    if (account == null) {
      setState(() => _error = tr('Choose where the money came in.'));
      return;
    }
    final ok = await confirmMoney(context,
        title: tr('Record payment'),
        body: bdtFundMovement(
            amountBdt: amount,
            accountName: account.name,
            accountCurrency: account.currency,
            intoAccount: true));
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).shipments.recordPayment(widget.bill.code,
          amount: amount, accountName: account.name);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final amount = parseMoney(_amount.text);
    final account = _chosen;
    final left =
        amount == null ? bill.amount : roundMoney(bill.amount - amount);
    final full = amount != null && (amount - bill.amount).abs() < 0.001;
    return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetHeader(
              title: tr('Record payment'),
              subtitle: '${bill.code} · ${bill.supplierName}'),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FigureStrip(figures: [
                      StripFigure(tr('Due'), formatBdt(bill.amount)),
                      StripFigure(
                          tr('Delivered'),
                          bill.deliveredOn.isEmpty
                              ? '—'
                              : dayMonth(bill.deliveredOn)),
                      StripFigure(
                          tr('Pays'),
                          widget.monthly
                              ? tr('Monthly')
                              : tr('After delivery')),
                    ]),
                    const SizedBox(height: 14),
                    _Label(tr('Amount received')),
                    BigAmountField(
                        key: const Key('record-amount'),
                        controller: _amount,
                        badge: full ? tr('Full due') : null,
                        onChanged: (_) => setState(() => _error = null)),
                    const SizedBox(height: 6),
                    Text(tr('Lower it if the customer paid only part.'),
                        style: const TextStyle(
                            fontSize: 12, height: 1.4, color: AppColors.muted)),
                    const SizedBox(height: 14),
                    _Label(tr('Received in')),
                    if (_loading)
                      const LinearProgressIndicator()
                    else if (_accounts.isEmpty)
                      Text(tr('No accounts yet. Add a fund in Finance first.'),
                          style: const TextStyle(color: AppColors.muted))
                    else
                      _AccountGrid(
                          accounts: _accounts,
                          selected: _account,
                          onSelected: (name) => setState(() {
                                _account = name;
                                _error = null;
                              })),
                    const SizedBox(height: 14),
                    if (amount != null && amount > 0 && account != null)
                      left <= 0.001
                          ? ResultPreview(
                              icon: Icons.check_rounded,
                              tone: ChipTone.green,
                              title: tr(
                                  '{code} becomes Paid', {'code': bill.code}),
                              body: tr(
                                  '{amount} goes into {account} · nothing left to collect',
                                  {
                                    'amount': formatBdt(amount),
                                    'account': account.name
                                  }))
                          : ResultPreview(
                              icon: Icons.timelapse_rounded,
                              tone: ChipTone.blue,
                              title: tr('{code} stays part paid',
                                  {'code': bill.code}),
                              body: tr(
                                  '{amount} goes into {account} · {left} still to collect',
                                  {
                                    'amount': formatBdt(amount),
                                    'account': account.name,
                                    'left': formatBdt(left < 0 ? 0 : left)
                                  })),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      ErrorNote(message: _error!),
                    ],
                    const SizedBox(height: 14),
                    AppButton(
                        key: const Key('record-save'),
                        label: tr('Save payment'),
                        icon: Icons.check_rounded,
                        kind: AppButtonKind.current,
                        busy: _busy,
                        onPressed: _save),
                  ])),
        ]));
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13, height: 1.35, fontWeight: FontWeight.w600)));
}

/// Accounts as tiles, two to a row.
class _AccountGrid extends StatelessWidget {
  const _AccountGrid(
      {required this.accounts,
      required this.selected,
      required this.onSelected});
  final List<FinanceAccount> accounts;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget tile(FinanceAccount account) {
      final on = account.name == selected;
      return Semantics(
          selected: on,
          button: true,
          inMutuallyExclusiveGroup: true,
          child: Material(
              key: ValueKey('received-${account.name}'),
              color: on ? AppColors.primarySoft : AppColors.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                      color: on ? AppColors.primary : AppColors.field,
                      width: on ? 2 : 1)),
              child: InkWell(
                  onTap: () => onSelected(account.name),
                  borderRadius: BorderRadius.circular(14),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          child: Row(children: [
                            Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                    color: on
                                        ? AppColors.primary
                                        : AppColors.paper,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Icon(accountIcon(account.kind),
                                    size: 18,
                                    color:
                                        on ? Colors.white : AppColors.inkSoft)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(account.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 15,
                                          height: 1.3,
                                          fontWeight: FontWeight.w700,
                                          color: on
                                              ? AppColors.primaryInk
                                              : AppColors.ink)),
                                  Text(account.currency,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.muted)),
                                ])),
                          ]))))));
    }

    return LayoutBuilder(builder: (context, box) {
      // Large text on a narrow phone gets one account per row.
      final scale = MediaQuery.textScalerOf(context).scale(100) / 100;
      if (box.maxWidth / scale < 300) {
        return Column(children: [
          for (var i = 0; i < accounts.length; i++)
            Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                child: tile(accounts[i])),
        ]);
      }
      return Column(children: [
        for (var i = 0; i < accounts.length; i += 2)
          Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
              child: IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Expanded(child: tile(accounts[i])),
                    const SizedBox(width: 10),
                    Expanded(
                        child: i + 1 < accounts.length
                            ? tile(accounts[i + 1])
                            : const SizedBox.shrink()),
                  ]))),
      ]);
    });
  }
}

/// 11250 rather than 11250.0 in an amount field.
String _plain(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);
