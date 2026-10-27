import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/money_payload.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/team_parts.dart';
import '../../widgets/ui.dart';
import '../admin/money_format.dart';

class FundAccountScreen extends StatefulWidget {
  const FundAccountScreen({super.key});

  @override
  State<FundAccountScreen> createState() => _FundAccountScreenState();
}

class _FundAccountScreenState extends State<FundAccountScreen> {
  final _name = TextEditingController();
  final _opening = TextEditingController();
  var _kind = 'cash';
  var _currency = 'BDT';
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 200) {
      setState(() => _error = tr('Enter a real account name.'));
      return;
    }
    final typed = _opening.text.trim();
    final opening = typed.isEmpty ? 0.0 : parseMoney(typed);
    if (opening == null || opening < 0) {
      setState(() => _error =
          tr('Opening balance must be 0 or more, with up to two decimals.'));
      return;
    }
    final body = opening == 0
        ? tr(
            '{name} ({currency}) will open with a zero opening balance. Use income or a transfer to add money.',
            {
                'name': name,
                'currency': _currency
              })
        : tr(
            'The {amount} opening balance of {name} goes to the ledger as capital. It is not income.',
            {'name': name, 'amount': formatMoney(opening, _currency)});
    final ok = await confirmMoney(context, title: tr('New fund'), body: body);
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).finance.createAccount(
          name: name, kind: _kind, currency: _currency, balance: opening);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typed = _opening.text.trim();
    final opening = typed.isEmpty ? 0.0 : parseMoney(typed);
    final sign = _currency == 'CNY' ? '¥' : '৳';
    return WorkspaceScaffold(
        title: tr('New fund'),
        subtitle: tr('A cash or general fund account'),
        root: false,
        footer: FooterActions(
            error: _error,
            child: AppButton(
                label: tr('Create fund'),
                icon: Icons.add_rounded,
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          FormCard(children: [
            LabeledField(
                label: tr('Account name'),
                child: TextField(
                    controller: _name,
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.sentences)),
            PairRow(
              first: LabeledField(
                  label: tr('Type'),
                  child: SegmentPicker<String>(
                      oneLine: true,
                      options: [
                        (
                          value: 'cash',
                          label: tr('Cash'),
                          icon: Icons.payments_outlined
                        ),
                        (
                          value: 'fund',
                          label: tr('Fund'),
                          icon: Icons.account_balance_wallet_outlined
                        ),
                      ],
                      selected: _kind,
                      onChanged: (value) => setState(() => _kind = value))),
              second: LabeledField(
                  label: tr('Currency'),
                  child: SegmentPicker<String>(
                      oneLine: true,
                      options: const [
                        (value: 'BDT', label: '৳ BDT', icon: null),
                        (value: 'CNY', label: '¥ CNY', icon: null),
                      ],
                      selected: _currency,
                      onChanged: (value) => setState(() => _currency = value))),
            ),
            LabeledField(
                label:
                    tr('Opening balance ({currency})', {'currency': _currency}),
                helper: tr(
                    "In the account's currency. Empty means 0 and no ledger line."),
                child: TextField(
                    controller: _opening,
                    onChanged: (_) => setState(() {}),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                        hintText: '0.00',
                        prefixIcon: fieldSign(sign, size: 17),
                        prefixIconConstraints: fieldSignConstraints))),
          ]),
          const SizedBox(height: 14),
          _Preview(
              name: _name.text.trim(),
              kind: _kind == 'cash' ? tr('Cash') : tr('Fund'),
              cash: _kind == 'cash',
              currency: _currency,
              opening: opening),
          const SizedBox(height: 14),
          TipNote(
              text: tr(
                  'Bank and bKash accounts are added in More, under Payment methods.')),
        ]);
  }
}

/// The account as it will open, on the navy money surface.
class _Preview extends StatelessWidget {
  const _Preview(
      {required this.name,
      required this.kind,
      required this.cash,
      required this.currency,
      required this.opening});
  final String name, kind, currency;
  final bool cash;

  /// Null while the typed amount is not a valid number.
  final double? opening;

  static const _soft = Color(0xB8FFFFFF);

  @override
  Widget build(BuildContext context) {
    final capital = opening != null && opening! > 0;
    return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(heroRadius)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: const Color(0x1FFFFFFF),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(
                    cash
                        ? Icons.payments_outlined
                        : Icons.account_balance_wallet_outlined,
                    size: 21,
                    color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name.isEmpty ? tr('New account') : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  Text(
                      tr('{type} · {currency} · new account',
                          {'type': kind, 'currency': currency}),
                      style: const TextStyle(fontSize: 12, color: _soft)),
                ])),
          ]),
          const SizedBox(height: 14),
          Text(tr('Opens with'),
              style: const TextStyle(fontSize: 13, color: _soft)),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                  opening == null ? '—' : formatMoney(opening!, currency),
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 30,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()]))),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0x24FFFFFF)),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.menu_book_outlined,
                    size: 17, color: Color(0xD9FFFFFF))),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
                    capital
                        ? tr('Goes to the ledger as capital. It is not income.')
                        : tr(
                            'No ledger line. Add money later with income or a transfer.'),
                    style: const TextStyle(
                        fontSize: 13, height: 1.5, color: Color(0xD9FFFFFF)))),
          ]),
        ]));
  }
}
