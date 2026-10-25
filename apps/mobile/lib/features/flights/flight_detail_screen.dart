import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../data/models/hub_flight.dart';
import '../../data/models/shipment.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flight_parts.dart';
import '../../widgets/ui.dart';
import '../admin/admin_shipment_screen.dart';
import '../admin/money_format.dart';
import 'flight_money_screen.dart';
import 'hub_flights_screen.dart';

class FlightDetailScreen extends StatefulWidget {
  const FlightDetailScreen({super.key, required this.code});

  final String code;

  @override
  State<FlightDetailScreen> createState() => _FlightDetailScreenState();
}

class _FlightDetailScreenState extends State<FlightDetailScreen> {
  FlightDetail? _detail;
  List<String> _flyerNames = const [];
  String? _error;
  var _loading = true;
  var _tab = 0;
  var _busy = false;
  String? _assign;

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
      final scope = AppScope.of(context);
      final detail = await scope.flights.detail(widget.code);
      final flyers = await scope.flyers.list();
      if (!mounted) return;
      final assigned = detail.summary.flyers.toSet();
      setState(() {
        _detail = detail;
        _flyerNames = [
          for (final flyer in flyers)
            if (!assigned.contains(flyer.name) && !flyer.archived) flyer.name
        ];
        _assign = null;
      });
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

  Future<void> _assignFlyer() async {
    final name = _assign;
    if (name == null) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).flights.assignFlyer(widget.code, name);
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMoney() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => FlightMoneyScreen(code: widget.code)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final summary = detail?.summary;
    final day = summary == null ? null : FlightDay.parse(summary.date);
    final badge =
        summary == null ? null : adminFlightBadge(summary, day, detail: true);
    return Scaffold(
      appBar: BackTitle(
          title: summary?.displayCode ?? displayFlightCode(widget.code),
          subtitle: day == null
              ? null
              : '${day.weekdayName} · ${day.day} ${day.month}',
          actions: [
            if (badge != null)
              Center(
                  child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 170),
                          child: StatusPill(label: badge.$1, tone: badge.$2)))),
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
              _RouteCard(summary: summary),
              const SizedBox(height: 14),
              _MoneyStrip(summary: summary, onOpen: _openMoney),
              const SizedBox(height: 14),
              ScreenTabs(labels: [
                tr('Bookings · {n}', {'n': detail.bookings.length}),
                tr('Flyers · {n}', {'n': summary.flyers.length}),
                tr('Money')
              ], index: _tab, onChanged: (i) => setState(() => _tab = i)),
              const SizedBox(height: 16),
              if (_tab == 0) ..._bookings(detail),
              if (_tab == 1) ..._flyers(detail),
              if (_tab == 2) ..._money(summary),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _bookings(FlightDetail detail) {
    final due =
        detail.bookings.fold(0.0, (total, row) => total + row.dueAmount);
    return [
      _ListHeading(
          title: trn(detail.bookings.length, '{n} shipment', '{n} shipments'),
          trailing: due > 0
              ? tr('{amount} still to collect', {'amount': formatBdt(due)})
              : null),
      if (detail.bookings.isEmpty)
        EmptyNote(
            icon: Icons.inventory_2_outlined,
            title: tr('No bookings'),
            body: tr('Choose this flight from shipment intake.'))
      else
        RowCard(children: [
          for (final booking in detail.bookings)
            _BookingRow(
                row: booking,
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => AdminShipmentScreen(code: booking.code)));
                  if (mounted) await _load();
                }),
        ]),
    ];
  }

  List<Widget> _flyers(FlightDetail detail) {
    final summary = detail.summary;
    return [
      _ListHeading(
          title: trn(detail.flyerDetails.length, '{n} flyer', '{n} flyers')),
      if (detail.flyerDetails.isEmpty)
        EmptyNote(
            icon: Icons.person_outline_rounded,
            title: tr('No flyers'),
            body: tr('Add one below.'))
      else
        RowCard(children: [
          for (var i = 0; i < detail.flyerDetails.length; i++)
            FlyerShareRow(
                name: detail.flyerDetails[i].name,
                detail: _hasPhone(detail.flyerDetails[i].bdPhone)
                    ? detail.flyerDetails[i].bdPhone
                    : null,
                settlement:
                    _settlementFor(summary, detail.flyerDetails[i].name),
                first: i == 0),
        ]),
      const SizedBox(height: 14),
      PaperCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardHeading(
            icon: Icons.person_add_alt_1_outlined,
            title: tr('Add flyer'),
            subtitle: tr('Who else carries cargo on this ticket.')),
        const SizedBox(height: 14),
        if (_flyerNames.isEmpty)
          Text(tr('No active flyers left to add.'),
              style: const TextStyle(color: AppColors.muted, height: 1.45))
        else ...[
          DropdownButtonFormField<String>(
            initialValue: _assign,
            isExpanded: true,
            decoration: InputDecoration(labelText: tr('Add flyer')),
            items: [
              for (final name in _flyerNames)
                DropdownMenuItem(value: name, child: Text(name))
            ],
            onChanged: (value) => setState(() => _assign = value),
          ),
          const SizedBox(height: 12),
          AppButton(
              label: tr('Add to flight'),
              icon: Icons.add_rounded,
              busy: _busy,
              onPressed: _assign == null ? null : _assignFlyer),
        ],
      ])),
    ];
  }

  List<Widget> _money(FlightSummary summary) {
    final share = summary.actualCost - summary.agencyShare;
    return [
      PaperCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardHeading(
            icon: Icons.confirmation_number_outlined,
            tone: ChipTone.neutral,
            title: tr('Ticket'),
            subtitle: tr(
                'Cash settlement, contributions and flyer payments are on a separate page.')),
        const Divider(height: 24),
        KvRow(label: tr('Actual cost'), value: formatBdt(summary.actualCost)),
        KvRow(label: tr('Agency share'), value: formatBdt(summary.agencyShare)),
        KvRow(label: tr("Flyers' share"), value: formatBdt(share)),
        KvRow(label: tr('Ticket paid'), value: formatBdt(summary.ticketPaid)),
        KvRow(
            label: tr('Ticket due'),
            value: formatBdt(summary.ticketDue),
            valueColor:
                summary.ticketDue > 0 ? AppColors.danger : AppColors.ok),
        if (summary.ticketRefundDue > 0)
          KvRow(
              label: tr('Ticket refund'),
              value: formatBdt(summary.ticketRefundDue)),
        KvRow(
            label: tr('Due from flyers'),
            value: formatBdt(summary.flyerDue),
            valueColor: summary.flyerDue > 0 ? AppColors.danger : AppColors.ok),
        if (summary.unallocatedFlyerPaid > 0)
          KvRow(
              label: tr('Unallocated payments'),
              value: formatBdt(summary.unallocatedFlyerPaid)),
        const Divider(height: 20),
        KvRow(label: tr('Shipment charges'), value: formatBdt(summary.revenue)),
      ])),
      const SizedBox(height: 14),
      AppButton(
          label: tr('Ticket and contributions'),
          icon: Icons.payments_outlined,
          kind: AppButtonKind.current,
          onPressed: _openMoney),
    ];
  }
}

