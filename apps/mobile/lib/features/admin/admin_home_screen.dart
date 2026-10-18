import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../data/models/dashboard.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import 'payment_review_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key, required this.dashboard});

  final DashboardRepository dashboard;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  DashboardCounts? _counts;
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
      final counts = await widget.dashboard.counts();
      if (!mounted) return;
      setState(() => _counts = counts);
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
    final counts = _counts;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.teal,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              const Text('হোম', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('পেমেন্ট যাচাই ও শিপমেন্ট। ফাইন্যান্স স্ন্যাপশট এই স্লাইসে নেই।', style: TextStyle(color: AppColors.muted, height: 1.35)),
              const SizedBox(height: 16),
              if (_loading && counts == null) const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
              if (_error != null) ErrorNote(message: _error!, onRetry: _load),
              if (counts != null) ...[
                PaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('রিভিউ বাকি ${counts.reviewCount}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('খোলা কাজ ${counts.openTodoCount}', style: const TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'পেমেন্ট রিভিউ',
                  kind: AppButtonKind.current,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaymentReviewScreen())),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
