import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/money_payload.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flight_parts.dart' show CategoryChip;
import '../../widgets/flow_parts.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/round7_parts.dart';
import '../../widgets/ui.dart';
import '../admin/money_format.dart';

/// Adds a cost for the whole flight: our cost only, never on a customer's
/// bill. True once it is saved.
Future<bool?> showAddFlightCostSheet(BuildContext context,
        {required String code,
        required String flight,
        required double costsSoFar,
        double? profit}) =>
    showFlowSheet<bool>(
        context,
        (_) => AddFlightCostSheet(
            code: code,
            flight: flight,
            costsSoFar: costsSoFar,
            profit: profit));

class AddFlightCostSheet extends StatefulWidget {
  const AddFlightCostSheet(
      {super.key,
      required this.code,
      required this.flight,
      required this.costsSoFar,
      this.profit});

  final String code;

  /// The airline number shown in the heading.
  final String flight;
  final double costsSoFar;

  /// The flight's profit now, for the "Profit X → Y" line; null hides it.
  final double? profit;

  /// The quick chips. Labour is saved as `others` with the label "Labour".
  static const chips = [
    'transport',
    'courier',
    'packaging',
    'customs',
    'labour'
  ];

  @override
  State<AddFlightCostSheet> createState() => _AddFlightCostSheetState();
}

class _AddFlightCostSheetState extends State<AddFlightCostSheet> {
  /// One of [AddFlightCostSheet.chips], or `new` for a name typed here.
  String? _choice;
  final _label = TextEditingController();
  final _amount = TextEditingController();
  List<FinanceAccount> _accounts = const [];
  PayFrom _from = (account: null, later: false);
  var _loading = true;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _label.dispose();
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

  void _pick(String choice) => setState(() {
        _choice = choice;
        _error = null;
      });

  FinanceAccount? get _account {
    if (_from.later) return null;
    for (final account in _accounts) {
      if (account.name == _from.account) return account;
    }
    return null;
  }

  Future<void> _save() async {
    final choice = _choice;
    if (choice == null) {
      setState(() => _error = tr('Pick what the cost was for.'));
      return;
    }
    final typed = _label.text.trim();
    if (choice == 'new' && typed.isEmpty) {
      setState(() => _error = tr('Type what the cost was for.'));
      return;
    }
    final amount = parseMoney(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = tr('Enter the cost amount.'));
      return;
    }
    final account = _account;
    if (!_from.later && account == null) {
      setState(() =>
          _error = tr('Choose the account it was paid from, or Pay later.'));
      return;
    }
    if (account != null) {
      final ok = await confirmMoney(context,
          title: tr('Pay cost'),
          body: bdtFundMovement(
              amountBdt: amount,
              accountName: account.name,
              accountCurrency: account.currency,
              intoAccount: false));
      if (!ok || !mounted) return;
    }
    final other = choice == 'labour' || choice == 'new';
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).flights.addCost(widget.code,
          category: other ? 'others' : choice,
          label: choice == 'labour'
              ? labourLabel
              : choice == 'new'
                  ? typed
                  : null,
          amount: amount,
          accountName: account?.name,
          payLater: account == null);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.status == 404
          ? tr('The server needs an update before flight costs can be added.')
          : error.message);
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = parseMoney(_amount.text) ?? 0;
    final profit = widget.profit;
    return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetHeader(
              title: tr('Add flight cost'),
              subtitle: tr('{flight} · flight costs so far {amount}', {
                'flight': widget.flight,
                'amount': formatBdt(widget.costsSoFar)
              })),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SheetLabel(tr('Pick one')),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final chip in AddFlightCostSheet.chips)
                        CategoryChip(
                            key: ValueKey('flight-cost-$chip'),
                            label: chip == 'labour'
                                ? tr('Labour')
                                : costCategoryLabel(chip),
                            selected: chip == _choice,
                            onTap: () => _pick(chip)),
                      NewChip(
                          key: const Key('flight-cost-new'),
                          label: tr('New'),
                          selected: _choice == 'new',
                          onTap: () => _pick('new')),
                    ]),
                    if (_choice == 'new') ...[
                      const SizedBox(height: 12),
                      TextField(
                          key: const Key('flight-cost-label'),
                          controller: _label,
                          autofocus: true,
                          textCapitalization: TextCapitalization.sentences,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(60)
                          ],
                          onChanged: (_) => setState(() => _error = null),
                          decoration: InputDecoration(
                              labelText: tr('What was it for?'))),
                    ],
                    const SizedBox(height: 16),
                    SheetLabel(tr('Amount')),
                    BigAmountField(
                        key: const Key('flight-cost-amount'),
                        controller: _amount,
                        onChanged: (_) => setState(() => _error = null)),
                    const SizedBox(height: 16),
                    SheetLabel(tr('Paid from')),
                    if (_loading)
                      const LinearProgressIndicator()
                    else
                      PayFromField(
                          key: const Key('flight-cost-account'),
                          accounts: _accounts,
                          value: _from,
                          showBalance: true,
                          sheetTitle: tr('Paid from'),
                          onChanged: (value) => setState(() {
                                _from = value;
                                _error = null;
                              })),
                    const SizedBox(height: 6),
                    Text(tr('Or choose "Pay later" to save it as unpaid.'),
                        style: const TextStyle(
                            fontSize: 12, height: 1.4, color: AppColors.muted)),
                    const SizedBox(height: 16),
                    NoteBox(
                        key: const Key('flight-cost-preview'),
                        icon: Icons.info_outline_rounded,
                        title: tr('Our cost only'),
                        body: tr("Not added to any customer's bill."),
                        extra: profit != null && amount > 0
                            ? ChangeLine(
                                label: tr('Profit'),
                                from: formatBdt(profit),
                                to: formatBdt(roundMoney(profit - amount)))
                            : null),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      ErrorNote(message: _error!),
                    ],
                    const SizedBox(height: 16),
                    AppButton(
                        key: const Key('flight-cost-save'),
                        label: tr('Save cost'),
                        icon: Icons.check_rounded,
                        kind: AppButtonKind.current,
                        busy: _busy,
                        onPressed: _save),
                  ])),
        ]));
  }
}
