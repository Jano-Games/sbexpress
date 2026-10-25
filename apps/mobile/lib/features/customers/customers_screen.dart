import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/customer.dart';
import '../../data/models/shipment.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/finance_parts.dart';
import '../../widgets/ui.dart';
import '../admin/admin_shipment_screen.dart';
import '../admin/money_format.dart';
import 'customer_activity_screen.dart';
import 'customer_credit_screen.dart';
import 'customer_form_screen.dart';
import 'statement_screen.dart';

String termsLabel(String terms) =>
    terms == 'monthly' ? tr('Monthly') : tr('Instant');

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _query = TextEditingController();
  List<CustomerSummary> _rows = const [];
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await AppScope.of(context).customers.list();
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

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const CustomerFormScreen()));
    if (created == true && mounted) await _load();
  }

  Future<void> _open(CustomerSummary row) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CustomerDetailScreen(code: row.code)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim().toLowerCase();
    final visible = [
      for (final row in _rows)
        if (query.isEmpty ||
            row.name.toLowerCase().contains(query) ||
            row.code.toLowerCase().contains(query) ||
            row.phone.toLowerCase().contains(query))
          row,
    ];
    final owing = [
      for (final row in visible)
        if (row.balance > 0) row
    ];
    final settled = [
      for (final row in visible)
        if (row.balance <= 0) row
    ];
    final totalDue = _rows.fold<double>(
        0, (sum, row) => sum + (row.balance > 0 ? row.balance : 0));
    final owingCount = _rows.where((row) => row.balance > 0).length;
    return WorkspaceScaffold(
        title: tr('Customers'),
        subtitle: tr('Contacts, shipments and receivables'),
        root: false,
        onRefresh: _load,
        actions: [
          Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.tonalIcon(
                  key: const Key('customer-new'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primarySoft,
                      foregroundColor: AppColors.primaryInk,
                      minimumSize: const Size(48, 44),
                      padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
                      shape: const StadiumBorder()),
                  onPressed: _create,
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: Text(tr('New'))))
        ],
        toolbar: SearchBox(
            controller: _query,
            hint: tr('Search name, code or phone'),
            onChanged: (_) => setState(() {})),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (_rows.isNotEmpty) ...[
            _ReceivablesSummary(
                customers: _rows.length, owing: owingCount, totalDue: totalDue),
            const SizedBox(height: 18),
          ],
          if (!_loading && _error == null && _rows.isEmpty)
            EmptyNote(
                icon: Icons.storefront_outlined,
                title: tr('No customers'),
                body: tr('New customers you add will appear here.'))
          else if (_rows.isNotEmpty && visible.isEmpty)
            EmptyNote(
                icon: Icons.search_off_rounded,
                title: tr('No matching customers'),
                body: tr('Try another name, code or phone.')),
          if (owing.isNotEmpty) ...[
            SectionTitle(title: tr('Owe money'), action: _Count(owing.length)),
            ListCard(children: [
              for (final row in owing)
                _CustomerRow(row: row, onOpen: () => _open(row)),
            ]),
            const SizedBox(height: 20),
          ],
          if (settled.isNotEmpty) ...[
            SectionTitle(title: tr('Settled'), action: _Count(settled.length)),
            ListCard(children: [
              for (final row in settled)
                _CustomerRow(row: row, onOpen: () => _open(row)),
            ]),
          ],
        ]);
  }
}

class _Count extends StatelessWidget {
  const _Count(this.value);
  final int value;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text('$value',
          style: const TextStyle(fontSize: 13, color: AppColors.muted)));
}

class _ReceivablesSummary extends StatelessWidget {
  const _ReceivablesSummary(
      {required this.customers, required this.owing, required this.totalDue});
  final int customers, owing;
  final double totalDue;

