import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../admin/money_format.dart';
import '../admin/payment_review_screen.dart';
import 'fund_account_screen.dart';
import 'ledger_screen.dart';
import 'office_entry_screen.dart';
import 'reconciliation_screen.dart';
import 'transfer_screen.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  FinanceSnapshot? _data;
  String? _error;
  var _loading = true;
  var _period = 'week';

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
      final data = await AppScope.of(context).finance.snapshot(period: _period);
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
      appBar: const BackTitle(title: 'ফাইন্যান্স'),
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 32),
          children: [
            const PageHeader(title: 'ফাইন্যান্স', subtitle: 'ক্যাশ, বকেয়া ও বুকড ফল। টাকা সরানোর আগে নিশ্চিত করতে হয়।'),
            ChoiceChips(
              options: const [
                (value: 'week', label: 'সপ্তাহ'),
                (value: 'all', label: 'সব'),
              ],
              selected: _period,
              onSelected: (value) {
                setState(() => _period = value);
                _load();
              },
            ),
            const SizedBox(height: 12),
            if (_loading && data == null) const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
            if (_error != null) ErrorNote(message: _error!, onRetry: _load),
            if (data != null) ...[
              Text(data.periodLabel, style: const TextStyle(color: AppColors.muted)),
              Text('¥1 = ${formatBdt(data.rate)}', style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: MetricTile(label: 'ক্যাশ BDT', value: formatBdt(data.cash.bdt), hint: 'CNY ${data.cash.cny.toStringAsFixed(2)}')),
                  const SizedBox(width: 8),
                  Expanded(child: MetricTile(label: 'মোট মূল্য', value: formatBdt(data.cash.worth), tone: ChipTone.blue)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: MetricTile(label: 'জমা', value: formatBdt(data.received), tone: ChipTone.green)),
                  const SizedBox(width: 8),
                  Expanded(child: MetricTile(label: 'ব্যয়', value: formatBdt(data.expenses), tone: ChipTone.amber)),
                ],
              ),
              const SizedBox(height: 8),
              MetricTile(label: 'নেট ক্যাশ', value: formatBdt(data.net), tone: data.net < 0 ? ChipTone.red : ChipTone.teal),
              const SizedBox(height: 8),
              const Text(
                'জমাতে কাস্টমার রসিদ, আয় ও মূলধন আছে। নতুন ফান্ডের শুরুর ব্যালেন্স মূলধন, প্রফিট নয়।',
                style: TextStyle(color: AppColors.muted, height: 1.35),
              ),
              const SizedBox(height: 16),
              const SectionTitle(title: 'বুকড ফল', subtitle: 'ক্যাশ ফ্লো আলাদা। এটা পিরিয়ডের বিল বনাম খরচ।'),
              PaperCard(
                child: Column(
                  children: [
                    KvRow(label: 'শিপমেন্ট', value: '${data.results.shipmentCount}'),
                    KvRow(label: 'বিল', value: formatBdt(data.results.billing)),
                    KvRow(label: 'খরচ', value: formatBdt(data.results.costs)),
                    KvRow(label: 'প্রফিট', value: formatBdt(data.results.profit), valueColor: data.results.profit < 0 ? AppColors.danger : AppColors.ok),
                    KvRow(label: 'মার্জিন', value: data.results.marginPct == null ? '—' : '${data.results.marginPct!.toStringAsFixed(0)}%'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SectionTitle(title: 'বকেয়া'),
              PaperCard(
                child: Column(
                  children: [
                    KvRow(label: 'কাস্টমার', value: '${formatBdt(data.receivables.total)} · ${data.receivables.count}'),
                    KvRow(label: 'ফ্লায়ার', value: formatBdt(data.flyerReceivables)),
                    KvRow(label: 'টিকিট', value: formatBdt(data.ticketPayables)),
                    KvRow(label: 'খরচ', value: formatBdt(data.costPayables)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SectionTitle(title: 'অ্যাকাউন্ট', subtitle: 'নাম ও ব্যালেন্স লেজারের। ব্যাংক ও বিকাশ সেটিংস থেকে যোগ হয়।'),
              if (data.accounts.isEmpty)
                const EmptyNote(title: 'অ্যাকাউন্ট নেই', body: 'রিসিভিং অ্যাকাউন্ট সেটআপ না হলে পেমেন্ট পোস্ট হবে না।')
              else
                for (final account in data.accounts) ...[
                  PaperCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(account.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${account.kind} · ${account.currency}', style: const TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 4),
                        Text(account.currency == 'CNY' ? '¥${account.balance.toStringAsFixed(2)}' : formatBdt(account.balance), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              AppButton(
                label: 'ট্রান্সফার',
                kind: AppButtonKind.current,
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TransferScreen()));
                  if (mounted) await _load();
                },
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'জমা বা খরচ',
                kind: AppButtonKind.teal,
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const OfficeEntryScreen()));
                  if (mounted) await _load();
                },
              ),
              const SizedBox(height: 8),
              AppButton(label: 'লেজার', kind: AppButtonKind.quiet, onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LedgerScreen()))),
              const SizedBox(height: 8),
              AppButton(label: 'মিলিয়ে দেখা', kind: AppButtonKind.quiet, onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ReconciliationScreen()))),
              const SizedBox(height: 8),
              AppButton(
                label: 'নতুন ফান্ড',
                kind: AppButtonKind.quiet,
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FundAccountScreen()));
                  if (mounted) await _load();
                },
              ),
              const SizedBox(height: 8),
              AppButton(label: 'পেমেন্ট রিভিউ', kind: AppButtonKind.teal, onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PaymentReviewScreen()))),
            ],
          ],
        ),
      ),
    );
  }
}
