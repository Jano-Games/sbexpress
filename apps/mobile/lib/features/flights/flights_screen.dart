import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import 'flight_detail_screen.dart';
import 'flight_form_screen.dart';
import 'ticket_import_screen.dart';
import '../../l10n/l10n.dart';

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
    return WorkspaceScaffold(
        root: widget.root,
        title: tr('Flights'),
        subtitle: tr('Schedule and capacity'),
        onRefresh: _load,
        actions: [
          IconButton(
              key: const Key('flights-import-ticket'),
              tooltip: tr('Import ticket'),
              onPressed: _importTicket,
              icon: const Icon(Icons.upload_file_rounded)),
          TextButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: Text(tr('New'))),
          const SizedBox(width: 8)
        ],
        toolbar: ScreenTabs(
            labels: [
              tr('Upcoming'),
              tr('Departed'),
              tr('Completed'),
              tr('All')
            ],
            index: const ['upcoming', 'departed', 'completed', 'all']
                .indexOf(_filter),
            onChanged: (i) => setState(() => _filter =
                const ['upcoming', 'departed', 'completed', 'all'][i])),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (!_loading && _error == null && visible.isEmpty)
            EmptyNote(
                title: tr('No flights in this filter'),
                body: tr('New flights will appear here.')),
          if (visible.isNotEmpty) ...[
            SectionTitle(
                title: trn(visible.length, '{n} flight', '{n} flights')),
            SurfaceGroup(children: [
              for (final row in visible)
                _FlightCard(
                    row: row,
                    onOpen: () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => FlightDetailScreen(code: row.code)));
                      if (mounted) await _load();
                    })
            ]),
          ],
        ]);
  }
}

class _FlightCard extends StatelessWidget {
  const _FlightCard({required this.row, required this.onOpen});
  final FlightSummary row;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onOpen,
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(row.displayCode,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600))),
              Flexible(
                  child: StatusPill(
                      label: row.statusLabel,
                      tone: flightStatusTone(row.status))),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.muted)
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.flight_takeoff_rounded,
                  size: 18, color: AppColors.teal),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('${row.depTime}  —  ${row.arrTime}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w500)))
            ]),
            const SizedBox(height: 3),
            Text('${row.date} · ${row.via}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 14),
            CapacityBar(booked: row.bookedKg, space: row.spaceKg.toDouble()),
            const SizedBox(height: 10),
            Text(
                row.flyers.isEmpty
                    ? tr('No flyer assigned')
                    : row.flyers.join(', '),
                style: const TextStyle(fontSize: 13)),
            Text(
                trn(
                    row.shipmentCount,
                    '{n} shipment · Mobiles {mobiles} · Laptops {laptops}',
                    '{n} shipments · Mobiles {mobiles} · Laptops {laptops}',
                    {'mobiles': row.mobiles, 'laptops': row.laptops}),
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            if (row.scheduleNeedsConfirmation)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(tr('Date has passed · Confirm the status'),
                      style: const TextStyle(
                          color: AppColors.danger, fontSize: 12))),
          ])));
}
