import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/ledger_actions.dart';
import '../../data/money_payload.dart';
import '../../theme/app_colors.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/ui.dart';
import '../admin/money_format.dart';

class StatementScreen extends StatefulWidget {
  const StatementScreen({super.key, required this.code, required this.name});

  final String code;
  final String name;

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  final _month = TextEditingController();
  final _amount = TextEditingController();
  List<StatementLinkInfo> _links = const [];
  List<StatementReceiptInfo> _receipts = const [];
  StatementBalance? _balance;
  String? _error;
  var _days = 7;
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month.text = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _month.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool get _monthOk => RegExp(r'^20\d{2}-(0[1-9]|1[0-2])$').hasMatch(_month.text.trim());

  Future<void> _load() async {
    if (!_monthOk) {
      setState(() => _error = 'মাস ২০২৬-১০ এই ফর্মে লিখুন।');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scope = AppScope.of(context).customers;
      final page = await scope.statementLinks(widget.code, _month.text.trim());
      final receipts = await scope.statementReceipts(widget.code);
      if (!mounted) return;
      setState(() {
        _links = page.links;
        _balance = page.balance;
        _receipts = receipts;
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

  Future<void> _create() async {
    if (!_monthOk) {
      setState(() => _error = 'মাস ২০২৬-১০ এই ফর্মে লিখুন।');
      return;
    }
    final amount = _amount.text.trim().isEmpty ? null : parseMoney(_amount.text);
    if (_amount.text.trim().isNotEmpty && (amount == null || amount <= 0)) {
      setState(() => _error = 'অনুরোধের অঙ্ক খালি রাখুন অথবা ধনাত্মক দিন।');
      return;
    }
    final due = _balance?.due;
    if (amount != null && due != null && amount > due + 0.001) {
      setState(() => _error = 'অনুরোধ বকেয়া ${formatBdt(due)}-এর বেশি নয়।');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await AppScope.of(context).customers.createStatementLink(widget.code, month: _month.text.trim(), days: _days, amount: amount);
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: link.url));
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke() async {
    final ok = await confirmMoney(context, title: 'সব লিংক বাতিল', body: 'এই কাস্টমারের চালু স্টেটমেন্ট লিংক আর খুলবে না।');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).customers.revokeStatementLinks(widget.code);
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve(StatementReceiptInfo receipt) async {
    final ok = await confirmMoney(context, title: 'রসিদ অনুমোদন', body: '${formatBdt(receipt.amount)} ${receipt.method} জমা হিসেবে ঢুকবে।');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).customers.approveStatementReceipt(widget.code, receipt.reference);
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(StatementReceiptInfo receipt) async {
    final reason = await askReason(context, title: 'রসিদ বাতিল');
    if (reason == null || !mounted) return;
    if (reason.length < 3) {
      setState(() => _error = 'বাতিলের কারণ কমপক্ষে ৩ অক্ষর।');
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.of(context).customers.rejectStatementReceipt(widget.code, receipt.reference, reason);
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
    final balance = _balance;
    return Scaffold(
      appBar: BackTitle(title: widget.code),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 32),
        children: [
          PageHeader(title: 'মাসিক স্টেটমেন্ট', subtitle: '${widget.name}। শুধু ইস্যু ও রিভিউ করা ইনভয়েস থাকলে লিংক হয়।'),
          TextField(controller: _month, decoration: const InputDecoration(labelText: 'মাস', helperText: 'যেমন ২০২৬-১০')),
          const SizedBox(height: 8),
          AppButton(label: 'এই মাস দেখুন', kind: AppButtonKind.quiet, busy: _loading, onPressed: _load),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorNote(message: _error!),
          ],
          if (balance != null) ...[
            const SizedBox(height: 12),
            PaperCard(
              child: Column(
                children: [
                  KvRow(label: 'বিল', value: formatBdt(balance.billed)),
                  KvRow(label: 'পেইড', value: formatBdt(balance.paid)),
                  KvRow(label: 'বাকি', value: formatBdt(balance.due)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const SectionTitle(title: 'নতুন লিংক'),
            ChoiceChips(
              options: const [(value: '7', label: '৭ দিন'), (value: '14', label: '১৪ দিন'), (value: '30', label: '৩০ দিন')],
              selected: '$_days',
              onSelected: (value) => setState(() => _days = int.parse(value)),
            ),
            const SizedBox(height: 8),
            TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'অনুরোধের অঙ্ক (ঐচ্ছিক)', helperText: 'খালি রাখলে পুরো বকেয়া')),
            const SizedBox(height: 8),
            AppButton(label: 'লিংক তৈরি ও কপি', kind: AppButtonKind.current, busy: _busy, onPressed: _create),
            const SizedBox(height: 8),
            AppButton(label: 'সব লিংক বাতিল', kind: AppButtonKind.danger, busy: _busy, onPressed: _revoke),
            const SizedBox(height: 16),
            const SectionTitle(title: 'সেভ করা লিংক'),
            if (_links.isEmpty) const EmptyNote(title: 'লিংক নেই', body: 'এই মাসে এখনো শেয়ার করা হয়নি।'),
            for (final link in _links) ...[
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusPill(label: link.status),
                    const SizedBox(height: 6),
                    Text(link.url ?? 'লিংক আর কপি করা যায় না', style: const TextStyle(height: 1.35)),
                    if (link.url != null)
                      TextButton(onPressed: () => Clipboard.setData(ClipboardData(text: link.url!)), child: const Text('কপি')),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SectionTitle(title: 'রসিদ'),
            if (_receipts.isEmpty) const EmptyNote(title: 'রসিদ নেই', body: 'কাস্টমার পাবলিক লিংকে রসিদ দিলে এখানে আসবে।'),
            for (final receipt in _receipts) ...[
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${receipt.month} · ${formatBdt(receipt.amount)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${receipt.method} · ${receipt.status}', style: const TextStyle(color: AppColors.muted)),
                    if (receipt.reason.isNotEmpty) Text(receipt.reason),
                    if (receipt.status == 'pending') ...[
                      const SizedBox(height: 8),
                      AppButton(label: 'অনুমোদন', kind: AppButtonKind.current, busy: _busy, onPressed: () => _approve(receipt)),
                      const SizedBox(height: 8),
                      AppButton(label: 'বাতিল', kind: AppButtonKind.danger, busy: _busy, onPressed: () => _reject(receipt)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}
