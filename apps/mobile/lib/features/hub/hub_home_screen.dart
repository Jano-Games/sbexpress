import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/hub/hub_chain.dart';
import '../../data/models/dashboard.dart';
import '../../data/models/flight.dart';
import '../../data/models/hub_flight.dart';
import '../../data/models/shipment.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../flights/hub_flights_screen.dart';
import '../shipments/shipment_process_screen.dart';

class HubHomeScreen extends StatefulWidget {
  const HubHomeScreen(
      {super.key,
      required this.dashboard,
      this.onOpenFlights,
      this.onOpenShipments});

  final DashboardRepository dashboard;

  /// Switches the shell to its tab; without it the screen is pushed.
  final VoidCallback? onOpenFlights;
  final VoidCallback? onOpenShipments;

  @override
  State<HubHomeScreen> createState() => _HubHomeScreenState();
}

class _HubHomeScreenState extends State<HubHomeScreen> {
  HubDashboard? _data;
  String? _error;
  var _loading = true;
  final _query = TextEditingController();
  HubListStep? _step;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.dashboard.hub();
      if (!mounted) return;
      setState(() => _data = data);
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

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final today = FlightDay.parse(DateTime.now().toIso8601String());
    final dayLabel = today == null
        ? null
        : '${today.weekdayName} · ${today.day} ${today.month}';
    return WorkspaceScaffold(
        title: tr('Dhaka hub'),
        subtitle: data == null
            ? dayLabel ?? tr("Preparing today's parcels and deliveries")
            : [
                if (dayLabel != null) dayLabel,
                trn(data.atHubCount, '{n} shipment at the hub',
                    '{n} shipments at the hub')
              ].join(' · '),
        root: true,
        onRefresh: _load,
        children: [
          if (_loading && data == null) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
          ],
          if (_error != null) ...[
            ErrorNote(message: _error!, onRetry: _load),
          ],
          if (data != null) ..._content(data),
        ]);
  }

  List<Widget> _content(HubDashboard data) {
    final counts = HubWorkCounts.fromShipments(data.toProcess);
    final earliest = counts.earliest;
    final query = _query.text.trim().toLowerCase();
    final queue = [
      for (final row in data.toProcess)
        if (hubListStep(row) != HubListStep.none &&
            (_step == null || hubListStep(row) == _step) &&
            (query.isEmpty ||
                row.code.toLowerCase().contains(query) ||
                row.supplierCode.toLowerCase().contains(query) ||
                row.description.toLowerCase().contains(query)))
          row
    ];
    final notices = [
      for (final notice in data.notices)
        if (notice.tag == 'WEIGHT' || data.upcomingFlights.isEmpty) notice
    ];
    return [
      TextField(
          controller: _query,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
              hintText: tr('Search hub shipments — code or cargo'),
              prefixIcon: const Icon(Icons.search_rounded, size: 21),
              enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide(color: AppColors.line)))),
      const SizedBox(height: 14),
      _TodayHero(
          counts: counts,
          selected: _step,
          onSelect: (step) =>
              setState(() => _step = _step == step ? null : step),
          next: earliest == null
              ? null
              : data.toProcess
                  .where((row) => hubListStep(row) == earliest)
                  .firstOrNull,
          onStart: _open),
      if (data.upcomingFlights.isNotEmpty) ...[
        const SizedBox(height: 22),
        SectionTitle(
            title: tr('Upcoming flights'),
            action: TextButton(
                onPressed: _openFlights, child: Text(tr('See all')))),
        SizedBox(
            // The strip scrolls sideways, so its height must fit the card at
            // the user's text size.
            height: 32 + 72 * MediaQuery.textScalerOf(context).scale(10) / 10,
            child: ListView.separated(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: data.upcomingFlights.length,
                separatorBuilder: (context, i) => const SizedBox(width: 10),
                itemBuilder: (context, i) => HubFlightStripCard(
                    flight: data.upcomingFlights[i],
                    next: i == 0,
                    onTap: () => _openFlight(data.upcomingFlights[i])))),
      ] else if (data.incoming.count > 0) ...[
        const SizedBox(height: 12),
        _Incoming(incoming: data.incoming),
      ],
      const SizedBox(height: 22),
      SectionTitle(
          title: _step == null
              ? tr('Awaiting processing')
              : tr('{step} pending', {'step': _stepName(_step!)}),
          action: _step != null
              ? TextButton(
                  onPressed: () => setState(() => _step = null),
                  child: Text(tr('Show all')))
              : widget.onOpenShipments == null
                  ? null
                  : TextButton(
                      onPressed: widget.onOpenShipments,
                      child: Text(tr('See all')))),
      if (queue.isEmpty)
        EmptyNote(
            icon: Icons.task_alt_rounded,
            title: query.isNotEmpty || _step != null
                ? tr('No matching shipments')
                : tr('No shipments waiting at the hub'),
            body: query.isNotEmpty || _step != null
                ? tr('Try another code or clear the filter.')
                : tr('Shipments appear here when they reach the Dhaka hub.'))
      else
        SurfaceGroup(children: [
          for (final row in queue)
            _QueueRow(
                row: row,
                now: hubListStep(row) == earliest,
                onOpen: () => _open(row.code)),
        ]),
      if (notices.isNotEmpty) ...[
        const SizedBox(height: 22),
        SectionTitle(title: tr('Needs attention')),
        SurfaceGroup(children: [
          for (final notice in notices) _NoticeRow(notice: notice),
        ]),
      ],
    ];
  }

  void _open(String code) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(
            builder: (_) => ShipmentProcessScreen(code: code)))
        .then((_) {
      if (mounted) _load();
    });
  }

  void _openFlights() {
    final open = widget.onOpenFlights;
    if (open != null) return open();
    Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const HubFlightsScreen()));
  }

  void _openFlight(HubFlight flight) {
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => HubFlightDetailScreen(code: flight.code)));
  }
}

