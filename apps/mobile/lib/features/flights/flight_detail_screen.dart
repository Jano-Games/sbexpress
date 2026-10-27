import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/flight.dart';
import '../../data/models/flow.dart';
import '../../data/models/hub_flight.dart';
import '../../data/models/shipment.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/finance_parts.dart' show showAccountSheet;
import '../../widgets/flight_parts.dart';
import '../../widgets/flow_parts.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/quick_parts.dart' show plainKg;
import '../../widgets/remove_parts.dart';
import '../../widgets/round7_parts.dart';
import '../../widgets/ui.dart';
import '../admin/admin_shipment_screen.dart';
import '../admin/money_format.dart';
import '../intake/intake_screen.dart';
import 'add_flight_cost_sheet.dart';
import 'hub_flights_screen.dart' show banglaPlace;
import 'ticket_flyers_screen.dart';

/// One flight: its route and load, what it earns, its costs, the ticket and
/// flyers, and the shipments on it.
class FlightDetailScreen extends StatefulWidget {
  const FlightDetailScreen({super.key, required this.code});

  final String code;

  @override
  State<FlightDetailScreen> createState() => _FlightDetailScreenState();
}

class _FlightDetailScreenState extends State<FlightDetailScreen> {
  FlightDetail? _detail;
  String? _error;
  var _loading = true;
  var _deleting = false;

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

