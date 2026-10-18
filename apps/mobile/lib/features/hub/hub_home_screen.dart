import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/hub/hub_chain.dart';
import '../../data/models/dashboard.dart';
import '../../data/models/shipment.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../shipments/shipment_process_screen.dart';

class HubHomeScreen extends StatefulWidget {
  const HubHomeScreen({super.key, required this.dashboard});

  final DashboardRepository dashboard;

  @override
  State<HubHomeScreen> createState() => _HubHomeScreenState();
}

class _HubHomeScreenState extends State<HubHomeScreen> {
  HubDashboard? _data;
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
      final data = await widget.dashboard.hub();
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (error) {
      if (!mounted) return;
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
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              if (_loading && data == null) ...[
                const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
                const SizedBox(height: 16),
              ],
              if (_error != null) ...[
                ErrorNote(message: _error!, onRetry: _load),
                const SizedBox(height: 12),
              ],
              if (data != null) ...[
                _TodayHero(data: data),
                const SizedBox(height: 12),
                _Incoming(incoming: data.incoming, atHub: data.atHubCount, tasks: data.openTodoCount),
                const SizedBox(height: 18),
                const SectionTitle(title: 'আজকের শিপমেন্ট', subtitle: 'কার্ড খুললে ওই শিপমেন্টের বর্তমান ধাপ।'),
                if (data.notices.isNotEmpty) ...[
                  for (final notice in data.notices) ...[
                    PaperCard(child: Text(notice.text, style: const TextStyle(height: 1.4))),
                    const SizedBox(height: 8),
                  ],
                ],
                if (data.toProcess.isEmpty)
                  const EmptyNote(title: 'হাবে অপেক্ষমাণ শিপমেন্ট নেই', body: 'ঢাকা হাবে এলে এখানে দেখা যাবে।')
                else
                  for (final row in data.toProcess) ...[
                    _ProcessCard(row: row, onOpen: () => _open(row.code)),
                    const SizedBox(height: 8),
                  ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _open(String code) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShipmentProcessScreen(code: code)));
  }
}

class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.data});

  final HubDashboard data;

  @override
  Widget build(BuildContext context) {
    final counts = HubWorkCounts.fromShipments(data.toProcess);
    final earliest = counts.earliest;
    final caption = counts.remaining == 0 ? 'আজ হাবে বাকি ধাপ নেই' : 'টি কাজ আজ বাকি';
    return Container(
      key: const Key('hub-today-hero'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.todayLabel, style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          const Text(
            'আজকের বাকি কাজ',
            key: Key('hub-today-title'),
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700, height: 1.15),
          ),
          const SizedBox(height: 16),
          Text(
            '${counts.remaining}',
            key: const Key('hub-today-remaining'),
            style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w700, height: 1),
          ),
          const SizedBox(height: 4),
          Text(caption, style: TextStyle(color: Colors.white.withValues(alpha: 0.86), fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HeroStat(
                  statKey: const Key('hub-count-weigh'),
                  label: hubListStepLabel(HubListStep.weigh),
                  value: '${counts.weigh}',
                  current: earliest == HubListStep.weigh,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroStat(
                  statKey: const Key('hub-count-pack'),
                  label: hubListStepLabel(HubListStep.pack),
                  value: '${counts.pack}',
                  current: earliest == HubListStep.pack,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeroStat(
                  statKey: const Key('hub-count-delivery'),
                  label: hubListStepLabel(HubListStep.deliveryChain),
                  value: '${counts.deliveryChain}',
                  current: earliest == HubListStep.deliveryChain,
                ),
              ),
            ],
          ),
          if (earliest != null) ...[
            const SizedBox(height: 14),
            Text(
              'এখন করুন: ${hubListStepLabel(earliest)}',
              key: const Key('hub-today-now'),
              style: const TextStyle(color: AppColors.amber, fontSize: 16, fontWeight: FontWeight.w700, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.statKey, required this.label, required this.value, required this.current});

  final Key statKey;
  final String label;
  final String value;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final foreground = current ? AppColors.amberInk : Colors.white;
    return Container(
      key: statKey,
      constraints: const BoxConstraints(minHeight: minTouchTarget),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: current ? AppColors.amber : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: foreground, fontSize: 22, fontWeight: FontWeight.w700, height: 1)),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: foreground, fontSize: 12, height: 1.25, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Incoming extends StatelessWidget {
  const _Incoming({required this.incoming, required this.atHub, required this.tasks});

  final HubIncoming incoming;
  final int atHub;
  final int tasks;

  @override
  Widget build(BuildContext context) {
    final flight = incoming.flightCode == null ? 'পরের ফ্লাইট নেই' : '${incoming.flightCode} · ${incoming.flightDate ?? ''}';
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('হাবে $atHub · খোলা কাজ $tasks', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('আসছে ${formatKg(incoming.kg)} · ${incoming.count} শিপমেন্ট', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(flight, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _ProcessCard extends StatelessWidget {
  const _ProcessCard({required this.row, required this.onOpen});

  final OperationalShipment row;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final delta = formatWeightDelta(row.weightDelta);
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(row.code, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              StatusPill(label: banglaStatus(row.status, row.statusLabel)),
            ],
          ),
          const SizedBox(height: 8),
          Text(row.supplierCode, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 4),
          Text('ওজন ${formatKg(row.effectiveKg)}${row.weighedKg == null ? ' · মাপা হয়নি' : ''}'),
          if (delta != null) Text(delta, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('পরের ধাপ: ${hubListStepLabel(hubListStep(row))}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          AppButton(label: 'ধাপ খুলুন', kind: AppButtonKind.current, onPressed: onOpen),
        ],
      ),
    );
  }
}
