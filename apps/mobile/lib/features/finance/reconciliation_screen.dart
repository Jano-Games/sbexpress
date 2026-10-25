import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/reconciliation.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/finance_parts.dart';
import '../../widgets/ui.dart';
import '../admin/admin_shipment_screen.dart';
import '../admin/money_format.dart';

class ReconciliationScreen extends StatefulWidget {
  const ReconciliationScreen({super.key});

  @override
  State<ReconciliationScreen> createState() => _ReconciliationScreenState();
}

class _ReconciliationScreenState extends State<ReconciliationScreen> {
  final _differencesKey = GlobalKey();
  final _missingKey = GlobalKey();
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

  void _jump(GlobalKey key) {
    final target = key.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target,
          duration: const Duration(milliseconds: 300), alignment: 0.05);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final issues = report == null
        ? 0
        : report.missingPostings.length + report.shipmentDifferences.length;
    return WorkspaceScaffold(
        title: tr('Reconciliation'),
        subtitle: tr('Balances checked against the ledger'),
        root: false,
        onRefresh: _load,
        actions: [
          if (report != null)
            Center(
                child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: StatusPill(
                        label: issues == 0
                            ? tr('All clear')
                            : tr('{n} to check', {'n': issues}),
                        tone: issues == 0 ? ChipTone.green : ChipTone.red))),
        ],
        children: [
          if (_loading && report == null) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (report != null) ...[
            _IssuesCard(
                report: report,
                onDifferences: () => _jump(_differencesKey),
                onMissing: () => _jump(_missingKey)),
            const SizedBox(height: 20),
            SectionTitle(
                title: tr('Accounts'),
                subtitle: tr(
                    "Opening balance + ledger movement = current, in each account's own currency")),
            if (report.accounts.isEmpty)
              EmptyNote(
                  icon: Icons.account_balance_outlined,
                  title: tr('No accounts'),
                  body: tr('Open a fund to see its reconciliation here.'))
            else
              for (final account in report.accounts) ...[
                _AccountCard(account: account),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 10),
            SectionTitle(
                key: _differencesKey,
                title: tr('Shipment differences'),
                action: Text(tr('All in BDT'),
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.muted))),
            if (report.shipmentDifferences.isEmpty)
              EmptyNote(
                  icon: Icons.task_alt_rounded,
                  title: tr('No differences'),
                  body: tr('Issued payments match the ledger.'))
            else
              ListCard(children: [
                for (final row in report.shipmentDifferences)
                  _DifferenceRow(
                      row: row,
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  AdminShipmentScreen(code: row.code)))),
              ]),
            if (report.missingPostings.isNotEmpty) ...[
              const SizedBox(height: 20),
              SectionTitle(
                  key: _missingKey,
                  title: tr('Missing snapshots'),
                  subtitle: tr(
                      'These are not rebuilt. Check them against bank or cash records.')),
              for (final row in report.missingPostings) ...[
                _MissingRow(row: row),
                const SizedBox(height: 10),
              ],
            ],
            const SizedBox(height: 10),
            HintNote(
                text: tr(
                    'Opening balances are worked out as current balance minus recorded movement. An older balance is normal for accounts that existed before the ledger.')),
          ],
        ]);
  }
}

class _IssuesCard extends StatelessWidget {
  const _IssuesCard(
      {required this.report,
      required this.onDifferences,
      required this.onMissing});
  final ReconciliationReport report;
  final VoidCallback onDifferences, onMissing;