  Future<void> _push(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) await _load();
  }

  Future<void> _addCost(FlightDetail detail) async {
    final saved = await showAddFlightCostSheet(context,
        code: widget.code,
        flight: detail.summary.displayCode,
        costsSoFar: _costTotal(detail),
        profit: detail.profitBreakdown?.profit);
    if (saved == true && mounted) await _load();
  }

  /// Pays a cost saved as pay later: pick the account, confirm, post.
  Future<void> _payCost(FlightCost cost) async {
    final scope = AppScope.of(context);
    List<FinanceAccount> accounts;
    try {
      accounts = (await scope.finance.snapshot()).accounts;
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      await showRemovalNotice(context,
          title: tr('Not paid'), message: error.message);
      return;
    }
    if (!mounted) return;
    final account = await showAccountSheet(context,
        title: tr('Paid from'), accounts: accounts);
    if (account == null || !mounted) return;
    final ok = await confirmMoney(context,
        title: tr('Pay cost'),
        body: bdtFundMovement(
            amountBdt: cost.amount,
            accountName: account.name,
            accountCurrency: account.currency,
            intoAccount: false));
    if (!ok || !mounted) return;
    try {
      await scope.flights
          .payCost(widget.code, cost.id, accountName: account.name);
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      await showRemovalNotice(context,
          title: tr('Not paid'),
          message: error.status == 404
              ? tr(
                  'The server needs an update before flight costs can be marked paid.')
              : error.message);
    }
  }

  /// Reverses a flight cost after a confirm; money paid from an account
  /// goes back to it.
  Future<void> _removeCost(FlightCost cost) async {
    final ok = await confirmRemoval(context,
        title: tr('Remove this flight cost?'),
        body: tr(
            '{name} · {amount} is reversed. If it was paid, the money goes back to its account.',
            {'name': flightCostTitle(cost), 'amount': formatBdt(cost.amount)}),
        action: tr('Remove'));
    if (!ok || !mounted) return;
    try {
      await AppScope.of(context).flights.removeCost(widget.code, cost.id);
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      await showRemovalNotice(context,
          title: tr('Not removed'),
          message: error.status == 404
              ? tr(
                  'The server needs an update before flight costs can be removed.')
              : error.message);
    }
  }

  /// The server refuses while the flight has bookings, a ticket cost or
  /// payments, and says which.
  Future<void> _delete(FlightSummary summary) {
    final flights = AppScope.of(context).flights;
    return confirmAndDelete(context,
        title: tr('Delete flight'),
        question: tr('Delete flight {code}? This cannot be undone.',
            {'code': summary.displayCode}),
        refusedTitle: tr('This flight cannot be deleted'),
        delete: () => flights.delete(widget.code),
        onBusy: (busy) {
          if (mounted) setState(() => _deleting = busy);
        });
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final summary = detail?.summary;
    final day = summary == null ? null : FlightDay.parse(summary.date);
    final bookings = detail?.bookings ?? const <AdminShipment>[];
    return Scaffold(
      appBar: BackTitle(
          title: summary?.displayCode ?? displayFlightCode(widget.code),
          subtitle: day == null
              ? null
              : '${day.weekdayName} · ${day.day} ${day.month}',
          actions: [
            if (summary != null)
              Center(
                  child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: StatusPill(
                              label: trn(bookings.length, '{n} shipment',
                                  '{n} shipments'),
                              tone: ChipTone.neutral)))),
          ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(pageGutter, 16, pageGutter, 32),
          children: [
            if (_loading && detail == null) const LinearProgressIndicator(),
            if (_error != null) ErrorNote(message: _error!, onRetry: _load),
            if (summary != null && detail != null) ...[
              _RouteCard(summary: summary, day: day),
              const SizedBox(height: 14),
              if (detail.profitBreakdown != null)
                _FlightProfitCard(detail: detail)
              else
                _ProfitCard(summary: summary, bookings: bookings),
              // Shown on an older server too: Add then says it needs an update.
              const SizedBox(height: 14),
              _FlightCostsCard(
                  detail: detail,
                  onAdd: () => _addCost(detail),
                  onPay: _payCost,
                  onRemove: _removeCost),
              if (detail.flightCosts != null) ...[
                const SizedBox(height: 14),
                _CostShareCard(detail: detail),
              ],
              const SizedBox(height: 14),
              LinkCard(
                  key: const Key('flight-ticket'),
                  icon: Icons.confirmation_number_outlined,
                  title: tr('Ticket and flyers'),
                  lines: [
                    _ticketLine(summary),
                    summary.flyers.isEmpty
                        ? tr('No flyers yet')
                        : summary.flyers.join(', '),
                  ],
                  onTap: () => _push(TicketFlyersScreen(code: widget.code))),
              const SizedBox(height: 20),
              _ShipmentsHeading(bookings: bookings),
              if (bookings.isEmpty)
                EmptyNote(
                    icon: Icons.inventory_2_outlined,
                    title: tr('No bookings'),
                    body: tr('Choose this flight from shipment intake.'))
              else
                RowCard(children: [
                  for (final booking in bookings)
                    _BookingRow(
                        row: booking,
                        onTap: () =>
                            _push(AdminShipmentScreen(code: booking.code))),
                ]),
              const SizedBox(height: 24),
              QuietDeleteButton(
                  key: const Key('flight-delete'),
                  label: tr('Delete flight'),
                  busy: _deleting,
                  onPressed: () => _delete(summary)),
            ],
          ],
        ),
      ),
      bottomNavigationBar: summary == null || summary.status != 'upcoming'
          ? null
          : ActionFooter(
              child: AppButton(
                  key: const Key('flight-book'),
                  label: tr('Book shipment · {kg} kg free',
                      {'kg': _kg(summary.leftKg < 0 ? 0 : summary.leftKg)}),
                  icon: Icons.add_rounded,
                  kind: AppButtonKind.current,
                  onPressed: () =>
                      _push(IntakeScreen(lockedFlightCode: widget.code)))),
    );
  }
}

String _kg(double value) =>
    value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);

String _ticketLine(FlightSummary summary) {
  if (summary.actualCost <= 0) return tr('Ticket cost not added yet');
  if (summary.flyersShare <= 0.001) {
    return tr(
        'We pay all · {amount}', {'amount': formatBdt(summary.actualCost)});
  }
  return tr('Flyers pay part · we pay {amount}',
      {'amount': formatBdt(summary.agencyShare)});
}

