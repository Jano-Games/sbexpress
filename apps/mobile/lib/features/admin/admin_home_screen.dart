import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../data/models/shipment.dart';
import '../../data/models/workspace.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../finance/finance_screen.dart';
import '../flights/flights_screen.dart';
import '../intake/intake_screen.dart';
import 'admin_shipment_screen.dart';
import 'money_format.dart';
import 'payment_review_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key, required this.dashboard});

  final DashboardRepository dashboard;

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
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.teal,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(pageGutter, 18, pageGutter, 28),
            children: [
              const BrandLockup(subtitle: 'অ্যাডমিন'),
              const SizedBox(height: 16),
              if (_loading && data == null) const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
              if (_error != null) ...[
                ErrorNote(message: _error!, onRetry: _load),
                const SizedBox(height: 12),
              ],
              if (data != null) ...[
                _ReviewHero(data: data, onReview: _openReview),
                const SizedBox(height: 12),
                Text('${data.todayLabel} · ${data.weekLabel}', style: const TextStyle(color: AppColors.muted, height: 1.3)),
                Text('¥1 = ${formatBdt(data.rate)}', style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: MetricTile(label: 'ক্যাশ', value: formatBdt(data.cashBdt), hint: 'CNY ${data.cashCny.toStringAsFixed(2)} · ${formatBdt(data.cashWorth)}')),
                    const SizedBox(width: 8),
                    Expanded(child: MetricTile(label: 'বকেয়া বিল', value: formatBdt(data.unpaid), tone: data.unpaid > 0 ? ChipTone.red : ChipTone.green)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: MetricTile(label: 'এই সপ্তাহে আয়', value: formatBdt(data.received), tone: ChipTone.green)),
                    const SizedBox(width: 8),
                    Expanded(child: MetricTile(label: 'সপ্তাহের নেট', value: formatBdt(data.net), hint: 'ব্যয় ${formatBdt(data.expenses)}', tone: data.net < 0 ? ChipTone.red : ChipTone.teal)),
                  ],
                ),
                const SizedBox(height: 16),
                _NextFlight(flight: data.nextFlight, onOpen: () => _push(const FlightsScreen())),
                if (data.notices.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SectionTitle(title: 'নজর দিন'),
                  for (final notice in data.notices) ...[
                    PaperCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          StatusPill(label: notice.tag, tone: noticeTone(notice.tag)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(notice.text, style: const TextStyle(height: 1.35))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                const SizedBox(height: 8),
                SectionTitle(title: 'চলমান শিপমেন্ট', subtitle: '${data.activeShipmentCount}টি এখনো ডেলিভারি হয়নি'),
                if (data.activeShipments.isEmpty)
                  const EmptyNote(title: 'চলমান শিপমেন্ট নেই', body: 'নতুন ইনটেক করলে এখানে দেখা যাবে।')
                else
                  for (final row in data.activeShipments.take(6)) ...[
                    _ActiveRow(row: row, onOpen: () => _push(AdminShipmentScreen(code: row.code))),
                    const SizedBox(height: 8),
                  ],
                const SizedBox(height: 8),
                AppButton(label: 'নতুন শিপমেন্ট', kind: AppButtonKind.current, onPressed: () => _push(const IntakeScreen())),
                const SizedBox(height: 8),
                AppButton(label: 'ফাইন্যান্স স্ন্যাপশট', kind: AppButtonKind.quiet, onPressed: () => _push(const FinanceScreen())),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openReview() => _push(const PaymentReviewScreen());

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class _ReviewHero extends StatelessWidget {
  const _ReviewHero({required this.data, required this.onReview});

  final AdminOverview data;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final waiting = data.reviewCount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(cardRadius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('আজ যাচাই', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('$waiting', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w700, height: 1)),
          const SizedBox(height: 4),
          Text(
            waiting == 0 ? 'রিভিউ বাকি নেই' : 'টি রসিদ যাচাই বাকি',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text('খোলা কাজ ${data.openTodoCount} · বুকড প্রফিট ${formatBdt(data.profit)}', style: TextStyle(color: Colors.white.withValues(alpha: 0.78))),
          const SizedBox(height: 14),
          AppButton(label: 'পেমেন্ট রিভিউ', kind: AppButtonKind.current, onPressed: onReview),
        ],
      ),
    );
  }
}

class _NextFlight extends StatelessWidget {
  const _NextFlight({required this.flight, required this.onOpen});

  final NextFlightCard? flight;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final next = flight;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('পরের ফ্লাইট', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (next == null)
            const Text('আপকামিং ফ্লাইট নেই')
          else ...[
            Text(displayFlightCode(next.code), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.teal)),
            Text(next.date, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 10),
            CapacityBar(booked: next.bookedKg, space: next.spaceKg),
          ],
          const SizedBox(height: 12),
          AppButton(label: 'সব ফ্লাইট', kind: AppButtonKind.quiet, onPressed: onOpen),
        ],
      ),
    );
  }
}

class _ActiveRow extends StatelessWidget {
  const _ActiveRow({required this.row, required this.onOpen});

  final AdminShipment row;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final name = row.supplierName;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(cardRadius),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(cardRadius),
        child: Container(
          constraints: const BoxConstraints(minHeight: minTouchTarget),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(cardRadius), border: Border.all(color: AppColors.line)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(row.code, style: const TextStyle(fontWeight: FontWeight.w700))),
                  StatusPill(label: banglaStatus(row.status, row.statusLabel), tone: shipmentStatusTone(row.statusIndex)),
                ],
              ),
              const SizedBox(height: 4),
              Text(name == null || name.isEmpty ? row.supplierCode : '$name · ${row.supplierCode}', style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 4),
              Text('${row.description} · ${formatKg(row.effectiveKg)} · বাকি ${formatBdt(row.dueAmount)}'),
            ],
          ),
        ),
      ),
    );
  }
}
