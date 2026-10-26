import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/ledger_actions.dart';
import '../../data/money_payload.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/finance_parts.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/ui.dart';
import '../admin/money_format.dart';

class StatementScreen extends StatefulWidget {
  const StatementScreen(
      {super.key, required this.code, required this.name, this.month});

  final String code;
  final String name;

  /// `YYYY-MM`; the current month when null.
  final String? month;

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  final _amount = TextEditingController();
  late String _month;
  List<StatementLinkInfo> _links = const [];
  List<StatementReceiptInfo> _receipts = const [];
  StatementBalance? _balance;
  String? _error;
  var _days = 7;
  var _loading = true;
  var _busy = false;

  static const _dayOptions = [7, 14, 30];

  @override
  void initState() {
    super.initState();
    final start = widget.month;
    _month = start != null && _isMonth(start) ? start : currentMonthKey();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  static bool _isMonth(String text) =>
      RegExp(r'^20\d{2}-(0[1-9]|1[0-2])$').hasMatch(text);

  bool get _atLatest => _month.compareTo(currentMonthKey()) >= 0;

  void _step(int delta) {
    final next = shiftMonth(_month, delta);
    if (!_isMonth(next) || _busy) return;
    setState(() {
      _month = next;
      _balance = null;
      _links = const [];
    });
    _load();
  }

  Future<void> _load() async {
    final month = _month;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scope = AppScope.of(context).customers;
      final page = await scope.statementLinks(widget.code, month);
      final receipts = await scope.statementReceipts(widget.code);
      if (!mounted || month != _month) return;
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
    final amount =
        _amount.text.trim().isEmpty ? null : parseMoney(_amount.text);
    if (_amount.text.trim().isNotEmpty && (amount == null || amount <= 0)) {
      setState(() => _error =
          tr('Leave the requested amount empty or enter a positive amount.'));
      return;
    }
    final due = _balance?.due;
    if (amount != null && due != null && amount > due + 0.001) {
      setState(() => _error = tr('The request cannot exceed the {amount} due.',
          {'amount': formatBdt(due)}));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await AppScope.of(context).customers.createStatementLink(
          widget.code,
          month: _month,
          days: _days,
          amount: amount);
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: link.url));
      _amount.clear();
      if (mounted) _copied();
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _copied() => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(tr('Link copied'))));

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) _copied();
  }

  Future<void> _revoke() async {
    final ok = await confirmMoney(context,
        title: tr('Revoke all links'),
        body: tr("This customer's active statement links will stop opening."));
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
    final ok = await confirmMoney(context,
        title: tr('Approve receipt'),
        body: tr('{amount} via {method} will be recorded as received.',
            {'amount': formatBdt(receipt.amount), 'method': receipt.method}));
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context)
          .customers
          .approveStatementReceipt(widget.code, receipt.reference);
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(StatementReceiptInfo receipt) async {
    final reason = await askReason(context, title: tr('Reject receipt'));
    if (reason == null || !mounted) return;
    if (reason.length < 3) {
      setState(() => _error = tr('The reason must be at least 3 characters.'));
      return;
    }
    setState(() => _busy = true);
    try {
      await AppScope.of(context)
          .customers
          .rejectStatementReceipt(widget.code, receipt.reference, reason);
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
    final pending =
        _receipts.where((receipt) => receipt.status == 'pending').length;
    return WorkspaceScaffold(
        title: tr('Monthly statement'),
        subtitle: '${widget.name} · ${widget.code}',
        root: false,
        onRefresh: _load,
        children: [
          _MonthHero(
              month: _month,
              balance: balance,
              loading: _loading,
              onPrevious: _busy ? null : () => _step(-1),
              onNext: _busy || _atLatest ? null : () => _step(1)),
          const SizedBox(height: 14),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          SectionTitle(
              title: tr('Receipts'),
              action: pending == 0
                  ? null
                  : StatusPill(
                      label: tr('{n} to review', {'n': pending}),
                      tone: ChipTone.amber)),
          if (_receipts.isEmpty)
            EmptyNote(
                icon: Icons.receipt_long_outlined,
                title: tr('No receipts'),
                body: tr(
                    'Receipts customers submit on the public link will appear here.'))
          else
            ListCard(children: [
              for (final receipt in [
                ..._receipts.where((row) => row.status == 'pending'),
                ..._receipts.where((row) => row.status != 'pending'),
              ])
                _ReceiptRow(
                    receipt: receipt,
                    busy: _busy,
                    onAccept: () => _approve(receipt),
                    onReject: () => _reject(receipt)),
            ]),
          if (balance != null) ...[
            const SizedBox(height: 16),
            _NewLinkCard(
                amount: _amount,
                days: _days,
                options: _dayOptions,
                due: balance.due,
                busy: _busy,
                onDays: (days) => setState(() => _days = days),
                onCreate: _create),
            const SizedBox(height: 20),
            SectionTitle(
                title: tr('Saved links'),
                action: _links.isEmpty
                    ? null
                    : DangerLink(
                        key: const Key('statement-revoke'),
                        label: tr('Revoke all'),
                        icon: Icons.link_off_rounded,
                        onPressed: _busy ? null : _revoke)),
            if (_links.isEmpty)
              EmptyNote(
                  icon: Icons.link_rounded,
                  title: tr('No links'),
                  body: tr('Nothing shared for this month yet.'))
            else
              ListCard(children: [
                for (final link in _links)
                  _LinkRow(
                      link: link,
                      onCopy: link.url == null ? null : () => _copy(link.url!)),
              ]),
          ],
        ]);
  }
}

