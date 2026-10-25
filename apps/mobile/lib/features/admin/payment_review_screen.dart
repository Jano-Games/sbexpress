import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/payment_review.dart';
import '../../l10n/l10n.dart';
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
        if (!queue.all.any((item) => _key(item) == _selected)) _selected = null;
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

  String _key(PaymentReviewItem item) =>
      '${item.kind.name}:${item.recordLabel}:${item.txnRef}';

  PaymentReviewItem? get _current {
    final queue = _queue;
    if (queue == null) return null;
    for (final item in queue.all) {
      if (_key(item) == _selected) return item;
    }
    return null;
  }

  Future<void> _approve(PaymentReviewItem item) async {
    if (!canApprovePayment(item) || _busy) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context).review.approve(item);
      if (!mounted) return;
      _selected = null;
      _shotError = null;
      _shotUrl = null;
      _reason.clear();
      _rejecting = false;
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
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
      if (!mounted) return;
      _selected = null;
      _shotError = null;
      _shotUrl = null;
      _reason.clear();
      _rejecting = false;
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
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
      final url =
          await AppScope.of(context).review.screenshotUrl(shot.reference);
      if (!mounted || _selected != _key(item)) return;
      setState(() => _shotUrl = url);
    } on ApiException catch (error) {
      if (!mounted || _selected != _key(item) || error.status == 401) return;
      setState(() => _shotError = error.message);
    }
  }

  void _backToQueue() {
    if (_busy) return;
    setState(() {
      _selected = null;
      _shotUrl = null;
      _shotError = null;
      _error = null;
      _rejecting = false;
      _reason.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final queue = _queue;
    final current = _current;
    final pending = queue?.all.length ?? 0;
    return PopScope(
      canPop: current == null && !_busy,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _backToQueue();
      },
      child: Scaffold(
        appBar: BackTitle(
            title:
                current == null ? tr('Payment review') : tr('Review receipt'),
            subtitle: current == null
                ? null
                : '${current.recordLabel} · ${current.kind == ReviewKind.shipment ? tr('Shipment') : tr('Monthly statement')}',
            actions: [
              if (current == null && pending > 0)
                Center(
                    child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: StatusPill(
                            label: tr('{n} pending', {'n': pending}),
                            tone: ChipTone.amber))),
            ],
            onBack: current == null ? null : _backToQueue),
        body: RefreshIndicator(
          onRefresh: _busy ? () async {} : _load,
          child: ListView(
            key: ValueKey(_selected ?? 'review-queue'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(pageGutter, 16, pageGutter, 32),
            children: [
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) ErrorNote(message: _error!, onRetry: _load),
              if (current == null) ...[
                PageHeader(
                    title: tr('Awaiting review'),
                    subtitle: queue == null
                        ? tr('Loading receipts')
                        : trn(
                            queue.all.length,
                            '{n} receipt · open it to match the transaction',
                            '{n} receipts · open each to match the transaction')),
                if (queue != null && queue.all.isEmpty)
                  EmptyNote(
                      icon: Icons.fact_check_outlined,
                      title: tr('No receipts awaiting review'),
                      body: tr('New receipts will appear here.')),
                if (queue != null)
                  for (final item in queue.all) ...[
                    _ReviewCard(
                        item: item,
                        onTap: () => setState(() {
                              _selected = _key(item);
                              _shotUrl = null;
                              _shotError = null;
                              _rejecting = false;
                              _reason.clear();
                            })),
                    const SizedBox(height: 10),
                  ],
              ] else
                _Detail(
                    item: current,
                    position: queue!.all.indexOf(current) + 1,
                    total: queue.all.length,
                    shotUrl: _shotUrl,
                    shotError: _shotError,
                    rejecting: _rejecting,
                    reason: _reason,
                    busy: _busy,
                    onShot: () => _loadShot(current),
                    onReject: () => _reject(current),
                    onCancelReject: () => setState(() => _rejecting = false)),
            ],
          ),
        ),
        bottomNavigationBar: current == null || _rejecting
            ? null
            : ActionFooter(
                child: Row(children: [
                Expanded(
                    flex: 2,
                    child: AppButton(
                        label: tr('Return'),
                        kind: AppButtonKind.danger,
                        onPressed: _busy
                            ? null
                            : () => setState(() => _rejecting = true))),
                const SizedBox(width: 10),
                Expanded(
                    flex: 3,
                    child: AppButton(
                        key: const Key('review-approve'),
                        label: tr('Approve'),
                        icon: Icons.check_rounded,
                        busy: _busy,
                        onPressed: canApprovePayment(current)
                            ? () => _approve(current)
                            : null)),
              ])),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.item, required this.onTap});
  final PaymentReviewItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PaperCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IconBadge(Icons.receipt_long_outlined, tone: ChipTone.amber),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(item.supplierName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                Text('${item.recordLabel} · ${item.method}',
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 8),
                Text(formatBdt(item.amount),
                    style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()])),
                const SizedBox(height: 6),
                InfoChip(
                    icon: item.hasScreenshot
                        ? Icons.image_outlined
                        : Icons.tag_rounded,
                    label: item.hasScreenshot
                        ? tr('Screenshot attached')
                        : tr('Transaction ID only')),
              ])),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.faint, size: 22),
        ]),
      );
}

