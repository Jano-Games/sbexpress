import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../data/models/flow.dart';
import '../../data/models/hub_flight.dart';
import '../../data/models/shipment.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flight_parts.dart';
import '../../widgets/flow_parts.dart';
import '../../widgets/ui.dart';
import '../admin/admin_shipment_screen.dart';
import '../admin/money_format.dart';
import '../intake/intake_screen.dart';
import 'hub_flights_screen.dart' show banglaPlace;
import 'ticket_flyers_screen.dart';

/// One flight: its route and load, what it earns, the ticket and flyers,
/// and the shipments on it.
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
              _ProfitCard(summary: summary, bookings: bookings),
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

/// Shipments at or past the Dhaka hub still missing a usual cost.
int _missingCosts(List<AdminShipment> bookings) => bookings
    .where((row) =>
        row.statusIndex >= dhakaHubIndex &&
        row.usualCosts != null &&
        usualCostsAdded(row.usualCosts!) < row.usualCosts!.length)
    .length;

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
    final missing = _missingCosts(bookings);
    final due = bookings.fold(0.0, (total, row) => total + row.dueAmount);
    final trailing = missing > 0
        ? trn(missing, '{n} missing cost', '{n} missing costs')
        : due > 0
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
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            fontWeight:
                                missing > 0 ? FontWeight.w600 : FontWeight.w400,
                            color: missing > 0
                                ? AppColors.accentInk
                                : AppColors.muted)))),
          ],
        ]));
  }
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.row, required this.onTap});

  final AdminShipment row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profit = row.profitBeforeTicket;
    final noCosts = (row.costTotal ?? 0) <= 0;
    final (String amount, String caption, Color color) = profit != null
        ? (
            formatBdt(profit),
            noCosts ? tr('before costs') : tr('profit'),
            profit < 0 ? AppColors.danger : AppColors.ink
          )
        : row.dueAmount > 0
            ? (formatBdt(row.dueAmount), tr('due'), AppColors.ink)
            : (tr('Paid'), '', AppColors.ok);
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(row.code,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          StatusPill(
                              label: banglaStatus(row.status, row.statusLabel),
                              tone: shipmentStatusTone(row.statusIndex)),
                        ]),
                    const SizedBox(height: 2),
                    Text(
                        tr('{name} · {kg} · charge {amount}', {
                          'name': row.supplierName ?? row.supplierCode,
                          'kg': formatKg(row.effectiveKg),
                          'amount': formatBdt(row.billAmount)
                        }),
                        style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AppColors.muted)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      PayWayChip(monthly: row.monthly),
                      if (row.usualCosts != null)
                        CostStatusChip(
                            costs: row.usualCosts!,
                            statusIndex: row.statusIndex),
                    ]),
                  ])),
              const SizedBox(width: 8),
              ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(amount,
                                maxLines: 1,
                                style: TextStyle(
                                    fontSize: 16,
                                    height: 1.3,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ]))),
                        if (caption.isNotEmpty)
                          Text(caption,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.muted)),
                      ])),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.faint),
            ])));
  }
}

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
