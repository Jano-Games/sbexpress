import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/hub_flight.dart';
import '../../data/models/shipment.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../shipments/shipment_process_screen.dart';

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
        title: 'ফ্লাইট',
        subtitle: 'চেংদু থেকে ঢাকায় যা আসছে',
        onRefresh: _load,
        toolbar: ScreenTabs(labels: [
          data == null ? 'আসন্ন' : 'আসন্ন · ${data.upcoming.length}',
          'এসে গেছে'
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
                    ? 'আসন্ন ফ্লাইট নেই'
                    : 'সম্প্রতি কোনো ফ্লাইট আসেনি',
                body: _tab == 0
                    ? 'নতুন ফ্লাইট বুক হলে এখানে দেখা যাবে।'
                    : 'ফ্লাইট শেষ হলে এখানে থাকবে।'),
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
                label: 'ফ্লাইট', value: '${data.upcoming.length}টি', size: 19)),
        const VerticalDivider(width: 24, color: AppColors.lineSoft),
        Expanded(
            child: AmountLabel(
                label: 'শিপমেন্ট', value: '${data.shipmentCount}টি', size: 19)),
        const VerticalDivider(width: 24, color: AppColors.lineSoft),
        Expanded(
            child:
                AmountLabel(label: 'মোট ওজন', value: _kg(data.kg), size: 19)),
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
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            InfoChip(
                icon: Icons.inventory_2_outlined,
                label: '${flight.shipmentCount}টি শিপমেন্ট'),
            InfoChip(icon: Icons.scale_outlined, label: _kg(flight.kg)),
            InfoChip(
                icon: Icons.person_outline_rounded,
                label: flight.flyers.isEmpty
                    ? 'ফ্লায়ার ঠিক হয়নি'
                    : flight.flyers.join(', '),
                muted: flight.flyers.isEmpty),
            if (flight.receivedCount > 0)
              InfoChip(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'হাবে ${flight.receivedCount}/${flight.shipmentCount}',
                  tone: ChipTone.green),
          ]),
          if (next) ...[
            const SizedBox(height: 10),
            const Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Flexible(
                  child: Text('কী কী আসছে দেখুন',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary))),
              Icon(Icons.chevron_right_rounded,
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
      if (_isClock(flight.arrTime)) 'নামবে ${flight.arrTime}',
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
                        '${flight.shipmentCount}টি শিপমেন্ট · ${_kg(flight.kg)}',
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
                  const StatusPill(label: 'পথে', tone: ChipTone.amber),
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
          title: flight?.displayCode ?? 'ফ্লাইট',
          subtitle: day == null
              ? null
              : '${day.weekday}বার · ${day.day} ${day.month}',
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
                  _RouteCard(flight: flight),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: MetricTile(
                            label: 'শিপমেন্ট',
                            value: '${flight.shipmentCount}টি')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: MetricTile(
                            label: 'মোট ওজন', value: _kg(flight.kg))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: MetricTile(
                            label: 'হাবে এসেছে',
                            value:
                                '${flight.receivedCount}/${flight.shipmentCount}')),
                  ]),
                  const SizedBox(height: 22),
                  SectionTitle(
                      title: 'এই ফ্লাইটে আসছে',
                      action: Text('${flight.shipments.length}টি',
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.muted))),
                  if (flight.shipments.isEmpty)
                    const EmptyNote(
                        icon: Icons.inventory_2_outlined,
                        title: 'এই ফ্লাইটে শিপমেন্ট নেই',
                        body: 'বুকিং হলে এখানে দেখা যাবে।')
                  else
                    SurfaceGroup(children: [
                      for (final row in flight.shipments)
                        _ManifestRow(row: row, onTap: () => _openShipment(row)),
                    ]),
                  if (flight.status != 'completed') ...[
                    const SizedBox(height: 14),
                    const HintNote(
                        text:
                            'কাস্টমস ক্লিয়ার হলে প্রতিটি শিপমেন্ট খুলে "হাবে গ্রহণ করুন" চাপুন — তারপর ওজনের ধাপ শুরু হবে।'),
                  ],
                ],
              ])),
    );
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
              city: banglaPlace(flight.from, fallback: 'চীন'),
              time: flight.depTime,
              note: 'ছাড়বে'),
          Expanded(
              child: Column(children: [
            const _DashedPlane(size: 34),
            const SizedBox(height: 4),
            Text(
                flight.stopLabel == null ? 'সরাসরি' : 'via ${flight.stopLabel}',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ])),
          _Endpoint(
              city: banglaPlace(flight.to, fallback: 'ঢাকা'),
              time: flight.arrTime,
              note: 'পৌঁছাবে',
              end: true),
        ]),
        if (flight.scheduleNeedsConfirmation) ...[
          const SizedBox(height: 12),
          const StatusPill(
              label: 'তারিখ পেরিয়েছে — অ্যাডমিন আপডেট করেননি',
              tone: ChipTone.amber),
        ],
        const Divider(height: 28),
        if (flight.flyerDetails.isEmpty)
          const Text('এই ফ্লাইটে এখনো ফ্লায়ার ঠিক হয়নি',
              style: TextStyle(color: AppColors.muted))
        else
          for (final flyer in flight.flyerDetails)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      child: Text(flyer.initial,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(flyer.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        Text(
                            _hasPhone(flyer.bdPhone)
                                ? 'ফ্লায়ার · ${flyer.bdPhone}'
                                : 'ফ্লায়ার · লাগেজে আনছেন',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.muted)),
                      ])),
                  if (_hasPhone(flyer.bdPhone))
                    IconButton.filledTonal(
                        tooltip: '${flyer.name}-এর নম্বর কপি করুন',
                        style: IconButton.styleFrom(
                            backgroundColor: AppColors.primarySoft,
                            foregroundColor: AppColors.primary),
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: flyer.bdPhone));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('নম্বর কপি হয়েছে')));
                          }
                        },
                        icon: const Icon(Icons.call_outlined, size: 20)),
                ])),
      ]));
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

