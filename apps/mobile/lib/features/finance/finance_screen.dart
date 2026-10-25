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
  const FinanceScreen({super.key, this.root = false});
  final bool root;

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  FinanceSnapshot? _data;
  String? _error;
  var _loading = true;
  var _period = 'week';
  var _section = 0;

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

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return WorkspaceScaffold(
        root: widget.root,
        title: 'হিসাব',
        subtitle: 'BDT ও CNY · রিপোর্ট BDT-তে',
        onRefresh: _load,
        toolbar: ScreenTabs(
            labels: const ['অ্যাকাউন্ট', 'রিপোর্ট', 'লেনদেন'],
            index: _section,
            onChanged: (i) => setState(() => _section = i)),
        children: [
          if (_loading && data == null) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (data != null && _section == 0) ...[
            PaperCard(
                radius: heroRadius,
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('মোট অ্যাকাউন্ট ব্যালেন্স · BDT',
                          style:
                              TextStyle(fontSize: 13, color: AppColors.muted)),
                      const SizedBox(height: 2),
                      Text(formatBdt(data.cash.worth),
                          style: const TextStyle(
                              fontSize: 30,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()])),
                      const Divider(height: 26),
                      IntrinsicHeight(
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Expanded(
                                child: AmountLabel(
                                    label: 'টাকা · BDT',
                                    value: formatBdt(data.cash.bdt),
                                    size: 18)),
                            const VerticalDivider(
                                width: 28, color: AppColors.lineSoft),
                            Expanded(
                                child: AmountLabel(
                                    label: 'ইউয়ান · CNY',
                                    value:
                                        '¥${data.cash.cny.toStringAsFixed(2)}',
                                    size: 18)),
                          ])),
                    ])),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: QuickAction(
                      label: 'ট্রান্সফার',
                      icon: Icons.swap_horiz_rounded,
                      onTap: () => _open(const TransferScreen()))),
              Expanded(
                  child: QuickAction(
                      label: 'জমা / খরচ',
                      icon: Icons.add_card_outlined,
                      onTap: () => _open(const OfficeEntryScreen()))),
              Expanded(
                  child: QuickAction(
                      label: 'মিলিয়ে দেখা',
                      icon: Icons.rule_rounded,
                      onTap: () => _open(const ReconciliationScreen()))),
              Expanded(
                  child: QuickAction(
                      label: 'লেজার',
                      icon: Icons.receipt_long_outlined,
                      onTap: () => _open(const LedgerScreen()))),
            ]),
            const SizedBox(height: 22),
            SectionTitle(
                title: 'আপনার অ্যাকাউন্ট',
                action: TextButton.icon(
                    onPressed: () => _open(const FundAccountScreen()),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('নতুন'))),
            if (data.accounts.isEmpty)
              const EmptyNote(
                  icon: Icons.account_balance_outlined,
                  title: 'অ্যাকাউন্ট নেই',
                  body: 'ব্যাংক, ক্যাশ বা ওয়ালেট অ্যাকাউন্ট যোগ করুন।')
            else
              SurfaceGroup(children: [
                for (final account in data.accounts)
                  Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        IconBadge(Icons.account_balance_outlined,
                            tone: account.currency == 'CNY'
                                ? ChipTone.amber
                                : ChipTone.blue),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(account.name,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              Text('${account.kind} · ${account.currency}',
                                  style: const TextStyle(
                                      fontSize: 13, color: AppColors.muted))
                            ])),
                        const SizedBox(width: 8),
                        Flexible(
                            child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                    account.currency == 'CNY'
                                        ? '¥${account.balance.toStringAsFixed(2)}'
                                        : formatBdt(account.balance),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: [
                                          FontFeature.tabularFigures()
                                        ])))),
                      ]))
              ]),
            const SizedBox(height: 16),
            _CashFlowCard(
                title: _period == 'week' ? 'এই সপ্তাহ' : 'সর্বমোট',
                received: data.received,
                expenses: data.expenses,
                net: data.net),
          ],
          if (data != null && _section == 1) ...[
            ChoiceChips(
                options: const [
                  (value: 'week', label: 'এই সপ্তাহ'),
                  (value: 'all', label: 'সর্বমোট')
                ],
                selected: _period,
                onSelected: (value) {
                  setState(() => _period = value);
                  _load();
                }),
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            FormSection(title: 'ক্যাশ ফ্লো', children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: AmountLabel(
                        label: 'জমা', value: formatBdt(data.received))),
                const SizedBox(width: 16),
                Expanded(
                    child: AmountLabel(
                        label: 'ব্যয়', value: formatBdt(data.expenses)))
              ]),
              const Divider(height: 28),
              KvRow(label: 'নেট ক্যাশ', value: formatBdt(data.net)),
              KvRow(
                  label: 'এক্সচেঞ্জ রেট',
                  value: '1 CNY = ${formatBdt(data.rate)}'),
            ]),
            FormSection(title: 'পাওনা ও পরিশোধযোগ্য', children: [
              KvRow(
                  label: 'কাস্টমারের কাছে পাওনা',
                  value: formatBdt(data.receivables.total)),
              KvRow(
                  label: 'ফ্লায়ারের কাছে পাওনা',
                  value: formatBdt(data.flyerReceivables)),
              const Divider(height: 20),
              KvRow(
                  label: 'টিকিট বাবদ দিতে হবে',
                  value: formatBdt(data.ticketPayables)),
              KvRow(
                  label: 'অন্যান্য খরচ বাকি',
                  value: formatBdt(data.costPayables)),
            ]),
            FormSection(
                title: 'বুকিংয়ের ফলাফল',
                caption: 'নির্বাচিত সময়ের বিল ও খরচ',
                children: [
                  KvRow(
                      label: 'শিপমেন্ট',
                      value: '${data.results.shipmentCount}'),
                  KvRow(label: 'বিল', value: formatBdt(data.results.billing)),
                  KvRow(label: 'খরচ', value: formatBdt(data.results.costs)),
                  const Divider(height: 20),
                  KvRow(
                      label: 'বুকিং প্রফিট',
                      value: formatBdt(data.results.profit),
                      valueColor: data.results.profit < 0
                          ? AppColors.danger
                          : AppColors.ok),
                  KvRow(
                      label: 'মার্জিন',
                      value: data.results.marginPct == null
                          ? '—'
                          : '${data.results.marginPct!.toStringAsFixed(0)}%'),
                ]),
            const Text(
                'শুরুর ব্যালেন্স ও মূলধন ক্যাশ জমায় থাকে; প্রফিটে যোগ হয় না।',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
          if (_section == 2) ...[
            const SectionTitle(title: 'নতুন লেনদেন'),
            SurfaceGroup(children: [
              MenuRow(
                  title: 'অ্যাকাউন্ট ট্রান্সফার',
                  subtitle: 'নিজস্ব অ্যাকাউন্টের মধ্যে টাকা সরান',
                  icon: Icons.swap_horiz_rounded,
                  onTap: () => _open(const TransferScreen())),
              MenuRow(
                  title: 'জমা বা খরচ',
                  subtitle: 'অফিসের আয়, ব্যয় ও মূলধন',
                  icon: Icons.add_card_outlined,
                  onTap: () => _open(const OfficeEntryScreen())),
            ]),
            const SizedBox(height: 24),
            const SectionTitle(title: 'যাচাই ও ইতিহাস'),
            SurfaceGroup(children: [
              MenuRow(
                  title: 'পেমেন্ট যাচাই',
                  subtitle: 'কাস্টমারের পাঠানো রসিদ দেখুন',
                  icon: Icons.fact_check_outlined,
                  onTap: () => _open(const PaymentReviewScreen())),
              MenuRow(
                  title: 'লেনদেনের লেজার',
                  subtitle: 'জমা, খরচ ও ট্রান্সফারের ইতিহাস',
                  icon: Icons.receipt_long_outlined,
                  onTap: () => _open(const LedgerScreen())),
            ]),
          ],
        ]);
  }
}

