import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/flow.dart';
import '../../data/money_payload.dart';
import '../../data/repositories/shipment_repository.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/finance_parts.dart' show AccountField;
import '../../widgets/flight_parts.dart' show CategoryChip;
import '../../widgets/flow_parts.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/ui.dart';
import 'money_format.dart';

/// Adds one cost to a shipment: a usual one with its usual amount filled in,
/// or any other. True once it is saved.
Future<bool?> showAddCostSheet(BuildContext context,
        {required String code,
        required String customer,
        required double costs,
        required double bill,
        String category = 'courier'}) =>
    showFlowSheet<bool>(
        context,
        (_) => AddCostSheet(
            code: code,
            customer: customer,
            costs: costs,
            bill: bill,
            category: category));

class AddCostSheet extends StatefulWidget {
  const AddCostSheet(
      {super.key,
      required this.code,
      required this.customer,
      required this.costs,
      required this.bill,
      required this.category});

  final String code;
  final String customer;

  /// Costs recorded so far and the customer's bill, for the preview.
  final double costs;
  final double bill;
  final String category;

  @override
  State<AddCostSheet> createState() => _AddCostSheetState();
}

class _AddCostSheetState extends State<AddCostSheet> {
  static const _categories = [...usualCostKeys, 'others'];

  late var _category = widget.category;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  CostDefaults _defaults = const CostDefaults();
  List<FinanceAccount> _accounts = const [];
  String? _account;
  var _later = false;
  var _noteOpen = false;