class _ManifestRow extends StatelessWidget {
  const _ManifestRow({required this.row, required this.onTap});
  final OperationalShipment row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = [
      row.supplierCode,
      if (row.description.isNotEmpty) row.description,
      formatKg(row.effectiveKg),
    ].join(' · ');
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.all(14),
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
                    Text(details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted)),
                  ])),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.faint),
            ])));
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
          child:
              end(flight.depTime, banglaPlace(flight.from, fallback: 'চীন'))),
      const Expanded(child: _DashedPlane(size: 18)),
      Flexible(
          child: end(flight.arrTime, banglaPlace(flight.to, fallback: 'ঢাকা'),
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
                semanticLabel: 'ফ্লাইট')),
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
        padding: const EdgeInsets.symmetric(vertical: 8),
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
          Text(day == null ? '' : '${day!.month} · ${day!.weekday}',
              maxLines: 1,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color:
                      highlight ? const Color(0xE6FFFFFF) : AppColors.muted)),
        ]));
  }
}

/// Status label and tone for a hub flight row.
(String, ChipTone) flightBadge(HubFlight flight, FlightDay? day,
    {bool next = false}) {
  if (flight.status == 'completed') return ('এসে গেছে', ChipTone.green);
  if (flight.status == 'departed') return ('পথে আছে', ChipTone.amber);
  if (flight.scheduleNeedsConfirmation) {
    return ('তারিখ আপডেট হয়নি', ChipTone.amber);
  }
  if (!flight.timesKnown) return ('সময় নিশ্চিত নয়', ChipTone.amber);
  final when = day?.relativeLabel;
  if (next) {
    return (
      when == null ? 'পরের ফ্লাইট' : 'পরের ফ্লাইট · $when',
      ChipTone.blue
    );
  }
  return (when ?? flight.statusLabel, ChipTone.neutral);
}

const _placeNames = {
  'chengdu': 'চেংদু',
  'ctu': 'চেংদু',
  'tfu': 'চেংদু',
  'dhaka': 'ঢাকা',
  'dac': 'ঢাকা',
  'kunming': 'কুনমিং',
  'kmg': 'কুনমিং',
  'guangzhou': 'গুয়াংজু',
  'can': 'গুয়াংজু',
  'chittagong': 'চট্টগ্রাম',
  'cgp': 'চট্টগ্রাম',
};

/// Bangla name for common airports; other places stay as the server sent them.
String banglaPlace(String? place, {required String fallback}) {
  if (place == null || place.trim().isEmpty) return fallback;
  return _placeNames[place.trim().toLowerCase()] ?? place.trim();
}

bool _isClock(String value) => RegExp(r'^\d{1,2}:\d{2}').hasMatch(value.trim());

bool _hasPhone(String value) => RegExp(r'\d{5,}').hasMatch(value);

String _kg(double kg) => '${kg.toStringAsFixed(1)} kg';
