import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/money_payload.dart';
import '../../data/repositories/shipment_repository.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flight_parts.dart' show CategoryChip;
import '../../widgets/flow_parts.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/round7_parts.dart';
import '../../widgets/ui.dart';
import 'money_format.dart';

/// Adds a cost to a shipment's bill: the customer pays it back, so it shows
/// on their invoice as a line. True once it is saved.
Future<bool?> showAddCostSheet(BuildContext context,
        {required String code,
        required String customer,
        required double bill,
        String? category}) =>
    showFlowSheet<bool>(
        context,
        (_) => AddCostSheet(
            code: code, customer: customer, bill: bill, category: category));

class AddCostSheet extends StatefulWidget {
  const AddCostSheet(
      {super.key,
      required this.code,
      required this.customer,
      required this.bill,
      this.category});

  final String code;
  final String customer;

  /// The customer's bill now, for the "Bill X → Y" preview.
  final double bill;

  /// A chip to start on; none means "Other".
  final String? category;

  /// The quick chips, in the design's order.
  static const choices = [
    'courier',
    'customs',
    'packaging',
    'transport',
    'others'
  ];

  @override
  State<AddCostSheet> createState() => _AddCostSheetState();
}

/// The line the customer reads on the bill for each chip. Saved data stays
/// in English, like the cost reasons; the operator can change it.
String _billName(String? category) => switch (category) {
      'courier' => 'Courier to customer',
      'customs' => 'Customs',
      'packaging' => 'Packaging',
      'transport' => 'Transport',
      _ => '',
    };

class _AddCostSheetState extends State<AddCostSheet> {
  late String? _category = widget.category;
  late final _name = TextEditingController(text: _billName(widget.category));
  final _amount = TextEditingController();
  List<FinanceAccount> _accounts = const [];
  PayFrom _from = (account: null, later: false);

  /// The operator typed a name; switching chips keeps it.
  var _nameTyped = false;
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
    _name.dispose();
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

  void _pick(String category) => setState(() {
        _category = _category == category ? null : category;
        if (!_nameTyped) _name.text = _billName(_category);
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
    final category = _category ?? 'others';
    final name = _name.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).shipments.recordCost(
          widget.code,
          shipmentExpenseBody(
              category: category,
              amount: amount,
              currency: 'BDT',
              reason: name.isEmpty ? usualCostReason(category) : name,
              label: name.isEmpty ? null : name,
              accountName: account?.name,
              paymentTiming: account == null ? 'later' : 'now'));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
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
    return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetHeader(
              title: tr('Add cost to the bill'),
              subtitle: tr('{code} · {name} pays this',
                  {'code': widget.code, 'name': widget.customer})),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SheetLabel(tr('What for'), extra: tr('(optional)')),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final category in AddCostSheet.choices)
                        CategoryChip(
                            key: ValueKey('cost-$category'),
                            label: costCategoryLabel(category),
                            selected: category == _category,
                            onTap: () => _pick(category)),
                    ]),
                    const SizedBox(height: 16),
                    SheetLabel(tr('Name on the bill')),
                    TextField(
                        key: const Key('cost-name'),
                        controller: _name,
                        textCapitalization: TextCapitalization.sentences,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(120)
                        ],
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                            hintText: tr('e.g. Courier to customer')),
                        onChanged: (_) => setState(() {
                              _nameTyped = true;
                              _error = null;
                            })),
                    const SizedBox(height: 16),
                    SheetLabel(tr('Amount')),
                    BigAmountField(
                        key: const Key('cost-amount'),
                        controller: _amount,
                        onChanged: (_) => setState(() => _error = null)),
                    const SizedBox(height: 16),
                    SheetLabel(tr('We paid it from')),
                    if (_loading)
                      const LinearProgressIndicator()
                    else
                      PayFromField(
                          key: const Key('cost-account'),
                          accounts: _accounts,
                          value: _from,
                          sheetTitle: tr('We paid it from'),
                          onChanged: (value) => setState(() {
                                _from = value;
                                _error = null;
                              })),
                    if (amount > 0) ...[
                      const SizedBox(height: 16),
                      Semantics(
                          liveRegion: true,
                          child: Container(
                              key: const Key('cost-preview'),
                              padding:
                                  const EdgeInsets.fromLTRB(14, 10, 14, 10),
                              decoration: BoxDecoration(
                                  color: AppColors.okSoft,
                                  borderRadius: BorderRadius.circular(14)),
                              child: Row(children: [
                                Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                        color: AppColors.card,
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: const Icon(
                                        Icons.description_outlined,
                                        size: 18,
                                        color: AppColors.ok)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(
                                          tr("Added to {name}'s bill",
                                              {'name': widget.customer}),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              height: 1.35,
                                              color: Color(0xFF1F5E3C))),
                                      ChangeLine(
                                          label: tr('Bill'),
                                          from: formatBdt(widget.bill),
                                          to: formatBdt(
                                              roundMoney(widget.bill + amount)),
                                          style: const TextStyle(
                                              fontSize: 16,
                                              height: 1.35,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF164D31))),
                                    ])),
                              ]))),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      ErrorNote(message: _error!),
                    ],
                    const SizedBox(height: 16),
                    AppButton(
                        key: const Key('cost-save'),
                        label: tr('Add to bill'),
                        icon: Icons.check_rounded,
                        kind: AppButtonKind.current,
                        busy: _busy,
                        onPressed: _save),
                  ])),
        ]));
  }
}
