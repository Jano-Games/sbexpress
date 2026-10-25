import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/ledger_actions.dart';
import '../../data/money_payload.dart';
import '../../l10n/l10n.dart';
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

  bool get _monthOk =>
      RegExp(r'^20\d{2}-(0[1-9]|1[0-2])$').hasMatch(_month.text.trim());

  Future<void> _load() async {
    if (!_monthOk) {
      setState(() => _error = tr('Enter the month as 2026-10.'));
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
      setState(() => _error = tr('Enter the month as 2026-10.'));
      return;
    }
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
          month: _month.text.trim(),
          days: _days,
          amount: amount);
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
    return WorkspaceScaffold(
        title: tr('Monthly statement'),
        root: false,
        subtitle: widget.code,
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr('{name}. A link can be made only when there are issued, reviewed invoices.',
                      {'name': widget.name}),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          TextField(
              controller: _month,
              decoration: InputDecoration(
                  labelText: tr('Month'),
                  helperText: tr('For example 2026-10'))),
          const SizedBox(height: 8),
          AppButton(
              label: tr('Show this month'),
              kind: AppButtonKind.quiet,
              busy: _loading,
              onPressed: _load),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorNote(message: _error!),
          ],
          if (balance != null) ...[
            const SizedBox(height: 12),
            PaperCard(
              child: Column(
                children: [
                  KvRow(label: tr('Billed'), value: formatBdt(balance.billed)),
                  KvRow(label: tr('Paid'), value: formatBdt(balance.paid)),
                  KvRow(label: tr('Due'), value: formatBdt(balance.due)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionTitle(title: tr('New link')),
            ChoiceChips(
              options: [
                (value: '7', label: tr('7 days')),
                (value: '14', label: tr('14 days')),
                (value: '30', label: tr('30 days'))
              ],
              selected: '$_days',
              onSelected: (value) => setState(() => _days = int.parse(value)),
            ),
            const SizedBox(height: 8),
            TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: tr('Requested amount (optional)'),
                    helperText:
                        tr('Leave empty to request the full due amount'))),
            const SizedBox(height: 8),
            AppButton(
                label: tr('Create and copy link'),
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _create),
            const SizedBox(height: 8),
            AppButton(
                label: tr('Revoke all links'),
                kind: AppButtonKind.danger,
                busy: _busy,
                onPressed: _revoke),
            const SizedBox(height: 16),
            SectionTitle(title: tr('Saved links')),
            if (_links.isEmpty)
              EmptyNote(
                  title: tr('No links'),
                  body: tr('Nothing shared for this month yet.')),
            for (final link in _links) ...[
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusPill(label: link.status),
                    const SizedBox(height: 6),
                    Text(link.url ?? tr('This link can no longer be copied'),
                        style: const TextStyle(height: 1.35)),
                    if (link.url != null)
                      TextButton(
                          onPressed: () =>
                              Clipboard.setData(ClipboardData(text: link.url!)),
                          child: Text(tr('Copy'))),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            SectionTitle(title: tr('Receipts')),
            if (_receipts.isEmpty)
              EmptyNote(
                  title: tr('No receipts'),
                  body: tr(
                      'Receipts customers submit on the public link will appear here.')),
            for (final receipt in _receipts) ...[
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${receipt.month} · ${formatBdt(receipt.amount)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${receipt.method} · ${receipt.status}',
                        style: const TextStyle(color: AppColors.muted)),
                    if (receipt.reason.isNotEmpty) Text(receipt.reason),
                    if (receipt.status == 'pending') ...[
                      const SizedBox(height: 8),
                      AppButton(
                          label: tr('Accept'),
                          kind: AppButtonKind.current,
                          busy: _busy,
                          onPressed: () => _approve(receipt)),
                      const SizedBox(height: 8),
                      AppButton(
                          label: tr('Reject'),
                          kind: AppButtonKind.danger,
                          busy: _busy,
                          onPressed: () => _reject(receipt)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ]);
  }
}
