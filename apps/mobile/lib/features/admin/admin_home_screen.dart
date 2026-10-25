import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../app_scope.dart';
import '../../data/models/hub_flight.dart';
import '../../data/models/session_user.dart';
import '../tasks/tasks_screen.dart';
import '../../data/models/flight.dart';
import '../../data/models/shipment.dart';
import '../../data/models/workspace.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../finance/finance_screen.dart';
import '../flights/flights_screen.dart';
import '../flights/flight_detail_screen.dart';
import '../intake/intake_screen.dart';
import '../shipments/shipments_screen.dart';
import 'admin_shipment_screen.dart';
import 'money_format.dart';
import 'payment_review_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen(
      {super.key,
      required this.dashboard,
      this.onOpenShipments,
      this.onOpenFinance});

  final DashboardRepository dashboard;

  /// Switch the shell to its tab; without them the screen is pushed.
  final VoidCallback? onOpenShipments;
  final VoidCallback? onOpenFinance;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  AdminOverview? _data;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.dashboard.overview();
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
    return WorkspaceScaffold(
        root: true,
        title: 'ওভারভিউ',
        subtitle: today == null
            ? 'SBExpress'
            : '${today.weekday}বার · ${today.day} ${today.month}',
        onRefresh: _load,
        actions: [
          FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primarySoft,
                  foregroundColor: AppColors.primaryInk,
                  minimumSize: const Size(48, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: const StadiumBorder()),
              onPressed: () => _push(const IntakeScreen()),
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('শিপমেন্ট')),
        ],
        children: [
          if (_loading && data == null) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (data != null) ...[
            const SectionTitle(title: 'আপনার করণীয়'),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: _TodoTile(
                      icon: Icons.receipt_long_outlined,
                      value: '${data.reviewCount}',
                      label: 'রসিদ যাচাই',
                      hot: data.reviewCount > 0,
                      onTap: _openReview)),
              const SizedBox(width: 10),
              Expanded(
                  child: _TodoTile(
                      icon: Icons.checklist_rounded,
                      value: '${data.openTodoCount}',
                      label: 'খোলা কাজ',
                      onTap: () => _push(TasksScreen(
                          role: UserRole.admin,
                          tasks: AppScope.of(context).tasks)))),
              const SizedBox(width: 10),
              Expanded(
                  child: _TodoTile(
                      icon: Icons.inventory_2_outlined,
                      value: '${data.activeShipmentCount}',
                      label: 'চলমান শিপমেন্ট',
                      onTap: _openShipments)),
            ]),
            const SizedBox(height: 16),
            _MoneyCard(data: data, onOpen: _openFinance),
            const SizedBox(height: 22),
            SectionTitle(
                title: 'পরবর্তী ফ্লাইট',
                action: TextButton(
                    onPressed: () => _push(const FlightsScreen()),
                    child: const Text('সময়সূচি'))),
            _NextFlight(
                flight: data.nextFlight,
                flyers: _flyersFor(data),
                onOpen: () => _push(data.nextFlight == null
                    ? const FlightsScreen()
                    : FlightDetailScreen(code: data.nextFlight!.code))),
            const SizedBox(height: 22),
            SectionTitle(
                title: 'চলমান শিপমেন্ট',
                subtitle: '${data.activeShipmentCount}টি ডেলিভারির অপেক্ষায়',
                action: TextButton(
                    onPressed: _openShipments, child: const Text('সব দেখুন'))),
            if (data.activeShipments.isEmpty)
              const EmptyNote(
                  icon: Icons.inventory_2_outlined,
                  title: 'চলমান শিপমেন্ট নেই',
                  body: 'উপরের শিপমেন্ট বাটন থেকে নতুন বুকিং করুন।')
            else
              SurfaceGroup(children: [
                for (final row in data.activeShipments.take(5))
                  _ShipmentRow(
                      row: row,
                      onTap: () => _push(AdminShipmentScreen(code: row.code))),
              ]),
            if (data.notices.isNotEmpty) ...[
              const SizedBox(height: 22),
              const SectionTitle(title: 'নজর দিন'),
              SurfaceGroup(children: [
                for (final notice in data.notices)
                  Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        IconBadge(
                            switch (notice.tag) {
                              'WEIGHT' => Icons.warning_amber_rounded,
                              'FLIGHT' => Icons.flight_rounded,
                              _ => Icons.event_note_outlined,
                            },
                            tone: noticeTone(notice.tag),
                            round: true),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(notice.text,
                                style: const TextStyle(
                                    fontSize: 14, height: 1.45))),
                      ])),
              ]),
            ],
          ],
        ]);
  }

  List<String> _flyersFor(AdminOverview data) {
    final next = data.nextFlight;
    if (next == null) return const [];
    for (final flight in data.flights) {
      if (flight.code == next.code) return flight.flyers;
    }
    return const [];
  }

  void _openReview() => _push(const PaymentReviewScreen());

  void _openShipments() {
    final open = widget.onOpenShipments;
    if (open != null) return open();
    _push(ShipmentsScreen(
        role: UserRole.admin, shipments: AppScope.of(context).shipments));
  }

  void _openFinance() {
    final open = widget.onOpenFinance;
    if (open != null) return open();
    _push(const FinanceScreen());
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) await _load();
  }
}

