import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/payment_review.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import 'money_format.dart';

class PaymentReviewScreen extends StatefulWidget {
  const PaymentReviewScreen({super.key});

  @override
  State<PaymentReviewScreen> createState() => _PaymentReviewScreenState();
}

class _PaymentReviewScreenState extends State<PaymentReviewScreen> {
  PaymentReviewQueue? _queue;
  String? _error;
  var _loading = true;
  var _busy = false;
  String? _selected;
  final _reason = TextEditingController();
  var _rejecting = false;
  String? _shotUrl;
  String? _shotError;

  @override
  void initState() {
    super.initState();
    _reason.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final queue = await AppScope.of(context).review.queue();
      if (!mounted) return;
      setState(() {
        _queue = queue;
        _selected ??= queue.all.isEmpty ? null : _key(queue.all.first);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _key(PaymentReviewItem item) => '${item.kind.name}:${item.recordLabel}:${item.txnRef}';

  PaymentReviewItem? get _current {
    final queue = _queue;
    if (queue == null) return null;
    for (final item in queue.all) {
      if (_key(item) == _selected) return item;
    }
    return queue.all.isEmpty ? null : queue.all.first;
  }

  Future<void> _approve(PaymentReviewItem item) async {
    if (!canApprovePayment(item) || _busy) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).review.approve(item);
      _reason.clear();
      _rejecting = false;
      _shotUrl = null;
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(PaymentReviewItem item) async {
    final reason = _reason.text.trim();
    if (reason.length < 3 || _busy) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).review.reject(item, reason);
      _reason.clear();
      _rejecting = false;
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadShot(PaymentReviewItem item) async {
    final shot = item.screenshot;
    if (shot == null) return;
    setState(() => _shotError = null);
    try {
      final url = await AppScope.of(context).review.screenshotUrl(shot.reference);
      if (!mounted) return;
      setState(() => _shotUrl = url);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _shotError = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = _queue;
    final current = _current;
    return Scaffold(
      appBar: const BackTitle(title: 'পেমেন্ট রিভিউ'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text('স্ক্রিনশট ঐচ্ছিক। না থাকলেও ট্রান্সফার মিলিয়ে অ্যাপ্রুভ করা যায়।', style: TextStyle(color: AppColors.muted, height: 1.35)),
          const SizedBox(height: 12),
          if (_loading && queue == null) const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (queue != null && queue.all.isEmpty) const EmptyNote(title: 'রিভিউ বাকি নেই', body: 'নতুন রসিদ এলে এখানে দেখা যাবে।'),
          if (queue != null)
            for (final item in queue.all) ...[
              _ReviewCard(
                item: item,
                selected: current != null && _key(current) == _key(item),
                onTap: () => setState(() {
                  _selected = _key(item);
                  _shotUrl = null;
                  _shotError = null;
                  _rejecting = false;
                }),
              ),
              const SizedBox(height: 8),
            ],
          if (current != null) ...[
            const SizedBox(height: 8),
            _Detail(
              item: current,
              shotUrl: _shotUrl,
              shotError: _shotError,
              rejecting: _rejecting,
              reason: _reason,
              busy: _busy,
              onShot: () => _loadShot(current),
              onApprove: () => _approve(current),
              onReject: () => _reject(current),
              onStartReject: () => setState(() => _rejecting = true),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.item, required this.selected, required this.onTap});

  final PaymentReviewItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.tealSoft : AppColors.card,
      borderRadius: BorderRadius.circular(cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        child: Container(
          constraints: const BoxConstraints(minHeight: minTouchTarget),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(cardRadius), border: Border.all(color: AppColors.line)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.recordLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${item.kind == ReviewKind.shipment ? 'শিপমেন্ট' : 'মাসিক স্টেটমেন্ট'} · ${item.supplierName}'),
              Text('${item.method} · ${formatBdt(item.amount)}'),
              Text(item.hasScreenshot ? 'স্ক্রিনশট আছে' : 'স্ক্রিনশট নেই', style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.item,
    required this.shotUrl,
    required this.shotError,
    required this.rejecting,
    required this.reason,
    required this.busy,
    required this.onShot,
    required this.onApprove,
    required this.onReject,
    required this.onStartReject,
  });

  final PaymentReviewItem item;
  final String? shotUrl;
  final String? shotError;
  final bool rejecting;
  final TextEditingController reason;
  final bool busy;
  final VoidCallback onShot;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onStartReject;

  @override
  Widget build(BuildContext context) {
    final source = item.sourceCurrency == 'BDT' ? null : '${item.sourceCurrency} ${item.sourceAmount.toStringAsFixed(2)}';
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatBdt(item.amount), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          if (source != null) Text(source, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 6),
          Text(item.method),
          Text(item.txnRef),
          Text(item.date, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 8),
          AppButton(
            label: 'ট্রানজ্যাকশন কপি',
            kind: AppButtonKind.quiet,
            onPressed: () => Clipboard.setData(ClipboardData(text: item.txnRef)),
          ),
          const SizedBox(height: 12),
          if (!item.hasScreenshot)
            const Text('স্ক্রিনশট নেই। পেমেন্ট আটকে থাকবে না।', style: TextStyle(height: 1.35))
          else ...[
            AppButton(label: 'স্ক্রিনশট দেখুন', kind: AppButtonKind.quiet, onPressed: onShot),
            if (shotError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(shotError!, style: const TextStyle(color: AppColors.danger))),
            if (shotUrl != null) Padding(padding: const EdgeInsets.only(top: 8), child: Image.network(shotUrl!, height: 180, fit: BoxFit.contain)),
          ],
          const SizedBox(height: 12),
          AppButton(
            key: const Key('review-approve'),
            label: 'অ্যাপ্রুভ',
            kind: AppButtonKind.current,
            busy: busy,
            onPressed: canApprovePayment(item) ? onApprove : null,
          ),
          const SizedBox(height: 8),
          if (!rejecting)
            AppButton(label: 'ফেরত দিন', kind: AppButtonKind.danger, onPressed: onStartReject)
          else ...[
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'কেন মিলল না')),
            const SizedBox(height: 8),
            AppButton(label: 'রিজেক্ট', kind: AppButtonKind.danger, busy: busy, onPressed: reason.text.trim().length < 3 ? null : onReject),
          ],
        ],
      ),
    );
  }
}
