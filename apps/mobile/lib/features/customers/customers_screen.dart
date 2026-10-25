import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/customer.dart';
import '../../data/models/shipment.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../admin/admin_shipment_screen.dart';
import '../admin/money_format.dart';
import 'customer_activity_screen.dart';
import 'customer_credit_screen.dart';
import 'customer_form_screen.dart';
import 'statement_screen.dart';

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
    return WorkspaceScaffold(
        title: tr('Customers'),
        root: false,
        onRefresh: _load,
        actions: [
          Padding(
              padding: const EdgeInsets.only(right: 12),
              child: AppButton(
                  label: tr('New'),
                  icon: Icons.add_rounded,
                  expand: false,
                  onPressed: () async {
                    final created = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                            builder: (_) => const CustomerFormScreen()));
                    if (created == true && mounted) await _load();
                  }))
        ],
        toolbar: TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
                hintText: tr('Search name, code or phone'),
                prefixIcon: const Icon(Icons.search_rounded))),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(tr('Contacts, shipments and receivables'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          const SizedBox(height: 12),
          if (_loading)
            const LinearProgressIndicator(
                color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (!_loading && _error == null && visible.isEmpty)
            EmptyNote(
                title: tr('No customers'),
                body: tr('New customers you add will appear here.')),
          for (final row in visible) ...[
            _CustomerCard(
              row: row,
              onOpen: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => CustomerDetailScreen(code: row.code))),
            ),
            const SizedBox(height: 8),
          ],
        ]);
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.row, required this.onOpen});
  final CustomerSummary row;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => PaperCard(
      onTap: onOpen,
      child: Column(children: [
        Row(children: [
          const IconBadge(Icons.storefront_outlined, tone: ChipTone.neutral),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(row.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                Text('${row.code} · ${row.phone}',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
              ])),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.muted, size: 19),
        ]),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1)),
        Row(children: [
          Expanded(
              child: Text(
                  trn(
                      row.orderCount,
                      '{n} shipment · {kg} kg',
                      '{n} shipments · {kg} kg',
                      {'kg': row.shippedKg.toStringAsFixed(1)}),
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 12))),
          const SizedBox(width: 8),
          Flexible(
              child: Text(formatBdt(row.balance),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                          row.balance > 0 ? AppColors.danger : AppColors.ok))),
        ]),
      ]));
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

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      appBar: BackTitle(title: widget.code),
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(pageGutter, 12, pageGutter, 32),
          children: [
            if (_loading && detail == null)
              const LinearProgressIndicator(
                  color: AppColors.teal, backgroundColor: AppColors.tealSoft),
            if (_error != null) ErrorNote(message: _error!, onRetry: _load),
            if (detail != null) ...[
              PageHeader(
                  title: detail.name,
                  subtitle: '${detail.code} · ${detail.phone}'),
              ScreenTabs(
                  labels: [tr('Summary'), tr('Shipments'), tr('Transactions')],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i)),
              const SizedBox(height: 20),
              if (_tab == 0) ...[
                PaperCard(
                  child: Column(
                    children: [
                      KvRow(
                          label: tr('Terms'),
                          value: detail.terms == 'monthly'
                              ? tr('Monthly')
                              : tr('Instant')),
                      KvRow(label: tr('Address'), value: detail.address),
                      KvRow(
                          label: tr('Billed'), value: formatBdt(detail.billed)),
                      KvRow(label: tr('Paid'), value: formatBdt(detail.paid)),
                      KvRow(
                          label: tr('Due'),
                          value: formatBdt(detail.balance),
                          valueColor: detail.balance > 0
                              ? AppColors.danger
                              : AppColors.ok),
                      KvRow(
                          label: tr('Credit'),
                          value: formatBdt(detail.creditBalance)),
                      KvRow(
                          label: tr('Discount'),
                          value: formatBdt(detail.discountTotal)),
                      KvRow(
                          label: tr('Pricing pending'),
                          value: '${detail.pricingPending}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: tr('Monthly statement'),
                  kind: AppButtonKind.teal,
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => StatementScreen(
                              code: detail.code, name: detail.name))),
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: tr('Account activity'),
                  kind: AppButtonKind.quiet,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => CustomerActivityScreen(
                            code: detail.code, name: detail.name)),
                  ),
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: tr('Credit'),
                  kind: AppButtonKind.quiet,
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => CustomerCreditScreen(
                        code: detail.code,
                        name: detail.name,
                        orders: detail.orders),
                  )),
                ),
              ],
              if (_tab == 1) ...[
                const SizedBox(height: 16),
                SectionTitle(title: tr('Shipments')),
                if (detail.orders.isEmpty)
                  EmptyNote(
                      title: tr('No shipments'),
                      body: tr('Shipments appear here after intake.')),
                for (final order in detail.orders) ...[
                  DirectoryTile(
                    title: order.code,
                    subtitle:
                        '${order.description} · ${formatKg(order.effectiveKg)} · ${tr('Due {amount}', {
                          'amount': formatBdt(order.dueAmount)
                        })}',
                    badge: banglaStatus(order.status, order.statusLabel),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) =>
                                AdminShipmentScreen(code: order.code))),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              if (_tab == 2) ...[
                SectionTitle(title: tr('Recent payments')),
                if (detail.payments.isEmpty)
                  EmptyNote(
                      title: tr('No payments'),
                      body: tr(
                          'Payments appear here once money reaches the ledger.')),
                for (final payment in detail.payments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PaperCard(
                        child: Text(
                            '${payment.code} · ${payment.method} · ${formatBdt(payment.amount)}')),
                  ),
                if (detail.invoices.isNotEmpty) ...[
                  SectionTitle(title: tr('Invoices')),
                  for (final invoice in detail.invoices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PaperCard(
                          child: Text(
                              '${invoice.number} · ${invoice.shipmentCode} · ${formatBdt(invoice.total)}')),
                    ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}
