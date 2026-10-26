import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flow.dart';
import '../../data/models/shipment.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/finance_parts.dart'
    show InitialAvatar, dayHeading, monthOnly, monthTitle;
import '../../widgets/flight_parts.dart'
    show HeroFigure, HeroFigures, MoneyHero, RowCard, dayMonth, heroSoft;
import '../../widgets/flow_parts.dart';
import '../../widgets/ui.dart';
import '../admin/admin_shipment_screen.dart';
import '../admin/money_format.dart';
import '../admin/payment_review_screen.dart';
import '../customers/statement_screen.dart';
import 'record_payment_sheet.dart';

/// Money customers still owe: after-delivery bills once the parcel is
/// handed over, and one monthly bill per customer.
class GetPaidScreen extends StatefulWidget {
  const GetPaidScreen({super.key, this.initialTab = 0});

  /// 0 after delivery, 1 monthly.
  final int initialTab;

  @override
  State<GetPaidScreen> createState() => _GetPaidScreenState();
}

class _GetPaidScreenState extends State<GetPaidScreen> {
  CollectSheet? _sheet;
  int? _reviewCount;
  String? _error;
  var _outdated = false;
  var _loading = true;
  late var _tab = widget.initialTab;

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
    final dashboard = AppScope.of(context).dashboard;
    try {
      final sheet = await dashboard.collect();
      if (!mounted) return;
      setState(() {
        _sheet = sheet;
        _outdated = false;
      });
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() {
        if (error.status == 404) {
          _outdated = true;
        } else {
          _error = error.message;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    try {
      final counts = await dashboard.counts();
      if (mounted) setState(() => _reviewCount = counts.reviewCount);
    } catch (_) {
      // The receipts row then shows without a count.
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) await _load();
  }

  Future<void> _record(HandedOverBill bill) async {
    final saved = await showRecordPaymentSheet(context, bill: bill);
    if (saved == true && mounted) await _load();
  }

  Future<void> _call(String name, String phone) async {
    if (phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(tr('No phone number saved for {name}.', {'name': name}))));
      return;
    }
    await Clipboard.setData(ClipboardData(text: phone.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(tr(
              '{phone} copied. Paste it in your phone app to call.',
              {'phone': phone.trim()}))));
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _sheet;
    return WorkspaceScaffold(
        title: tr('Get paid'),
        subtitle: tr('Money customers still owe · {day}',
            {'day': dayHeading(DateTime.now())}),
        onRefresh: _load,
        toolbar: _outdated
            ? null
            : ScreenTabs(labels: [
                sheet == null
                    ? tr('After delivery')
                    : tr(
                        'After delivery · {n}', {'n': sheet.handedOver.length}),
                sheet == null
                    ? tr('Monthly')
                    : tr('Monthly · {n}', {'n': sheet.monthlyOwing}),
              ], index: _tab, onChanged: (i) => setState(() => _tab = i)),
        children: [
          if (_loading && sheet == null) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (_outdated)
            EmptyNote(
                icon: Icons.cloud_sync_outlined,
                title: tr('The server needs an update'),
                body: tr(
                    'Get paid needs the newer server. Once the owner updates it, pull down to refresh.'))
          else if (sheet != null) ...[
            if (_tab == 0) ..._afterDelivery(sheet) else ..._monthlyTab(sheet),
            const SizedBox(height: 14),
            LinkCard(
                icon: Icons.receipt_long_outlined,
                tone: ChipTone.amber,
                title: tr('Receipts to review'),
                lines: [tr('Sent by customers from their links')],
                trailing: _reviewCount == null || _reviewCount == 0
                    ? null
                    : FlowChip(label: '$_reviewCount', tone: ChipTone.amber),
                onTap: () => _open(const PaymentReviewScreen())),
          ],
        ]);
  }