FlightSettlement? _settlementFor(FlightSummary summary, String name) {
  for (final row in summary.settlements) {
    if (row.name == name) return row;
  }
  return null;
}

bool _hasPhone(String value) => RegExp(r'\d{5,}').hasMatch(value);

class _ListHeading extends StatelessWidget {
  const _ListHeading({required this.title, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, height: 1.35))),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Flexible(
              child: Text(trailing!,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 13, height: 1.5, color: AppColors.muted))),
        ],
      ]));
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.summary});
  final FlightSummary summary;

  @override
  Widget build(BuildContext context) => PaperCard(
      radius: heroRadius,
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        RouteEnds(
            depTime: summary.depTime,
            arrTime: summary.arrTime,
            from: banglaPlace(summary.from, fallback: tr('China')),
            to: banglaPlace(summary.to, fallback: tr('Dhaka')),
            stop: summary.stopLabel),
        if (summary.scheduleNeedsConfirmation) ...[
          const SizedBox(height: 12),
          Align(
              alignment: Alignment.centerLeft,
              child: StatusPill(
                  label: tr('Date has passed · Confirm the status'),
                  tone: ChipTone.amber)),
        ],
        const Divider(height: 30),
        CapacityText(
            booked: summary.bookedKg,
            space: summary.spaceKg.toDouble(),
            size: 15),
        const SizedBox(height: 8),
        MeterBar(value: summary.fill),
        const SizedBox(height: 10),
        Wrap(
            spacing: 14,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Count(
                  icon: Icons.smartphone_rounded,
                  label: tr('Mobiles {n}', {'n': summary.mobiles})),
              _Count(
                  icon: Icons.laptop_rounded,
                  label: tr('Laptops {n}', {'n': summary.laptops})),
              Text(tr('Ref {code}', {'code': summary.code}),
                  style: const TextStyle(
                      fontSize: 12, height: 1.6, color: AppColors.muted)),
            ]),
      ]));
}

class _Count extends StatelessWidget {
  const _Count({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: AppColors.inkSoft),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
      ]);
}

/// Navy strip with the booking money of this flight and the ticket position.
class _MoneyStrip extends StatelessWidget {
  const _MoneyStrip({required this.summary, required this.onOpen});
  final FlightSummary summary;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final refund = summary.ticketDue <= 0 && summary.ticketRefundDue > 0;
    return MoneyHero(
        label: tr('Shipment charges on this flight'),
        amount: formatBdt(summary.revenue),
        amountSize: 28,
        trailing: HeroButton(label: tr('Ticket money'), onTap: onOpen),
        children: [
          HeroFigures(figures: [
            HeroFigure(tr('Ticket cost'), formatBdt(summary.actualCost)),
            refund
                ? HeroFigure(
                    tr('Ticket refund'), formatBdt(summary.ticketRefundDue))
                : HeroFigure(tr('Ticket due'), formatBdt(summary.ticketDue),
                    alert: summary.ticketDue > 0),
            HeroFigure(tr('Due from flyers'), formatBdt(summary.flyerDue),
                alert: summary.flyerDue > 0),
          ]),
        ]);
  }
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.row, required this.onTap});

  final AdminShipment row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final paid = row.dueAmount <= 0;
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              const IconBadge(Icons.inventory_2_outlined,
                  tone: ChipTone.neutral),
              const SizedBox(width: 12),
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
                    Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text:
                                  '${row.supplierName ?? row.supplierCode} · ${formatKg(row.effectiveKg)} · '),
                          TextSpan(
                              text: paid
                                  ? tr('Paid')
                                  : tr('{amount} due',
                                      {'amount': formatBdt(row.dueAmount)}),
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: paid
                                      ? AppColors.ok
                                      : AppColors.accentInk)),
                        ]),
                        style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AppColors.muted)),
                  ])),
              const SizedBox(width: 6),
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
