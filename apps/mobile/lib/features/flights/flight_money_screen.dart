import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/flight.dart';
import '../../data/models/hub_flight.dart';
import '../../data/money_payload.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/account_picker.dart';
import '../../widgets/flight_parts.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/ui.dart';
import '../admin/money_format.dart';
import 'flight_detail_screen.dart';

/// "BG305 · Wednesday 21 Oct" under a ticket money title.
String _flightLine(FlightSummary? summary, String code) {
  if (summary == null) return displayFlightCode(code);
  final day = FlightDay.parse(summary.date);
  return [
    summary.displayCode,
    if (day != null) '${day.weekdayName} ${day.day} ${day.month}'
  ].join(' · ');
}

FlightSettlement? _settlement(FlightSummary? summary, String name) {
  if (summary == null) return null;
  for (final row in summary.settlements) {
    if (row.name == name) return row;
  }
  return null;
}

/// 15000 rather than 15000.0 in an amount field.
String _plain(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();

/// The flyers' part of the ticket: actual cost less the agency share.
double _flyerShare(FlightSummary summary) =>
    roundMoney(summary.actualCost - summary.agencyShare);

/// Money flyers have paid on this ticket, split or not.
double _flyerReceived(FlightSummary summary) => roundMoney(
    summary.settlements.fold(0.0, (total, row) => total + row.paidAmount) +
        summary.unallocatedFlyerPaid);

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
    return WorkspaceScaffold(
        title: tr('Ticket money'),
        subtitle: _flightLine(summary, widget.code),
        root: false,
        onRefresh: _load,
        footer: ActionFooter(
            child: AppButton(
                label: tr('Record flyer payment'),
                icon: Icons.south_west_rounded,
                kind: AppButtonKind.current,
                onPressed: summary == null
                    ? null
                    : () => _open(FlyerPaymentScreen(code: widget.code)))),
        children: [
          if (_loading && summary == null) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (summary != null) ...[
            _TicketHero(summary: summary),
            const SizedBox(height: 14),
            _FromFlyers(
                summary: summary,
                onSplit: () => _open(ContributionScreen(code: widget.code))),
            const SizedBox(height: 14),
            _TicketPayment(
                summary: summary,
                onSettle: () => _open(TicketSettleScreen(code: widget.code))),
          ],
        ]);
  }
}

class _TicketHero extends StatelessWidget {
  const _TicketHero({required this.summary});
  final FlightSummary summary;

  @override
  Widget build(BuildContext context) {
    final cost = summary.actualCost;
    final share = _flyerShare(summary);
    final agencyPart = cost <= 0 ? 0.0 : (summary.agencyShare / cost);
    Widget legend(Color dot, String label, String value) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Flexible(
              child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '$label ',
                        style: const TextStyle(color: heroSoft)),
                    TextSpan(
                        text: value,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ]),
                  style: const TextStyle(fontSize: 13, height: 1.4))),
        ]);
    const agencyColor = Color(0x61FFFFFF);
    return MoneyHero(
        label: tr('Actual ticket cost'),
        amount: formatBdt(cost),
        amountSize: 32,
        children: [
          Semantics(
              label: tr("Agency share {agency}, flyers' share {flyers}", {
                'agency': formatBdt(summary.agencyShare),
                'flyers': formatBdt(share)
              }),
              excludeSemantics: true,
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: SizedBox(
                      height: 10,
                      child: Row(children: [
                        if (agencyPart > 0)
                          Expanded(
                              flex: (agencyPart * 1000).round().clamp(1, 1000),
                              child: Container(color: agencyColor)),
                        if (agencyPart > 0 && agencyPart < 1)
                          const SizedBox(width: 3),
                        if (agencyPart < 1)
                          Expanded(
                              flex: ((1 - agencyPart) * 1000)
                                  .round()
                                  .clamp(1, 1000),
                              child: Container(
                                  color: cost <= 0
                                      ? const Color(0x24FFFFFF)
                                      : Colors.white)),
                      ])))),
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 6,
              children: [
                legend(agencyColor, tr('Agency share'),
                    formatBdt(summary.agencyShare)),
                legend(Colors.white, tr("Flyers' share"), formatBdt(share)),
              ]),
          HeroFigures(size: 17, figures: [
            HeroFigure(tr('Due from flyers'), formatBdt(summary.flyerDue),
                alert: summary.flyerDue > 0),
            summary.ticketDue <= 0 && summary.ticketRefundDue > 0
                ? HeroFigure(
                    tr('Ticket refund'), formatBdt(summary.ticketRefundDue))
                : HeroFigure(tr('Ticket due'), formatBdt(summary.ticketDue),
                    alert: summary.ticketDue > 0),
          ]),
        ]);
  }
}

