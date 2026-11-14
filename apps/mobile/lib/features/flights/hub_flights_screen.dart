import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/hub_flight.dart';
import '../../data/models/shipment.dart';
import '../../data/uploads/signed_photos.dart';
import '../../l10n/l10n.dart';
import '../../l10n/places.dart';
import '../../theme/app_colors.dart';
import '../../widgets/people_parts.dart' show PersonAvatar;
import '../../widgets/flight_status_parts.dart';
import '../../widgets/ui.dart';
import '../shipments/shipment_process_screen.dart';
import 'flight_people_cards.dart';
import 'track_screen.dart';
import '../sorting/sort_flight_screen.dart';
import '../sorting/sort_parts.dart' show CustomerMark, SortPhotoStrip;

export '../../l10n/places.dart' show banglaPlace;

/// Upcoming and recent flights into Dhaka, as the hub sees them: schedule,
/// flyer and weight on board. No fare or booking money.
class HubFlightsScreen extends StatefulWidget {
  const HubFlightsScreen({super.key, this.root = false});
  final bool root;

  @override
  State<HubFlightsScreen> createState() => _HubFlightsScreenState();
}

class _HubFlightsScreenState extends State<HubFlightsScreen> {
  HubFlightSchedule? _data;
  String? _error;
  var _loading = true;
  var _tab = 0;

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
      final data = await AppScope.of(context).flights.hubSchedule();
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
    final rows = data == null
        ? const <HubFlight>[]
        : _tab == 0
            ? data.upcoming
            : data.arrived;
    return WorkspaceScaffold(
        root: widget.root,
        title: tr('Flights'),
        subtitle: tr('Arriving in Bangladesh from China'),
        onRefresh: _load,
        toolbar: ScreenTabs(labels: [
          data == null
              ? tr('Coming up')
              : tr('Coming up · {n}', {'n': data.upcoming.length}),
          tr('Arrived')
        ], index: _tab, onChanged: (i) => setState(() => _tab = i)),
        children: [
          if (_loading && data == null) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (data != null && _tab == 0 && data.upcoming.isNotEmpty) ...[
            _ScheduleSummary(data: data),
            const SizedBox(height: 14),
          ],
          if (data != null && rows.isEmpty)
            EmptyNote(
                icon: Icons.flight_outlined,
                title: _tab == 0
                    ? tr('No upcoming flights')
                    : tr('No flights arrived recently'),
                body: _tab == 0
                    ? tr('New flights appear here once booked.')
                    : tr('Completed flights are listed here.')),
          for (var i = 0; i < rows.length; i++) ...[
            HubFlightCard(
                flight: rows[i],
                next: _tab == 0 && i == 0,
                onTap: () => _open(rows[i])),
            const SizedBox(height: 12),
          ],
        ]);
  }

  Future<void> _open(HubFlight flight) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => HubFlightDetailScreen(code: flight.code)));
    if (mounted) await _load();
  }
}

class _ScheduleSummary extends StatelessWidget {
  const _ScheduleSummary({required this.data});
  final HubFlightSchedule data;

  @override
  Widget build(BuildContext context) => PaperCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: IntrinsicHeight(
          child: Row(children: [
        Expanded(
            child: AmountLabel(
                label: tr('Flights'),
                value: tr('{n}', {'n': data.upcoming.length}),
                size: 19)),
        const VerticalDivider(width: 24, color: AppColors.lineSoft),
        Expanded(
            child: AmountLabel(
                label: tr('Orders'),
                value: tr('{n}', {'n': data.shipmentCount}),
                size: 19)),
        const VerticalDivider(width: 24, color: AppColors.lineSoft),
        Expanded(
            child: AmountLabel(
                label: tr('Total weight'), value: _kg(data.kg), size: 19)),
      ])));
}

/// One flight in the schedule. The next one is outlined in blue.
class HubFlightCard extends StatelessWidget {
  const HubFlightCard(
      {super.key,
      required this.flight,
      required this.onTap,
      this.next = false});
  final HubFlight flight;
  final VoidCallback onTap;
  final bool next;