String _stepName(HubListStep step) =>
    step == HubListStep.deliveryChain ? tr('Delivery') : hubListStepLabel(step);

class _TodayHero extends StatelessWidget {
  const _TodayHero(
      {required this.counts,
      required this.selected,
      required this.onSelect,
      required this.next,
      required this.onStart});
  final HubWorkCounts counts;
  final HubListStep? selected;
  final ValueChanged<HubListStep> onSelect;
  final OperationalShipment? next;
  final ValueChanged<String> onStart;

  @override
  Widget build(BuildContext context) {
    final earliest = counts.earliest;
    final done = counts.remaining == 0;
    return Container(
        key: const Key('hub-today-hero'),
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(heroRadius),
            boxShadow: cardShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(tr("Today's tasks"),
                    key: const Key('hub-today-title'),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700))),
            const SizedBox(width: 12),
            StatusPill(
                key: const Key('hub-today-remaining'),
                label: done
                    ? tr('All done')
                    : tr('{n} left', {'n': counts.remaining}),
                tone: done ? ChipTone.green : ChipTone.amber),
          ]),
          if (done) ...[
            const SizedBox(height: 4),
            Text(tr('No hub steps left today'),
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (key, step, label, icon, value) in [
              (
                const Key('hub-count-weigh'),
                HubListStep.weigh,
                tr('Weigh'),
                Icons.scale_outlined,
                counts.weigh
              ),
              (
                const Key('hub-count-pack'),
                HubListStep.pack,
                tr('Pack'),
                Icons.inventory_2_outlined,
                counts.pack
              ),
              (
                const Key('hub-count-delivery'),
                HubListStep.deliveryChain,
                tr('Delivery'),
                Icons.local_shipping_outlined,
                counts.deliveryChain
              ),
            ]) ...[
              if (step != HubListStep.weigh) const SizedBox(width: 10),
              Expanded(
                  child: _StepTile(
                      statKey: key,
                      label: label,
                      icon: icon,
                      value: value,
                      now: earliest == step,
                      selected: selected == step,
                      onTap: value == 0 ? null : () => onSelect(step))),
            ],
          ]),
          if (earliest != null && next != null) ...[
            const SizedBox(height: 14),
            AppButton(
                key: const Key('hub-today-now'),
                label: tr('Start — {code} · {step}',
                    {'code': next!.code, 'step': _stepName(earliest)}),
                icon: Icons.arrow_forward_rounded,
                onPressed: () => onStart(next!.code)),
          ],
        ]));
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile(
      {required this.statKey,
      required this.label,
      required this.icon,
      required this.value,
      required this.now,
      required this.selected,
      required this.onTap});

  final Key statKey;
  final String label;
  final IconData icon;
  final int value;
  final bool now, selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? AppColors.primary
        : now
            ? AppColors.accentLine
            : Colors.transparent;
    return Semantics(
        button: onTap != null,
        selected: selected,
        child: Material(
            color: Colors.transparent,
            child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  key: statKey,
                  constraints: const BoxConstraints(minHeight: 96),
                  padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                  decoration: BoxDecoration(
                    color: now ? AppColors.accentSoft : AppColors.paper,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border, width: 1.5),
                  ),
                  child: LayoutBuilder(
                      builder: (context, constraints) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(icon,
                                    size: 22,
                                    color: now
                                        ? const Color(0xFFC25A16)
                                        : AppColors.muted),
                                const Spacer(),
                                // A narrow tile keeps the orange fill as the "now"
                                // signal and drops the tag.
                                if (now && constraints.maxWidth >= 72)
                                  Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 1),
                                      decoration: BoxDecoration(
                                          color: AppColors.accentStrong,
                                          borderRadius:
                                              BorderRadius.circular(999)),
                                      child: Text(tr('Now'),
                                          textScaler: TextScaler.noScaling,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              height: 1.4,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white))),
                              ]),
                              const SizedBox(height: 6),
                              Text('$value',
                                  style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      height: 1.05)),
                              const SizedBox(height: 4),
                              FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(label,
                                      maxLines: 1,
                                      style: TextStyle(
                                          fontSize: 13,
                                          height: 1.25,
                                          fontWeight: FontWeight.w600,
                                          color: now
                                              ? AppColors.accentInk
                                              : AppColors.inkSoft))),
                            ],
                          )),
                ))));
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.row, required this.now, required this.onOpen});
  final OperationalShipment row;
  final bool now;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final step = hubListStep(row);
    final delta = formatWeightDelta(row.weightDelta);
    final (icon, done) = switch (step) {
      HubListStep.weigh => (Icons.scale_outlined, 0),
      HubListStep.pack => (Icons.inventory_2_outlined, 1),
      HubListStep.deliveryChain => (Icons.local_shipping_outlined, 2),
      HubListStep.none => (Icons.inventory_2_outlined, 0),
    };
    final details = [
      row.supplierCode,
      if (row.description.isNotEmpty) row.description,
      formatKg(row.effectiveKg),
    ].join(' · ');
    return InkWell(
        onTap: onOpen,
        child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: now ? AppColors.accentSoft : AppColors.paper,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon,
                      size: 21,
                      color:
                          now ? const Color(0xFFC25A16) : AppColors.inkSoft)),
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
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                          StatusPill(
                              label: tr(
                                  '{step} pending', {'step': _stepName(step)}),
                              tone: now ? ChipTone.amber : ChipTone.neutral),
                        ]),
                    const SizedBox(height: 2),
                    Text.rich(
                        TextSpan(text: details, children: [
                          if (delta != null)
                            TextSpan(
                                text: '  $delta',
                                style: const TextStyle(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w600)),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted)),
                    const SizedBox(height: 7),
                    StepBars(done: done, segmentWidth: 24),
                  ])),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.faint),
            ])));
  }
}

