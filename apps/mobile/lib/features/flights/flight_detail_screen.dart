import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../data/models/shipment.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../admin/admin_shipment_screen.dart';
import '../admin/money_format.dart';
import 'flight_money_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final summary = detail?.summary;
    return Scaffold(
      appBar: BackTitle(
          title: summary?.displayCode ?? displayFlightCode(widget.code)),
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(pageGutter, 12, pageGutter, 32),
          children: [
            if (_loading && detail == null)
              const LinearProgressIndicator(
                  color: AppColors.teal, backgroundColor: AppColors.tealSoft),
            if (_error != null) ...[
              ErrorNote(message: _error!, onRetry: _load),
              const SizedBox(height: 12),
            ],
            if (summary != null && detail != null) ...[
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(summary.displayCode,
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.teal))),
                        StatusPill(
                            label: summary.statusLabel,
                            tone: flightStatusTone(summary.status)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                        '${summary.date} · ${summary.depTime} → ${summary.arrTime}'),
                    Text(summary.via,
                        style: const TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 10),
                    CapacityBar(
                        booked: summary.bookedKg,
                        space: summary.spaceKg.toDouble()),
                    const SizedBox(height: 8),
                    Text(
                        tr('{kg} kg left · Reference {code}', {
                          'kg': summary.leftKg.toStringAsFixed(1),
                          'code': summary.code
                        }),
                        style: const TextStyle(
                            color: AppColors.muted, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ScreenTabs(
                  labels: [tr('Bookings'), tr('Flyers'), tr('Money')],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i)),
              const SizedBox(height: 20),
              if (_tab == 2) ...[
                const SizedBox(height: 12),
                SectionTitle(
                    title: tr('Ticket'),
                    subtitle: tr(
                        'Cash settlement, contributions and flyer payments are on a separate page.')),
                PaperCard(
                  child: Column(
                    children: [
                      KvRow(
                          label: tr('Actual cost'),
                          value: formatBdt(summary.actualCost)),
                      KvRow(
                          label: tr('Agency share'),
                          value: formatBdt(summary.agencyShare)),
                      KvRow(
                          label: tr('Due from flyers'),
                          value: formatBdt(summary.flyerDue)),
                      KvRow(
                          label: tr('Ticket paid'),
                          value: formatBdt(summary.ticketPaid)),
                      KvRow(
                          label: tr('Ticket due'),
                          value: formatBdt(summary.ticketDue),
                          valueColor: summary.ticketDue > 0
                              ? AppColors.danger
                              : AppColors.ok),
                      if (summary.ticketRefundDue > 0)
                        KvRow(
                            label: tr('Ticket refund'),
                            value: formatBdt(summary.ticketRefundDue)),
                      KvRow(
                          label: tr('Shipment charges'),
                          value: formatBdt(summary.revenue)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: tr('Ticket and contributions'),
                  kind: AppButtonKind.current,
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => FlightMoneyScreen(code: widget.code)));
                    if (mounted) await _load();
                  },
                ),
              ],
              if (_tab == 1) ...[
                const SizedBox(height: 16),
                SectionTitle(title: tr('Flyers')),
                if (detail.flyerDetails.isEmpty)
                  EmptyNote(title: tr('No flyers'), body: tr('Add one below.')),
                for (final flyer in detail.flyerDetails) ...[
                  PaperCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(flyer.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(flyer.bdPhone,
                            style: const TextStyle(color: AppColors.muted)),
                        for (final settlement in summary.settlements
                            .where((item) => item.name == flyer.name))
                          Text(tr('Contribution {contribution} · Paid {paid}', {
                            'contribution': formatBdt(settlement.contribution),
                            'paid': formatBdt(settlement.paidAmount)
                          })),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_flyerNames.isEmpty)
                  Text(tr('No active flyers left to add.'),
                      style: const TextStyle(color: AppColors.muted))
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _assign,
                    decoration: InputDecoration(labelText: tr('Add flyer')),
                    items: [
                      for (final name in _flyerNames)
                        DropdownMenuItem(value: name, child: Text(name))
                    ],
                    onChanged: (value) => setState(() => _assign = value),
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                      label: tr('Add to flight'),
                      busy: _busy,
                      onPressed: _assign == null ? null : _assignFlyer),
                ],
              ],
              if (_tab == 0) ...[
                const SizedBox(height: 16),
                SectionTitle(
                    title: tr('Bookings'),
                    subtitle: trn(detail.bookings.length, '{n} shipment',
                        '{n} shipments')),
                if (detail.bookings.isEmpty)
                  EmptyNote(
                      title: tr('No bookings'),
                      body: tr('Choose this flight from shipment intake.')),
                for (final booking in detail.bookings) ...[
                  _Booking(
                      row: booking,
                      onOpen: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  AdminShipmentScreen(code: booking.code)))),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Booking extends StatelessWidget {
  const _Booking({required this.row, required this.onOpen});

  final AdminShipment row;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return DirectoryTile(
      title: row.code,
      subtitle: tr('{supplier} · {kg} · {due} due', {
        'supplier': row.supplierName ?? row.supplierCode,
        'kg': formatKg(row.effectiveKg),
        'due': formatBdt(row.dueAmount)
      }),
      badge: banglaStatus(row.status, row.statusLabel),
      onTap: onOpen,
    );
  }
}
