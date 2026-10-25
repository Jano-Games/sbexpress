import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/ledger_actions.dart';
import '../../data/money_payload.dart';
import '../../data/repositories/shipment_repository.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/account_picker.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/ui.dart';
import 'money_format.dart';

class ShipmentCostsScreen extends StatefulWidget {
  const ShipmentCostsScreen({super.key, required this.code});

  final String code;

  @override
  State<ShipmentCostsScreen> createState() => _ShipmentCostsScreenState();
}

class _ShipmentCostsScreenState extends State<ShipmentCostsScreen> {
  ShipmentCostSheet? _sheet;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sheet = await AppScope.of(context).shipments.costSheet(widget.code);
      if (!mounted) return;
      setState(() => _sheet = sheet);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _void(ShipmentCostItem item) async {
    final reason = await askReason(context,
        title: tr('Cancel {name}', {'name': item.name}));
    if (reason == null || !mounted) return;
    if (reason.length < 3) {
      setState(() => _error =
          tr('The reason for cancelling needs at least 3 characters.'));
      return;
    }
    final ok = await confirmMoney(context,
        title: tr('Cancel cost'),
        body: tr(
            '{name} ({amount}) will be cancelled. The server blocks this if the cost has any payment.',
            {'name': item.name, 'amount': formatBdt(item.amount)}));
    if (!ok || !mounted) return;
    try {
      await AppScope.of(context)
          .shipments
          .voidCost(widget.code, item.id, reason);
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _sheet;
    return WorkspaceScaffold(
        title: tr('Costs'),
        root: false,
        onRefresh: _load,
        subtitle: widget.code,
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr(
                      'New costs can be added to the invoice. Paying an earlier cost does not bill it again.'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          if (_loading && sheet == null)
            const LinearProgressIndicator(
                color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ...[
            ErrorNote(message: _error!, onRetry: _load),
            const SizedBox(height: 12),
          ],
          if (sheet != null) ...[
            PaperCard(
                child: KvRow(
                    label: tr('Total cost'), value: formatBdt(sheet.total))),
            const SizedBox(height: 12),
            if (sheet.items.isEmpty)
              EmptyNote(
                  title: tr('No costs added'),
                  body: tr('Add courier, packaging or any other cost.')),
            for (final item in sheet.items) ...[
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(costCategories[item.category] ?? item.category,
                        style: const TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 8),
                    KvRow(label: tr('Amount'), value: formatBdt(item.amount)),
                    KvRow(label: tr('Paid'), value: formatBdt(item.paidAmount)),
                    KvRow(
                        label: tr('Due'),
                        value: formatBdt(item.dueAmount),
                        valueColor: item.dueAmount > 0
                            ? AppColors.danger
                            : AppColors.ok),
                    if (item.voided)
                      Text(tr('Cancelled'),
                          style: const TextStyle(color: AppColors.muted)),
                    if (!item.voided && item.dueAmount > 0) ...[
                      const SizedBox(height: 8),
                      AppButton(
                        label: tr('Pay'),
                        kind: AppButtonKind.current,
                        onPressed: () async {
                          final saved = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                  builder: (_) => CostSettleScreen(
                                      code: widget.code, item: item)));
                          if (saved == true) await _load();
                        },
                      ),
                    ],
                    if (!item.voided &&
                        !item.legacyField &&
                        item.paidAmount == 0) ...[
                      const SizedBox(height: 8),
                      AppButton(
                          label: tr('Cancel'),
                          kind: AppButtonKind.danger,
                          onPressed: () => _void(item)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            AppButton(
              label: tr('Add cost'),
              kind: AppButtonKind.teal,
              onPressed: () async {
                final saved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                        builder: (_) => CostEntryScreen(code: widget.code)));
                if (saved == true) await _load();
              },
            ),
          ],
        ]);
  }
}

class CostEntryScreen extends StatefulWidget {
  const CostEntryScreen({super.key, required this.code});

  final String code;

