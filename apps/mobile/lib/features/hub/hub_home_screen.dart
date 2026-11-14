import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/dashboard.dart';
import '../../data/models/flight.dart';
import '../../data/models/hub_flight.dart';
import '../../data/models/shipment.dart' show formatKg;
import '../../data/models/sorting.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flight_status_parts.dart' show HubLandingCard;
import '../../widgets/ui.dart';
import '../flights/hub_flights_screen.dart';
import '../flights/track_screen.dart';
import '../notifications/notifications_screen.dart';
import '../sorting/sort_customer_screen.dart';
import '../sorting/sort_flight_screen.dart';

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
  HubSortSummary _todo = HubSortSummary.empty;
  String? _error;
  var _loading = true;
  final _bell = GlobalKey<NotificationBellState>();

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
    final sorting = AppScope.of(context).sorting;
    // The bell loads itself once; a refresh of the page refreshes it too.
    if (_data != null) _bell.currentState?.reload();
    try {
      final todo = sorting
          .hubSummary()
          .then<HubSortSummary?>((v) => v, onError: (Object _) => null);
      final data = await widget.dashboard.hub();
      final summary = await todo;
      if (!mounted) return;
      setState(() {
        _data = data;
        if (summary != null) _todo = summary;
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
                trn(data.atHubCount, '{n} order at the hub',
                    '{n} orders at the hub')
              ].join(' · '),
        root: true,
        actions: [NotificationBell(key: _bell)],
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
    final inAir = data.upcomingFlights
        .where((f) =>
            f.tracking != null && f.tracking!.left && !f.tracking!.landed)
        .firstOrNull;
    final notices = [
      for (final notice in data.notices)
        if (notice.tag == 'WEIGHT' || data.upcomingFlights.isEmpty) notice
    ];
    final todo = _todoRows();
    return [
      if (inAir != null) ...[
        _NextFlight(
            flight: inAir,
            onTrack: () => _push(TrackScreen(
                code: inAir.code, title: displayFlightCode(inAir.code))),
            onOpen: () => _openFlight(inAir)),
        const SizedBox(height: 22),
      ],
      SectionTitle(title: tr('To do today')),
      if (todo.isEmpty)
        EmptyNote(
            key: const Key('hub-todo-empty'),
            icon: Icons.task_alt_rounded,
            title: tr('Nothing to do right now'),
            body: tr(
                'Work shows up here when a flight is received or the admin sends a customer back.'))
      else
        SurfaceGroup(children: todo),
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
      if (notices.isNotEmpty) ...[
        const SizedBox(height: 22),
        SectionTitle(title: tr('Needs attention')),
        SurfaceGroup(children: [
          for (final notice in notices) _NoticeRow(notice: notice),
        ]),
      ],
    ];
  }

  /// Fix first, then sort, then what waits for the admin and what is out.
  List<Widget> _todoRows() {
    final t = _todo;
    bool many(List<HubSortBucket> b) => b.length > 1;
    return [
      for (final b in t.sentBack)
        _TodoRow(
            key: Key('hub-todo-fix-${b.flightCode}'),
            icon: Icons.undo_rounded,
            tone: ChipTone.amber,
            title: tr('Fix and send again'),
            subtitle: tr('{customers} · {flight} · sent back by the admin',
                {'customers': b.customers.join(', '), 'flight': b.number}),
            count: b.customers.length,
            onTap: () => b.customers.length == 1
                ? _push(SortCustomerScreen(
                    flightCode: b.flightCode, customer: b.customers.single))
                : _push(SortFlightScreen(flightCode: b.flightCode))),
      for (final b in t.toSort)
        _TodoRow(
            key: Key('hub-todo-sort-${b.flightCode}'),
            icon: Icons.checklist_rounded,
            tone: ChipTone.blue,
            title: tr('Sort {flight}', {'flight': b.number}),
            subtitle:
                '${trn(b.customers.length, '{n} customer', '{n} customers')} · ${trn(b.orders, '{n} order', '{n} orders')}',
            count: b.customers.length,
            onTap: () => _push(SortFlightScreen(flightCode: b.flightCode))),
      for (final b in t.waiting)
        _TodoRow(
            key: Key('hub-todo-waiting-${b.flightCode}'),
            icon: Icons.schedule_rounded,
            tone: ChipTone.neutral,
            title: many(t.waiting)
                ? tr('Waiting for admin · {flight}', {'flight': b.number})
                : tr('Waiting for admin'),
            subtitle: b.customers.join(', '),
            count: b.customers.length,
            onTap: () => _push(SortFlightScreen(flightCode: b.flightCode))),
      for (final b in t.delivery)
        _TodoRow(
            key: Key('hub-todo-delivery-${b.flightCode}'),
            icon: Icons.local_shipping_outlined,
            tone: ChipTone.green,
            title: many(t.delivery)
                ? tr('In delivery · {flight}', {'flight': b.number})
                : tr('In delivery'),
            subtitle: tr('Confirm each one when the customer has it'),
            count: b.customers.length,
            onTap: () => _push(SortFlightScreen(flightCode: b.flightCode))),
    ];
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) await _load();
  }

  void _openFlights() {
    final open = widget.onOpenFlights;
    if (open != null) return open();
    Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const HubFlightsScreen()));
  }

  void _openFlight(HubFlight flight) =>
      _push(HubFlightDetailScreen(code: flight.code));
}

/// The flight in the air now: landing time, legs, Track and Open flight.
class _NextFlight extends StatelessWidget {
  const _NextFlight(
      {required this.flight, required this.onTrack, required this.onOpen});

  final HubFlight flight;
  final VoidCallback onTrack, onOpen;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(
            title: tr('Next flight · {flight}',
                {'flight': displayFlightCode(flight.code)})),
        HubLandingCard(flight: flight),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: AppButton(
                  key: const Key('hub-home-track'),
                  label: tr('Track'),
                  icon: Icons.map_outlined,
                  kind: AppButtonKind.quiet,
                  onPressed: onTrack)),
          const SizedBox(width: 10),
          Expanded(
              child: AppButton(
                  key: const Key('hub-home-open-flight'),
                  label: tr('Open flight'),
                  icon: Icons.chevron_right_rounded,
                  kind: AppButtonKind.quiet,
                  onPressed: onOpen)),
        ]),
      ]);
}

class _TodoRow extends StatelessWidget {
  const _TodoRow(
      {super.key,
      required this.icon,
      required this.tone,
      required this.title,
      required this.subtitle,
      required this.count,
      required this.onTap});

  final IconData icon;
  final ChipTone tone;
  final String title, subtitle;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = toneColors(tone);
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              IconBadge(icon, tone: tone, size: 44),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 1),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: AppColors.muted)),
                  ])),
              const SizedBox(width: 8),
              Container(
                  constraints:
                      const BoxConstraints(minWidth: 26, minHeight: 26),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(999)),
                  child: Text('$count',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: colors.foreground))),
              const SizedBox(width: 4),
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
            trn(incoming.count, '{n} order incoming · {kg}',
                '{n} orders incoming · {kg}', {'kg': formatKg(incoming.kg)}),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        if (flight != null)
          Text(flight,
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
      ])),
    ]));
  }
}
