import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/flight.dart';
import '../../data/money_payload.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/account_picker.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/ui.dart';
import '../admin/money_format.dart';

class FlightMoneyScreen extends StatefulWidget {
  const FlightMoneyScreen({super.key, required this.code});

  final String code;

  @override
  State<FlightMoneyScreen> createState() => _FlightMoneyScreenState();
}

class _FlightMoneyScreenState extends State<FlightMoneyScreen> {
  FlightDetail? _detail;
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
      final detail = await AppScope.of(context).flights.detail(widget.code);
      if (!mounted) return;
      setState(() => _detail = detail);
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
    final summary = _detail?.summary;
    return WorkspaceScaffold(title: tr('Ticket money'), root: false, children: [
      Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
              tr(
                  'Split contributions first, then record flyer payments. Ticket payment is separate.'),
              style: const TextStyle(
                  fontSize: 13, color: AppColors.muted, height: 1.5))),
      if (_loading && summary == null)
        const LinearProgressIndicator(
            color: AppColors.teal, backgroundColor: AppColors.tealSoft),
      if (_error != null) ...[
        ErrorNote(message: _error!, onRetry: _load),
        const SizedBox(height: 12),
      ],
      if (summary != null) ...[
        PaperCard(
          child: Column(
            children: [
              KvRow(
                  label: tr('Actual cost'),
                  value: formatBdt(summary.actualCost)),
              KvRow(label: tr('Agency'), value: formatBdt(summary.agencyShare)),
              KvRow(
                  label: tr('Due from flyers'),
                  value: formatBdt(summary.flyerDue)),
              KvRow(
                  label: tr('Ticket due'),
                  value: formatBdt(summary.ticketDue),
                  valueColor:
                      summary.ticketDue > 0 ? AppColors.danger : AppColors.ok),
              KvRow(
                  label: tr('Ticket refund'),
                  value: formatBdt(summary.ticketRefundDue)),
              if (summary.unallocatedFlyerPaid > 0)
                KvRow(
                    label: tr('Unallocated payments'),
                    value: formatBdt(summary.unallocatedFlyerPaid)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppButton(
            label: tr('Settle ticket payment'),
            kind: AppButtonKind.current,
            onPressed: () => _open(TicketSettleScreen(code: widget.code))),
        const SizedBox(height: 8),
        AppButton(
            label: tr('Split contributions'),
            kind: AppButtonKind.teal,
            onPressed: () => _open(ContributionScreen(code: widget.code))),
        const SizedBox(height: 8),
        AppButton(
            label: tr('Flyer payment'),
            kind: AppButtonKind.teal,
            onPressed: () => _open(FlyerPaymentScreen(code: widget.code))),
      ],
    ]);
  }
}

class TicketSettleScreen extends StatefulWidget {
  const TicketSettleScreen({super.key, required this.code});

  final String code;

