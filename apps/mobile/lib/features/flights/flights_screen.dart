import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/data_changes.dart';
import '../../data/models/flight.dart';
import '../../data/models/hub_flight.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flight_parts.dart';
import '../../widgets/ui.dart';
import 'flight_detail_screen.dart';
import 'flight_form_screen.dart';
import 'hub_flights_screen.dart';
import 'ticket_import_screen.dart';

class FlightsScreen extends StatefulWidget {
  const FlightsScreen({super.key, this.root = false});
  final bool root;

  @override
  State<FlightsScreen> createState() => _FlightsScreenState();
}

class _FlightsScreenState extends State<FlightsScreen> {
  List<FlightSummary> _rows = const [];
  String? _error;
  var _loading = true;
  var _filter = 'upcoming';

  static const _filters = ['upcoming', 'departed', 'completed', 'all'];

  @override
  void initState() {
    super.initState();
    dataChanges.addListener(_onDataChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    dataChanges.removeListener(_onDataChanged);
    super.dispose();
  }

  /// A flight was deleted on another screen.
  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await AppScope.of(context).flights.list();
      if (!mounted) return;
      setState(() => _rows = rows);
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

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const FlightFormScreen()));
    if (created == true && mounted) await _load();
  }

  Future<void> _importTicket() async {
    final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const TicketImportScreen()));
    if (created == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _rows
        .where((row) => _filter == 'all' || row.status == _filter)
        .toList();
    final nextCode = _nextFlightCode(visible);
    final bookedKg = visible.fold(0.0, (total, row) => total + row.bookedKg);
    return WorkspaceScaffold(
        root: widget.root,
        title: tr('Flights'),
        subtitle: tr('Schedule and capacity'),
        onRefresh: _load,
        actions: [
          IconButton.outlined(
              key: const Key('flights-import-ticket'),
              tooltip: tr('Import ticket'),
              onPressed: _importTicket,
              style: IconButton.styleFrom(
                  backgroundColor: AppColors.card,
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.line)),
              icon: const Icon(Icons.upload_file_rounded, size: 20)),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primarySoft,
                  foregroundColor: AppColors.primaryInk,
                  minimumSize: const Size(48, 44),
                  padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
                  shape: const StadiumBorder()),
              onPressed: _create,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: Text(tr('New flight'))),
          if (!widget.root) const SizedBox(width: 12),
        ],
        toolbar: ScreenTabs(
            labels: [
              tr('Upcoming'),
              tr('Departed'),
              tr('Completed'),
              tr('All')
            ],
            index: _filters.indexOf(_filter),
            onChanged: (i) => setState(() => _filter = _filters[i])),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (!_loading && _error == null && visible.isEmpty)
            EmptyNote(
                icon: Icons.flight_outlined,
                title: tr('No flights in this filter'),
                body: tr('New flights will appear here.')),
          if (visible.isNotEmpty) ...[
            Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child:
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                      child: Text(
                          trn(visible.length, '{n} flight', '{n} flights'),
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              height: 1.35))),
                  const SizedBox(width: 8),
                  Flexible(
                      child: Text(
                          tr('{kg} kg booked in total',
                              {'kg': bookedKg.toStringAsFixed(1)}),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: AppColors.muted))),
                ])),
            for (final row in visible) ...[
              AdminFlightCard(
                  row: row,
                  next: row.code == nextCode,
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => FlightDetailScreen(code: row.code)));
                    if (mounted) await _load();
                  }),
              const SizedBox(height: 12),
            ],
          ],
        ]);
  }
}

/// The first upcoming flight that has not passed its date.
String? _nextFlightCode(List<FlightSummary> rows) {
  for (final row in rows) {
    final day = FlightDay.parse(row.date);
    if (row.status == 'upcoming' &&
        !row.scheduleNeedsConfirmation &&
        (day == null || day.daysAway >= 0)) {
      return row.code;
    }
  }
  return null;
}

/// One flight in the admin schedule; the next one is outlined in blue.
class AdminFlightCard extends StatelessWidget {
  const AdminFlightCard(
      {super.key, required this.row, required this.onTap, this.next = false});
  final FlightSummary row;
  final VoidCallback onTap;
  final bool next;

  @override
  Widget build(BuildContext context) {
    final day = FlightDay.parse(row.date);
    final badge = adminFlightBadge(row, day, next: next);
    final noFlyer = row.flyers.isEmpty;
    final shipments = trn(row.shipmentCount, '{n} shipment', '{n} shipments');
    return PaperCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        border: next
            ? const BorderSide(color: AppColors.primary, width: 1.5)
            : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DateBlock(day: day, highlight: next),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Flexible(
                        flex: 3,
                        child: Text(row.displayCode,
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
                  RouteLine(
                      depTime: row.depTime,
                      arrTime: row.arrTime,
                      from: banglaPlace(row.from, fallback: tr('China')),
                      to: banglaPlace(row.to, fallback: tr('Bangladesh')),
                      stop: row.stopLabel,
                      highlight: next),
                ])),
          ]),
          const SizedBox(height: 12),
          MeterBar(value: row.fill),
          const SizedBox(height: 6),
          CapacityText(
              booked: row.bookedKg,
              space: row.spaceKg.toDouble(),
              extra: '· $shipments'),
          if (row.scheduleNeedsConfirmation) ...[
            const SizedBox(height: 4),
            Text(tr('Date has passed · Confirm the status'),
                style: const TextStyle(
                    color: AppColors.danger, fontSize: 12, height: 1.4)),
          ],
          const Divider(height: 20),
          Row(children: [
            Icon(
                noFlyer
                    ? Icons.warning_amber_rounded
                    : Icons.person_outline_rounded,
                size: 17,
                color: noFlyer ? AppColors.accentInk : AppColors.inkSoft),
            const SizedBox(width: 6),
            Expanded(
                child: Text(
                    noFlyer ? tr('No flyer assigned') : row.flyers.join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: noFlyer ? FontWeight.w700 : FontWeight.w500,
                        color: noFlyer
                            ? AppColors.accentInk
                            : AppColors.inkSoft))),
            const SizedBox(width: 12),
            _DeviceCount(
                icon: Icons.smartphone_rounded,
                count: row.mobiles,
                label: tr('Mobiles')),
            const SizedBox(width: 12),
            _DeviceCount(
                icon: Icons.laptop_rounded,
                count: row.laptops,
                label: tr('Laptops')),
          ]),
        ]));
  }
}

class _DeviceCount extends StatelessWidget {
  const _DeviceCount(
      {required this.icon, required this.count, required this.label});
  final IconData icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
      label: '$label $count',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: AppColors.inkSoft),
        const SizedBox(width: 4),
        Text('$count',
            style: const TextStyle(fontSize: 13, color: AppColors.inkSoft)),
      ]));
}
