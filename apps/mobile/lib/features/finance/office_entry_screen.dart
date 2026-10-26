import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/ledger_actions.dart';
import '../../data/money_payload.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/finance_parts.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/ui.dart';
import '../admin/money_format.dart';

class OfficeEntryScreen extends StatefulWidget {
  const OfficeEntryScreen({super.key, this.initialKind = 'income'});

  /// income, capital or expense.
  final String initialKind;

  @override
  State<OfficeEntryScreen> createState() => _OfficeEntryScreenState();
}

class _OfficeEntryScreenState extends State<OfficeEntryScreen> {
  List<FinanceAccount> _accounts = const [];
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _account;
  late var _kind = widget.initialKind;
  var _category = 'others';
  String? _error;
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  FinanceAccount? get _picked {
    for (final account in _accounts) {
      if (account.name == _account) return account;
    }
    return null;
  }

  bool get _expense => _kind == 'expense';

  Future<void> _save() async {
    final account = _picked;
    final amount = parseMoney(_amount.text);
    final note = _note.text.trim();
    if (account == null ||
        amount == null ||
        amount <= 0 ||
        note.isEmpty ||
        (_kind != 'expense' && note.length > 160)) {
      setState(() => _error = tr(
          'Enter an account, amount and note. Income notes are up to 160 characters.'));
      return;
    }
    final chosen = account;
    final label = switch (_kind) {
      'capital' => tr('Owner capital'),
      'expense' => tr('Office expense'),
      _ => tr('Income'),
    };
    final money = {
      'amount': formatMoney(amount, chosen.currency),
      'account': chosen.name
    };
    final direction = _kind == 'expense'
        ? tr('{amount} leaves {account}.', money)
        : tr('{amount} goes into {account}.', money);
    final ok = await confirmMoney(context,
        title: label,
        body:
            '$direction ${_kind == 'capital' ? tr('Cash goes up, profit does not.') : ''}');
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final finance = AppScope.of(context).finance;
      if (_kind == 'expense') {
        await finance.recordOfficeExpense(
            category: _category,
            amount: amount,
            reason: note,
            accountName: chosen.name,
            currency: chosen.currency);
      } else {
        await finance.recordIncome(
            amount: amount,
            accountName: chosen.name,
            currency: chosen.currency,
            note: note,
            kind: _kind);
      }
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
    final account = _picked;
    final amount = parseMoney(_amount.text);
    final limit = _expense ? 500 : 160;
    return WorkspaceScaffold(
        title: tr('Deposit or expense'),
        subtitle: tr('Office money outside shipments'),
        root: false,
        footer: ActionFooter(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (account != null && amount != null && amount > 0) ...[
            AmountSentence(
                template: _expense
                    ? tr(
                        '{amount} leaves {account}.', {'account': account.name})
                    : tr('{amount} goes into {account}.',
                        {'account': account.name}),
                amount: formatMoney(amount, account.currency)),
            const SizedBox(height: 8),
          ],
          AppButton(
              key: const Key('office-save'),
              label: switch (_kind) {
                'capital' => tr('Save capital'),
                'expense' => tr('Save expense'),
                _ => tr('Save income'),
              },
              icon: Icons.check_rounded,
              kind: AppButtonKind.current,
              busy: _busy,
              onPressed: _save),
        ])),
        children: [
          SectionTitle(title: tr('What is it?')),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (i, option) in [
              (
                'income',
                Icons.trending_up_rounded,
                ChipTone.green,
                tr('Income'),
                tr('Money in')
              ),
              (
                'capital',
                Icons.work_outline_rounded,
                ChipTone.neutral,
                tr('Capital'),
                tr('Owner adds')
              ),
              (
                'expense',
                Icons.receipt_long_outlined,
                ChipTone.neutral,
                tr('Expense'),
                tr('Money out')
              ),
            ].indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                  child: OptionCard(
                      key: Key('office-kind-${option.$1}'),
                      icon: option.$2,
                      tone: option.$3,
                      title: option.$4,
                      subtitle: option.$5,
                      selected: _kind == option.$1,
                      onTap: () => setState(() => _kind = option.$1))),
            ],
          ]),
          const SizedBox(height: 10),
          HintNote(
              text: switch (_kind) {
            'capital' =>
              tr('Money the owner puts in. Cash goes up, profit does not.'),
            'expense' => tr(
                "Office costs only. Shipment costs go on the shipment's costs page."),
            _ => tr(
                'Office income outside shipments. Customer payments are recorded on the shipment.'),
          }),
          if (_expense) ...[
            const SizedBox(height: 20),
            SectionTitle(title: tr('Category')),
            CheckChips(
                options: [
                  for (final entry in costCategories.entries)
                    (value: entry.key, label: entry.value)
                ],
                selected: _category,
                onSelected: (value) => setState(() => _category = value)),
          ],
          const SizedBox(height: 20),
          SectionTitle(title: _expense ? tr('Paid from') : tr('Paid into')),
          if (_loading)
            const LinearProgressIndicator()
          else
            AccountChoiceList(
                accounts: _accounts,
                selected: _account,
                onSelected: (account) =>
                    setState(() => _account = account.name)),
          const SizedBox(height: 16),
          FieldLabel(account == null
              ? tr('Amount')
              : tr('Amount ({currency})', {'currency': account.currency})),
          MoneyField(
              key: const Key('office-amount'),
              controller: _amount,
              currency: account?.currency,
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 16),
          FieldLabel(_expense ? tr('Reason') : tr('Note')),
          TextField(
              key: const Key('office-note'),
              controller: _note,
              maxLength: limit,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                  hintText: _expense
                      ? tr('What was it for?')
                      : tr('Where did the money come from?'))),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorNote(message: _error!),
          ],
        ]);
  }
}
