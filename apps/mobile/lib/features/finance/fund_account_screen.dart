import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/money_payload.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/money_confirm.dart';
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
    return WorkspaceScaffold(
        title: tr('New fund'),
        root: false,
        footer: ActionFooter(
            child: AppButton(
                label: tr('Create fund'),
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr(
                      'A cash or general fund. The opening amount is a capital payment; leave it empty for 0 and no ledger line. Bank and bKash accounts are added from payment methods.'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          TextField(
              controller: _name,
              decoration: InputDecoration(labelText: tr('Account name'))),
          const SizedBox(height: 12),
          TextField(
            controller: _opening,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText:
                    tr('Opening balance ({currency})', {'currency': _currency}),
                helperText: tr("In the account's currency. Empty means 0.")),
          ),
          const SizedBox(height: 12),
          SectionTitle(title: tr('Type')),
          ChoiceChips(
            options: [
              (value: 'cash', label: tr('Cash')),
              (value: 'fund', label: tr('Fund'))
            ],
            selected: _kind,
            onSelected: (value) => setState(() => _kind = value),
          ),
          const SizedBox(height: 12),
          SectionTitle(title: tr('Currency')),
          ChoiceChips(
            options: const [
              (value: 'BDT', label: 'BDT'),
              (value: 'CNY', label: 'CNY')
            ],
            selected: _currency,
            onSelected: (value) => setState(() => _currency = value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
        ]);
  }
}
