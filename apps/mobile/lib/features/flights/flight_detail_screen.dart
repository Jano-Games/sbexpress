import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../data/models/shipment.dart';
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
                        'বাকি ${summary.leftKg.toStringAsFixed(1)} kg · রেফারেন্স ${summary.code}',
                        style: const TextStyle(
                            color: AppColors.muted, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ScreenTabs(
                  labels: const ['বুকিং', 'ফ্লায়ার', 'হিসাব'],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i)),
              const SizedBox(height: 20),
              if (_tab == 2) ...[
                const SizedBox(height: 12),
                const SectionTitle(
                    title: 'টিকিট',
                    subtitle:
                        'ক্যাশ সেটল, কনট্রিবিউশন ও ফ্লায়ার জমা আলাদা পেজে।'),
                PaperCard(
                  child: Column(
                    children: [
                      KvRow(
                          label: 'আসল খরচ',
                          value: formatBdt(summary.actualCost)),
                      KvRow(
                          label: 'এজেন্সি শেয়ার',
                          value: formatBdt(summary.agencyShare)),
                      KvRow(
                          label: 'ফ্লায়ার বাকি',
                          value: formatBdt(summary.flyerDue)),
                      KvRow(
                          label: 'টিকিট পরিশোধ',
                          value: formatBdt(summary.ticketPaid)),
                      KvRow(
                          label: 'টিকিট বাকি',
                          value: formatBdt(summary.ticketDue),
                          valueColor: summary.ticketDue > 0
                              ? AppColors.danger
                              : AppColors.ok),
                      if (summary.ticketRefundDue > 0)
                        KvRow(
                            label: 'টিকিট রিফান্ড',
                            value: formatBdt(summary.ticketRefundDue)),
                      KvRow(
                          label: 'শিপমেন্ট বিল',
                          value: formatBdt(summary.revenue)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: 'টিকিট ও কনট্রিবিউশন',
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
                const SectionTitle(title: 'ফ্লায়ার'),
                if (detail.flyerDetails.isEmpty)
                  const EmptyNote(
                      title: 'ফ্লায়ার নেই', body: 'নিচ থেকে একজন যোগ করুন।'),
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
                          Text(
                              'কনট্রিবিউশন ${formatBdt(settlement.contribution)} · পেইড ${formatBdt(settlement.paidAmount)}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_flyerNames.isEmpty)
                  const Text('যোগ করার মতো সক্রিয় ফ্লায়ার নেই।',
                      style: TextStyle(color: AppColors.muted))
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _assign,
                    decoration:
                        const InputDecoration(labelText: 'ফ্লায়ার যোগ করুন'),
                    items: [
                      for (final name in _flyerNames)
                        DropdownMenuItem(value: name, child: Text(name))
                    ],
                    onChanged: (value) => setState(() => _assign = value),
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                      label: 'ফ্লাইটে যোগ করুন',
                      busy: _busy,
                      onPressed: _assign == null ? null : _assignFlyer),
                ],
              ],
              if (_tab == 0) ...[
                const SizedBox(height: 16),
                SectionTitle(
                    title: 'বুকিং',
                    subtitle: '${detail.bookings.length}টি শিপমেন্ট'),
                if (detail.bookings.isEmpty)
                  const EmptyNote(
                      title: 'বুকিং নেই',
                      body: 'শিপমেন্ট ইনটেক থেকে এই ফ্লাইট বেছে নিন।'),
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
      subtitle:
          '${row.supplierName ?? row.supplierCode} · ${formatKg(row.effectiveKg)} · বাকি ${formatBdt(row.dueAmount)}',
      badge: banglaStatus(row.status, row.statusLabel),
      onTap: onOpen,
    );
  }
}