  List<Widget> _afterDelivery(CollectSheet sheet) {
    final overdue = [
      for (final row in sheet.handedOver)
        if (row.overdue) row
    ];
    final recent = [
      for (final row in sheet.handedOver)
        if (!row.overdue) row
    ];
    double sum(List<HandedOverBill> rows) =>
        rows.fold(0.0, (total, row) => total + row.amount);
    return [
      MoneyHero(
          label: tr('To collect after delivery'),
          amount: formatBdt(sheet.afterDeliveryDue),
          amountSize: 32,
          children: [
            Text(
                trn(
                    sheet.handedOver.length,
                    '{n} shipment handed over and not paid',
                    '{n} shipments handed over and not paid'),
                style: const TextStyle(
                    fontSize: 13, height: 1.4, color: heroSoft)),
            HeroFigures(size: 16, figures: [
              HeroFigure(tr('Waiting over a week · {n}', {'n': overdue.length}),
                  formatBdt(sum(overdue)),
                  alert: overdue.isNotEmpty),
              HeroFigure(tr('Delivered this week · {n}', {'n': recent.length}),
                  formatBdt(sum(recent))),
            ]),
          ]),
      const SizedBox(height: 18),
      SectionTitle(
          title: tr('Handed over, not paid'),
          action: Text(tr('Oldest first'),
              style: const TextStyle(fontSize: 13, color: AppColors.muted))),
      if (sheet.handedOver.isEmpty)
        EmptyNote(
            icon: Icons.check_circle_outline_rounded,
            title: tr('Nothing to collect'),
            body: tr('No handed-over shipment is waiting for payment.'))
      else
        for (var i = 0; i < sheet.handedOver.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _HandedOverCard(
              bill: sheet.handedOver[i],
              onCall: () => _call(sheet.handedOver[i].supplierName,
                  sheet.handedOver[i].supplierPhone),
              onRecord: () => _record(sheet.handedOver[i]),
              onOpen: () =>
                  _open(AdminShipmentScreen(code: sheet.handedOver[i].code))),
        ],
      if (sheet.comingSoon.isNotEmpty) ...[
        const SizedBox(height: 18),
        _MutedHeading(
            title: tr('Coming soon'), trailing: tr('Due once handed over')),
        for (var i = 0; i < sheet.comingSoon.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _ComingSoonRow(
              bill: sheet.comingSoon[i],
              onOpen: () =>
                  _open(AdminShipmentScreen(code: sheet.comingSoon[i].code))),
        ],
      ],
      const SizedBox(height: 22),
      ..._monthlyList(sheet),
    ];
  }

  List<Widget> _monthlyTab(CollectSheet sheet) {
    final billed = sheet.monthly.fold(0.0, (total, row) => total + row.billed);
    final paid = sheet.monthly.fold(0.0, (total, row) => total + row.paid);
    return [
      MoneyHero(
          label:
              tr('Monthly bills · {month}', {'month': monthTitle(sheet.month)}),
          amount: formatBdt(sheet.monthlyDue),
          amountSize: 32,
          children: [
            Text(
                trn(sheet.monthlyOwing, '{n} customer still owes this month',
                    '{n} customers still owe this month'),
                style: const TextStyle(
                    fontSize: 13, height: 1.4, color: heroSoft)),
            HeroFigures(size: 16, figures: [
              HeroFigure(tr('Billed'), formatBdt(billed)),
              HeroFigure(tr('Paid'), formatBdt(paid)),
            ]),
          ]),
      const SizedBox(height: 18),
      ..._monthlyList(sheet),
    ];
  }

  List<Widget> _monthlyList(CollectSheet sheet) => [
        Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        tr('Monthly bills · {month}',
                            {'month': monthOnly(sheet.month)}),
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            height: 1.35)),
                    Text(tr('One bill per customer for the month'),
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted, height: 1.4)),
                  ])),
              const SizedBox(width: 8),
              ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                      tr('{amount} due',
                          {'amount': formatBdt(sheet.monthlyDue)}),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          fontWeight: FontWeight.w700))),
            ])),
        if (sheet.monthly.isEmpty)
          EmptyNote(
              icon: Icons.calendar_month_outlined,
              title: tr('No monthly bills yet'),
              body: tr(
                  'Monthly customers appear here once a bill for this month is issued.'))
        else
          RowCard(children: [
            for (final bill in sheet.monthly)
              _MonthlyRow(
                  bill: bill,
                  onOpen: () => _open(StatementScreen(
                      code: bill.code, name: bill.name, month: sheet.month))),
          ]),
      ];
}

class _MutedHeading extends StatelessWidget {
  const _MutedHeading({required this.title, required this.trailing});
  final String title, trailing;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft))),
        const SizedBox(width: 8),
        Flexible(
            child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(trailing,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 13, height: 1.45, color: AppColors.muted)))),
      ]));
}

String _sinceDelivery(HandedOverBill bill) => switch (bill.days) {
      0 => tr('Delivered today'),
      1 => tr('Delivered yesterday'),
      _ => tr('{n} days since delivery', {'n': bill.days}),
    };