  @override
  Widget build(BuildContext context) {
    final day = FlightDay.parse(flight.date);
    final badge = flightBadge(flight, day, next: next);
    return PaperCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        border: next
            ? const BorderSide(color: AppColors.primary, width: 1.5)
            : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FlightDateBlock(day: day, highlight: next),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Flexible(
                        flex: 3,
                        child: Text(flight.displayCode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 8),
                    Expanded(
                        flex: 5,
                        child: Align(
                            alignment: Alignment.centerRight,
                            child:
                                StatusPill(label: badge.$1, tone: badge.$2))),
                  ]),
                  const SizedBox(height: 6),
                  FlightRouteLine(flight: flight),
                ])),
          ]),
          if (hubFlightNote(flight) case final note?) ...[
            const SizedBox(height: 8),
            StatusNote(text: note.$1, tone: note.$2),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            InfoChip(
                icon: Icons.inventory_2_outlined,
                label: trn(flight.shipmentCount, '{n} order', '{n} orders')),
            InfoChip(icon: Icons.scale_outlined, label: _kg(flight.kg)),
            InfoChip(
                icon: Icons.person_outline_rounded,
                label: flight.flyers.isEmpty
                    ? tr('Flyer not set')
                    : flight.flyers.join(', '),
                muted: flight.flyers.isEmpty),
            if (flight.receivedCount > 0)
              InfoChip(
                  icon: Icons.check_circle_outline_rounded,
                  label: tr('At hub {received}/{total}', {
                    'received': flight.receivedCount,
                    'total': flight.shipmentCount
                  }),
                  tone: ChipTone.green),
          ]),
          if (next) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Flexible(
                  child: Text(tr("See what's coming"),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary))),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.primary),
            ]),
          ],
        ]));
  }
}

/// Compact card for the hub home strip.
class HubFlightStripCard extends StatelessWidget {
  const HubFlightStripCard(
      {super.key,
      required this.flight,
      required this.onTap,
      this.next = false});
  final HubFlight flight;
  final VoidCallback onTap;
  final bool next;

  @override
  Widget build(BuildContext context) {
    final day = FlightDay.parse(flight.date);
    final when = [
      if (day != null) '${day.day} ${day.month}',
      if (_landsAt(flight) case final lands?)
        tr('Lands {time}', {'time': lands}),
    ].join(' · ');
    return SizedBox(
        width: 236,
        child: PaperCard(
            onTap: onTap,
            padding: const EdgeInsets.all(14),
            border: next
                ? const BorderSide(color: AppColors.primary, width: 1.5)
                : null,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: next ? AppColors.primary : AppColors.neutralSoft,
                        borderRadius: BorderRadius.circular(11)),
                    child: Icon(Icons.flight_rounded,
                        size: 20,
                        color: next ? Colors.white : AppColors.inkSoft)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(flight.displayCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(when.isEmpty ? flight.date : when,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                    ])),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: Text(
                        [
                          trn(flight.shipmentCount, '{n} order', '{n} orders'),
                          _kg(flight.kg)
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSoft))),
                if (day != null && flight.status == 'upcoming') ...[
                  const SizedBox(width: 6),
                  StatusPill(
                      label: day.relativeLabel,
                      tone: next ? ChipTone.blue : ChipTone.neutral),
                ],
                if (flight.status == 'departed') ...[
                  const SizedBox(width: 6),
                  StatusPill(label: tr('En route'), tone: ChipTone.amber),
                ],
              ]),
            ])));
  }
}

class HubFlightDetailScreen extends StatefulWidget {
  const HubFlightDetailScreen({super.key, required this.code});
  final String code;

  @override
  State<HubFlightDetailScreen> createState() => _HubFlightDetailScreenState();
}

class _HubFlightDetailScreenState extends State<HubFlightDetailScreen> {
  HubFlightDetail? _flight;
  String? _error;
  var _loading = true;
  var _receiving = false;

  /// Flyer and staff face photos.
  SignedPhotoLoader? _faces;