  @override
  State<CostEntryScreen> createState() => _CostEntryScreenState();
}

class _CostEntryScreenState extends State<CostEntryScreen> {
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _label = TextEditingController();
  List<FinanceAccount> _accounts = const [];
  String? _account;
  String? _currency;
  var _category = 'courier';
  var _timing = 'later';
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final finance = await AppScope.of(context).finance.snapshot();
        if (!mounted) return;
        setState(() => _accounts = finance.accounts);
      } on ApiException catch (error) {
        if (!mounted || error.status == 401) return;
        setState(() => _error = error.message);
      }
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseMoney(_amount.text);
    final reason = _reason.text.trim();
    if (amount == null || amount <= 0 || reason.isEmpty) {
      setState(() => _error = tr('Enter an amount and a reason.'));
      return;
    }
    if (_timing == 'now' && _account == null) {
      setState(() => _error = tr('Choose an account to pay now.'));
      return;
    }
    FinanceAccount? account;
    for (final row in _accounts) {
      if (row.name == _account) account = row;
    }
    if (_timing == 'now') {
      final ok = await confirmMoney(
        context,
        title: tr('Pay cost'),
        body: tr('{amount} goes out of {account} and the cost is recorded.', {
          'amount': formatMoney(amount, account?.currency ?? 'BDT'),
          'account': account?.name
        }),
      );
      if (!ok || !mounted) return;
    }
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
              currency: account?.currency ?? 'BDT',
              reason: reason,
              label: _label.text,
              accountName: account?.name,
              paymentTiming: _timing,
            ),
          );
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
    return WorkspaceScaffold(
        title: tr('Add cost'),
        root: false,
        footer: ActionFooter(
            child: AppButton(
                label: tr('Save cost'),
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr(
                      'Later only records the cost as unpaid. Now means the money has just left an account.'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          ChoiceChips(
            options: [
              for (final entry in costCategories.entries)
                (value: entry.key, label: entry.value)
            ],
            selected: _category,
            onSelected: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _label,
              decoration: InputDecoration(labelText: tr('Name (optional)'))),
          const SizedBox(height: 8),
          TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: tr('Amount'))),
          const SizedBox(height: 8),
          TextField(
              controller: _reason,
              decoration: InputDecoration(labelText: tr('Reason'))),
          const SizedBox(height: 12),
          SectionTitle(title: tr('Payment timing')),
          ChoiceChips(
            options: [
              (value: 'later', label: tr('Later')),
              (value: 'now', label: tr('Now'))
            ],
            selected: _timing,
            onSelected: (value) => setState(() => _timing = value),
          ),
          if (_timing == 'now') ...[
            const SizedBox(height: 12),
            AccountPicker(
              accounts: _accounts,
              selected: _account,
              onSelected: (account) => setState(() {
                _account = account.name;
                _currency = account.currency;
              }),
            ),
            if (_currency != null)
              Text(tr('Currency: {currency}', {'currency': _currency}),
                  style: const TextStyle(color: AppColors.muted)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
        ]);
  }
}

class CostSettleScreen extends StatefulWidget {
  const CostSettleScreen({super.key, required this.code, required this.item});

  final String code;
  final ShipmentCostItem item;

  @override
  State<CostSettleScreen> createState() => _CostSettleScreenState();
}

class _CostSettleScreenState extends State<CostSettleScreen> {
  late final TextEditingController _amount =
      TextEditingController(text: widget.item.dueAmount.toString());
  final _reason = TextEditingController();
  List<FinanceAccount> _accounts = const [];
  String? _account;
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final finance = await AppScope.of(context).finance.snapshot();
        if (!mounted) return;
        setState(() => _accounts = finance.accounts);
      } on ApiException catch (error) {
        if (!mounted || error.status == 401) return;
        setState(() => _error = error.message);
      }
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseMoney(_amount.text);
    final reason = _reason.text.trim();
    FinanceAccount? account;
    for (final row in _accounts) {
      if (row.name == _account) account = row;
    }
    if (amount == null ||
        amount <= 0 ||
        amount > widget.item.dueAmount + 0.001 ||
        account == null ||
        reason.isEmpty) {
      setState(() => _error = tr(
          'Choose an account, enter a reason and an amount no more than the amount due.'));
      return;
    }
    final chosen = account;
    final ok = await confirmMoney(context,
        title: tr('Pay cost'),
        body: tr('{amount} goes out of {account} for {cost}.', {
          'amount': formatMoney(amount, chosen.currency),
          'account': chosen.name,
          'cost': widget.item.name
        }));
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).shipments.recordCost(
            widget.code,
            shipmentExpenseBody(
              category: costCategories.containsKey(widget.item.category)
                  ? widget.item.category
                  : 'others',
              amount: amount,
              currency: chosen.currency,
              reason: reason,
              accountName: chosen.name,
              costId: widget.item.legacyField ? null : widget.item.id,
              costField: widget.item.legacyField ? widget.item.costField : null,
            ),
          );
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
    return WorkspaceScaffold(
        title: widget.item.name,
        root: false,
        footer: ActionFooter(
            child: AppButton(
                label: tr('Save cost payment'),
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr('{amount} due. You can pay part of it.',
                      {'amount': formatBdt(widget.item.dueAmount)}),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          AccountPicker(
              accounts: _accounts,
              selected: _account,
              onSelected: (account) => setState(() => _account = account.name)),
          const SizedBox(height: 8),
          TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: tr('Amount'))),
          const SizedBox(height: 8),
          TextField(
              controller: _reason,
              decoration: InputDecoration(labelText: tr('Reason'))),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
        ]);
  }
}