class _Detail extends StatelessWidget {
  const _Detail(
      {required this.item,
      required this.position,
      required this.total,
      required this.shotUrl,
      required this.shotError,
      required this.rejecting,
      required this.reason,
      required this.busy,
      required this.onShot,
      required this.onReject,
      required this.onCancelReject});
  final PaymentReviewItem item;
  final int position, total;
  final String? shotUrl;
  final String? shotError;
  final bool rejecting;
  final TextEditingController reason;
  final bool busy;
  final VoidCallback onShot, onReject, onCancelReject;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (total > 1)
          Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(
                  tr('Receipt {position} of {total}',
                      {'position': position, 'total': total}),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft))),
        PaperCard(
            radius: heroRadius,
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: InfoChip(
                            icon: Icons.account_balance_wallet_outlined,
                            label: item.method))),
                const SizedBox(width: 8),
                const Icon(Icons.schedule_rounded,
                    size: 15, color: AppColors.muted),
                const SizedBox(width: 4),
                Text(item.date,
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.muted)),
              ]),
              const SizedBox(height: 14),
              Text(tr('To be received · BDT'),
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              Text(formatBdt(item.amount),
                  style: const TextStyle(
                      fontSize: 34,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()])),
              if (item.sourceCurrency != 'BDT')
                Text(
                    tr('Customer sent {amount}', {
                      'amount':
                          '${item.sourceCurrency} ${item.sourceAmount.toStringAsFixed(2)}'
                    }),
                    style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 10),
              const Divider(height: 1),
              _Line(
                  label: item.kind == ReviewKind.shipment
                      ? tr('Shipment')
                      : tr('Statement'),
                  value: item.recordLabel),
              _Line(label: tr('Customer'), value: item.supplierName),
              _Line(
                  label: tr('Transaction ID'),
                  value: item.txnRef,
                  trailing: IconButton(
                      tooltip: tr('Copy transaction ID'),
                      color: AppColors.primary,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: item.txnRef));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(tr('Transaction ID copied'))));
                        }
                      })),
              _Line(label: tr('Submitted on'), value: item.date, last: true),
            ])),
        const SizedBox(height: 14),
        if (!item.hasScreenshot)
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.field, width: 1.5)),
              child: Row(children: [
                const IconBadge(Icons.hide_image_outlined,
                    tone: ChipTone.neutral, round: true),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(tr('No screenshot attached'),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(tr('Optional — you can also approve by matching the transaction ID'),
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                              height: 1.45)),
                    ])),
              ]))
        else
          PaperCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Text(tr('Proof of payment'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                if (shotUrl == null)
                  AppButton(
                      label: tr('View screenshot'),
                      icon: Icons.image_outlined,
                      kind: AppButtonKind.tonal,
                      onPressed: onShot),
                if (shotError != null)
                  ErrorNote(message: shotError!, onRetry: onShot),
                if (shotUrl != null) ...[
                  InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => showDialog<void>(
                          context: context,
                          builder: (context) => Dialog.fullscreen(
                                backgroundColor: AppColors.ink,
                                child: SafeArea(
                                    child: Column(children: [
                                  Align(
                                      alignment: Alignment.centerRight,
                                      child: IconButton(
                                          tooltip: tr('Close'),
                                          icon: const Icon(Icons.close,
                                              color: Colors.white),
                                          onPressed: () =>
                                              Navigator.pop(context))),
                                  Expanded(
                                      child: InteractiveViewer(
                                          minScale: 0.5,
                                          maxScale: 5,
                                          child: Center(
                                              child: Image.network(shotUrl!,
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, error,
                                                          stack) =>
                                                      Text(tr('Could not load image'),
                                                          style: const TextStyle(
                                                              color: Colors
                                                                  .white)))))),
                                ])),
                              )),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(shotUrl!,
                              height: 220,
                              fit: BoxFit.contain,
                              errorBuilder: (_, error, stack) => ErrorNote(
                                  message: tr('Could not load image'),
                                  onRetry: onShot)))),
                  const SizedBox(height: 8),
                  Text(tr('Tap the image to enlarge'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                ],
              ])),
        const SizedBox(height: 14),
        HintNote(
            text: item.method.isEmpty
                ? tr('Approve once you are sure the money reached the account.')
                : tr(
                    'Match the ID and amount on the {method} statement, then approve.',
                    {'method': item.method})),
        if (rejecting) ...[
          const SizedBox(height: 18),
          SectionTitle(title: tr('Return receipt')),
          TextField(
              controller: reason,
              minLines: 2,
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                  labelText: tr('Reason for return'),
                  hintText: tr('Say which transaction detail did not match'))),
          const SizedBox(height: 12),
          AppButton(
              label: tr('Confirm return'),
              kind: AppButtonKind.danger,
              busy: busy,
              onPressed: reason.text.trim().length < 3 ? null : onReject),
          const SizedBox(height: 4),
          TextButton(
              onPressed: busy ? null : onCancelReject,
              child: Text(tr('Cancel'))),
        ],
      ]);
}

class _Line extends StatelessWidget {
  const _Line(
      {required this.label,
      required this.value,
      this.trailing,
      this.last = false});
  final String label, value;
  final Widget? trailing;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
      constraints: const BoxConstraints(minHeight: 50),
      decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.lineSoft))),
      child: Row(children: [
        Text(label,
            style: const TextStyle(fontSize: 14, color: AppColors.muted)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600))),
        if (trailing != null) trailing!,
      ]));
}