class _TodoTile extends StatelessWidget {
  const _TodoTile(
      {required this.icon,
      required this.value,
      required this.label,
      required this.onTap,
      this.hot = false});
  final IconData icon;
  final String value, label;
  final VoidCallback onTap;
  final bool hot;

  @override
  Widget build(BuildContext context) => PaperCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      border: hot
          ? const BorderSide(color: AppColors.accentLine, width: 1.5)
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(icon, tone: hot ? ChipTone.amber : ChipTone.blue, size: 36),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w700, height: 1.1)),
        const SizedBox(height: 4),
        Text(label,
            maxLines: 2,
            style: TextStyle(
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: hot ? AppColors.accentInk : AppColors.inkSoft)),
      ]));
}

class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.data, required this.onOpen});
  final AdminOverview data;
  final VoidCallback onOpen;

  static const _soft = Color(0xB8FFFFFF);

  @override
  Widget build(BuildContext context) {
    Widget figure(String label, String value, {Color color = Colors.white}) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: _soft)),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]);
    return Material(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(heroRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onOpen,
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const Text('এই সপ্তাহের হিসাব',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                              Text(data.weekLabel,
                                  style: const TextStyle(
                                      fontSize: 12, color: _soft)),
                            ])),
                        const Text('বিস্তারিত',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: Colors.white),
                      ]),
                      const SizedBox(height: 14),
                      const Text('নেট ক্যাশ',
                          style: TextStyle(fontSize: 13, color: _soft)),
                      Text(formatBdt(data.net),
                          style: const TextStyle(
                              fontSize: 30,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFeatures: [FontFeature.tabularFigures()])),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Color(0x24FFFFFF)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child:
                                figure('জমা হয়েছে', formatBdt(data.received))),
                        Expanded(
                            child: figure('ব্যয়', formatBdt(data.expenses))),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child:
                                figure('বুকিং প্রফিট', formatBdt(data.profit))),
                        Expanded(
                            child: figure(
                                'কাস্টমারের বকেয়া', formatBdt(data.unpaid),
                                color: data.unpaid > 0
                                    ? const Color(0xFFFFB3B0)
                                    : Colors.white)),
                      ]),
                      const SizedBox(height: 14),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _BalanceChip(
                            label: 'টাকা', value: formatBdt(data.cashBdt)),
                        _BalanceChip(
                            label: 'ইউয়ান',
                            value: '¥${data.cashCny.toStringAsFixed(2)}'),
                      ]),
                    ]))));
  }
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(8)),
      child: Text('$label $value',
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)));
}

class _NextFlight extends StatelessWidget {
  const _NextFlight(
      {required this.flight, required this.flyers, required this.onOpen});
  final NextFlightCard? flight;
  final List<String> flyers;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final next = flight;
    final day = next == null ? null : FlightDay.parse(next.date);
    return PaperCard(
        onTap: onOpen,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const IconBadge(Icons.flight_rounded, size: 44),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      next == null
                          ? 'আসন্ন ফ্লাইট নেই'
                          : [
                              displayFlightCode(next.code),
                              if (day != null) '${day.day} ${day.month}'
                            ].join(' · '),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(
                      next == null
                          ? 'সময়সূচি যোগ করতে ফ্লাইটের তালিকা খুলুন'
                          : flyers.isEmpty
                              ? 'ফ্লায়ার ঠিক হয়নি'
                              : 'ফ্লায়ার ${flyers.join(', ')}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted)),
                ])),
            if (day != null)
              StatusPill(label: day.relativeLabel, tone: ChipTone.blue),
          ]),
          if (next != null) ...[
            const SizedBox(height: 14),
            CapacityBar(booked: next.bookedKg, space: next.spaceKg)
          ],
        ]));
  }
}

class _ShipmentRow extends StatelessWidget {
  const _ShipmentRow({required this.row, required this.onTap});
  final AdminShipment row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const IconBadge(Icons.inventory_2_outlined, tone: ChipTone.neutral),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(row.code,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(
                      '${row.supplierName ?? row.supplierCode} · ${formatKg(row.effectiveKg)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted)),
                ])),
            const SizedBox(width: 8),
            Flexible(
                child: Align(
                    alignment: Alignment.centerRight,
                    child: StatusPill(
                        label: banglaStatus(row.status, row.statusLabel),
                        tone: shipmentStatusTone(row.statusIndex)))),
          ])));
}