/// The flight costs' total: the server's sum, else the rows added up.
double _costTotal(FlightDetail detail) =>
    detail.flightCostTotal ??
    (detail.flightCosts ?? const <FlightCost>[])
        .fold(0.0, (sum, cost) => sum + cost.amount);

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.summary, required this.day});
  final FlightSummary summary;
  final FlightDay? day;

  @override
  Widget build(BuildContext context) {
    final badge = adminFlightBadge(summary, day, detail: true);
    final plain = summary.status == 'upcoming' &&
        !summary.scheduleNeedsConfirmation &&
        (day == null || day!.daysAway >= 0);
    Widget end(String time, String place, {bool right = false}) {
      final known = isClockTime(time);
      return Column(
          crossAxisAlignment:
              right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(known ? time : '--:--',
                style: TextStyle(
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: known ? AppColors.ink : AppColors.faint,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            Text(place,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]);
    }

    return PaperCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!plain) ...[
            Align(
                alignment: Alignment.centerLeft,
                child: StatusPill(
                    label: summary.scheduleNeedsConfirmation
                        ? tr('Date has passed · Confirm the status')
                        : badge.$1,
                    tone: summary.scheduleNeedsConfirmation
                        ? ChipTone.amber
                        : badge.$2)),
            const SizedBox(height: 10),
          ],
          Row(children: [
            Expanded(
                flex: 3,
                child: end(summary.depTime,
                    banglaPlace(summary.from, fallback: tr('China')))),
            const SizedBox(width: 10),
            Expanded(
                flex: 4,
                child: Column(children: [
                  const DashedPlane(size: 22, highlight: true),
                  Text(stopText(summary.stopLabel),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, height: 1.2, color: AppColors.muted)),
                ])),
            const SizedBox(width: 10),
            Expanded(
                flex: 3,
                child: end(summary.arrTime,
                    banglaPlace(summary.to, fallback: tr('Bangladesh')),
                    right: true)),
          ]),
          const Divider(height: 24, color: AppColors.lineSoft),
          MeterBar(value: summary.fill),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
                child: CapacityText(
                    booked: summary.bookedKg,
                    space: summary.spaceKg.toDouble())),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _Count(
                icon: Icons.smartphone_rounded,
                label: tr('Mobiles {n}', {'n': summary.mobiles})),
            const SizedBox(width: 14),
            _Count(
                icon: Icons.laptop_rounded,
                label: tr('Laptops {n}', {'n': summary.laptops})),
          ]),
        ]));
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: AppColors.inkSoft),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
      ]);
}

/// Navy card: charges − shipment costs − our ticket share = profit, and the
/// money still to come in.
class _ProfitCard extends StatelessWidget {
  const _ProfitCard({required this.summary, required this.bookings});
  final FlightSummary summary;
  final List<AdminShipment> bookings;

  String _note() {
    if (bookings.isEmpty) return tr('No shipments booked yet');
    final none = [
      for (final row in bookings)
        if (row.costTotal != null && row.costTotal! <= 0) row.code
    ];
    if (none.length == 1) {
      return tr('So far · {code} has no costs added yet', {'code': none.first});
    }
    if (none.length > 1) {
      return tr(
          'So far · {n} shipments have no costs added yet', {'n': none.length});
    }
    final open = bookings.any((row) =>
        row.usualCosts != null &&
        usualCostsAdded(row.usualCosts!) < row.usualCosts!.length);
    return open
        ? tr('So far · some costs are still to be added')
        : tr('So far');
  }