  @override
  Widget build(BuildContext context) {
    final differences = report.shipmentDifferences.length;
    final missing = report.missingPostings.length;
    final total = differences + missing;
    if (total == 0) {
      return PaperCard(
          border: const BorderSide(color: Color(0xFFB9DCC8), width: 1.5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const IconBadge(Icons.task_alt_rounded, tone: ChipTone.green),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(tr('Everything adds up'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(tr('Every shipment payment matches the ledger and every line has an account.'),
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: AppColors.inkSoft)),
                ])),
          ]));
    }
    Widget issue(int count, String label, ChipTone tone, VoidCallback onTap) {
      final colors = toneColors(tone);
      return InkWell(
          onTap: onTap,
          child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Container(
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                            color: colors.background,
                            borderRadius: BorderRadius.circular(999)),
                        child: Text('$count',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colors.foreground))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(label,
                            style: const TextStyle(
                                fontSize: 15,
                                height: 1.35,
                                fontWeight: FontWeight.w600))),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.faint),
                  ]))));
    }

    return PaperCard(
        padding: EdgeInsets.zero,
        border: const BorderSide(color: AppColors.dangerLine, width: 1.5),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
              color: AppColors.dangerSoft,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.warning_amber_rounded,
                        size: 21, color: AppColors.danger)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          trn(total, "{n} thing doesn't add up",
                              "{n} things don't add up"),
                          style: const TextStyle(
                              fontSize: 16,
                              height: 1.35,
                              fontWeight: FontWeight.w700)),
                      Text(tr('Nothing is fixed automatically. Check them against bank or cash records.'),
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: AppColors.inkSoft)),
                    ])),
              ])),
          if (differences > 0) ...[
            const Divider(height: 1, color: Color(0xFFF3D6D8)),
            issue(
                differences,
                trn(differences, 'Shipment with mismatched payments',
                    'Shipments with mismatched payments'),
                ChipTone.red,
                onDifferences),
          ],
          if (missing > 0) ...[
            const Divider(height: 1, color: AppColors.lineSoft),
            issue(
                missing,
                trn(missing, 'Line with no account snapshot',
                    'Lines with no account snapshot'),
                ChipTone.amber,
                onMissing),
          ],
        ]));
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account});
  final ReconciliationAccount account;

  @override
  Widget build(BuildContext context) {
    final opening = account.impliedOpeningBalance;
    final ledger = account.recordedNetMovement;
    final hasOpening = opening.abs() >= 0.005;
    final openingFlex = (opening.abs() * 100).round();
    final ledgerFlex = (ledger.abs() * 100).round();
    String money(double value) => formatMoney(value, account.currency);
    Widget part(String label, String value,
            {Color? dot, Color? valueColor, bool end = false}) =>
        Column(
            crossAxisAlignment:
                end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (dot == null)
                WordFitText(label,
                    textAlign: end ? TextAlign.end : null,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted))
              else
                LegendDot(color: dot, label: label, round: false, small: true),
              FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: end
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: Text(value,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: end ? 17 : 15,
                          fontWeight: end ? FontWeight.w700 : FontWeight.w600,
                          color: valueColor ?? AppColors.ink,
                          fontFeatures: const [FontFeature.tabularFigures()]))),
            ]);
    const sign = TextStyle(fontSize: 15, color: AppColors.muted);
    return PaperCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SplitRow(
              maxFraction: 0.55,
              start: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: account.name),
                    TextSpan(
                        text: '  ${account.currency}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted)),
                  ]),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              end: StatusPill(
                  label: hasOpening
                      ? tr('Has opening balance')
                      : tr('All in ledger'),
                  tone: hasOpening ? ChipTone.neutral : ChipTone.green)),
          const SizedBox(height: 12),
          Semantics(
              label: tr('{opening} opening and {ledger} from the ledger',
                  {'opening': money(opening), 'ledger': money(ledger)}),
              excludeSemantics: true,
              child: SizedBox(
                  height: 8,
                  child: Row(children: [
                    if (hasOpening && openingFlex > 0) ...[
                      Expanded(
                          flex: openingFlex,
                          child: Container(
                              decoration: BoxDecoration(
                                  color: AppColors.faint,
                                  borderRadius: BorderRadius.circular(4)))),
                      if (ledgerFlex > 0) const SizedBox(width: 2),
                    ],
                    if (ledgerFlex > 0 || !hasOpening)
                      Expanded(
                          flex: ledgerFlex > 0 ? ledgerFlex : 1,
                          child: Container(
                              decoration: BoxDecoration(
                                  color: ledgerFlex > 0
                                      ? AppColors.primary
                                      : AppColors.lineSoft,
                                  borderRadius: BorderRadius.circular(4)))),
                  ]))),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: part(tr('Opening'), money(opening),
                    dot: hasOpening ? AppColors.faint : null,
                    valueColor: hasOpening ? null : AppColors.muted)),
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('+', style: sign)),
            Expanded(
                child: part(tr('Ledger'), money(ledger),
                    dot: hasOpening ? AppColors.primary : null)),
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('=', style: sign)),
            Expanded(
                child: part(tr('Current'), money(account.balance), end: true)),
          ]),
        ]));
  }
}

class _DifferenceRow extends StatelessWidget {
  const _DifferenceRow({required this.row, required this.onTap});
  final ShipmentDifference row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, double value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: AppColors.paper, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          WordFitText(label,
              maxLines: 2,
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(formatBdt(value),
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()]))),
        ]));
    return Semantics(
        button: true,
        label: tr('Open shipment {code}', {'code': row.code}),
        child: InkWell(
            onTap: onTap,
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Text(row.code,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: StatusPill(
                                      label: tr('Difference {amount}', {
                                        'amount':
                                            signedMoney(row.difference, 'BDT')
                                      }),
                                      tone: ChipTone.red))),
                        ]),
                        const SizedBox(height: 8),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: tile(tr('Allocated as paid'),
                                      row.allocatedPaid)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: tile(
                                      tr('In the ledger'), row.ledgerPaid)),
                            ]),
                      ])),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.faint),
                ]))));
  }
}

class _MissingRow extends StatelessWidget {
  const _MissingRow({required this.row});
  final MissingPosting row;

  @override
  Widget build(BuildContext context) {
    final expense = row.kind == 'expense';
    return PaperCard(
        padding: const EdgeInsets.all(13),
        border: const BorderSide(color: AppColors.accentLine, width: 1.5),
        child: Row(children: [
          IconBadge(
              expense ? Icons.north_east_rounded : Icons.south_west_rounded,
              tone: ChipTone.amber),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(expense ? tr('Expense') : tr('Payment'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                Text(
                    [
                      if (row.reference.isNotEmpty) row.reference,
                      tr('no account recorded')
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 13, height: 1.4, color: AppColors.muted)),
              ])),
          const SizedBox(width: 8),
          Text(formatBdt(row.amount),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]));
  }
}
