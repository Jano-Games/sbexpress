import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../l10n/l10n.dart';
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
        title: tr('Finance'),
        subtitle: tr('BDT and CNY · reports in BDT'),
        onRefresh: _load,
        toolbar: ScreenTabs(
            labels: [tr('Accounts'), tr('Reports'), tr('Transactions')],
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
                      Text(tr('Total account balance · BDT'),
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.muted)),
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
                                    label: tr('Taka · BDT'),
                                    value: formatBdt(data.cash.bdt),
                                    size: 18)),
                            const VerticalDivider(
                                width: 28, color: AppColors.lineSoft),
                            Expanded(
                                child: AmountLabel(
                                    label: tr('Yuan · CNY'),
                                    value:
                                        '¥${data.cash.cny.toStringAsFixed(2)}',
                                    size: 18)),
                          ])),
                    ])),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: QuickAction(
                      label: tr('Transfer'),
                      icon: Icons.swap_horiz_rounded,
                      onTap: () => _open(const TransferScreen()))),
              Expanded(
                  child: QuickAction(
                      label: tr('Deposit / expense'),
                      icon: Icons.add_card_outlined,
                      onTap: () => _open(const OfficeEntryScreen()))),
              Expanded(
                  child: QuickAction(
                      label: tr('Reconcile'),
                      icon: Icons.rule_rounded,
                      onTap: () => _open(const ReconciliationScreen()))),
              Expanded(
                  child: QuickAction(
                      label: tr('Ledger'),
                      icon: Icons.receipt_long_outlined,
                      onTap: () => _open(const LedgerScreen()))),
            ]),
            const SizedBox(height: 22),
            SectionTitle(
                title: tr('Your accounts'),
                action: TextButton.icon(
                    onPressed: () => _open(const FundAccountScreen()),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(tr('New')))),
            if (data.accounts.isEmpty)
              EmptyNote(
                  icon: Icons.account_balance_outlined,
                  title: tr('No accounts'),
                  body: tr('Add a bank, cash or wallet account.'))
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
                title: _period == 'week' ? tr('This week') : tr('All time'),
                received: data.received,
                expenses: data.expenses,
                net: data.net),
          ],
          if (data != null && _section == 1) ...[
            ChoiceChips(
                options: [
                  (value: 'week', label: tr('This week')),
                  (value: 'all', label: tr('All time'))
                ],
                selected: _period,
                onSelected: (value) {
                  setState(() => _period = value);
                  _load();
                }),
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            FormSection(title: tr('Cash flow'), children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: AmountLabel(
                        label: tr('Deposits'),
                        value: formatBdt(data.received))),
                const SizedBox(width: 16),
                Expanded(
                    child: AmountLabel(
                        label: tr('Expenses'), value: formatBdt(data.expenses)))
              ]),
              const Divider(height: 28),
              KvRow(label: tr('Net cash'), value: formatBdt(data.net)),
              KvRow(
                  label: tr('Exchange rate'),
                  value: '1 CNY = ${formatBdt(data.rate)}'),
            ]),
            FormSection(title: tr('Receivables and payables'), children: [
              KvRow(
                  label: tr('Customer receivables'),
                  value: formatBdt(data.receivables.total)),
              KvRow(
                  label: tr('Flyer receivables'),
                  value: formatBdt(data.flyerReceivables)),
              const Divider(height: 20),
              KvRow(
                  label: tr('Flight tickets to pay'),
                  value: formatBdt(data.ticketPayables)),
              KvRow(
                  label: tr('Other costs to pay'),
                  value: formatBdt(data.costPayables)),
            ]),
            FormSection(
                title: tr('Booking results'),
                caption: tr('Billing and costs for the selected period'),
                children: [
                  KvRow(
                      label: tr('Shipments'),
                      value: '${data.results.shipmentCount}'),
                  KvRow(
                      label: tr('Billed'),
                      value: formatBdt(data.results.billing)),
                  KvRow(
                      label: tr('Costs'), value: formatBdt(data.results.costs)),
                  const Divider(height: 20),
                  KvRow(
                      label: tr('Booking profit'),
                      value: formatBdt(data.results.profit),
                      valueColor: data.results.profit < 0
                          ? AppColors.danger
                          : AppColors.ok),
                  KvRow(
                      label: tr('Margin'),
                      value: data.results.marginPct == null
                          ? '—'
                          : '${data.results.marginPct!.toStringAsFixed(0)}%'),
                ]),
            Text(
                tr('Opening balances and capital count as cash received, not profit.'),
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
          if (_section == 2) ...[
            SectionTitle(title: tr('New transaction')),
            SurfaceGroup(children: [
              MenuRow(
                  title: tr('Account transfer'),
                  subtitle: tr('Move money between your own accounts'),
                  icon: Icons.swap_horiz_rounded,
                  onTap: () => _open(const TransferScreen())),
              MenuRow(
                  title: tr('Deposit or expense'),
                  subtitle: tr('Office income, expenses and capital'),
                  icon: Icons.add_card_outlined,
                  onTap: () => _open(const OfficeEntryScreen())),
            ]),
            const SizedBox(height: 24),
            SectionTitle(title: tr('Review and history')),
            SurfaceGroup(children: [
              MenuRow(
                  title: tr('Payment review'),
                  subtitle: tr('Check receipts sent by customers'),
                  icon: Icons.fact_check_outlined,
                  onTap: () => _open(const PaymentReviewScreen())),
              MenuRow(
                  title: tr('Transaction ledger'),
                  subtitle: tr('History of deposits, expenses and transfers'),
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
          label: tr('Deposits {received}, expenses {expenses}', {
            'received': formatBdt(received),
            'expenses': formatBdt(expenses)
          }),
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
      line(AppColors.primary, tr('Money received'), received),
      line(AppColors.accent, tr('Expenses'), expenses),
      const Divider(height: 18),
      Row(children: [
        Expanded(
            child: Text(tr('Net cash'),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700))),
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
