import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import 'flight_detail_screen.dart';
import 'flight_form_screen.dart';

class FlightsScreen extends StatefulWidget {
  const FlightsScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final row in _rows)
        if (_filter == 'all' || row.status == _filter) row,
    ];
    return Scaffold(
      appBar: const BackTitle(title: 'ফ্লাইট'),
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 28),
          children: [
            const PageHeader(title: 'ফ্লাইট', subtitle: 'ক্যাপাসিটি, ফ্লায়ার ও বুকিং। টিকিটের টাকা ফ্লাইট খুলে সেটল করুন।'),
            ChoiceChips(
              options: const [
                (value: 'upcoming', label: 'আসছে'),
                (value: 'departed', label: 'উড়েছে'),
                (value: 'completed', label: 'শেষ'),
                (value: 'all', label: 'সব'),
              ],
              selected: _filter,
              onSelected: (value) => setState(() => _filter = value),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'নতুন ফ্লাইট',
              kind: AppButtonKind.current,
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const FlightFormScreen()));
                if (created == true) await _load();
              },
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
            if (_error != null) ErrorNote(message: _error!, onRetry: _load),
            if (!_loading && _error == null && visible.isEmpty)
              const EmptyNote(title: 'এই ফিল্টারে ফ্লাইট নেই', body: 'নতুন ফ্লাইট যোগ করলে এখানে দেখা যাবে।'),
            for (final row in visible) ...[
              _FlightCard(
                row: row,
                onOpen: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FlightDetailScreen(code: row.code)));
                  await _load();
                },
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _FlightCard extends StatelessWidget {
  const _FlightCard({required this.row, required this.onOpen});

  final FlightSummary row;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(cardRadius),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(cardRadius),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(cardRadius), border: Border.all(color: AppColors.line)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(row.displayCode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.teal))),
                  StatusPill(label: row.statusLabel, tone: flightStatusTone(row.status)),
                ],
              ),
              const SizedBox(height: 4),
              Text('${row.date} · ${row.depTime}–${row.arrTime} · ${row.via}', style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 8),
              Text(row.flyers.isEmpty ? 'ফ্লায়ার নেই' : row.flyers.join(', ')),
              const SizedBox(height: 8),
              CapacityBar(booked: row.bookedKg, space: row.spaceKg.toDouble()),
              const SizedBox(height: 4),
              Text('${row.shipmentCount} শিপমেন্ট · মোবাইল ${row.mobiles} · ল্যাপটপ ${row.laptops}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              if (row.scheduleNeedsConfirmation) ...[
                const SizedBox(height: 6),
                const Text('তারিখ পেরিয়ে গেছে, স্ট্যাটাস আপডেট করুন', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