  /// Device photos from China, one loader for every order on the flight.
  SignedPhotoLoader? _devices;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _faces ??= AppScope.of(context).photos.loader();
    _devices ??= AppScope.of(context).media.ordersLoader(_orderOfPhoto);
  }

  @override
  void dispose() {
    _faces?.dispose();
    _devices?.dispose();
    super.dispose();
  }

  /// Receives every order through customs on this flight, as this user.
  Future<void> _receive(int count) async {
    final messenger = ScaffoldMessenger.of(context);
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(
                    trn(count, 'Receive {n} order?', 'Receive {n} orders?')),
                content: Text(tr(
                    'They move to Received at BD Hub with your name and photo. Sorting comes next.')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(tr('Cancel'))),
                  FilledButton(
                      key: const Key('hub-receive-confirm'),
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(tr('Receive'))),
                ]));
    if (yes != true || !mounted) return;
    setState(() => _receiving = true);
    try {
      final received =
          await AppScope.of(context).flights.receiveAtHub(widget.code);
      messenger.showSnackBar(SnackBar(
          content: Text(trn(
              received.length, '{n} order received', '{n} orders received'))));
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (error.status != 401) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _receiving = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final flight = await AppScope.of(context).flights.hubDetail(widget.code);
      if (!mounted) return;
      setState(() => _flight = flight);
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
    final flight = _flight;
    final day = flight == null ? null : FlightDay.parse(flight.date);
    final badge = flight == null ? null : flightBadge(flight, day);
    return Scaffold(
      appBar: BackTitle(
          title: flight?.displayCode ?? tr('Flight'),
          subtitle: day == null
              ? null
              : '${day.weekdayName} · ${day.day} ${day.month}',
          actions: [
            if (badge != null)
              Center(
                  child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: StatusPill(label: badge.$1, tone: badge.$2))),
          ]),
      body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.fromLTRB(pageGutter, 16, pageGutter, 28),
              children: [
                if (_loading && flight == null) const LinearProgressIndicator(),
                if (_error != null) ErrorNote(message: _error!, onRetry: _load),
                if (flight != null) ...[
                  if (flight.tracking case final t? when t.left || t.landed)
                    HubLandingCard(
                        flight: flight,
                        onTrack: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => TrackScreen(
                                    code: flight.code,
                                    title: flight.displayCode))))
                  else
                    _RouteCard(flight: flight),
                  const SizedBox(height: 12),
                  WhoIsComingCard(flyers: flight.flyerDetails, loader: _faces!),
                  const SizedBox(height: 12),
                  if (flight.readyToReceive == null)
                    Row(children: [
                      Expanded(
                          child: MetricTile(
                              label: tr('Orders'),
                              value: tr('{n}', {'n': flight.shipmentCount}))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: MetricTile(
                              label: tr('Total weight'),
                              value: _kg(flight.kg))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: MetricTile(
                              label: tr('Reached hub'),
                              value:
                                  '${flight.receivedCount}/${flight.shipmentCount}')),
                    ])
                  else
                    _ReceiveCard(
                        flight: flight,
                        loader: _faces!,
                        busy: _receiving,
                        onReceive: () => _receive(flight.readyToReceive!)),
                  if (flight.receivedBy.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ReceivedByCard(
                        groups: flight.receivedBy,
                        total: flight.shipmentCount,
                        loader: _faces!),
                  ],
                  if (flight.receivedCount > 0) ...[
                    const SizedBox(height: 12),
                    AppButton(
                        key: const Key('hub-open-sort'),
                        label: tr('Sort by customer'),
                        icon: Icons.checklist_rounded,
                        onPressed: () => _openSort(flight)),
                  ],
                  const SizedBox(height: 22),
                  SectionTitle(
                      title: tr('Coming on this flight'),
                      action: Text(
                          '${trn(flight.shipments.length, '{n} order', '{n} orders')} · ${_kg(flight.kg)}',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.muted))),
                  if (flight.shipments.isEmpty)
                    EmptyNote(
                        icon: Icons.inventory_2_outlined,
                        title: tr('No orders on this flight'),
                        body: tr('Orders appear here once booked.'))
                  else
                    SurfaceGroup(children: [
                      for (final (code, rows) in _byCustomer(flight.shipments))
                        _CustomerManifest(
                            customer: code,
                            rows: rows,
                            extras: flight.orderExtras,
                            loader: _devices!,
                            onOpen: _openShipment),
                    ]),
                  if (flight.status != 'completed' &&
                      flight.readyToReceive == null) ...[
                    const SizedBox(height: 14),
                    HintNote(
                        text: tr(
                            'Once customs clears them, receive the orders here. Sorting comes next.')),
                  ],
                ],
              ])),
    );
  }

  String? _orderOfPhoto(String reference) {
    for (final e in _flight?.orderExtras.entries ??
        const <MapEntry<String, HubOrderExtras>>[]) {
      if (e.value.devicePhotos.any((d) => d.reference == reference)) {
        return e.key;
      }
    }
    return null;
  }

  Future<void> _openSort(HubFlightDetail flight) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SortFlightScreen(flightCode: flight.code)));
    if (mounted) await _load();
  }

  Future<void> _openShipment(OperationalShipment row) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ShipmentProcessScreen(code: row.code)));
    if (mounted) await _load();
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.flight});
  final HubFlightDetail flight;

  @override
  Widget build(BuildContext context) => PaperCard(
      radius: heroRadius,
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          _Endpoint(
              city: banglaPlace(flight.from, fallback: tr('China')),
              time: flight.depTime,
              note: tr('Departs')),
          Expanded(
              child: Column(children: [
            const _DashedPlane(size: 34),
            const SizedBox(height: 4),
            Text(
                flight.stopLabel == null
                    ? tr('Direct')
                    : 'via ${flight.stopLabel}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ])),
          _Endpoint(
              city: banglaPlace(flight.to, fallback: tr('Bangladesh')),
              time: flight.arrTime,
              note: tr('Arrives'),
              end: true),
        ]),
        if (flight.scheduleNeedsConfirmation) ...[
          const SizedBox(height: 12),
          StatusPill(
              label: tr('Date has passed — not updated by admin'),
              tone: ChipTone.amber),
        ],
      ]));
}