  @override
  State<TicketSettleScreen> createState() => _TicketSettleScreenState();
}

class _TicketSettleScreenState extends State<TicketSettleScreen> {
  FlightSummary? _summary;
  List<FinanceAccount> _accounts = const [];
  String? _account;
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final scope = AppScope.of(context);
      final detail = await scope.flights.detail(widget.code);
      final finance = await scope.finance.snapshot();
      if (!mounted) return;
      setState(() {
        _summary = detail.summary;
        _accounts = finance.accounts;
      });
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _save() async {
    final summary = _summary;
    FinanceAccount? account;
    for (final row in _accounts) {
      if (row.name == _account) account = row;
    }
    if (summary == null || account == null) {
      setState(() => _error = tr('Choose an account.'));
      return;
    }
    final chosen = account;
    if (summary.ticketDue <= 0 && summary.ticketRefundDue <= 0) {
      setState(
          () => _error = tr('Nothing is due or to refund on this ticket.'));
      return;
    }
    final effect = summary.ticketDue > 0
        ? tr('Due: {movement}', {
            'movement': bdtFundMovement(
                amountBdt: summary.ticketDue,
                accountName: chosen.name,
                accountCurrency: chosen.currency,
                intoAccount: false)
          })
        : tr('Refund: {movement}', {
            'movement': bdtFundMovement(
                amountBdt: summary.ticketRefundDue,
                accountName: chosen.name,
                accountCurrency: chosen.currency,
                intoAccount: true)
          });
    final ok =
        await confirmMoney(context, title: tr('Settle ticket'), body: effect);
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).flights.settleTicket(widget.code, chosen.name);
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
    final summary = _summary;
    return WorkspaceScaffold(
        title: tr('Ticket payment'),
        root: false,
        footer: ActionFooter(
            child: AppButton(
                label: tr('Settle now'),
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr(
                      'Only the outstanding ticket cost or refund is posted to this account. Nothing else changes.'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          if (summary != null) ...[
            KvRow(label: tr('Due'), value: formatBdt(summary.ticketDue)),
            KvRow(
                label: tr('Refund'), value: formatBdt(summary.ticketRefundDue)),
          ],
          const SizedBox(height: 12),
          AccountPicker(
              accounts: _accounts,
              selected: _account,
              onSelected: (account) => setState(() => _account = account.name)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
        ]);
  }
}

class ContributionScreen extends StatefulWidget {
  const ContributionScreen({super.key, required this.code});

  final String code;

  @override
  State<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends State<ContributionScreen> {
  FlightSummary? _summary;
  final _contribution = <String, TextEditingController>{};
  final _legacy = <String, TextEditingController>{};
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final controller in _contribution.values) {
      controller.dispose();
    }
    for (final controller in _legacy.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final detail = await AppScope.of(context).flights.detail(widget.code);
      if (!mounted) return;
      final summary = detail.summary;
      for (final name in summary.flyers) {
        FlightSettlement? settlement;
        for (final row in summary.settlements) {
          if (row.name == name) settlement = row;
        }
        _contribution[name] = TextEditingController(
            text: settlement == null ? '' : settlement.contribution.toString());
        _legacy[name] = TextEditingController();
      }
      setState(() => _summary = summary);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _save() async {
    final summary = _summary;
    if (summary == null || summary.flyers.isEmpty) return;
    final target = roundMoney(summary.actualCost - summary.agencyShare);
    final rows = <({String name, double contribution, double legacyPaid})>[];
    var contributionSum = 0.0;
    var legacySum = 0.0;
    for (final name in summary.flyers) {
      final contribution = parseMoney(_contribution[name]?.text ?? '');
      final legacy = summary.unallocatedFlyerPaid <= 0
          ? 0.0
          : (_legacy[name]!.text.trim().isEmpty
              ? 0.0
              : parseMoney(_legacy[name]!.text));
      if (contribution == null ||
          contribution < 0 ||
          legacy == null ||
          legacy < 0) {
        setState(() => _error = tr('Enter 0 or more for each flyer.'));
        return;
      }
      contributionSum += contribution;
      legacySum += legacy;
      rows.add((name: name, contribution: contribution, legacyPaid: legacy));
    }
    if ((roundMoney(contributionSum) - target).abs() > 0.001) {
      setState(() => _error = tr('Contributions must add up to {amount}.',
          {'amount': formatBdt(target)}));
      return;
    }
    if ((roundMoney(legacySum) - summary.unallocatedFlyerPaid).abs() > 0.001) {
      setState(() => _error = tr(
          'Split the earlier unallocated payments of {amount} exactly once.',
          {'amount': formatBdt(summary.unallocatedFlyerPaid)}));
      return;
    }
    final ok = await confirmMoney(context,
        title: tr('Contributions'),
        body: tr(
            'The flyer share of {amount} will be locked. Later payments cannot exceed it.',
            {'amount': formatBdt(target)}));
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context)
          .flights
          .allocateContributions(widget.code, rows);
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
    final summary = _summary;
    final target = summary == null
        ? 0.0
        : roundMoney(summary.actualCost - summary.agencyShare);
    return WorkspaceScaffold(
        title: tr('Contributions'),
        root: false,
        footer: ActionFooter(
            child: AppButton(
                label: tr('Save split'),
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed:
                    summary == null || summary.flyers.isEmpty ? null : _save)),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr('Shares must add up to {amount}. One entry per flyer.',
                      {'amount': formatBdt(target)}),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          if (summary == null)
            const LinearProgressIndicator(
                color: AppColors.teal, backgroundColor: AppColors.tealSoft)
          else if (summary.flyers.isEmpty)
            EmptyNote(
                title: tr('No flyers'),
                body: tr('Add flyers to the flight first.'))
          else
            for (final name in summary.flyers) ...[
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: _contribution[name],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: tr('Contribution')),
              ),
              if (summary.unallocatedFlyerPaid > 0) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _legacy[name],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: tr('Earlier payment'),
                      helperText: tr('Total {amount}',
                          {'amount': formatBdt(summary.unallocatedFlyerPaid)})),
                ),
              ],
              const SizedBox(height: 12),
            ],
          if (_error != null)
            Text(_error!,
                style: const TextStyle(color: AppColors.danger, height: 1.35)),
        ]);
  }
}

