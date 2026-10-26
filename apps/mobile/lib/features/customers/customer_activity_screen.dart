import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/customer_activity.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/finance_parts.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/ui.dart';
import '../admin/admin_shipment_screen.dart';
import '../admin/money_format.dart';

class CustomerActivityScreen extends StatefulWidget {
  const CustomerActivityScreen(
      {super.key, required this.code, required this.name});

  final String code;
  final String name;

  @override
  State<CustomerActivityScreen> createState() => _CustomerActivityScreenState();
}

class _CustomerActivityScreenState extends State<CustomerActivityScreen> {
  CustomerActivityPage? _page;
  String? _error;
  var _loading = true;
  var _busy = false;
  var _pageNumber = 1;

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
      final page = await AppScope.of(context)
          .customers
          .activity(widget.code, page: _pageNumber);
      if (!mounted) return;
      setState(() => _page = page);
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

  Future<void> _reverse(CustomerActivityEntry entry) async {
    final reason = await askReason(context, title: tr('Reverse entry'));
    if (reason == null || !mounted) return;
    if (reason.length < 3) {
      setState(() => _error = tr('The reason must be at least 3 characters.'));
      return;
    }
    final ok = await confirmMoney(
      context,
      title: tr('Reverse transaction'),
      body: tr('{label} {amount} will be reversed.', {
        'label': activityLabel(entry.label),
        'amount': formatBdt(entry.amount)
      }),
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context)
          .finance
          .reverse(kind: entry.reversalKind, id: entry.id, reason: reason);
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _go(int page) {
    setState(() => _pageNumber = page);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final pages = page == null || page.limit <= 0
        ? 1
        : (page.total / page.limit).ceil().clamp(1, 1 << 30);
    final hasNext = page != null && page.page * page.limit < page.total;
    final groups = <String, List<CustomerActivityEntry>>{};
    for (final entry in page?.entries ?? const <CustomerActivityEntry>[]) {
      final when = localTime(entry.at);
      groups
          .putIfAbsent(when == null ? '—' : dayHeading(when), () => [])
          .add(entry);
    }
    return WorkspaceScaffold(
        title: tr('Account activity'),
        subtitle: '${widget.name} · ${widget.code}',
        root: false,
        onRefresh: _load,
        actions: [
          if (page != null && page.total > 0)
            Center(
                child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: StatusPill(
                        label: trn(page.total, '{n} line', '{n} lines'),
                        tone: ChipTone.neutral))),
        ],
        children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
              child: Wrap(spacing: 14, runSpacing: 6, children: [
                LegendDot(color: AppColors.ok, label: tr('Money in')),
                LegendDot(color: AppColors.inkSoft, label: tr('Money out')),
                LegendDot(color: AppColors.primary, label: tr('Credit')),
                Text('· ${tr('Amounts in BDT')}',
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.muted)),
              ])),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (page != null && page.entries.isEmpty)
            EmptyNote(
                icon: Icons.history_rounded,
                title: tr('No activity'),
                body:
                    tr('Money movements appear here when they are recorded.')),
          for (final group in groups.entries) ...[
            DayHeader(group.key),
            ListCard(children: [
              for (final entry in group.value)
                _ActivityRow(
                    entry: entry,
                    busy: _busy,
                    onReverse: () => _reverse(entry),
                    onShipment: entry.shipmentCode == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => AdminShipmentScreen(
                                    code: entry.shipmentCode!)))),
            ]),
            const SizedBox(height: 14),
          ],
          if (page != null && page.total > 0)
            PagerBar(
                summary: trn(
                    page.total,
                    '{n} line · page {page} of {pages}',
                    '{n} lines · page {page} of {pages}',
                    {'page': page.page, 'pages': pages}),
                onPrevious: page.page <= 1 || _loading
                    ? null
                    : () => _go(page.page - 1),
                onNext: !hasNext || _loading ? null : () => _go(page.page + 1)),
        ]);
  }
}

enum _Flow { moneyIn, moneyOut, credit }

