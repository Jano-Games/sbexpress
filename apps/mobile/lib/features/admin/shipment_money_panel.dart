import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/workspace.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import 'money_format.dart';

class ShipmentMoneyPanel extends StatefulWidget {
  const ShipmentMoneyPanel({super.key, required this.code, required this.dueAmount});

  final String code;
  final double dueAmount;

  @override
  State<ShipmentMoneyPanel> createState() => _ShipmentMoneyPanelState();
}

class _ShipmentMoneyPanelState extends State<ShipmentMoneyPanel> {
  InvoiceDocument? _invoice;
  List<FinanceAccount> _accounts = const [];
  String? _error;
  String? _link;
  var _loading = true;
  var _busy = false;
  var _days = 7;
  var _confirmFree = false;
  final _reason = TextEditingController();
  final _amount = TextEditingController();
  String? _account;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _reason.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scope = AppScope.of(context);
      final invoice = await scope.shipments.invoice(widget.code);
      final finance = await scope.finance.snapshot();
      if (!mounted) return;
      setState(() {
        _invoice = invoice;
        _accounts = finance.accounts;
      });
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

  Future<void> _issue() async {
    final invoice = _invoice;
    if (invoice == null) return;
    if (invoice.lines.isEmpty) {
      setState(() => _error = 'বিলের লাইন নেই। ওয়েবে চার্জ বসিয়ে তারপর ইস্যু করুন।');
      return;
    }
    if (invoice.total == 0 && !_confirmFree) {
      setState(() => _error = 'শূন্য বিল ইস্যু করতে ফ্রি অব চার্জ নিশ্চিত করুন।');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).shipments.issueInvoice(
            widget.code,
            invoice,
            revisionReason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
            confirmFree: invoice.total == 0 && _confirmFree,
          );
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(String scope) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await AppScope.of(context).shipments.shareTracking(widget.code, days: _days, scope: scope);
      if (!mounted) return;
      setState(() => _link = link.url);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    FinanceAccount? account;
    for (final row in _accounts) {
      if (row.name == _account) account = row;
    }
    final amount = double.tryParse(_amount.text.trim());
    if (account == null || amount == null || amount <= 0) {
      setState(() => _error = 'অ্যাকাউন্ট বেছে নিন এবং যে টাকা এসেছে সেই অঙ্ক লিখুন।');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).shipments.recordPayment(widget.code, amount: amount, accountName: account.name, currency: account.currency);
      _amount.clear();
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loading && invoice == null) const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
        if (_error != null) ...[
          const SizedBox(height: 8),
          ErrorNote(message: _error!, onRetry: _load),
        ],
        if (invoice != null) ...[
          const SizedBox(height: 12),
          const SectionTitle(title: 'ইনভয়েস', subtitle: 'লাইন হিসাব থেকে আসে। এখানে নতুন লাইন যোগ হয় না।'),
          PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invoice.number, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(invoice.issued ? 'ইস্যু হয়েছে' : invoice.state, style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 8),
                if (invoice.lines.isEmpty) const Text('এখনো কোনো লাইন নেই।'),
                for (final line in invoice.lines) KvRow(label: line.label, value: formatBdt(line.amount)),
                KvRow(label: 'ছাড়', value: formatBdt(invoice.discount)),
                KvRow(label: 'মোট', value: formatBdt(invoice.total)),
                KvRow(label: 'বাকি', value: formatBdt(invoice.dueAmount), valueColor: invoice.dueAmount > 0 ? AppColors.danger : AppColors.ok),
              ],
            ),
          ),
          if (!invoice.issued) ...[
            const SizedBox(height: 8),
            if (invoice.needsReview || invoice.saved)
              TextField(controller: _reason, decoration: const InputDecoration(labelText: 'রিভিশনের কারণ', helperText: 'ইস্যু করা বিল বদলালে কারণ লাগে')),
            if (invoice.total == 0) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _confirmFree,
                onChanged: (value) => setState(() => _confirmFree = value ?? false),
                title: const Text('এই শিপমেন্ট ফ্রি অব চার্জ'),
              ),
            ],
            AppButton(label: 'ইনভয়েস ইস্যু করুন', kind: AppButtonKind.current, busy: _busy, onPressed: invoice.lines.isEmpty ? null : _issue),
          ],
          const SizedBox(height: 12),
          const SectionTitle(title: 'শেয়ার', subtitle: 'আলাদা রিকোয়েস্টেড অ্যামাউন্ট নেই। লিংক ১–৯০ দিন।'),
          ChoiceChips(
            options: const [(value: '7', label: '৭ দিন'), (value: '14', label: '১৪ দিন'), (value: '30', label: '৩০ দিন')],
            selected: '$_days',
            onSelected: (value) => setState(() => _days = int.parse(value)),
          ),
          const SizedBox(height: 8),
          AppButton(label: 'ট্র্যাকিং লিংক', kind: AppButtonKind.quiet, busy: _busy, onPressed: () => _share('tracking_only')),
          const SizedBox(height: 8),
          AppButton(label: 'ইনভয়েসসহ লিংক', kind: AppButtonKind.teal, busy: _busy, onPressed: () => _share('invoice')),
          if (_link != null) ...[
            const SizedBox(height: 8),
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_link!, style: const TextStyle(height: 1.35)),
                  const SizedBox(height: 8),
                  AppButton(label: 'লিংক কপি', kind: AppButtonKind.quiet, onPressed: () => Clipboard.setData(ClipboardData(text: _link!))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const SectionTitle(title: 'টাকা জমা', subtitle: 'যে অ্যাকাউন্টে টাকা ঢুকেছে এবং যে অঙ্ক এসেছে, সেটাই লিখুন।'),
          if (_accounts.isEmpty)
            const EmptyNote(title: 'রিসিভিং অ্যাকাউন্ট নেই', body: 'ওয়েবের ফাইন্যান্সে আসল অ্যাকাউন্ট যোগ না করা পর্যন্ত এখান থেকে জমা দেওয়া যাবে না।')
          else if (widget.dueAmount <= 0 && invoice.dueAmount <= 0)
            const EmptyNote(title: 'বকেয়া নেই', body: 'এই শিপমেন্টে আর জমা দেওয়ার মতো বাকি নেই।')
          else ...[
            for (final account in _accounts) ...[
              _AccountPick(account: account, selected: _account == account.name, onTap: () => setState(() => _account = account.name)),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'প্রাপ্ত অঙ্ক', helperText: 'বাকি ${formatBdt(invoice.dueAmount)}'),
            ),
            const SizedBox(height: 8),
            AppButton(label: 'জমা সেভ করুন', kind: AppButtonKind.current, busy: _busy, onPressed: _pay),
          ],
        ],
      ],
    );
  }
}

class _AccountPick extends StatelessWidget {
  const _AccountPick({required this.account, required this.selected, required this.onTap});

  final FinanceAccount account;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.tealSoft : AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? AppColors.teal : AppColors.line)),
          child: Text('${account.name} · ${account.currency}', style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