/// Orders on the flight, how many reached the hub, who is receiving and
/// the one-tap Receive orders.
class _ReceiveCard extends StatelessWidget {
  const _ReceiveCard(
      {required this.flight,
      required this.loader,
      required this.busy,
      required this.onReceive});

  final HubFlightDetail flight;
  final SignedPhotoLoader loader;
  final bool busy;
  final VoidCallback onReceive;

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).session.user;
    final ready = flight.readyToReceive ?? 0;
    final total = flight.shipmentCount;
    return PaperCard(
        key: const Key('hub-receive-card'),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(tr('Orders on this flight'),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted)),
                  Text(
                      '${trn(total, '{n} order', '{n} orders')} · ${_kg(flight.kg)}',
                      style: const TextStyle(
                          fontSize: 22,
                          height: 1.25,
                          fontWeight: FontWeight.w700)),
                ])),
            Text(tr('{n} received', {'n': flight.receivedCount}),
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: total == 0 ? 0 : flight.receivedCount / total,
                  minHeight: 8,
                  color: AppColors.ok,
                  backgroundColor: AppColors.neutralSoft)),
          if (user != null) ...[
            const SizedBox(height: 12),
            Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  PersonAvatar(user.name,
                      photoRef: user.photoRef, loader: loader, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(tr('Receiving as {name}', {'name': user.name}),
                            style: const TextStyle(
                                fontSize: 14,
                                height: 1.35,
                                fontWeight: FontWeight.w600)),
                        Text(tr('Your name and photo go on each order you receive'),
                            style: const TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: AppColors.muted)),
                      ])),
                ])),
          ],
          const SizedBox(height: 12),
          AppButton(
              key: const Key('hub-receive'),
              label: ready == 0
                  ? tr('Nothing to receive yet')
                  : trn(ready, 'Receive {n} order', 'Receive {n} orders'),
              icon: Icons.inventory_2_outlined,
              kind: AppButtonKind.current,
              busy: busy,
              onPressed: ready == 0 ? null : onReceive),
          if (ready == 0 && flight.receivedCount < total) ...[
            const SizedBox(height: 8),
            Text(tr('Orders can be received once customs clears them.'),
                style: const TextStyle(
                    fontSize: 12, height: 1.4, color: AppColors.muted)),
          ],
        ]));
  }
}