class _HandedOverCard extends StatelessWidget {
  const _HandedOverCard(
      {required this.bill,
      required this.onCall,
      required this.onRecord,
      required this.onOpen});
  final HandedOverBill bill;
  final VoidCallback onCall, onRecord, onOpen;

  @override
  Widget build(BuildContext context) => PaperCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(14),
      border: bill.overdue
          ? const BorderSide(color: AppColors.accentLine, width: 1.5)
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          InitialAvatar(
              name: bill.supplierName,
              tone: bill.overdue ? ChipTone.amber : ChipTone.neutral),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(bill.supplierName,
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w700)),
                Text(
                    '${bill.code} · ${bill.supplierCode} · ${tr('delivered {date}', {
                          'date': dayMonth(bill.deliveredOn)
                        })}',
                    style: const TextStyle(
                        fontSize: 13, height: 1.4, color: AppColors.muted)),
              ])),
          const SizedBox(width: 8),
          ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(formatBdt(bill.amount),
                      maxLines: 1,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()])))),
        ]),
        const SizedBox(height: 10),
        FlowChip(
            label: _sinceDelivery(bill),
            icon: Icons.schedule_rounded,
            tone: bill.overdue ? ChipTone.amber : ChipTone.neutral),
        const SizedBox(height: 12),
        Row(children: [
          Tooltip(
              message: tr('Call {name}', {'name': bill.supplierName}),
              child: OutlinedButton(
                  onPressed: onCall,
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 46),
                      padding: EdgeInsets.zero,
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.field)),
                  child: const Icon(Icons.call_outlined, size: 19))),
          const SizedBox(width: 10),
          Expanded(
              child: AppButton(
                  key: ValueKey('record-${bill.code}'),
                  label: tr('Record payment'),
                  icon: Icons.check_rounded,
                  kind: AppButtonKind.tonal,
                  onPressed: onRecord)),
        ]),
      ]));
}

class _ComingSoonRow extends StatelessWidget {
  const _ComingSoonRow({required this.bill, required this.onOpen});
  final ComingSoonBill bill;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Material(
      color: AppColors.lineSoft,
      borderRadius: BorderRadius.circular(cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onOpen,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                InitialAvatar(name: bill.supplierName, size: 40),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(bill.supplierName,
                          style: const TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkSoft)),
                      Text(
                          '${bill.code} · ${banglaStatus(bill.status, bill.statusLabel)}',
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: AppColors.muted)),
                    ])),
                const SizedBox(width: 8),
                ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(formatBdt(bill.amount),
                            maxLines: 1,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkSoft)))),
              ]))));
}

class _MonthlyRow extends StatelessWidget {
  const _MonthlyRow({required this.bill, required this.onOpen});
  final MonthlyBill bill;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final sent = bill.linkSentOn;
    final FlowChip link = sent == null
        ? FlowChip(label: tr('Link not sent'))
        : bill.linkActive
            ? FlowChip(
                label: tr('Link sent {date}', {'date': dayMonth(sent)}),
                icon: Icons.check_rounded,
                tone: ChipTone.green)
            : FlowChip(
                label:
                    tr('Link sent {date} · expired', {'date': dayMonth(sent)}));
    final owes = bill.due > 0;
    return InkWell(
        onTap: onOpen,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    InitialAvatar(
                        name: bill.name,
                        tone: sent != null ? ChipTone.blue : ChipTone.neutral),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text.rich(
                              TextSpan(children: [
                                TextSpan(text: bill.name),
                                TextSpan(
                                    text: ' · ${bill.code}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.muted)),
                              ]),
                              style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700)),
                          Text(
                              tr('Billed {billed} · paid {paid}', {
                                'billed': formatBdt(bill.billed),
                                'paid': formatBdt(bill.paid)
                              }),
                              style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: AppColors.muted)),
                          const SizedBox(height: 3),
                          link,
                        ])),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                      owes
                                          ? formatBdt(bill.due)
                                          : tr('Paid up'),
                                      maxLines: 1,
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: owes
                                              ? AppColors.ink
                                              : AppColors.ok,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures()
                                          ]))),
                              if (owes)
                                Text(tr('due'),
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.muted)),
                            ])),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.faint),
                  ]),
                  if (sent == null && owes) ...[
                    const SizedBox(height: 12),
                    Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: OutlinedButton.icon(
                            onPressed: onOpen,
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(48, 46),
                                foregroundColor: AppColors.primaryInk,
                                side: const BorderSide(color: AppColors.field)),
                            icon: const Icon(Icons.send_outlined, size: 18),
                            label: Text(tr('Send bill link')))),
                  ],
                ])));
  }
}
