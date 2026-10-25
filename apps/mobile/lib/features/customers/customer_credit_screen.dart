import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/shipment.dart';
import '../../data/money_payload.dart';
import '../../l10n/l10n.dart';
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
        title: tr('Customer credit'),
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
                label: tr('Credit balance'),
                value: formatBdt(balance),
                tone: balance > 0 ? ChipTone.green : ChipTone.neutral),
            const SizedBox(height: 16),
            AppButton(
              label: tr('Apply to bill'),
              kind: AppButtonKind.current,
              onPressed: () => _open(ApplyCreditScreen(
                  code: widget.code, balance: balance, orders: widget.orders)),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: tr('Refund'),
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
      setState(() => _error =
          tr('Choose a shipment and enter an amount within the credit.'));
      return;
    }
    final shipmentCode = code;
    final ok = await confirmMoney(context,
        title: tr('Apply credit'),
        body: tr(
            '{amount} will be applied to the issued invoice for {shipment}. Draft bills are not affected.',
            {'amount': formatBdt(amount), 'shipment': shipmentCode}));
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
        title: tr('Apply to bill'),
        root: false,
        footer: ActionFooter(
            child: AppButton(
                label: tr('Apply'),
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr('Balance {amount}. Applies only to issued invoices that are not under review.',
                      {'amount': formatBdt(widget.balance)}),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          if (widget.orders.isEmpty)
            EmptyNote(
                title: tr('No shipments'),
                body: tr(
                    'Credit can be applied here once an invoice is issued.')),
          for (final order in widget.orders) ...[
            _OrderPick(
              title: order.code,
              subtitle:
                  tr('Due {amount}', {'amount': formatBdt(order.dueAmount)}),
              selected: _shipment == order.code,
              onTap: () => setState(() => _shipment = order.code),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: tr('Amount'))),
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
      setState(() => _error = tr(
          'Choose an account, an amount within the credit and a reason of at least 3 characters.'));
      return;
    }
    final chosen = account;
    final ok = await confirmMoney(context,
        title: tr('Refund credit'),
        body: tr('{amount} will be refunded from {account}.', {
          'amount': formatMoney(amount, chosen.currency),
          'account': chosen.name
        }));
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
        title: tr('Refund'),
        root: false,
        footer: ActionFooter(
            child: AppButton(
                label: tr('Save refund'),
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr('Balance {amount}. Choose the account the money leaves from.',
                      {'amount': formatBdt(widget.balance)}),
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
