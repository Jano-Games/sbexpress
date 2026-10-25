import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/reconciliation.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../admin/admin_shipment_screen.dart';
import '../admin/money_format.dart';

class ReconciliationScreen extends StatefulWidget {
  const ReconciliationScreen({super.key});

  @override
  State<ReconciliationScreen> createState() => _ReconciliationScreenState();
}

class _ReconciliationScreenState extends State<ReconciliationScreen> {
  ReconciliationReport? _report;
  String? _error;
  var _loading = true;

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
      final report = await AppScope.of(context).finance.reconciliation();
      if (!mounted) return;
      setState(() => _report = report);
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
    final report = _report;
    return WorkspaceScaffold(
        title: 'মিলিয়ে দেখা',
        root: false,
        onRefresh: _load,
        children: [
          const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                  'অ্যাকাউন্টের টাকা তার মুদ্রায়। শিপমেন্টের পার্থক্য BDT। পুরনো ব্যালেন্স যা লেজারে নেই, সেটা শুরুর ব্যালেন্স হিসেবে আলাদা।',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          if (_loading && report == null)
            const LinearProgressIndicator(
                color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (report != null) ...[
            PaperCard(
              child: Text(
                '${report.missingPostings.length} লাইনে অ্যাকাউন্ট স্ন্যাপশট নেই। ${report.shipmentDifferences.length} শিপমেন্টে পেমেন্ট মিলছে না।\n${report.note}',
                style: TextStyle(
                  height: 1.4,
                  color: report.missingPostings.isNotEmpty ||
                          report.shipmentDifferences.isNotEmpty
                      ? AppColors.danger
                      : AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SectionTitle(
                title: 'অ্যাকাউন্ট',
                subtitle:
                    'বর্তমান ব্যালেন্স, লেজারে নড়া, এবং যে অংশ লেজারে নেই।'),
            if (report.accounts.isEmpty)
              const EmptyNote(
                  title: 'অ্যাকাউন্ট নেই',
                  body: 'ফান্ড খুললে এখানে মিল দেখা যাবে।')
            else
              for (final account in report.accounts) ...[
                PaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(account.currency,
                          style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 8),
                      KvRow(
                          label: 'বর্তমান',
                          value:
                              formatMoney(account.balance, account.currency)),
                      KvRow(
                          label: 'লেজার',
                          value: formatMoney(
                              account.recordedNetMovement, account.currency)),
                      KvRow(
                          label: 'শুরু (অনুমান)',
                          value: formatMoney(
                              account.impliedOpeningBalance, account.currency)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 8),
            const SectionTitle(
                title: 'শিপমেন্ট পার্থক্য', subtitle: 'সব অংক BDT।'),
            if (report.shipmentDifferences.isEmpty)
              const EmptyNote(
                  title: 'পার্থক্য নেই',
                  body: 'ইস্যু করা পেমেন্ট আর লেজার একই।')
            else
              for (final row in report.shipmentDifferences) ...[
                PaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.code,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      KvRow(
                          label: 'বরাদ্দ', value: formatBdt(row.allocatedPaid)),
                      KvRow(label: 'লেজার', value: formatBdt(row.ledgerPaid)),
                      KvRow(
                          label: 'পার্থক্য',
                          value: formatBdt(row.difference),
                          valueColor: AppColors.danger),
                      const SizedBox(height: 8),
                      AppButton(
                        label: 'শিপমেন্ট খুলুন',
                        kind: AppButtonKind.quiet,
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) =>
                                    AdminShipmentScreen(code: row.code))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            if (report.missingPostings.isNotEmpty) ...[
              const SizedBox(height: 8),
              const SectionTitle(
                  title: 'স্ন্যাপশট নেই',
                  subtitle:
                      'এগুলো আবার বানানো হয় না। ব্যাংক বা ক্যাশ রেকর্ডের সাথে মিলিয়ে নিন।'),
              for (final row in report.missingPostings) ...[
                PaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.kind,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(row.reference,
                          style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 6),
                      Text(formatBdt(row.amount),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ]);
  }
}