  /// The operator typed an amount; switching category keeps it.
  var _typed = false;
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
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    try {
      final finance = await scope.finance.snapshot();
      if (!mounted) return;
      setState(() => _accounts = finance.accounts);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    }
    try {
      final settings = await scope.settings.current();
      if (!mounted) return;
      setState(() => _defaults = settings.costDefaults ?? const CostDefaults());
    } catch (_) {
      // Without saved usual amounts the field simply starts empty.
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _prefill();
    });
  }

  void _prefill() {
    if (_typed) return;
    final usual = _defaults.of(_category);
    _amount.text = usual > 0 ? _plain(usual) : '';
  }

  FinanceAccount? get _chosen {
    for (final account in _accounts) {
      if (account.name == _account) return account;
    }
    return null;
  }

  Future<void> _save() async {
    final amount = parseMoney(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = tr('Enter the cost amount.'));
      return;
    }
    final account = _chosen;
    if (!_later && account == null) {
      setState(
          () => _error = tr('Choose the account the money will come from.'));
      return;
    }
    if (!_later) {
      final ok = await confirmMoney(context,
          title: tr('Pay cost'),
          body: bdtFundMovement(
              amountBdt: amount,
              accountName: account!.name,
              accountCurrency: account.currency,
              intoAccount: false));
      if (!ok || !mounted) return;
    }
    final note = _note.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).shipments.recordCost(
          widget.code,
          shipmentExpenseBody(
              category: _category,
              amount: amount,
              currency: 'BDT',
              reason: note.isEmpty ? usualCostReason(_category) : note,
              label: _category == 'others' && note.isNotEmpty
                  ? (note.length > 120 ? note.substring(0, 120) : note)
                  : null,
              accountName: _later ? null : account!.name,
              paymentTiming: _later ? 'later' : 'now'));
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
    final usual = _defaults.of(_category);
    final isUsual = usual > 0 && (amount - usual).abs() < 0.001;
    final label = usualCostLabel(_category);
    final costsAfter = roundMoney(widget.costs + amount);
    final profitAfter = roundMoney(widget.bill - costsAfter);
    final String hint = _category == 'others'
        ? tr('Add a note to say what this cost was.')
        : usual > 0
            ? tr(
                '{cost} is usually {amount}. Change it if this one was different.',
                {
                    'cost': label,
                    'amount': formatBdt(usual)
                  })
            : tr('No usual amount saved for {cost} yet. Set one in Settings.',
                {'cost': label});
    return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetHeader(
              title: tr('Add cost · {code}', {'code': widget.code}),
              subtitle: tr('{name} · costs so far {amount}', {
                'name': widget.customer,
                'amount': formatBdt(widget.costs)
              })),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label(tr('Category')),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final category in _categories)
                        CategoryChip(
                            key: ValueKey('cost-$category'),
                            label: usualCostLabel(category),
                            selected: category == _category,
                            onTap: () => setState(() {
                                  _category = category;
                                  _prefill();
                                })),
                    ]),
                    const SizedBox(height: 16),
                    _label(tr('Amount')),
                    BigAmountField(
                        key: const Key('cost-amount'),
                        controller: _amount,
                        badge: isUsual ? tr('Usual amount') : null,
                        onChanged: (_) => setState(() {
                              _typed = true;
                              _error = null;
                            })),
                    const SizedBox(height: 6),
                    Text(hint,
                        style: const TextStyle(
                            fontSize: 12, height: 1.4, color: AppColors.muted)),
                    const SizedBox(height: 16),
                    if (!_later) ...[
                      _label(tr('Paid now from')),
                      if (_loading)
                        const LinearProgressIndicator()
                      else
                        AccountField(
                            key: const Key('cost-account'),
                            accounts: _accounts,
                            selected: _chosen,
                            sheetTitle: tr('Paid now from'),
                            onSelected: (account) => setState(() {
                                  _account = account.name;
                                  _error = null;
                                })),
                      const SizedBox(height: 6),
                    ],
                    Semantics(
                        toggled: _later,
                        child: InkWell(
                            key: const Key('cost-later'),
                            onTap: () => setState(() => _later = !_later),
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(minHeight: 56),
                                child: Row(children: [
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(tr('Pay later'),
                                            style: const TextStyle(
                                                fontSize: 15,
                                                height: 1.35,
                                                fontWeight: FontWeight.w600)),
                                        Text(tr('Save it as unpaid. Nothing leaves an account.'),
                                            style: const TextStyle(
                                                fontSize: 13,
                                                height: 1.4,
                                                color: AppColors.muted)),
                                      ])),
                                  ExcludeSemantics(
                                      child: Switch(
                                          value: _later,
                                          onChanged: (value) =>
                                              setState(() => _later = value))),
                                ])))),
                    if (_noteOpen)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextField(
                              key: const Key('cost-note'),
                              controller: _note,
                              maxLength: 200,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                  labelText: tr('Note (optional)'))))
                    else
                      Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                              onPressed: () => setState(() => _noteOpen = true),
                              icon: const Icon(Icons.edit_outlined, size: 17),
                              label: Text.rich(TextSpan(children: [
                                TextSpan(text: tr('Add a note')),
                                TextSpan(
                                    text: ' ${tr('(optional)')}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.muted)),
                              ])))),
                    const SizedBox(height: 10),
                    ResultPreview(
                        icon: Icons.trending_up_rounded,
                        caption: tr('After saving'),
                        title: tr('Costs {costs} · Profit {profit}', {
                          'costs': formatBdt(costsAfter),
                          'profit': formatBdt(profitAfter)
                        }),
                        trailing: [
                          tr('was {amount}',
                              {'amount': formatBdt(widget.costs)}),
                          tr('and {amount}', {
                            'amount': formatBdt(
                                roundMoney(widget.bill - widget.costs))
                          }),
                        ]),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      ErrorNote(message: _error!),
                    ],
                    const SizedBox(height: 14),
                    AppButton(
                        key: const Key('cost-save'),
                        label: tr('Save cost'),
                        icon: Icons.check_rounded,
                        kind: AppButtonKind.current,
                        busy: _busy,
                        onPressed: _save),
                  ])),
        ]));
  }

  Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13, height: 1.35, fontWeight: FontWeight.w600)));
}

/// 300 rather than 300.0 in an amount field.
String _plain(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);
