import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/money_payload.dart';
import '../../theme/app_colors.dart';
import '../../widgets/account_picker.dart';
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
    if (from == null || to == null || from.name == to.name || amount == null || amount <= 0 || note.isEmpty || note.length > 200) {
      setState(() => _error = 'আলাদা দুটি অ্যাকাউন্ট, অঙ্ক ও ১–২০০ অক্ষরের নোট দিন।');
      return;
    }
    final source = from;
    final dest = to;
    double? received;
    if (source.currency != dest.currency) {
      received = parseMoney(_received.text);
      if (received == null || received <= 0) {
        setState(() => _error = '${dest.currency} অ্যাকাউন্টে যা ঢুকবে সেই অঙ্ক লিখুন।');
        return;
      }
    }
    final body = received == null
        ? '${formatMoney(amount, source.currency)} ${source.name} থেকে ${dest.name}-এ যাবে।'
        : '${formatMoney(amount, source.currency)} ${source.name} ছাড়বে এবং ${formatMoney(received, dest.currency)} ${dest.name}-এ ঢুকবে।';
    final ok = await confirmMoney(context, title: 'ট্রান্সফার', body: body);
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).finance.transfer(from: source.name, to: dest.name, amount: amount, note: note, receivedAmount: received);
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
    final from = _find(_from);
    final to = _find(_to);
    final cross = from != null && to != null && from.currency != to.currency;
    return Scaffold(
      appBar: const BackTitle(title: 'ট্রান্সফার'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 32),
        children: [
          const PageHeader(title: 'অ্যাকাউন্ট ট্রান্সফার', subtitle: 'এক ফান্ড থেকে অন্য ফান্ডে। প্রফিট বদলায় না।'),
          if (_loading) const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_accounts.length < 2)
            const EmptyNote(title: 'দুটি অ্যাকাউন্ট লাগে', body: 'পেমেন্ট মেথড বা ফান্ড যোগ করলে এখান থেকে সরানো যাবে।')
          else ...[
            const SectionTitle(title: 'যেখান থেকে'),
            AccountPicker(accounts: _accounts, selected: _from, onSelected: (account) => setState(() => _from = account.name)),
            const SectionTitle(title: 'যেখানে'),
            AccountPicker(accounts: _accounts, selected: _to, onSelected: (account) => setState(() => _to = account.name)),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'অঙ্ক${from == null ? '' : ' (${from.currency})'}'),
            ),
            if (cross) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _received,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'গন্তব্যে ঢুকবে (${to.currency})'),
              ),
            ],
            const SizedBox(height: 8),
            TextField(controller: _note, maxLength: 200, decoration: const InputDecoration(labelText: 'নোট')),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
          const SizedBox(height: 16),
          AppButton(label: 'ট্রান্সফার সেভ', kind: AppButtonKind.current, busy: _busy, onPressed: _accounts.length < 2 ? null : _save),
        ],
      ),
    );
  }
}
