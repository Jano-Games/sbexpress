import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/flight.dart';
import '../../data/models/ledger_actions.dart';
import '../../data/models/ledger_page.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/finance_parts.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/ui.dart';
import '../admin/money_format.dart';

String ledgerTypeLabel(String type) => switch (type) {
      'customer' => tr('Customer payment'),
      'customer-credit' => tr('Customer advance'),
      'flyer' => tr('Flyer payment'),
      'income' => tr('Income'),
      'capital' => tr('Owner capital'),
      'expense' => tr('Expense'),
      'refund' => tr('Refund'),
      'transfer' => tr('Transfer'),
      _ => type,
    };

String ledgerPeriodTitle(String period) => switch (period) {
      'all' => tr('All time'),
      'week' => tr('This week'),
      _ => monthTitle(period),
    };

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key, this.initialFilter});

  /// Defaults to this month, every account and type.
  final LedgerFilter? initialFilter;

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  late LedgerFilter _filter =
      widget.initialFilter ?? LedgerFilter(period: currentMonthKey());
  late final _search = TextEditingController(text: _filter.search);
  LedgerPage? _page;
  List<FinanceAccount> _accounts = const [];
  String? _error;
  var _loading = true;
  var _busy = false;
  var _request = 0;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
      _loadAccounts();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final finance = await AppScope.of(context).finance.snapshot();
      if (mounted) setState(() => _accounts = finance.accounts);
    } catch (_) {
      // The account filter still offers "All accounts".
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    final filter = _filter;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await AppScope.of(context).finance.ledger(filter);
      if (!mounted || request != _request) return;
      setState(() => _page = page);
    } on ApiException catch (error) {
      if (!mounted || request != _request || error.status == 401) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _apply(LedgerFilter filter) {
    _debounce?.cancel();
    setState(() => _filter = filter);
    _load();
  }

  void _onSearch(String text) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || text.trim() == _filter.search.trim()) return;
      _apply(_filter.copyWith(search: text, page: 1));
    });
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final months = [
      for (var i = 0; i < 12; i++) shiftMonth(monthKey(now.year, now.month), -i)
    ];
    final picked = await showChoiceSheet(context,
        title: tr('Period'),
        selected: _filter.period,
        options: [
          (value: 'all', label: tr('All time')),
          (value: 'week', label: tr('This week')),
          for (final month in months) (value: month, label: monthTitle(month)),
          if (!['all', 'week', ...months].contains(_filter.period))
            (value: _filter.period, label: monthTitle(_filter.period)),
        ]);
    if (picked != null && picked != _filter.period) {
      _apply(_filter.copyWith(period: picked, page: 1));
    }
  }

  Future<void> _pickAccount() async {
    const all = '\u0000all';
    final picked = await showChoiceSheet(context,
        title: tr('Account'),
        selected: _filter.account ?? all,
        options: [
          (value: all, label: tr('All accounts')),
          for (final account in _accounts)
            (
              value: account.name,
              label: '${account.name} · ${account.currency}'
            ),
          if (_filter.account != null &&
              _filter.account != ledgerNoAccount &&
              !_accounts.any((account) => account.name == _filter.account))
            (value: _filter.account!, label: _filter.account!),
          (value: ledgerNoAccount, label: tr('No account')),
        ]);
    if (picked == null || picked == (_filter.account ?? all)) return;
    _apply(picked == all
        ? _filter.copyWith(clearAccount: true, page: 1)
        : _filter.copyWith(account: picked, page: 1));
  }

  Future<void> _pickType() async {
    final picked = await showChoiceSheet(context,
        title: tr('Type'),
        selected: _filter.type,
        options: [
          (value: 'all', label: tr('All types')),
          for (final type in ledgerTypes)
            (value: type, label: ledgerTypeLabel(type)),
        ]);
    if (picked != null && picked != _filter.type) {
      _apply(_filter.copyWith(type: picked, page: 1));
    }
  }

  Future<void> _reverse(LedgerLine line, {LedgerLine? partner}) async {
    final reason = await askReason(context, title: tr('Reverse entry'));
    if (reason == null || !mounted) return;
    if (reason.length < 3) {
      setState(() => _error = tr('The reason must be at least 3 characters.'));
      return;
    }
    final outLine = partner == null || line.amount < 0 ? line : partner;
    final inLine = partner == null ? null : (line.amount < 0 ? partner : line);
    final ok = await confirmMoney(context,
        title: tr('Reverse ledger entry'),
        body: inLine == null
            ? tr(
                '{description} will be reversed. The money returns to the original account.',
                {
                    'description': _title(line)
                  })
            : tr(
                'Both sides of the transfer from {from} to {to} will be reversed.',
                {'from': outLine.account ?? '—', 'to': inLine.account ?? '—'}));
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppScope.of(context)
          .finance
          .reverse(kind: line.reversalKind, id: line.recordId, reason: reason);
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
    final page = _page;
    final filtered = _filter.account != null ||
        _filter.type != 'all' ||
        _filter.search.trim().isNotEmpty;
    return WorkspaceScaffold(
        title: tr('Ledger'),
        subtitle: tr('Every money movement, newest first'),
        root: false,
        onRefresh: _load,
        toolbar: Column(children: [
          SearchBox(
              key: const Key('ledger-search'),
              controller: _search,
              maxLength: 200,
              hint: tr('Description, reference or shipment'),
              onChanged: _onSearch),
          const SizedBox(height: 10),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                FilterPill(
                    key: const Key('ledger-period'),
                    label: switch (_filter.period) {
                      'all' => tr('All time'),
                      'week' => tr('This week'),
                      final month => month.startsWith('${DateTime.now().year}-')
                          ? monthOnly(month)
                          : monthTitle(month),
                    },
                    active: _filter.period != 'all',
                    onTap: _pickPeriod),
                const SizedBox(width: 8),
                FilterPill(
                    key: const Key('ledger-account'),
                    label: switch (_filter.account) {
                      null => tr('All accounts'),
                      ledgerNoAccount => tr('No account'),
                      final name => name,
                    },
                    active: _filter.account != null,
                    onTap: _pickAccount),
                const SizedBox(width: 8),
                FilterPill(
                    key: const Key('ledger-type'),
                    label: _filter.type == 'all'
                        ? tr('All types')
                        : ledgerTypeLabel(_filter.type),
                    active: _filter.type != 'all',
                    onTap: _pickType),
              ])),
        ]),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (page != null) ...[
            _TotalsHero(title: ledgerPeriodTitle(_filter.period), page: page),
            const SizedBox(height: 16),
            if (page.entries.isEmpty)
              EmptyNote(
                  icon: Icons.receipt_long_outlined,
                  title: tr('No lines'),
                  body: filtered
                      ? tr('Nothing matches these filters.')
                      : tr(
                          'Money movements appear here when they are recorded.'))
            else
              ..._days(page),
            if (page.total > 0)
              PagerBar(
                  summary:
                      '${trn(page.total, '{n} line · page {page} of {pages}', '{n} lines · page {page} of {pages}', {
                        'page': page.page,
                        'pages': page.pages
                      })} · ${tr('both sides of a transfer reverse together')}',
                  onPrevious: !page.hasPrevious || _loading
                      ? null
                      : () => _apply(_filter.copyWith(page: page.page - 1)),
                  onNext: !page.hasNext || _loading
                      ? null
                      : () => _apply(_filter.copyWith(page: page.page + 1))),
          ],
        ]);
  }

  /// Lines grouped by day, with both sides of a transfer in one card.
  List<Widget> _days(LedgerPage page) {
    final days = <String, List<Widget>>{};
    final used = <String>{};
    final reversible = <String>{};
    for (final line in page.entries) {
      if (!used.add(line.key)) continue;
      final when = localTime(line.at);
      final rows = days.putIfAbsent(
          when == null ? '—' : dayHeading(when), () => <Widget>[]);
      final canReverse = line.canReverse &&
          reversible.add('${line.reversalKind}:${line.recordId}');
      LedgerLine? partner;
      if (line.isTransfer) {
        for (final other in page.entries) {
          if (other.key != line.key &&
              other.recordId == line.recordId &&
              other.isTransfer &&
              !used.contains(other.key)) {
            partner = other;
            break;
          }
        }
      }
      if (partner != null) {
        used.add(partner.key);
        final pair = partner;
        rows.add(_TransferCard(
            out: line.amount < 0 ? line : pair,
            into: line.amount < 0 ? pair : line,
            busy: _busy,
            onReverse:
                canReverse ? () => _reverse(line, partner: pair) : null));
      } else {
        rows.add(_LineRow(
            line: line,
            title: _title(line),
            subtitle: _subtitle(line),
            busy: _busy,
            onReverse: canReverse ? () => _reverse(line) : null));
      }
    }
    return [
      for (final day in days.entries) ...[
        DayHeader(day.key),
        ListCard(children: day.value),
        const SizedBox(height: 14),
      ]
    ];
  }

  String _title(LedgerLine line) {
    if (line.isTransfer) return tr('Transfer');
    final description = line.description == 'Payment received'
        ? tr('Payment received')
        : line.description;
    final shipment = line.shipmentCode;
    if (shipment != null && !description.contains(shipment)) {
      return '$shipment · $description';
    }
    return description;
  }

  String _subtitle(LedgerLine line) => [
        line.account ?? tr('No account'),
        if (line.isTransfer && transferNote(line).isNotEmpty)
          transferNote(line)
        else
          ledgerTypeLabel(line.type),
        if (line.type == 'expense' && line.reference.isNotEmpty)
          costCategories[line.reference] ?? line.reference,
        if (line.flightCode != null) displayFlightCode(line.flightCode!),
        if (line.supplierCode != null) line.supplierCode!,
      ].join(' · ');
}