class _ActivityRow extends StatelessWidget {
  const _ActivityRow(
      {required this.entry,
      required this.busy,
      required this.onReverse,
      required this.onShipment});
  final CustomerActivityEntry entry;
  final bool busy;
  final VoidCallback onReverse;
  final VoidCallback? onShipment;

  bool get _isCredit =>
      entry.reversalKind == 'credit' ||
      entry.label == 'Credit applied' ||
      entry.label == 'Credit adjustment';

  @override
  Widget build(BuildContext context) {
    final flow = _isCredit
        ? _Flow.credit
        : entry.amount < 0
            ? _Flow.moneyOut
            : _Flow.moneyIn;
    final (icon, tone, color) = switch (flow) {
      _Flow.moneyIn => (Icons.south_west_rounded, ChipTone.green, AppColors.ok),
      _Flow.moneyOut => (
          Icons.north_east_rounded,
          ChipTone.neutral,
          AppColors.ink
        ),
      _Flow.credit => (
          entry.label == 'Credit applied'
              ? Icons.sell_outlined
              : Icons.tune_rounded,
          ChipTone.blue,
          AppColors.primaryInk
        ),
    };
    final amount = flow == _Flow.credit && entry.label == 'Credit applied'
        ? formatBdt(entry.amount.abs())
        : signedMoney(entry.amount, 'BDT');
    final when = localTime(entry.at);
    final source = entry.accountName ?? tr('From credit balance');
    final cny = entry.sourceCurrency == 'CNY';
    const meta = TextStyle(fontSize: 13, height: 1.45, color: AppColors.muted);
    const note =
        TextStyle(fontSize: 13, height: 1.45, color: AppColors.inkSoft);
    final hasFooter = onShipment != null || entry.canReverse;
    return Padding(
        padding: EdgeInsets.fromLTRB(14, 14, 14, hasFooter ? 4 : 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconBadge(icon, tone: tone),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                SplitRow(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    start: Text(activityLabel(entry.label),
                        style: const TextStyle(
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w700)),
                    end: FitAmount(amount,
                        style: TextStyle(
                            fontSize: 16,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: color))),
                _pair(
                    Text(
                        [source, if (when != null) clockTime(when)].join(' · '),
                        style: meta),
                    cny
                        ? FitAmount(
                            flow == _Flow.credit &&
                                    entry.label == 'Credit applied'
                                ? formatMoney(entry.sourceAmount.abs(),
                                    entry.sourceCurrency)
                                : signedSource(entry),
                            style: const TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                                color: AppColors.inkSoft))
                        : null),
                if (entry.reference.isNotEmpty || cny)
                  _pair(
                      entry.reference.isEmpty
                          ? const SizedBox.shrink()
                          : Text(
                              tr('Ref {reference}',
                                  {'reference': entry.reference}),
                              style: note),
                      cny
                          ? FitAmount(
                              tr('1 CNY = {rate}',
                                  {'rate': formatBdt(entry.sourceFxRate)}),
                              style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: AppColors.muted))
                          : null),
                if (entry.reason.isNotEmpty)
                  Text(tr('Reason: {reason}', {'reason': entry.reason}),
                      style: note),
                if (hasFooter)
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (onShipment != null)
                          Flexible(
                              child: ShipmentChip(
                                  code: entry.shipmentCode!,
                                  onTap: onShipment!))
                        else
                          const SizedBox.shrink(),
                        if (entry.canReverse)
                          Flexible(
                              child: DangerLink(
                                  label: tr('Reverse'),
                                  icon: Icons.undo_rounded,
                                  onPressed: busy ? null : onReverse)),
                      ]),
              ])),
        ]));
  }

  static Widget _pair(Widget start, Widget? end) => end == null
      ? start
      : SplitRow(
          crossAxisAlignment: CrossAxisAlignment.start, start: start, end: end);

  /// The original-currency amount carries the sign of the BDT amount.
  static String signedSource(CustomerActivityEntry entry) {
    final sign = entry.amount < 0 ? -1.0 : 1.0;
    return formatMoney(sign * entry.sourceAmount.abs(), entry.sourceCurrency);
  }
}