class _FromFlyers extends StatelessWidget {
  const _FromFlyers({required this.summary, required this.onSplit});
  final FlightSummary summary;
  final VoidCallback onSplit;

  @override
  Widget build(BuildContext context) {
    final share = _flyerShare(summary);
    final received = _flyerReceived(summary);
    final splitSaved = summary.settlements.any((row) => row.contribution > 0);
    final hasFlyers = summary.flyers.isNotEmpty;
    final String? note = !hasFlyers
        ? null
        : summary.unallocatedFlyerPaid > 0
            ? tr(
                '{amount} was received before the split and is not assigned to a flyer yet. Assign it once in the split.',
                {
                    'amount': formatBdt(summary.unallocatedFlyerPaid)
                  })
            : !splitSaved && share > 0
                ? tr(
                    'Split the share between the flyers before recording their payments.')
                : null;
    return PaperCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CardHeading(
          icon: Icons.groups_2_outlined,
          title: tr('From flyers'),
          subtitle: tr('Split the {amount} share, then record payments',
              {'amount': formatBdt(share)})),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
            child: Text(
                tr('{amount} received', {'amount': formatBdt(received)}),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, height: 1.4))),
        const SizedBox(width: 8),
        Flexible(
            child: Text(
                tr('{amount} to go', {'amount': formatBdt(summary.flyerDue)}),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13, height: 1.5, color: AppColors.muted))),
      ]),
      const SizedBox(height: 6),
      MeterBar(value: share <= 0 ? 0 : received / share),
      const SizedBox(height: 4),
      if (!hasFlyers)
        Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(tr('Add flyers to the flight first.'),
                style: const TextStyle(color: AppColors.muted, height: 1.45)))
      else
        for (var i = 0; i < summary.flyers.length; i++) ...[
          const Divider(height: 1, color: AppColors.lineSoft),
          FlyerShareRow(
              name: summary.flyers[i],
              settlement: _settlement(summary, summary.flyers[i]),
              first: i == 0,
              padding: const EdgeInsets.symmetric(vertical: 12)),
        ],
      const SizedBox(height: 6),
      if (note != null)
        ActionNote(
            text: note,
            action: AccentOutlineButton(
                label: tr('Split contributions'),
                icon: Icons.call_split_rounded,
                onPressed: onSplit))
      else if (hasFlyers)
        AppButton(
            label: tr('Split contributions'),
            icon: Icons.call_split_rounded,
            kind: AppButtonKind.quiet,
            onPressed: onSplit),
    ]));
  }
}