  @override
  Widget build(BuildContext context) {
    final costs = summary.totalShipmentCosts;
    final profit = summary.margin ??
        (costs == null ? null : summary.revenue - summary.agencyShare - costs);
    final customersDue =
        bookings.fold(0.0, (total, row) => total + row.dueAmount);
    final customersPaid =
        bookings.fold(0.0, (total, row) => total + row.paidAmount);
    final owing = [
      for (final row in summary.settlements)
        if (row.due > 0) row.name
    ];
    Widget line(String label, String value, {String? note}) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: label),
                    if (note != null)
                      TextSpan(
                          text: ' $note',
                          style:
                              const TextStyle(fontSize: 12, color: heroSoft)),
                  ]),
                  style: const TextStyle(
                      fontSize: 15, height: 1.4, color: Colors.white))),
          const SizedBox(width: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]));
    Widget comingIn(String amount, String caption) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(amount,
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 16,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: heroAlert,
                      fontFeatures: [FontFeature.tabularFigures()]))),
          Text(caption,
              style:
                  const TextStyle(fontSize: 12, height: 1.35, color: heroSoft)),
        ]);
    return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(heroRadius)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('Flight profit'),
              style: const TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          Text(_note(),
              style:
                  const TextStyle(fontSize: 12, height: 1.4, color: heroSoft)),
          const SizedBox(height: 4),
          line(tr('Shipment charges'), formatBdt(summary.revenue)),
          if (costs != null)
            line('− ${tr('Shipment costs')}', '−${formatBdt(costs)}'),
          line('− ${tr('Our ticket share')}',
              '−${formatBdt(summary.agencyShare)}',
              note: summary.actualCost > 0
                  ? tr('of {amount}', {'amount': formatBdt(summary.actualCost)})
                  : null),
          if (profit != null) ...[
            const SizedBox(height: 12),
            Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0x3DFFFFFF)))),
                child: Row(children: [
                  Text('= ${tr('Profit')}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerEnd,
                          child: Text(formatBdt(profit),
                              maxLines: 1,
                              style: TextStyle(
                                  fontSize: 32,
                                  height: 1.15,
                                  fontWeight: FontWeight.w700,
                                  color: profit < 0 ? heroAlert : Colors.white,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ])))),
                ])),
          ],
          const SizedBox(height: 14),
          Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                  color: const Color(0x14FFFFFF),
                  borderRadius: BorderRadius.circular(14)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(tr('Still to come in'),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: heroSoft)),
                    const SizedBox(height: 4),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: comingIn(
                                  formatBdt(customersDue),
                                  tr('Customers · {amount} paid',
                                      {'amount': formatBdt(customersPaid)}))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: comingIn(
                                  formatBdt(summary.flyerDue),
                                  owing.isEmpty
                                      ? tr('Flyers')
                                      : '${tr('Flyers')} · ${owing.join(', ')}')),
                        ]),
                  ])),
        ]));
  }
}

class _ShipmentsHeading extends StatelessWidget {
  const _ShipmentsHeading({required this.bookings});
  final List<AdminShipment> bookings;

  @override
  Widget build(BuildContext context) {
    final due = bookings.fold(0.0, (total, row) => total + row.dueAmount);
    final trailing = due > 0
        ? tr('{amount} still to collect', {'amount': formatBdt(due)})
        : null;
    return Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
              child: Text(tr('Shipments'),
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.35))),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Flexible(
                child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(trailing,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: AppColors.muted)))),
          ],
        ]));
  }
}

/// A shipment on the flight: who, how heavy, its bill and whether it is
/// paid, due or late.
class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.row, required this.onTap});

  final AdminShipment row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final late = row.lateDays;
    final (String label, ChipTone tone) =
        late != null && late > 0 && row.dueAmount > 0
            ? (trn(late, '{n} day late', '{n} days late'), ChipTone.red)
            : row.dueAmount > 0
                ? (
                    tr('{amount} due', {'amount': formatBdt(row.dueAmount)}),
                    ChipTone.amber
                  )
                : (tr('Paid'), ChipTone.green);
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        '${row.code} · ${row.supplierName ?? row.supplierCode}',
                        style: const TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w600)),
                    Text(
                        [
                          formatKg(row.effectiveKg),
                          tr('bill {amount}',
                              {'amount': formatBdt(row.billAmount)}),
                          if (row.monthly) tr('pays monthly'),
                          banglaStatus(row.status, row.statusLabel),
                        ].join(' · '),
                        style: const TextStyle(
                            fontSize: 12, height: 1.4, color: AppColors.muted)),
                  ])),
              const SizedBox(width: 8),
              ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: StatusPill(
                      key: ValueKey('booking-chip-${row.code}'),
                      label: label,
                      tone: tone)),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.faint),
            ])));
  }
}

