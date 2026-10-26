import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/shipment.dart';
import '../../data/money_payload.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/finance_parts.dart';
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
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
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
        subtitle: '${widget.name} · ${widget.code}',
        root: false,
        onRefresh: _load,
        children: [
          if (_loading && balance == null) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (balance != null) ...[
            MoneyHero(children: [
              HeroAmount(
                  label: tr('Credit balance'), value: formatBdt(balance)),
              const SizedBox(height: 8),
              Text(
                  balance > 0
                      ? tr(
                          'Advances and adjustments the customer has not used yet.')
                      : tr('No credit to use or refund right now.'),
                  style: const TextStyle(
                      fontSize: 12, height: 1.45, color: HeroColors.soft)),
            ]),
            const SizedBox(height: 20),
            SectionTitle(title: tr('Use the credit')),
            SurfaceGroup(children: [
              MenuRow(
                  key: const Key('credit-apply'),
                  title: tr('Apply to bill'),
                  subtitle: tr('Pay part of an issued invoice from the credit'),
                  icon: Icons.sell_outlined,
                  onTap: () => _open(ApplyCreditScreen(
                      code: widget.code,
                      balance: balance,
                      orders: widget.orders))),
              MenuRow(
                  key: const Key('credit-refund'),
                  title: tr('Refund'),
                  subtitle: tr('Give the credit back from an account'),
                  icon: Icons.north_east_rounded,
                  tone: ChipTone.neutral,
                  onTap: () => _open(
                      RefundCreditScreen(code: widget.code, balance: balance))),
            ]),
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
        subtitle: tr(
            'Credit balance {amount}', {'amount': formatBdt(widget.balance)}),
        root: false,
        footer: ActionFooter(
            child: AppButton(
                key: const Key('credit-apply-save'),
                label: tr('Apply'),
                icon: Icons.check_rounded,
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          HintNote(
              text: tr(
                  'Balance {amount}. Applies only to issued invoices that are not under review.',
                  {'amount': formatBdt(widget.balance)})),
          const SizedBox(height: 20),
          SectionTitle(title: tr('Shipment')),
          if (widget.orders.isEmpty)
            EmptyNote(
                icon: Icons.inventory_2_outlined,
                title: tr('No shipments'),
                body:
                    tr('Credit can be applied here once an invoice is issued.'))
          else
            ListCard(children: [
              for (final order in widget.orders)
                RadioRow(
                    key: ValueKey('credit-order-${order.code}'),
                    title: order.code,
                    subtitle: tr(
                        'Due {amount}', {'amount': formatBdt(order.dueAmount)}),
                    icon: Icons.inventory_2_outlined,
                    selected: _shipment == order.code,
                    onTap: () => setState(() => _shipment = order.code)),
            ]),
          const SizedBox(height: 16),
          FieldLabel(tr('Amount (BDT)')),
          MoneyField(
              key: const Key('credit-apply-amount'),
              controller: _amount,
              currency: 'BDT',
              hint: widget.balance.toStringAsFixed(2)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorNote(message: _error!),
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
  var _loading = true;
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
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  FinanceAccount? get _picked {
    for (final row in _accounts) {
      if (row.name == _account) return row;
    }
    return null;
  }

  Future<void> _save() async {
    final account = _picked;
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
    final account = _picked;
    final amount = parseMoney(_amount.text);
    return WorkspaceScaffold(
        title: tr('Refund'),
        subtitle: tr(
            'Credit balance {amount}', {'amount': formatBdt(widget.balance)}),
        root: false,
        footer: ActionFooter(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (account != null && amount != null && amount > 0) ...[
            AmountSentence(
                template:
                    tr('{amount} leaves {account}.', {'account': account.name}),
                amount: formatMoney(amount, account.currency)),
            const SizedBox(height: 8),
          ],
          AppButton(
              key: const Key('credit-refund-save'),
              label: tr('Save refund'),
              icon: Icons.check_rounded,
              kind: AppButtonKind.current,
              busy: _busy,
              onPressed: _save),
        ])),
        children: [
          HintNote(
              text: tr(
                  'Balance {amount}. Choose the account the money leaves from.',
                  {'amount': formatBdt(widget.balance)})),
          const SizedBox(height: 20),
          SectionTitle(title: tr('Paid from')),
          if (_loading)
            const LinearProgressIndicator()
          else
            AccountChoiceList(
                accounts: _accounts,
                selected: _account,
                onSelected: (account) =>
                    setState(() => _account = account.name)),
          const SizedBox(height: 16),
          FieldLabel(account == null
              ? tr('Amount')
              : tr('Amount ({currency})', {'currency': account.currency})),
          MoneyField(
              key: const Key('credit-refund-amount'),
              controller: _amount,
              currency: account?.currency,
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 16),
          FieldLabel(tr('Reason')),
          TextField(
              key: const Key('credit-refund-reason'),
              controller: _reason,
              maxLength: 200,
              minLines: 2,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  InputDecoration(hintText: tr('At least 3 characters'))),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorNote(message: _error!),
          ],
        ]);
  }
}