/// The note typed with a transfer; the API puts it after "To X · ".
String transferNote(LedgerLine line) {
  final cut = line.description.indexOf(' · ');
  return cut == -1 ? '' : line.description.substring(cut + 3);
}

class _TotalsHero extends StatelessWidget {
  const _TotalsHero({required this.title, required this.page});
  final String title;
  final LedgerPage page;

  @override
  Widget build(BuildContext context) {
    final bdt = page.totalFor('BDT');
    final cny = page.totalFor('CNY');
    String? extra(double value) =>
        value == 0 ? null : '+ ${formatMoney(value, 'CNY')}';
    return MoneyHero(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600))),
            Text(trn(page.total, '{n} line', '{n} lines'),
                style: const TextStyle(fontSize: 12, color: HeroColors.soft)),
          ]),
          const SizedBox(height: 12),
          IntrinsicHeight(
              child: Row(children: [
            Expanded(
                child: HeroFigure(
                    key: const Key('ledger-money-in'),
                    icon: Icons.south_west_rounded,
                    label: tr('Money in'),
                    value: formatBdt(bdt.moneyIn),
                    size: 24,
                    note: extra(cny.moneyIn))),
            const VerticalDivider(width: 28, color: HeroColors.line),
            Expanded(
                child: HeroFigure(
                    key: const Key('ledger-money-out'),
                    icon: Icons.north_east_rounded,
                    label: tr('Money out'),
                    value: formatBdt(bdt.moneyOut),
                    size: 24,
                    note: extra(cny.moneyOut))),
          ])),
        ]);
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow(
      {required this.line,
      required this.title,
      required this.subtitle,
      required this.busy,
      required this.onReverse});
  final LedgerLine line;
  final String title, subtitle;
  final bool busy;
  final VoidCallback? onReverse;

  @override
  Widget build(BuildContext context) {
    final into = line.amount > 0;
    final (icon, tone) = line.isReversal
        ? (Icons.undo_rounded, ChipTone.neutral)
        : line.isTransfer
            ? (Icons.swap_horiz_rounded, ChipTone.blue)
            : into
                ? (Icons.south_west_rounded, ChipTone.green)
                : (Icons.north_east_rounded, ChipTone.neutral);
    return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              IconBadge(icon, tone: tone, size: 36),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Flexible(
                          child: Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600))),
                      if (line.isReversal || line.isReversed) ...[
                        const SizedBox(width: 6),
                        Flexible(
                            child: StatusPill(
                                label: line.isReversal
                                    ? tr('Reversal')
                                    : tr('Reversed'),
                                tone: ChipTone.neutral)),
                      ],
                    ]),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, height: 1.4, color: AppColors.muted)),
                  ])),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(signedMoney(line.amount, line.currency),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: into ? AppColors.ok : AppColors.ink,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                if (onReverse != null)
                  DangerLink(
                      label: tr('Reverse'), onPressed: busy ? null : onReverse),
              ]),
            ])));
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard(
      {required this.out,
      required this.into,
      required this.busy,
      required this.onReverse});
  final LedgerLine out, into;
  final bool busy;
  final VoidCallback? onReverse;

  @override
  Widget build(BuildContext context) {
    final note = transferNote(out);
    Widget side(LedgerLine line) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 0, 6),
        child: SplitRow(
            maxFraction: 0.6,
            start: Text(line.account ?? tr('No account'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: AppColors.inkSoft)),
            end: FitAmount(signedMoney(line.amount, line.currency),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: line.amount > 0 ? AppColors.ok : AppColors.ink))));
    return Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconBadge(
                out.isReversal ? Icons.undo_rounded : Icons.swap_horiz_rounded,
                tone: out.isReversal ? ChipTone.neutral : ChipTone.blue,
                size: 36),
            const SizedBox(width: 12),
            Expanded(
                child: SplitRow(
                    start: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(
                                child: Text(tr('Transfer'),
                                    style: const TextStyle(
                                        fontSize: 15,
                                        height: 1.35,
                                        fontWeight: FontWeight.w600))),
                            if (out.isReversal || out.isReversed) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                  child: StatusPill(
                                      label: out.isReversal
                                          ? tr('Reversal')
                                          : tr('Reversed'),
                                      tone: ChipTone.neutral)),
                            ],
                          ]),
                          if (note.isNotEmpty)
                            Text(note,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: AppColors.muted)),
                        ]),
                    end: onReverse == null
                        ? const SizedBox.shrink()
                        : DangerLink(
                            key: Key('ledger-reverse-${out.recordId}'),
                            label: tr('Reverse both'),
                            onPressed: busy ? null : onReverse))),
          ]),
          Container(
              margin: const EdgeInsetsDirectional.only(start: 48, top: 6),
              decoration: const BoxDecoration(
                  border: BorderDirectional(
                      start: BorderSide(color: AppColors.line, width: 2))),
              child: Column(children: [side(out), side(into)])),
        ]));
  }
}