/// The flight's profit as the server adds it up: shipment charges and what
/// flyers paid, less the ticket and the flight costs.
class _FlightProfitCard extends StatelessWidget {
  const _FlightProfitCard({required this.detail});
  final FlightDetail detail;

  @override
  Widget build(BuildContext context) {
    final money = detail.profitBreakdown!;
    final bookings = detail.bookings;
    final customersDue =
        bookings.fold(0.0, (total, row) => total + row.dueAmount);
    return PaperCard(
        key: const Key('flight-profit'),
        radius: heroRadius,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(tr('Flight profit'),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted)),
                  FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(formatBdt(money.profit),
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: 30,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                              color: money.profit < 0
                                  ? AppColors.danger
                                  : AppColors.ok,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ]))),
                ])),
            const SizedBox(width: 8),
            ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                        trn(
                            bookings.length,
                            '{n} shipment · {kg} kg',
                            '{n} shipments · {kg} kg',
                            {'kg': plainKg(detail.shipmentKg)}),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.muted)))),
          ]),
          const SizedBox(height: 6),
          MoneyRow(
              label: tr('Shipment charges'),
              value: formatBdt(money.shipmentCharges)),
          MoneyRow(
              label: tr('Flyers paid us'),
              value: '+${formatBdt(money.flyerIncome)}'),
          MoneyRow(label: tr('Ticket'), value: '−${formatBdt(money.ticket)}'),
          MoneyRow(
              label: tr('Flight costs'),
              value: '−${formatBdt(money.flightCosts)}'),
          if (money.otherCosts > 0.001)
            MoneyRow(
                label: tr('Older shipment costs'),
                value: '−${formatBdt(money.otherCosts)}'),
          const SizedBox(height: 4),
          Text(tr("Costs on customers' bills are paid back by them, so they are left out."),
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: AppColors.muted)),
          const SizedBox(height: 12),
          Text(tr('Still to come in'),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted)),
          const SizedBox(height: 6),
          FigureStrip(figures: [
            StripFigure(tr('Customers'), formatBdt(customersDue)),
            StripFigure(tr('Flyers'), formatBdt(detail.summary.flyerDue)),
          ]),
        ]));
  }
}

/// Costs for the whole flight, with Add and a remove on each.
class _FlightCostsCard extends StatelessWidget {
  const _FlightCostsCard(
      {required this.detail,
      required this.onAdd,
      required this.onPay,
      required this.onRemove});
  final FlightDetail detail;
  final VoidCallback onAdd;
  final ValueChanged<FlightCost> onPay, onRemove;

