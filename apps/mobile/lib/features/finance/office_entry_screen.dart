import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/ledger_actions.dart';
import '../../data/money_payload.dart';
import '../../theme/app_colors.dart';
import '../../widgets/account_picker.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/ui.dart';
import '../admin/money_format.dart';

class OfficeEntryScreen extends StatefulWidget {
  const OfficeEntryScreen({super.key});

  @override
  State<OfficeEntryScreen> createState() => _OfficeEntryScreenState();
}

class _OfficeEntryScreenState extends State<OfficeEntryScreen> {
  List<FinanceAccount> _accounts = const [];
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _account;
  var _kind = 'income';
  var _category = 'others';
  String? _error;
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

  Future<void> _save() async {
    final account = _picked;
    final amount = parseMoney(_amount.text);
    final note = _note.text.trim();
    if (account == null ||
        amount == null ||
        amount <= 0 ||
        note.isEmpty ||
        (_kind != 'expense' && note.length > 160)) {
      setState(() =>
          _error = 'অ্যাকাউন্ট, অঙ্ক ও নোট দিন। আয়ের নোট ১৬০ অক্ষরের মধ্যে।');
      return;
    }
    final chosen = account;
    final label = switch (_kind) {
      'capital' => 'মালিকের মূলধন',
      'expense' => 'অফিস খরচ',
      _ => 'আয়',
    };
    final direction = _kind == 'expense'
        ? '${chosen.name} থেকে যাবে'
        : '${chosen.name}-এ ঢুকবে';
    final ok = await confirmMoney(context,
        title: label,
        body:
            '${formatMoney(amount, chosen.currency)} $direction। ${_kind == 'capital' ? 'ক্যাশ বাড়বে, প্রফিট নয়।' : ''}');
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
    return WorkspaceScaffold(
        title: 'জমা বা খরচ',
        root: false,
        footer: ActionFooter(
            child: AppButton(
                label: 'সেভ করুন',
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                  'শিপমেন্ট ছাড়া অফিসের আয়, মূলধন বা খরচ। শিপমেন্ট খরচ শিপমেন্টের খরচ পেজে।',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          ChoiceChips(
            options: const [
              (value: 'income', label: 'আয়'),
              (value: 'capital', label: 'মূলধন'),
              (value: 'expense', label: 'খরচ'),
            ],
            selected: _kind,
            onSelected: (value) => setState(() => _kind = value),
          ),
          const SizedBox(height: 12),
          if (_kind == 'expense') ...[
            ChoiceChips(
              options: [
                for (final entry in costCategories.entries)
                  (value: entry.key, label: entry.value)
              ],
              selected: _category,
              onSelected: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 12),
          ],
          AccountPicker(
              accounts: _accounts,
              selected: _account,
              onSelected: (account) => setState(() => _account = account.name)),
          TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'অঙ্ক')),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLength: _kind == 'expense' ? 500 : 160,
            decoration:
                InputDecoration(labelText: _kind == 'expense' ? 'কারণ' : 'নোট'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
        ]);
  }
}
