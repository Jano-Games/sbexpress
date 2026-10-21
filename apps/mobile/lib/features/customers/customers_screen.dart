import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/customer.dart';
import '../../data/models/shipment.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../admin/admin_shipment_screen.dart';
import '../admin/money_format.dart';
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
        if (query.isEmpty || row.name.toLowerCase().contains(query) || row.code.toLowerCase().contains(query) || row.phone.toLowerCase().contains(query)) row,
    ];
    return Scaffold(
      appBar: const BackTitle(title: 'কাস্টমার'),
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 28),
          children: [
            const PageHeader(title: 'কাস্টমার', subtitle: 'বকেয়া ইস্যু করা ইনভয়েস থেকে। নাম শুধু অ্যাডমিন দেখে।'),
            TextField(controller: _query, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'নাম, কোড বা ফোন')),
            const SizedBox(height: 12),
            AppButton(
              label: 'নতুন কাস্টমার',
              kind: AppButtonKind.current,
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const CustomerFormScreen()));
                if (created == true) await _load();
              },
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
            if (_error != null) ErrorNote(message: _error!, onRetry: _load),
            if (!_loading && _error == null && visible.isEmpty) const EmptyNote(title: 'কাস্টমার নেই', body: 'নতুন কাস্টমার যোগ করলে এখানে দেখা যাবে।'),
            for (final row in visible) ...[
              _CustomerCard(
                row: row,
                onOpen: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CustomerDetailScreen(code: row.code))),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.row, required this.onOpen});

  final CustomerSummary row;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(cardRadius),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(cardRadius),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(cardRadius), border: Border.all(color: AppColors.line)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(row.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                  StatusPill(label: row.balance > 0 ? 'বাকি' : 'ক্লিয়ার', tone: row.balance > 0 ? ChipTone.red : ChipTone.green),
                ],
              ),
              const SizedBox(height: 4),
              Text('${row.code} · ${row.phone}', style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 6),
              Text('বাকি ${formatBdt(row.balance)} · অর্ডার ${row.orderCount} · ${row.shippedKg.toStringAsFixed(1)} kg'),
            ],
          ),
        ),
      ),
    );
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
          padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 32),
          children: [
            if (_loading && detail == null) const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
            if (_error != null) ErrorNote(message: _error!, onRetry: _load),
            if (detail != null) ...[
              PageHeader(title: detail.name, subtitle: '${detail.code} · ${detail.phone}'),
              PaperCard(
                child: Column(
                  children: [
                    KvRow(label: 'টার্ম', value: detail.terms == 'monthly' ? 'মাসিক' : 'সাথে সাথে'),
                    KvRow(label: 'ঠিকানা', value: detail.address),
                    KvRow(label: 'বিল', value: formatBdt(detail.billed)),
                    KvRow(label: 'পেইড', value: formatBdt(detail.paid)),
                    KvRow(label: 'বাকি', value: formatBdt(detail.balance), valueColor: detail.balance > 0 ? AppColors.danger : AppColors.ok),
                    KvRow(label: 'ক্রেডিট', value: formatBdt(detail.creditBalance)),
                    KvRow(label: 'ছাড়', value: formatBdt(detail.discountTotal)),
                    KvRow(label: 'দাম বাকি', value: '${detail.pricingPending}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'মাসিক স্টেটমেন্ট',
                kind: AppButtonKind.teal,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StatementScreen(code: detail.code, name: detail.name))),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: 'ক্রেডিট',
                kind: AppButtonKind.quiet,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => CustomerCreditScreen(code: detail.code, name: detail.name, orders: detail.orders),
                )),
              ),
              const SizedBox(height: 16),
              const SectionTitle(title: 'শিপমেন্ট'),
              if (detail.orders.isEmpty) const EmptyNote(title: 'শিপমেন্ট নেই', body: 'ইনটেক করলে এখানে আসবে।'),
              for (final order in detail.orders) ...[
                DirectoryTile(
                  title: order.code,
                  subtitle: '${order.description} · ${formatKg(order.effectiveKg)} · বাকি ${formatBdt(order.dueAmount)}',
                  badge: banglaStatus(order.status, order.statusLabel),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AdminShipmentScreen(code: order.code))),
                ),
                const SizedBox(height: 8),
              ],
              const SectionTitle(title: 'সাম্প্রতিক পেমেন্ট'),
              if (detail.payments.isEmpty) const EmptyNote(title: 'পেমেন্ট নেই', body: 'লেজারে টাকা ঢুকলে এখানে দেখা যাবে।'),
              for (final payment in detail.payments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PaperCard(child: Text('${payment.code} · ${payment.method} · ${formatBdt(payment.amount)}')),
                ),
              if (detail.invoices.isNotEmpty) ...[
                const SectionTitle(title: 'ইনভয়েস'),
                for (final invoice in detail.invoices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PaperCard(child: Text('${invoice.number} · ${invoice.shipmentCode} · ${formatBdt(invoice.total)}')),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
