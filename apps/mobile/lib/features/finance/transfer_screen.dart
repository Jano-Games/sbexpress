import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/money_payload.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/finance_parts.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/ui.dart';
import '../admin/money_format.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  List<FinanceAccount> _accounts = const [];
  final _amount = TextEditingController();
  final _received = TextEditingController();
  final _note = TextEditingController();
  String? _from;
  String? _to;
  String? _error;
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _received.dispose();
    _note.dispose();
    super.dispose();
  }

  FinanceAccount? _find(String? name) {
    for (final account in _accounts) {
      if (account.name == name) return account;
    }
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final finance = await AppScope.of(context).finance.snapshot();
      if (!mounted) return;
      setState(() => _accounts = finance.accounts);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final from = _find(_from);
    final to = _find(_to);
    final amount = parseMoney(_amount.text);
    final note = _note.text.trim();
    if (from == null ||
        to == null ||
        from.name == to.name ||
        amount == null ||
        amount <= 0 ||
        note.isEmpty ||
        note.length > 200) {
      setState(() => _error = tr(
          'Choose two different accounts, an amount and a 1–200 character note.'));
      return;
    }
    final source = from;
    final dest = to;
    double? received;
    if (source.currency != dest.currency) {
      received = parseMoney(_received.text);
      if (received == null || received <= 0) {
        setState(() => _error = tr(
            'Enter the amount arriving in the {currency} account.',
            {'currency': dest.currency}));
        return;
      }
    }
    final body = received == null
        ? tr('{amount} moves from {from} to {to}.', {
            'amount': formatMoney(amount, source.currency),
            'from': source.name,
            'to': dest.name
          })
        : tr('{amount} leaves {from} and {received} arrives in {to}.', {
            'amount': formatMoney(amount, source.currency),
            'from': source.name,
            'received': formatMoney(received, dest.currency),
            'to': dest.name
          });
    final ok = await confirmMoney(context, title: tr('Transfer'), body: body);
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).finance.transfer(
          from: source.name,
          to: dest.name,
          amount: amount,
          note: note,
          receivedAmount: received);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "1 CNY = ৳17.50" from what leaves and what arrives.
  String? _rate(
      FinanceAccount from, FinanceAccount to, double? sent, double? received) {
    if (sent == null || received == null || sent <= 0 || received <= 0) {
      return null;
    }
    if (from.currency == 'BDT' && to.currency == 'CNY') {
      return tr('1 CNY = {rate}', {'rate': formatBdt(sent / received)});
    }
    if (from.currency == 'CNY' && to.currency == 'BDT') {
      return tr('1 CNY = {rate}', {'rate': formatBdt(received / sent)});
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final from = _find(_from);
    final to = _find(_to);
    final cross = from != null && to != null && from.currency != to.currency;
    final sent = parseMoney(_amount.text);
    final received = cross ? parseMoney(_received.text) : sent;
    final rate = cross ? _rate(from, to, sent, received) : null;
    final showAfter = from != null &&
        to != null &&
        from.name != to.name &&
        sent != null &&
        sent > 0 &&
        received != null &&
        received > 0;
    return WorkspaceScaffold(
        title: tr('Account transfer'),
        subtitle: tr('From one fund to another. Profit does not change.'),
        root: false,
        footer: ActionFooter(
            child: AppButton(
                key: const Key('transfer-save'),
                label: tr('Save transfer'),
                icon: Icons.swap_horiz_rounded,
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _accounts.length < 2 ? null : _save)),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (!_loading && _accounts.length < 2)
            EmptyNote(
                icon: Icons.account_balance_outlined,
                title: tr('Two accounts needed'),
                body:
                    tr('Add payment methods or funds to move money from here.'))
          else if (_accounts.length >= 2) ...[
            _SideCard(
                title: tr('From'),
                account: from,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AccountField(
                          key: const Key('transfer-from'),
                          accounts: _accounts,
                          selected: from,
                          sheetTitle: tr('From account'),
                          onSelected: (account) =>
                              setState(() => _from = account.name)),
                      const SizedBox(height: 12),
                      FieldLabel(from == null
                          ? tr('Amount')
                          : tr('Amount ({currency})',
                              {'currency': from.currency})),
                      MoneyField(
                          key: const Key('transfer-amount'),
                          controller: _amount,
                          currency: from?.currency,
                          onChanged: (_) => setState(() {})),
                    ])),
            _Connector(
                label: from != null && to != null && cross
                    ? '${from.currency} → ${to.currency}'
                    : null),
            _SideCard(
                title: tr('To'),
                account: to,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AccountField(
                          key: const Key('transfer-to'),
                          accounts: _accounts,
                          selected: to,
                          tone: ChipTone.neutral,
                          sheetTitle: tr('To account'),
                          onSelected: (account) =>
                              setState(() => _to = account.name)),
                      if (cross) ...[
                        const SizedBox(height: 12),
                        FieldLabel(tr('Amount arriving ({currency})',
                            {'currency': to.currency})),
                        MoneyField(
                            key: const Key('transfer-received'),
                            controller: _received,
                            currency: to.currency,
                            onChanged: (_) => setState(() {})),
                        FieldHint(rate == null
                            ? tr(
                                'Different currencies, so enter what actually arrives.')
                            : tr(
                                'Different currencies, so enter what actually arrives. Works out to {rate}.',
                                {'rate': rate})),
                      ],
                    ])),
            const SizedBox(height: 14),
            FieldLabel(tr('Note')),
            TextField(
                key: const Key('transfer-note'),
                controller: _note,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                    hintText: tr('What is this transfer for?'))),
            if (showAfter) ...[
              const SizedBox(height: 4),
              _AfterCard(from: from, to: to, sent: sent, received: received),
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorNote(message: _error!),
          ],
        ]);
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard(
      {required this.title, required this.account, required this.child});
  final String title;
  final FinanceAccount? account;
  final Widget child;

  @override
  Widget build(BuildContext context) => PaperCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          if (account != null)
            Expanded(
                child: Text(
                    tr('Balance {amount}', {
                      'amount': formatMoney(account!.balance, account!.currency)
                    }),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.muted))),
        ]),
        const SizedBox(height: 12),
        child,
      ]));
}