class _MonthHero extends StatelessWidget {
  const _MonthHero(
      {required this.month,
      required this.balance,
      required this.loading,
      required this.onPrevious,
      required this.onNext});
  final String month;
  final StatementBalance? balance;
  final bool loading;
  final VoidCallback? onPrevious, onNext;

  @override
  Widget build(BuildContext context) {
    final figures = balance;
    return MoneyHero(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
        children: [
          Row(children: [
            HeroStepButton(
                key: const Key('statement-previous'),
                icon: Icons.chevron_left_rounded,
                tooltip: tr('Previous month'),
                onPressed: onPrevious),
            const SizedBox(width: 8),
            Expanded(
                child: Column(children: [
              Text(tr('Statement month'),
                  style: const TextStyle(fontSize: 12, color: HeroColors.soft)),
              Text(monthTitle(month),
                  key: const Key('statement-month'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, height: 1.3, fontWeight: FontWeight.w700)),
            ])),
            const SizedBox(width: 8),
            HeroStepButton(
                key: const Key('statement-next'),
                icon: Icons.chevron_right_rounded,
                tooltip: tr('Next month'),
                onPressed: onNext),
          ]),
          const SizedBox(height: 12),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HeroAmount(
                        label:
                            tr('Due for {month}', {'month': monthOnly(month)}),
                        value: figures == null ? '—' : formatBdt(figures.due),
                        color: figures != null && figures.due > 0
                            ? HeroColors.due
                            : Colors.white),
                    if (loading && figures == null) ...[
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(
                          color: Colors.white,
                          backgroundColor: HeroColors.track),
                    ],
                    const SizedBox(height: 12),
                    const HeroDivider(),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: HeroFigure(
                              label: tr('Billed'),
                              value: figures == null
                                  ? '—'
                                  : formatBdt(figures.billed))),
                      const SizedBox(width: 16),
                      Expanded(
                          child: HeroFigure(
                              label: tr('Paid'),
                              value: figures == null
                                  ? '—'
                                  : formatBdt(figures.paid))),
                    ]),
                  ])),
        ]);
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow(
      {required this.receipt,
      required this.busy,
      required this.onAccept,
      required this.onReject});
  final StatementReceiptInfo receipt;
  final bool busy;
  final VoidCallback onAccept, onReject;

  @override
  Widget build(BuildContext context) {
    final waiting = receipt.status == 'pending';
    final (icon, tone, label) = switch (receipt.status) {
      'pending' => (Icons.receipt_long_outlined, ChipTone.amber, tr('Waiting')),
      'approved' => (Icons.check_rounded, ChipTone.green, tr('Accepted')),
      'rejected' => (Icons.close_rounded, ChipTone.red, tr('Rejected')),
      _ => (Icons.receipt_long_outlined, ChipTone.neutral, receipt.status),
    };
    final body = Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconBadge(icon, tone: tone),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(formatBdt(receipt.amount),
                      style: TextStyle(
                          fontSize: waiting ? 18 : 15,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                  Text(
                      '${receipt.method} · ${tr('{month} statement', {
                            'month': monthOnly(receipt.month)
                          })}',
                      style: const TextStyle(
                          fontSize: 13, height: 1.4, color: AppColors.muted)),
                  if (receipt.reason.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('“${receipt.reason}”',
                            style: const TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: AppColors.inkSoft))),
                ])),
            const SizedBox(width: 8),
            StatusPill(label: label, tone: tone),
          ]),
          if (waiting) ...[
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, box) {
              final reject = AppButton(
                  key: Key('receipt-reject-${receipt.reference}'),
                  label: tr('Reject'),
                  icon: Icons.close_rounded,
                  kind: AppButtonKind.danger,
                  onPressed: busy ? null : onReject);
              final accept = AppButton(
                  key: Key('receipt-accept-${receipt.reference}'),
                  label: tr('Accept'),
                  icon: Icons.check_rounded,
                  kind: AppButtonKind.current,
                  busy: busy,
                  onPressed: onAccept);
              // Side by side as designed; stacked when large text leaves
              // too little room for the labels.
              final scale = MediaQuery.textScalerOf(context).scale(1);
              if (box.maxWidth < 280 * scale) {
                return Column(children: [
                  accept,
                  const SizedBox(height: 8),
                  reject,
                ]);
              }
              return Row(children: [
                Expanded(flex: 5, child: reject),
                const SizedBox(width: 10),
                Expanded(flex: 7, child: accept),
              ]);
            }),
          ],
        ]));
    if (!waiting) return body;
    return DecoratedBox(
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.accentLine, width: 1.5),
            borderRadius: BorderRadius.circular(cardRadius)),
        child: body);
  }
}

