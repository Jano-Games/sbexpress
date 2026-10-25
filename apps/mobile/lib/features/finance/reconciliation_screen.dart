import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/reconciliation.dart';
import '../../l10n/l10n.dart';
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
        title: tr('Reconciliation'),
        root: false,
        onRefresh: _load,
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr(
                      'Account amounts are in their own currency; shipment differences are in BDT. Older balances not in the ledger are shown separately as opening balance.'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          if (_loading && report == null)
            const LinearProgressIndicator(
                color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (report != null) ...[
            PaperCard(
              child: Text(
                '${trn(report.missingPostings.length, '{n} line has no account snapshot.', '{n} lines have no account snapshot.')} ${trn(report.shipmentDifferences.length, '{n} shipment has mismatched payments.', '{n} shipments have mismatched payments.')}\n${report.note}',
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
            SectionTitle(
                title: tr('Accounts'),
                subtitle: tr(
                    'Current balance, ledger movement, and the part not in the ledger.')),
            if (report.accounts.isEmpty)
              EmptyNote(
                  title: tr('No accounts'),
                  body: tr('Open a fund to see its reconciliation here.'))
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
                          label: tr('Current'),
                          value:
                              formatMoney(account.balance, account.currency)),
                      KvRow(
                          label: tr('Ledger'),
                          value: formatMoney(
                              account.recordedNetMovement, account.currency)),
                      KvRow(
                          label: tr('Opening (implied)'),
                          value: formatMoney(
                              account.impliedOpeningBalance, account.currency)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 8),
            SectionTitle(
                title: tr('Shipment differences'),
                subtitle: tr('All amounts in BDT.')),
            if (report.shipmentDifferences.isEmpty)
              EmptyNote(
                  title: tr('No differences'),
                  body: tr('Issued payments match the ledger.'))
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
                          label: tr('Allocated'),
                          value: formatBdt(row.allocatedPaid)),
                      KvRow(
                          label: tr('Ledger'),
                          value: formatBdt(row.ledgerPaid)),
                      KvRow(
                          label: tr('Difference'),
                          value: formatBdt(row.difference),
                          valueColor: AppColors.danger),
                      const SizedBox(height: 8),
                      AppButton(
                        label: tr('Open shipment'),
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
              SectionTitle(
                  title: tr('Missing snapshots'),
                  subtitle: tr(
                      'These are not rebuilt. Check them against bank or cash records.')),
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