/// Money in against money out for the selected period.
class _CashFlowCard extends StatelessWidget {
  const _CashFlowCard(
      {required this.title,
      required this.received,
      required this.expenses,
      required this.net});
  final String title;
  final double received, expenses, net;

  @override
  Widget build(BuildContext context) {
    final total = received + expenses;
    final share = total <= 0 ? 0.5 : (received / total).clamp(0.04, 0.96);
    Widget line(Color color, String label, double value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 14, color: AppColors.inkSoft))),
          Text(formatBdt(value),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]));
    return PaperCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      Semantics(
          label: 'জমা ${formatBdt(received)}, ব্যয় ${formatBdt(expenses)}',
          excludeSemantics: true,
          child: SizedBox(
              height: 10,
              child: Row(children: [
                Expanded(
                    flex: (share * 1000).round(),
                    child: Container(
                        decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(5)))),
                const SizedBox(width: 3),
                Expanded(
                    flex: ((1 - share) * 1000).round(),
                    child: Container(
                        decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(5)))),
              ]))),
      const SizedBox(height: 10),
      line(AppColors.primary, 'জমা হয়েছে', received),
      line(AppColors.accent, 'ব্যয়', expenses),
      const Divider(height: 18),
      Row(children: [
        const Expanded(
            child: Text('নেট ক্যাশ',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
        Text(formatBdt(net),
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: net < 0 ? AppColors.danger : AppColors.ink,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    ]));
  }
}
