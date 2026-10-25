import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/shipment.dart';
import '../../data/money_payload.dart';
import '../../theme/app_colors.dart';
import '../../widgets/account_picker.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/ui.dart';
import '../admin/money_format.dart';

class CustomerCreditScreen extends StatefulWidget {
  const CustomerCreditScreen(
      {super.key,
      required this.code,
      required this.name,
      required this.orders});

  final String code;
  final String name;
  final List<AdminShipment> orders;

  @override
  State<CustomerCreditScreen> createState() => _CustomerCreditScreenState();
}

class _CustomerCreditScreenState extends State<CustomerCreditScreen> {
  double? _balance;
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
      final balance =
          await AppScope.of(context).customers.creditBalance(widget.code);
      if (!mounted) return;
      setState(() => _balance = balance);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Widget screen) async {
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => screen));
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final balance = _balance;
    return WorkspaceScaffold(
        title: 'কাস্টমার ক্রেডিট',
        root: false,
        subtitle: widget.code,
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(widget.name,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          if (_loading && balance == null)
            const LinearProgressIndicator(
                color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (balance != null) ...[
            MetricTile(
                label: 'ক্রেডিট ব্যালেন্স',
                value: formatBdt(balance),
                tone: balance > 0 ? ChipTone.green : ChipTone.neutral),
            const SizedBox(height: 16),
            AppButton(
              label: 'বিলে বসান',
              kind: AppButtonKind.current,
              onPressed: () => _open(ApplyCreditScreen(
                  code: widget.code, balance: balance, orders: widget.orders)),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'রিফান্ড',
              kind: AppButtonKind.teal,
              onPressed: () => _open(
                  RefundCreditScreen(code: widget.code, balance: balance)),
            ),
          ],
        ]);
  }
}

class ApplyCreditScreen extends StatefulWidget {
  const ApplyCreditScreen(
      {super.key,
      required this.code,
      required this.balance,
      required this.orders});

  final String code;
  final double balance;
  final List<AdminShipment> orders;

  @override
  State<ApplyCreditScreen> createState() => _ApplyCreditScreenState();
}

class _ApplyCreditScreenState extends State<ApplyCreditScreen> {
  final _amount = TextEditingController();
  String? _shipment;
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseMoney(_amount.text);
    final code = _shipment;
    if (code == null ||
        amount == null ||
        amount <= 0 ||
        amount > widget.balance + 0.001) {
      setState(
          () => _error = 'শিপমেন্ট বেছে নিন এবং ক্রেডিটের মধ্যে অঙ্ক দিন।');
      return;
    }
    final shipmentCode = code;
    final ok = await confirmMoney(context,
        title: 'ক্রেডিট বসান',
        body:
            '${formatBdt(amount)} $shipmentCode-এর ইস্যু করা ইনভয়েসে বসবে। ড্রাফট বিলে বসবে না।');
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context)
          .customers
          .applyCredit(widget.code, shipmentCode: shipmentCode, amount: amount);
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
    return WorkspaceScaffold(
        title: 'বিলে বসান',
        root: false,
        footer: ActionFooter(
            child: AppButton(
                label: 'বসান',
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  'ব্যালেন্স ${formatBdt(widget.balance)}। ইস্যু করা ও রিভিউ-মুক্ত ইনভয়েসেই বসবে।',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          if (widget.orders.isEmpty)
            const EmptyNote(
                title: 'শিপমেন্ট নেই',
                body: 'ইনভয়েস ইস্যু হলে এখান থেকে বসানো যাবে।'),
          for (final order in widget.orders) ...[
            _OrderPick(
              title: order.code,
              subtitle: 'বাকি ${formatBdt(order.dueAmount)}',
              selected: _shipment == order.code,
              onTap: () => setState(() => _shipment = order.code),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'অঙ্ক')),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
        ]);
  }
}

class RefundCreditScreen extends StatefulWidget {
  const RefundCreditScreen(
      {super.key, required this.code, required this.balance});

  final String code;
  final double balance;

  @override
  State<RefundCreditScreen> createState() => _RefundCreditScreenState();
}

class _RefundCreditScreenState extends State<RefundCreditScreen> {
  final _amount = TextEditingController();
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
    FinanceAccount? account;
    for (final row in _accounts) {
      if (row.name == _account) account = row;
    }
    final amount = parseMoney(_amount.text);
    final reason = _reason.text.trim();
    if (account == null ||
        amount == null ||
        amount <= 0 ||
        amount > widget.balance + 0.001 ||
        reason.length < 3) {
      setState(() =>
          _error = 'অ্যাকাউন্ট, ক্রেডিটের মধ্যে অঙ্ক ও ৩ অক্ষরের কারণ দিন।');
      return;
    }
    final chosen = account;
    final ok = await confirmMoney(context,
        title: 'ক্রেডিট রিফান্ড',
        body:
            '${formatMoney(amount, chosen.currency)} ${chosen.name} থেকে ফেরত যাবে।');
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).customers.refundCredit(widget.code,
          amount: amount,
          accountName: chosen.name,
          currency: chosen.currency,
          reason: reason);
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
    return WorkspaceScaffold(
        title: 'রিফান্ড',
        root: false,
        footer: ActionFooter(
            child: AppButton(
                label: 'রিফান্ড সেভ',
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  'ব্যালেন্স ${formatBdt(widget.balance)}। যে অ্যাকাউন্ট থেকে টাকা বের হবে সেটা বেছে নিন।',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          AccountPicker(
              accounts: _accounts,
              selected: _account,
              onSelected: (account) => setState(() => _account = account.name)),
          TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'অঙ্ক')),
          const SizedBox(height: 8),
          TextField(
              controller: _reason,
              decoration: const InputDecoration(labelText: 'কারণ')),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
        ]);
  }
}

class _OrderPick extends StatelessWidget {
  const _OrderPick(
      {required this.title,
      required this.subtitle,
      required this.selected,
      required this.onTap});

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.tealSoft : AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: selected ? AppColors.teal : AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(subtitle, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