  @override
  Widget build(BuildContext context) {
    Widget figure(String label, String value,
            {Color color = AppColors.ink, bool first = false}) =>
        Container(
            padding: EdgeInsetsDirectional.only(start: first ? 0 : 12, end: 8),
            decoration: first
                ? null
                : const BoxDecoration(
                    border: BorderDirectional(
                        start: BorderSide(color: AppColors.lineSoft))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              WordFitText(label,
                  maxLines: 2,
                  style: const TextStyle(
                      fontSize: 12, height: 1.35, color: AppColors.muted)),
              FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(value,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 20,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: color,
                          fontFeatures: const [FontFeature.tabularFigures()]))),
            ]));
    return PaperCard(
        padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: figure(tr('Customers'), '$customers', first: true)),
          Expanded(child: figure(tr('Owe money'), '$owing')),
          Expanded(
              flex: 2,
              child: figure(tr('Total due'), formatBdt(totalDue),
                  color: totalDue > 0 ? AppColors.danger : AppColors.ink)),
        ]));
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.row, required this.onOpen});
  final CustomerSummary row;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final owes = row.balance > 0;
    return InkWell(
        onTap: onOpen,
        child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              InitialAvatar(
                  name: row.name, tone: owes ? ChipTone.red : ChipTone.neutral),
              const SizedBox(width: 12),
              Expanded(
                  child: SplitRow(
                      maxFraction: 0.45,
                      start: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                                spacing: 8,
                                runSpacing: 2,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(row.name,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          height: 1.35,
                                          fontWeight: FontWeight.w700)),
                                  if (row.pricingPending > 0)
                                    StatusPill(
                                        label: tr('{n} to price',
                                            {'n': row.pricingPending}),
                                        tone: ChipTone.amber)
                                  else if (row.creditBalance > 0)
                                    StatusPill(
                                        label: tr('Credit {amount}', {
                                          'amount': formatBdt(row.creditBalance)
                                        }),
                                        tone: ChipTone.blue),
                                ]),
                            WordFitText(
                                [row.code, if (row.phone.isNotEmpty) row.phone]
                                    .join(' · '),
                                style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: AppColors.muted)),
                            Text(
                                '${trn(row.orderCount, '{n} shipment · {kg} kg', '{n} shipments · {kg} kg', {
                                      'kg': row.shippedKg.toStringAsFixed(1)
                                    })} · ${termsLabel(row.terms)}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: AppColors.inkSoft)),
                          ]),
                      end: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FitAmount(formatBdt(row.balance),
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: owes
                                        ? AppColors.danger
                                        : AppColors.ok)),
                            Text(owes ? tr('due') : tr('settled'),
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.muted)),
                          ]))),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.faint),
            ])));
  }
}

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({super.key, required this.code});

  final String code;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  CustomerDetail? _detail;
  String? _error;
  var _loading = true;
  var _tab = 0;

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
      final detail = await AppScope.of(context).customers.detail(widget.code);
      if (!mounted) return;
      setState(() => _detail = detail);
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

  Future<void> _push(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return WorkspaceScaffold(
        title: detail?.name ?? widget.code,
        subtitle: detail == null
            ? null
            : [detail.code, if (detail.phone.isNotEmpty) detail.phone]
                .join(' · '),
        root: false,
        onRefresh: _load,
        actions: [
          if (detail != null)
            Center(
                child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: StatusPill(
                        label: detail.terms == 'monthly'
                            ? tr('Monthly terms')
                            : tr('Instant terms'),
                        tone: ChipTone.neutral))),
        ],
        toolbar: ScreenTabs(labels: [
          tr('Summary'),
          detail == null
              ? tr('Shipments')
              : tr('Shipments · {n}', {'n': detail.orders.length}),
          tr('Transactions'),
        ], index: _tab, onChanged: (i) => setState(() => _tab = i)),
        footer: detail == null
            ? null
            : ActionFooter(
                child: AppButton(
                    label: tr('Monthly statement'),
                    icon: Icons.description_outlined,
                    kind: AppButtonKind.current,
                    onPressed: () => _push(StatementScreen(
                        code: detail.code, name: detail.name)))),
        children: [
          if (_loading && detail == null) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (detail != null)
            ...switch (_tab) {
              0 => _summary(detail),
              1 => _shipments(detail),
              _ => _transactions(detail),
            },
        ]);
  }

  List<Widget> _summary(CustomerDetail detail) {
    final paidShare = detail.billed <= 0 ? null : detail.paid / detail.billed;
    return [
      MoneyHero(children: [
        HeroAmount(
            label: tr('Amount due'),
            value: formatBdt(detail.balance),
            color: detail.balance > 0 ? HeroColors.due : Colors.white),
        const SizedBox(height: 12),
        if (paidShare != null) ...[
          HeroBar(
              value: paidShare,
              label: tr('{pct}% of billed amount paid',
                  {'pct': (paidShare * 100).clamp(0, 100).round()})),
          const SizedBox(height: 6),
          Text(
              tr('{pct}% of billed amount paid',
                  {'pct': (paidShare * 100).clamp(0, 100).round()}),
              style: const TextStyle(fontSize: 12, color: HeroColors.soft)),
        ] else
          Text(tr('Nothing billed yet'),
              style: const TextStyle(fontSize: 12, color: HeroColors.soft)),
        const SizedBox(height: 12),
        const HeroDivider(),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: HeroFigure(
                  label: tr('Billed'), value: formatBdt(detail.billed))),
          const SizedBox(width: 16),
          Expanded(
              child:
                  HeroFigure(label: tr('Paid'), value: formatBdt(detail.paid))),
        ]),
      ]),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: StatTile(
                label: tr('Credit'), value: formatBdt(detail.creditBalance))),
        const SizedBox(width: 10),
        Expanded(
            child: StatTile(
                label: tr('Discount'), value: formatBdt(detail.discountTotal))),
        const SizedBox(width: 10),
        Expanded(
            child: StatTile(
                label: tr('Pricing pending'),
                value: '${detail.pricingPending}',
                highlight: detail.pricingPending > 0)),
      ]),
      const SizedBox(height: 12),
      PaperCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.location_on_outlined,
                    size: 19, color: AppColors.inkSoft)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(tr('Address'),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                  Text(detail.address.isEmpty ? '—' : detail.address,
                      style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w500)),
                ])),
          ])),
      const SizedBox(height: 20),
      SectionTitle(title: tr('Account')),
      SurfaceGroup(children: [
        MenuRow(
            title: tr('Account activity'),
            subtitle: tr('Payments, advances, credit and refunds'),
            icon: Icons.history_rounded,
            onTap: () => _push(
                CustomerActivityScreen(code: detail.code, name: detail.name))),
        MenuRow(
            title: tr('Credit'),
            subtitle: tr('Advance and credit balance · {amount}',
                {'amount': formatBdt(detail.creditBalance)}),
            icon: Icons.account_balance_wallet_outlined,
            onTap: () => _push(CustomerCreditScreen(
                code: detail.code, name: detail.name, orders: detail.orders))),
      ]),
    ];
  }

  List<Widget> _shipments(CustomerDetail detail) => [
        if (detail.orders.isEmpty)
          EmptyNote(
              icon: Icons.inventory_2_outlined,
              title: tr('No shipments'),
              body: tr('Shipments appear here after intake.'))
        else
          ListCard(children: [
            for (final order in detail.orders)
              _OrderRow(
                  order: order,
                  onTap: () => _push(AdminShipmentScreen(code: order.code))),
          ]),
      ];

  List<Widget> _transactions(CustomerDetail detail) => [
        SectionTitle(
            title: tr('Recent payments'),
            action: TextButton(
                onPressed: () => _push(CustomerActivityScreen(
                    code: detail.code, name: detail.name)),
                child: Text(tr('All activity')))),
        if (detail.payments.isEmpty)
          EmptyNote(
              icon: Icons.payments_outlined,
              title: tr('No payments'),
              body: tr('Payments appear here once money reaches the ledger.'))
        else
          ListCard(children: [
            for (final payment in detail.payments) _PaymentRow(payment),
          ]),
        if (detail.invoices.isNotEmpty) ...[
          const SizedBox(height: 20),
          SectionTitle(title: tr('Invoices')),
          ListCard(children: [
            for (final invoice in detail.invoices) _InvoiceRow(invoice),
          ]),
        ],
      ];
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.onTap});
  final AdminShipment order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const IconBadge(Icons.inventory_2_outlined, tone: ChipTone.neutral),
            const SizedBox(width: 12),
            Expanded(
                child: SplitRow(
                    maxFraction: 0.45,
                    start: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.code,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          Text(
                              [
                                if (order.description.isNotEmpty)
                                  order.description,
                                formatKg(order.effectiveKg)
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.muted)),
                          const SizedBox(height: 4),
                          StatusPill(
                              label:
                                  banglaStatus(order.status, order.statusLabel),
                              tone: shipmentStatusTone(order.statusIndex)),
                        ]),
                    end: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FitAmount(formatBdt(order.dueAmount),
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: order.dueAmount > 0
                                      ? AppColors.danger
                                      : AppColors.ok)),
                          Text(order.dueAmount > 0 ? tr('due') : tr('settled'),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.muted)),
                        ]))),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.faint),
          ])));
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow(this.payment);
  final CustomerPayment payment;

  @override
  Widget build(BuildContext context) {
    final when = localTime(payment.at);
    final out = payment.amount < 0;
    return Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          IconBadge(out ? Icons.north_east_rounded : Icons.south_west_rounded,
              tone: out ? ChipTone.neutral : ChipTone.green),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(payment.code,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                Text(
                    [payment.method, if (when != null) shortDate(when)]
                        .join(' · '),
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.muted)),
              ])),
          const SizedBox(width: 8),
          Text(signedMoney(payment.amount, 'BDT'),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: out ? AppColors.ink : AppColors.ok,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]));
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow(this.invoice);
  final CustomerInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final issued = localTime(invoice.issuedAt);
    return Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const IconBadge(Icons.receipt_long_outlined, tone: ChipTone.blue),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(invoice.number,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                Text(
                    [
                      invoice.shipmentCode,
                      if (issued != null) shortDate(issued),
                      if (invoice.discount > 0)
                        tr('Discount {amount}',
                            {'amount': formatBdt(invoice.discount)}),
                    ].join(' · '),
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.muted)),
              ])),
          const SizedBox(width: 8),
          Text(formatBdt(invoice.total),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ]));
  }
}