/// Dashed line and arrow between the two account cards.
class _Connector extends StatelessWidget {
  const _Connector({this.label});
  final String? label;

  @override
  Widget build(BuildContext context) => SizedBox(
      height: 52,
      child: Stack(alignment: Alignment.center, children: [
        const Positioned.fill(
            child: CustomPaint(painter: _DashPainter(color: AppColors.field))),
        Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.paper, width: 5)),
            child: const Icon(Icons.arrow_downward_rounded,
                size: 19, color: Colors.white)),
        if (label != null)
          Align(
              alignment: const Alignment(0.55, 0),
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.line)),
                  child: Text(label!,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft)))),
      ]));
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    final x = size.width / 2;
    for (var y = 0.0; y < size.height; y += 8) {
      canvas.drawLine(Offset(x, y), Offset(x, y + 4), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => oldDelegate.color != color;
}

class _AfterCard extends StatelessWidget {
  const _AfterCard(
      {required this.from,
      required this.to,
      required this.sent,
      required this.received});
  final FinanceAccount from, to;
  final double sent, received;

  @override
  Widget build(BuildContext context) {
    Widget line(FinanceAccount account, double after) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(children: [
          Expanded(
              child: Text(account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Flexible(
              flex: 2,
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(formatMoney(account.balance, account.currency),
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.muted)),
                    const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 15, color: AppColors.faint)),
                    Text(formatMoney(after, account.currency),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color:
                                after < 0 ? AppColors.danger : AppColors.ink)),
                  ]))),
        ]));
    return PaperCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('After this transfer'),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted)),
          line(from, from.balance - sent),
          line(to, to.balance + received),
        ]));
  }
}