class _TicketPayment extends StatelessWidget {
  const _TicketPayment({required this.summary, required this.onSettle});
  final FlightSummary summary;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) => PaperCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardHeading(
            icon: Icons.confirmation_number_outlined,
            tone: ChipTone.neutral,
            title: tr('Ticket payment'),
            subtitle: tr('Separate from flyer payments')),
        const SizedBox(height: 14),
        StatStrip(items: [
          (tr('Paid'), formatBdt(summary.ticketPaid), null),
          (
            tr('Ticket due'),
            formatBdt(summary.ticketDue),
            summary.ticketDue > 0 ? AppColors.danger : null
          ),
          (tr('Refund'), formatBdt(summary.ticketRefundDue), AppColors.inkSoft),
        ]),
        const SizedBox(height: 14),
        Text(tr('Settling posts only the outstanding ticket cost (or a refund) to the account you choose. Nothing else changes.'),
            style: const TextStyle(
                fontSize: 13, height: 1.5, color: AppColors.muted)),
        const SizedBox(height: 14),
        AppButton(
            label: tr('Settle ticket payment'),
            icon: Icons.north_east_rounded,
            kind: AppButtonKind.quiet,
            onPressed: onSettle),
      ]));
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
    final refund = summary != null &&
        summary.ticketDue <= 0 &&
        summary.ticketRefundDue > 0;
    return WorkspaceScaffold(
        title: tr('Ticket payment'),
        subtitle: _flightLine(summary, widget.code),
        root: false,
        footer: ActionFooter(
            child: AppButton(
                label: tr('Settle now'),
                icon: Icons.check_rounded,
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          if (summary == null && _error == null)
            const LinearProgressIndicator(),
          if (summary != null) ...[
            MoneyHero(
                label: refund ? tr('Ticket refund') : tr('Ticket due'),
                amount: formatBdt(
                    refund ? summary.ticketRefundDue : summary.ticketDue),
                children: [
                  HeroFigures(figures: [
                    HeroFigure(
                        tr('Actual cost'), formatBdt(summary.actualCost)),
                    HeroFigure(tr('Paid'), formatBdt(summary.ticketPaid)),
                    HeroFigure(
                        tr('Refund'), formatBdt(summary.ticketRefundDue)),
                  ]),
                ]),
            const SizedBox(height: 14),
          ],
          PaperCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                CardHeading(
                    icon: Icons.account_balance_wallet_outlined,
                    title: refund
                        ? tr('Refund into account')
                        : tr('Pay from account'),
                    subtitle: tr(
                        'Only the outstanding ticket cost or refund is posted to this account. Nothing else changes.')),
                const SizedBox(height: 14),
                AccountPicker(
                    accounts: _accounts,
                    selected: _account,
                    onSelected: (account) =>
                        setState(() => _account = account.name)),
              ])),
          if (_error != null) ...[
            const SizedBox(height: 14),
            ErrorNote(message: _error!),
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

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final detail = await AppScope.of(context).flights.detail(widget.code);
      if (!mounted) return;
      final summary = detail.summary;
      for (final name in summary.flyers) {
        final settlement = _settlement(summary, name);
        _contribution[name] = TextEditingController(
            text: settlement == null ? '' : _plain(settlement.contribution))
          ..addListener(_changed);
        _legacy[name] = TextEditingController()..addListener(_changed);
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
    final target = _flyerShare(summary);
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

  /// Sum of what is typed so far; blanks and bad input count as 0.
  double _entered(Map<String, TextEditingController> fields) => roundMoney(
      fields.values.fold(0.0, (total, c) => total + (parseMoney(c.text) ?? 0)));

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final target = summary == null ? 0.0 : _flyerShare(summary);
    final entered = _entered(_contribution);
    final left = roundMoney(target - entered);
    final legacyLeft = summary == null
        ? 0.0
        : roundMoney(summary.unallocatedFlyerPaid - _entered(_legacy));
    return WorkspaceScaffold(
        title: tr('Contributions'),
        subtitle: _flightLine(summary, widget.code),
        root: false,
        footer: ActionFooter(
            child: AppButton(
                label: tr('Save split'),
                icon: Icons.check_rounded,
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed:
                    summary == null || summary.flyers.isEmpty ? null : _save)),
        children: [
          if (summary == null && _error == null)
            const LinearProgressIndicator()
          else if (summary != null && summary.flyers.isEmpty)
            EmptyNote(
                icon: Icons.person_outline_rounded,
                title: tr('No flyers'),
                body: tr('Add flyers to the flight first.'))
          else if (summary != null) ...[
            MoneyHero(
                label: tr("Flyers' share"),
                amount: formatBdt(target),
                children: [
                  Text(
                      tr('Shares must add up to {amount}. One entry per flyer.',
                          {'amount': formatBdt(target)}),
                      style: const TextStyle(
                          fontSize: 13, height: 1.45, color: heroSoft)),
                  HeroFigures(figures: [
                    HeroFigure(tr('Entered'), formatBdt(entered)),
                    left.abs() < 0.001
                        ? HeroFigure(tr('Left to split'), formatBdt(0))
                        : HeroFigure(
                            left > 0 ? tr('Left to split') : tr('Too much'),
                            formatBdt(left.abs()),
                            alert: true),
                  ]),
                ]),
            const SizedBox(height: 14),
            if (summary.unallocatedFlyerPaid > 0) ...[
              ActionNote(
                  text: tr(
                      '{amount} was received before the split. Enter who paid it under each flyer, once in total.',
                      {'amount': formatBdt(summary.unallocatedFlyerPaid)})),
              const SizedBox(height: 14),
            ],
            for (var i = 0; i < summary.flyers.length; i++) ...[
              PaperCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Row(children: [
                      LetterAvatar(summary.flyers[i],
                          color:
                              i == 0 ? AppColors.primary : AppColors.inkSoft),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(summary.flyers[i],
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700))),
                    ]),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _contribution[summary.flyers[i]],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: tr('Contribution'),
                          prefixIcon: currencyPrefix('BDT'),
                          prefixIconConstraints: currencyPrefixConstraints),
                    ),
                    if (summary.unallocatedFlyerPaid > 0) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _legacy[summary.flyers[i]],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                            labelText: tr('Earlier payment'),
                            prefixIcon: currencyPrefix('BDT'),
                            prefixIconConstraints: currencyPrefixConstraints,
                            helperText: tr('Total {amount}', {
                              'amount': formatBdt(summary.unallocatedFlyerPaid)
                            })),
                      ),
                    ],
                  ])),
              const SizedBox(height: 12),
            ],
            if (summary.unallocatedFlyerPaid > 0 && legacyLeft.abs() >= 0.001)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4),
                  child: Text(
                      tr('{amount} of the earlier payment still to assign.',
                          {'amount': formatBdt(legacyLeft)}),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted, height: 1.45))),
          ],
          if (_error != null) ErrorNote(message: _error!),
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

  FinanceAccount? get _selectedAccount {
    for (final row in _accounts) {
      if (row.name == _account) return row;
    }
    return null;
  }

  Future<void> _save() async {
    final name = _flyer;
    final settlement = name == null ? null : _settlement(_summary, name);
    final account = _selectedAccount;
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
    final account = _selectedAccount;
    final chosen = _flyer == null ? null : _settlement(summary, _flyer!);
    return WorkspaceScaffold(
        title: tr('Flyer payment'),
        subtitle: _flightLine(summary, widget.code),
        root: false,
        footer: ActionFooter(
            child: AppButton(
                label: tr('Save flyer payment'),
                icon: Icons.check_rounded,
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
              child: Text(
                  tr(
                      'Record the account the money arrived in and the flyer who paid.'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          if (summary == null && _error == null)
            const LinearProgressIndicator()
          else if (summary != null) ...[
            SectionTitle(title: tr('Who paid')),
            if (summary.flyers.isEmpty)
              EmptyNote(
                  icon: Icons.person_outline_rounded,
                  title: tr('No flyers'),
                  body: tr('Add flyers to the flight first.'))
            else
              RowCard(children: [
                for (var i = 0; i < summary.flyers.length; i++)
                  _FlyerPick(
                      name: summary.flyers[i],
                      settlement: _settlement(summary, summary.flyers[i]),
                      first: i == 0,
                      selected: _flyer == summary.flyers[i],
                      onTap: () => setState(() => _flyer = summary.flyers[i])),
              ]),
            const SizedBox(height: 16),
            PaperCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  FieldLabel(tr('Received in')),
                  AccountPicker(
                      accounts: _accounts,
                      selected: _account,
                      onSelected: (account) =>
                          setState(() => _account = account.name)),
                  FieldLabel(tr('Amount received ({currency})',
                      {'currency': account?.currency ?? 'BDT'})),
                  TextField(
                      controller: _amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                          hintText: '0',
                          prefixIcon:
                              currencyPrefix(account?.currency ?? 'BDT'),
                          prefixIconConstraints: currencyPrefixConstraints,
                          helperText: chosen == null || chosen.contribution <= 0
                              ? null
                              : tr('{amount} due from this flyer.',
                                  {'amount': formatBdt(chosen.due)}))),
                ])),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            ErrorNote(message: _error!),
          ],
        ]);
  }
}

class _FlyerPick extends StatelessWidget {
  const _FlyerPick(
      {required this.name,
      required this.settlement,
      required this.first,
      required this.selected,
      required this.onTap});

  final String name;
  final FlightSettlement? settlement;
  final bool first, selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final row = settlement;
    final split = row != null && row.contribution > 0;
    return RadioRow(
        selected: selected,
        onTap: onTap,
        leading: LetterAvatar(name,
            size: 34, color: first ? AppColors.primary : AppColors.inkSoft),
        title: name,
        subtitle: split
            ? tr('Share {share} · Paid {paid}', {
                'share': formatBdt(row.contribution),
                'paid': formatBdt(row.paidAmount)
              })
            : tr('Split not saved yet'),
        trailing: !split
            ? null
            : row.due <= 0
                ? StatusPill(label: tr('Paid up'), tone: ChipTone.green)
                : null);
  }
}