class _Endpoint extends StatelessWidget {
  const _Endpoint(
      {required this.city,
      required this.time,
      required this.note,
      this.end = false});
  final String city, time, note;
  final bool end;

  @override
  Widget build(BuildContext context) {
    final known = _isClock(time);
    return Column(
        crossAxisAlignment:
            end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(city,
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          Text(known ? time : '--:--',
              style: TextStyle(
                  fontSize: 26,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: known ? AppColors.ink : AppColors.faint,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          Text(note,
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]);
  }
}

/// Orders grouped by customer code, in manifest order.
List<(String, List<OperationalShipment>)> _byCustomer(
    List<OperationalShipment> rows) {
  final groups = <String, List<OperationalShipment>>{};
  for (final row in rows) {
    groups.putIfAbsent(row.supplierCode, () => []).add(row);
  }
  return [for (final e in groups.entries) (e.key, e.value)];
}

/// One customer on the flight: its orders, who carries them and the device
/// photos taken in China. The hub sees the customer code only.
class _CustomerManifest extends StatelessWidget {
  const _CustomerManifest(
      {required this.customer,
      required this.rows,
      required this.extras,
      required this.loader,
      required this.onOpen});

  final String customer;
  final List<OperationalShipment> rows;
  final Map<String, HubOrderExtras> extras;
  final SignedPhotoLoader loader;
  final ValueChanged<OperationalShipment> onOpen;

  @override
  Widget build(BuildContext context) {
    final kg = rows.fold<double>(0, (n, r) => n + r.effectiveKg);
    return Padding(
      key: Key('hub-customer-$customer'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          CustomerMark(name: customer, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(customer,
                  style: const TextStyle(
                      fontSize: 15.5, fontWeight: FontWeight.w700)),
              Text(
                  '${trn(rows.length, '{n} order', '{n} orders')} · ${_kg(kg)}',
                  style:
                      const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        Container(
          margin: const EdgeInsets.only(left: 20),
          padding: const EdgeInsets.only(left: 14),
          decoration: const BoxDecoration(
              border:
                  Border(left: BorderSide(color: AppColors.line, width: 2))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final row in rows)
              _ManifestOrder(
                  row: row,
                  extras: extras[row.code],
                  loader: loader,
                  onTap: () => onOpen(row)),
          ]),
        ),
      ]),
    );
  }
}

class _ManifestOrder extends StatelessWidget {
  const _ManifestOrder(
      {required this.row,
      required this.extras,
      required this.loader,
      required this.onTap});

  final OperationalShipment row;
  final HubOrderExtras? extras;
  final SignedPhotoLoader loader;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photos = extras?.devicePhotos ?? const <DevicePhoto>[];
    final flyer = extras?.flyerName;
    return InkWell(
      key: Key('hub-order-${row.code}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        row.description.isEmpty || row.description == '—'
                            ? row.code
                            : '${row.code} · ${row.description}',
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (flyer != null && flyer.isNotEmpty)
                            Text(tr('Carried by {name}', {'name': flyer}),
                                style: const TextStyle(
                                    fontSize: 12.5, color: AppColors.muted)),
                          StatusPill(
                              label: banglaStatus(row.status, row.statusLabel),
                              tone: shipmentStatusTone(row.statusIndex)),
                        ]),
                  ]),
            ),
            const SizedBox(width: 8),
            Text(formatKg(row.effectiveKg),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            SortPhotoStrip(
                stored: [for (final d in photos) d.reference],
                labels: {for (final d in photos) d.reference: d.label},
                loader: loader,
                group: tr('Device photos'),
                size: 58),
          ],
        ]),
      ),
    );
  }
}

/// Departure and arrival with a dashed line between them.
class FlightRouteLine extends StatelessWidget {
  const FlightRouteLine({super.key, required this.flight});
  final HubFlight flight;