final _weightNotice = RegExp(
    r'^(\S+) \(([^)]*)\) weighed ([\d.]+) kg vs ([\d.]+) kg booked — Δ([+-]?[\d.]+)\s*kg$');

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.notice});
  final HubNotice notice;

  @override
  Widget build(BuildContext context) {
    final weight = notice.tag == 'WEIGHT';
    final match = weight ? _weightNotice.firstMatch(notice.text) : null;
    final over = match != null && !match.group(5)!.startsWith('-');
    final title = match == null
        ? notice.text
        : over
            ? tr('{code} — heavier than booked', {'code': match.group(1)})
            : tr('{code} — lighter than booked', {'code': match.group(1)});
    final body = match == null
        ? null
        : tr('Weighed {weighed} kg · booked {booked} kg',
            {'weighed': match.group(3), 'booked': match.group(4)});
    return Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          IconBadge(weight ? Icons.warning_amber_rounded : Icons.flight_rounded,
              tone: weight ? ChipTone.red : ChipTone.blue, round: true),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4)),
                if (body != null)
                  Text(body,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted)),
              ])),
        ]));
  }
}

class _Incoming extends StatelessWidget {
  const _Incoming({required this.incoming});
  final HubIncoming incoming;

  @override
  Widget build(BuildContext context) {
    final flight = incoming.flightCode == null
        ? null
        : '${displayFlightCode(incoming.flightCode!)} · ${incoming.flightDate ?? ''}';
    return PaperCard(
        child: Row(children: [
      const IconBadge(Icons.flight_land_rounded),
      const SizedBox(width: 12),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            trn(incoming.count, '{n} shipment incoming · {kg}',
                '{n} shipments incoming · {kg}', {'kg': formatKg(incoming.kg)}),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        if (flight != null)
          Text(flight,
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
      ])),
    ]));
  }
}
