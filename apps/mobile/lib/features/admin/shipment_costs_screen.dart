import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/ledger_actions.dart';
import '../../data/money_payload.dart';
import '../../data/repositories/shipment_repository.dart';
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
    final reason = await askReason(context, title: '${item.name} বাতিল');
    if (reason == null || !mounted) return;
    if (reason.length < 3) {
      setState(() => _error = 'বাতিলের কারণ কমপক্ষে ৩ অক্ষর।');
      return;
    }
    final ok = await confirmMoney(context, title: 'খরচ বাতিল', body: '${item.name} (${formatBdt(item.amount)}) বাতিল হবে। কোনো পেমেন্ট থাকলে সার্ভার আটকাবে।');
    if (!ok || !mounted) return;
    try {
      await AppScope.of(context).shipments.voidCost(widget.code, item.id, reason);
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _sheet;
    return Scaffold(
      appBar: BackTitle(title: widget.code),
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 32),
          children: [
            const PageHeader(title: 'খরচ', subtitle: 'নতুন খরচ বিলে যোগ হতে পারে। আগের খরচ মিটালে আবার বিল হয় না।'),
            if (_loading && sheet == null) const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
            if (_error != null) ...[
              ErrorNote(message: _error!, onRetry: _load),
              const SizedBox(height: 12),
            ],
            if (sheet != null) ...[
              PaperCard(child: KvRow(label: 'মোট খরচ', value: formatBdt(sheet.total))),
              const SizedBox(height: 12),
              if (sheet.items.isEmpty) const EmptyNote(title: 'খরচ নেই', body: 'কুরিয়ার, প্যাকেজিং বা অন্য খরচ যোগ করুন।'),
              for (final item in sheet.items) ...[
                PaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(costCategories[item.category] ?? item.category, style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 8),
                      KvRow(label: 'অঙ্ক', value: formatBdt(item.amount)),
                      KvRow(label: 'পেইড', value: formatBdt(item.paidAmount)),
                      KvRow(label: 'বাকি', value: formatBdt(item.dueAmount), valueColor: item.dueAmount > 0 ? AppColors.danger : AppColors.ok),
                      if (item.voided) const Text('বাতিল', style: TextStyle(color: AppColors.muted)),
                      if (!item.voided && item.dueAmount > 0) ...[
                        const SizedBox(height: 8),
                        AppButton(
                          label: 'পরিশোধ',
                          kind: AppButtonKind.current,
                          onPressed: () async {
                            final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => CostSettleScreen(code: widget.code, item: item)));
                            if (saved == true) await _load();
                          },
                        ),
                      ],
                      if (!item.voided && !item.legacyField && item.paidAmount == 0) ...[
                        const SizedBox(height: 8),
                        AppButton(label: 'বাতিল', kind: AppButtonKind.danger, onPressed: () => _void(item)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              AppButton(
                label: 'নতুন খরচ',
                kind: AppButtonKind.teal,
                onPressed: () async {
                  final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => CostEntryScreen(code: widget.code)));
                  if (saved == true) await _load();
                },
              ),
            ],
          ],
        ),
      ),
    );
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
      setState(() => _error = 'অঙ্ক ও কারণ দিন।');
      return;
    }
    if (_timing == 'now' && _account == null) {
      setState(() => _error = 'এখন পরিশোধ করতে অ্যাকাউন্ট বেছে নিন।');
      return;
    }
    FinanceAccount? account;
    for (final row in _accounts) {
      if (row.name == _account) account = row;
    }
    if (_timing == 'now') {
      final ok = await confirmMoney(
        context,
        title: 'খরচ পরিশোধ',
        body: '${formatMoney(amount, account?.currency ?? 'BDT')} ${account?.name} থেকে যাবে এবং খরচ রেকর্ড হবে।',
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
    return Scaffold(
      appBar: const BackTitle(title: 'নতুন খরচ'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 32),
        children: [
          const PageHeader(title: 'নতুন খরচ', subtitle: 'পরে রাখলে শুধু বকেয়া হয়। এখন মানে টাকা এই মুহূর্তে অ্যাকাউন্ট থেকে গেছে।'),
          ChoiceChips(
            options: [for (final entry in costCategories.entries) (value: entry.key, label: entry.value)],
            selected: _category,
            onSelected: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 12),
          TextField(controller: _label, decoration: const InputDecoration(labelText: 'নাম (ঐচ্ছিক)')),
          const SizedBox(height: 8),
          TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'অঙ্ক')),
          const SizedBox(height: 8),
          TextField(controller: _reason, decoration: const InputDecoration(labelText: 'কারণ')),
          const SizedBox(height: 12),
          const SectionTitle(title: 'কখন পরিশোধ'),
          ChoiceChips(
            options: const [(value: 'later', label: 'পরে'), (value: 'now', label: 'এখন')],
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
            if (_currency != null) Text('মুদ্রা $_currency', style: const TextStyle(color: AppColors.muted)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
          const SizedBox(height: 16),
          AppButton(label: 'খরচ সেভ', kind: AppButtonKind.current, busy: _busy, onPressed: _save),
        ],
      ),
    );
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
  late final TextEditingController _amount = TextEditingController(text: widget.item.dueAmount.toString());
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
    if (amount == null || amount <= 0 || amount > widget.item.dueAmount + 0.001 || account == null || reason.isEmpty) {
      setState(() => _error = 'অ্যাকাউন্ট, কারণ ও বকেয়ার মধ্যে অঙ্ক দিন।');
      return;
    }
    final chosen = account;
    final ok = await confirmMoney(context, title: 'খরচ পরিশোধ', body: '${formatMoney(amount, chosen.currency)} ${chosen.name} থেকে ${widget.item.name}-এর জন্য যাবে।');
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).shipments.recordCost(
            widget.code,
            shipmentExpenseBody(
              category: costCategories.containsKey(widget.item.category) ? widget.item.category : 'others',
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
    return Scaffold(
      appBar: const BackTitle(title: 'খরচ পরিশোধ'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 32),
        children: [
          PageHeader(title: widget.item.name, subtitle: 'বাকি ${formatBdt(widget.item.dueAmount)}। আংশিক পরিশোধ করা যায়।'),
          AccountPicker(accounts: _accounts, selected: _account, onSelected: (account) => setState(() => _account = account.name)),
          const SizedBox(height: 8),
          TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'অঙ্ক')),
          const SizedBox(height: 8),
          TextField(controller: _reason, decoration: const InputDecoration(labelText: 'কারণ')),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
          const SizedBox(height: 16),
          AppButton(label: 'পরিশোধ সেভ', kind: AppButtonKind.current, busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}