  @override
  Widget build(BuildContext context) {
    Widget end(String time, String city, {bool right = false}) {
      final known = _isClock(time);
      return Column(
          crossAxisAlignment:
              right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(known ? time : '--:--',
                style: TextStyle(
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: known ? AppColors.ink : AppColors.faint,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            Text(city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]);
    }

    return Row(children: [
      Flexible(
          child: end(
              flight.depTime, banglaPlace(flight.from, fallback: tr('China')))),
      const Expanded(child: _DashedPlane(size: 18)),
      Flexible(
          child: end(flight.arrTime,
              banglaPlace(flight.to, fallback: tr('Bangladesh')),
              right: true)),
    ]);
  }
}

class _DashedPlane extends StatelessWidget {
  const _DashedPlane({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        Positioned.fill(
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: CustomPaint(painter: _DashPainter()))),
        Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
                color: size > 24 ? AppColors.primarySoft : AppColors.card,
                shape: BoxShape.circle),
            child: Icon(Icons.flight_rounded,
                size: size * 0.55,
                color: AppColors.primary,
                semanticLabel: tr('Flight'))),
      ]));
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC3CAD5)
      ..strokeWidth = 1.5;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(
          Offset(x, y), Offset((x + 4).clamp(0, size.width), y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FlightDateBlock extends StatelessWidget {
  const FlightDateBlock({super.key, required this.day, this.highlight = false});
  final FlightDay? day;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final foreground = highlight ? Colors.white : AppColors.ink;
    return Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
        decoration: BoxDecoration(
            color: highlight ? AppColors.primary : AppColors.paper,
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(day == null ? '—' : '${day!.day}',
              style: TextStyle(
                  fontSize: 21,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: foreground)),
          // Long Bangla weekdays (বৃহস্পতি) shrink rather than clip.
          FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(day == null ? '' : '${day!.month} · ${day!.weekday}',
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: highlight
                          ? const Color(0xE6FFFFFF)
                          : AppColors.muted))),
        ]));
  }
}

/// Status label and tone for a hub flight row.
(String, ChipTone) flightBadge(HubFlight flight, FlightDay? day,
    {bool next = false}) {
  if (flight.status == 'completed') return (tr('Arrived'), ChipTone.green);
  if (flight.status == 'departed') return (tr('On the way'), ChipTone.amber);
  if (flightCancelled(flight.status, flight.tracking)) {
    return (tr('Cancelled by airline'), ChipTone.red);
  }
  if (flight.scheduleNeedsConfirmation) {
    return (tr('Date not updated'), ChipTone.amber);
  }
  if (!flight.timesKnown) return (tr('Time not confirmed'), ChipTone.amber);
  final when = day?.relativeLabel;
  if (next) {
    return (
      when == null ? tr('Up next') : tr('Next flight · {when}', {'when': when}),
      ChipTone.blue
    );
  }
  return (when ?? flight.statusLabel, ChipTone.neutral);
}

bool _isClock(String value) => RegExp(r'^\d{1,2}:\d{2}').hasMatch(value.trim());

String _kg(double kg) => '${kg.toStringAsFixed(1)} kg';

/// The airline's landing time once it left, else the planned one.
String? _landsAt(HubFlight flight) {
  final t = flight.tracking;
  if (t != null && (t.left || t.landed) && t.landsAt != null) return t.landsAt;
  return _isClock(flight.arrTime) ? flight.arrTime : null;
}

/// A line from the airline under a hub flight row, if it said something.
(String, ChipTone)? hubFlightNote(HubFlight flight) {
  if (flightCancelled(flight.status, flight.tracking)) {
    return (
      tr('The airline cancelled it. The admin sets the new date.'),
      ChipTone.red
    );
  }
  if (flight.status == 'upcoming') return null;
  final look = flightLook(
      status: flight.status,
      dateOver: false,
      tracking: flight.tracking,
      plain: (flight.statusLabel, ChipTone.neutral));
  return look.note == null ? null : (look.note!, look.noteTone);
}