  @override
  Widget build(BuildContext context) {
    final costs = detail.flightCosts ?? const <FlightCost>[];
    return PaperCard(
        key: const Key('flight-costs'),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CardHead(
              title: tr('Flight costs'),
              subtitle: tr('For the whole flight · not on any bill'),
              trailing: AddButton(
                  key: const Key('flight-cost-add'), onPressed: onAdd)),
          const SizedBox(height: 4),
          if (costs.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(tr('No flight costs yet.'),
                    style: const TextStyle(
                        fontSize: 13, height: 1.45, color: AppColors.muted)))
          else
            for (final cost in costs)
              CostLine(
                  key: ValueKey('flight-cost-${cost.id}'),
                  icon: flightCostIcon(cost),
                  title: flightCostTitle(cost),
                  detail: flightCostDetail(cost),
                  detailColor: cost.paid ? null : AppColors.accentInk,
                  amount: formatBdt(cost.amount),
                  divider: true,
                  extra: cost.paid
                      ? null
                      : TextButton.icon(
                          key: ValueKey('flight-cost-pay-${cost.id}'),
                          onPressed: () => onPay(cost),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              minimumSize: const Size(48, 40),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 2, vertical: 4),
                              alignment: AlignmentDirectional.centerStart,
                              textStyle: const TextStyle(
                                  fontFamily: 'HindSiliguri',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          icon: const Icon(Icons.check_circle_outline_rounded,
                              size: 16),
                          label: Text(tr('Mark paid'))),
                  trailing: IconButton(
                      key: ValueKey('flight-cost-remove-${cost.id}'),
                      tooltip: tr('Remove'),
                      constraints:
                          const BoxConstraints(minWidth: 44, minHeight: 44),
                      color: AppColors.muted,
                      onPressed: () => onRemove(cost),
                      icon: const Icon(Icons.close_rounded, size: 18))),
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                Expanded(
                    child: Text(tr('Total'),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700))),
                Text(formatBdt(_costTotal(detail)),
                    key: const Key('flight-cost-total'),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ])),
        ]));
  }
}

/// How the flight costs reach each shipment: a share by weight, shown on
/// the first shipment that has kg.
class _CostShareCard extends StatelessWidget {
  const _CostShareCard({required this.detail});
  final FlightDetail detail;

  @override
  Widget build(BuildContext context) {
    final total = _costTotal(detail);
    final kg = detail.shipmentKg;
    AdminShipment? example;
    for (final row in detail.bookings) {
      if (row.effectiveKg > 0) {
        example = row;
        break;
      }
    }
    final text = [
      tr("Each shipment's profit takes a share by weight."),
      if (example != null && total > 0 && kg > 0)
        tr(
            '{code} carries {kg} of {total} kg, so its share is {share} of {costs}.',
            {
              'code': example.code,
              'kg': example.effectiveKg.toStringAsFixed(1),
              'total': plainKg(kg),
              'share': formatBdt(_round(total * example.effectiveKg / kg)),
              'costs': formatBdt(total)
            }),
    ].join(' ');
    return PaperCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('How the flight costs reach each shipment'),
          style: const TextStyle(
              fontSize: 15, height: 1.3, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(text,
          style: const TextStyle(
              fontSize: 13, height: 1.45, color: AppColors.muted)),
    ]));
  }
}

/// Two-decimal money for a worked-out share.
double _round(double value) => (value * 100).roundToDouble() / 100;

/// A flyer with their share of the ticket and what they still owe.
class FlyerShareRow extends StatelessWidget {
  const FlyerShareRow(
      {super.key,
      required this.name,
      required this.settlement,
      this.detail,
      this.first = false,
      this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12)});
  final String name;
  final String? detail;
  final FlightSettlement? settlement;

  /// The first flyer gets the blue avatar, the rest a dark one.
  final bool first;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final row = settlement;
    final split = row != null && row.contribution > 0;
    final (label, tone) = !split
        ? (tr('Split not saved yet'), ChipTone.neutral)
        : row.due <= 0
            ? (tr('Paid up'), ChipTone.green)
            : (
                tr('{amount} due', {'amount': formatBdt(row.due)}),
                ChipTone.amber
              );
    return Padding(
        padding: padding,
        child: Row(children: [
          LetterAvatar(name,
              color: first ? AppColors.primary : AppColors.inkSoft),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                if (detail != null)
                  Text(detail!,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted, height: 1.4)),
                if (split)
                  Text(
                      tr('Share {share} · Paid {paid}', {
                        'share': formatBdt(row.contribution),
                        'paid': formatBdt(row.paidAmount)
                      }),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted, height: 1.4)),
              ])),
          const SizedBox(width: 8),
          ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: StatusPill(label: label, tone: tone)),
        ]));
  }
}