class FlyerPaymentScreen extends StatefulWidget {
  const FlyerPaymentScreen({super.key, required this.code});

  final String code;

  @override
  State<FlyerPaymentScreen> createState() => _FlyerPaymentScreenState();
}

class _FlyerPaymentScreenState extends State<FlyerPaymentScreen> {
  FlightSummary? _summary;
  List<FinanceAccount> _accounts = const [];
  final _amount = TextEditingController();
  String? _flyer;
  String? _account;
  String? _error;
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
      final scope = AppScope.of(context);
      final detail = await scope.flights.detail(widget.code);
      final finance = await scope.finance.snapshot();
      if (!mounted) return;
      setState(() {
        _summary = detail.summary;
        _accounts = finance.accounts;
      });
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    }
  }

  FlightSettlement? _settlement(String name) {
    final summary = _summary;
    if (summary == null) return null;
    for (final row in summary.settlements) {
      if (row.name == name) return row;
    }
    return null;
  }

  Future<void> _save() async {
    final name = _flyer;
    final settlement = name == null ? null : _settlement(name);
    FinanceAccount? account;
    for (final row in _accounts) {
      if (row.name == _account) account = row;
    }
    final amount = parseMoney(_amount.text);
    if (name == null ||
        settlement == null ||
        settlement.contribution <= 0 ||
        account == null ||
        amount == null ||
        amount <= 0) {
      setState(() => _error = tr(
          'Save the split first, then choose the flyer, account and amount.'));
      return;
    }
    final chosen = account;
    final due = roundMoney(settlement.contribution - settlement.paidAmount);
    if (amount > due + 0.001) {
      setState(() => _error = tr(
          "Enter no more than this flyer's {amount} due.",
          {'amount': formatBdt(due)}));
      return;
    }
    final ok = await confirmMoney(context,
        title: tr('Flyer payment'),
        body: tr('{amount} goes into {account} as a payment from {flyer}.', {
          'amount': formatMoney(amount, chosen.currency),
          'account': chosen.name,
          'flyer': name
        }));
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).flights.recordFlyerPayment(widget.code,
          amount: amount,
          accountName: chosen.name,
          currency: chosen.currency,
          flyerName: name);
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
    final summary = _summary;
    return WorkspaceScaffold(
        title: tr('Flyer payment'),
        root: false,
        footer: ActionFooter(
            child: AppButton(
                label: tr('Save flyer payment'),
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr(
                      'Record the account the money arrived in and the flyer who paid.'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          if (summary == null)
            const LinearProgressIndicator(
                color: AppColors.teal, backgroundColor: AppColors.tealSoft)
          else ...[
            for (final name in summary.flyers) ...[
              _PickTile(
                title: name,
                subtitle: () {
                  final row = _settlement(name);
                  if (row == null) return tr('Split not saved yet');
                  return tr('Share {share} · Paid {paid}', {
                    'share': formatBdt(row.contribution),
                    'paid': formatBdt(row.paidAmount)
                  });
                }(),
                selected: _flyer == name,
                onTap: () => setState(() => _flyer = name),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            AccountPicker(
                accounts: _accounts,
                selected: _account,
                onSelected: (account) =>
                    setState(() => _account = account.name)),
            TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: tr('Amount received'))),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
        ]);
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile(
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
          padding: const EdgeInsets.all(14),
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