class _NewLinkCard extends StatelessWidget {
  const _NewLinkCard(
      {required this.amount,
      required this.days,
      required this.options,
      required this.due,
      required this.busy,
      required this.onDays,
      required this.onCreate});
  final TextEditingController amount;
  final int days;
  final List<int> options;
  final double due;
  final bool busy;
  final ValueChanged<int> onDays;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => PaperCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('New payment link'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        Text(tr('Only issued, reviewed invoices can be shared.'),
            style: const TextStyle(
                fontSize: 13, height: 1.45, color: AppColors.muted)),
        const SizedBox(height: 14),
        FieldLabel(tr('Link works for')),
        ScreenTabs(
            labels: [
              tr('7 days'),
              tr('14 days'),
              tr('30 days'),
            ],
            index: options.indexOf(days).clamp(0, options.length - 1),
            onChanged: (i) => onDays(options[i])),
        const SizedBox(height: 14),
        FieldLabel(tr('Requested amount (optional)')),
        MoneyField(
            key: const Key('statement-amount'),
            controller: amount,
            hint: due.toStringAsFixed(2)),
        FieldHint(tr('Leave empty to ask for the full {amount} due.',
            {'amount': formatBdt(due)})),
        const SizedBox(height: 14),
        AppButton(
            key: const Key('statement-create'),
            label: tr('Create and copy link'),
            icon: Icons.link_rounded,
            kind: AppButtonKind.current,
            busy: busy,
            onPressed: onCreate),
      ]));
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link, required this.onCopy});
  final StatementLinkInfo link;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final ends = localTime(link.expiresAt);
    final (label, tone, dateText) = switch (link.status) {
      'active' => (
          tr('Active'),
          ChipTone.green,
          ends == null ? null : tr('Until {date}', {'date': shortDate(ends)})
        ),
      'expired' => (
          tr('Expired'),
          ChipTone.neutral,
          ends == null ? null : tr('Ended {date}', {'date': shortDate(ends)})
        ),
      'revoked' => (tr('Revoked'), ChipTone.red, null),
      _ => (link.status, ChipTone.neutral, null),
    };
    final active = link.status == 'active';
    return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      StatusPill(label: label, tone: tone),
                      if (dateText != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                            child: Text(dateText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.muted))),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(
                        link.url == null
                            ? tr('This link can no longer be copied')
                            : link.url!.replaceFirst(RegExp(r'^https?://'), ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: link.url == null ? 13 : 14,
                            fontWeight: link.url == null
                                ? FontWeight.w400
                                : active
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                            color: link.url == null
                                ? AppColors.muted
                                : active
                                    ? AppColors.ink
                                    : AppColors.inkSoft)),
                  ])),
              if (onCopy != null) ...[
                const SizedBox(width: 8),
                IconButton(
                    tooltip: tr('Copy'),
                    onPressed: onCopy,
                    style: IconButton.styleFrom(
                        backgroundColor:
                            active ? AppColors.primarySoft : Colors.transparent,
                        foregroundColor:
                            active ? AppColors.primary : AppColors.inkSoft,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(controlRadius))),
                    icon: const Icon(Icons.copy_rounded, size: 19)),
              ] else
                const SizedBox(width: 8),
            ])));
  }
}
