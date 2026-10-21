import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/money_payload.dart';
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
      setState(() => _error = 'অ্যাকাউন্টের আসল নাম লিখুন।');
      return;
    }
    final typed = _opening.text.trim();
    final opening = typed.isEmpty ? 0.0 : parseMoney(typed);
    if (opening == null || opening < 0) {
      setState(() => _error = 'শুরুর ব্যালেন্স ০ বা তার বেশি, দুই দশমিক পর্যন্ত।');
      return;
    }
    final body = opening == 0
        ? '$name ($_currency) খুলবে। শুরুর ব্যালেন্স ০। টাকা ঢোকাতে আয় বা ট্রান্সফার ব্যবহার করুন।'
        : '$name-এ ${formatMoney(opening, _currency)} শুরুর ব্যালেন্স ক্যাপিটাল হিসেবে লেজারে যাবে। এটা আয় নয়।';
    final ok = await confirmMoney(context, title: 'নতুন ফান্ড', body: body);
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).finance.createAccount(name: name, kind: _kind, currency: _currency, balance: opening);
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
    return Scaffold(
      appBar: const BackTitle(title: 'নতুন ফান্ড'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 32),
        children: [
          const PageHeader(
            title: 'নতুন ফান্ড',
            subtitle: 'ক্যাশ বা সাধারণ ফান্ড। শুরুর টাকা ক্যাপিটাল পেমেন্ট। খালি রাখলে ০, কোনো লেজার লাইন হয় না। ব্যাংক ও বিকাশ পেমেন্ট মেথড থেকে যোগ হয়।',
          ),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'অ্যাকাউন্টের নাম')),
          const SizedBox(height: 12),
          TextField(
            controller: _opening,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'শুরুর ব্যালেন্স ($_currency)', helperText: 'অ্যাকাউন্টের মুদ্রায়। খালি মানে ০।'),
          ),
          const SizedBox(height: 12),
          const SectionTitle(title: 'ধরন'),
          ChoiceChips(
            options: const [(value: 'cash', label: 'ক্যাশ'), (value: 'fund', label: 'ফান্ড')],
            selected: _kind,
            onSelected: (value) => setState(() => _kind = value),
          ),
          const SizedBox(height: 12),
          const SectionTitle(title: 'মুদ্রা'),
          ChoiceChips(
            options: const [(value: 'BDT', label: 'BDT'), (value: 'CNY', label: 'CNY')],
            selected: _currency,
            onSelected: (value) => setState(() => _currency = value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger, height: 1.35)),
          ],
          const SizedBox(height: 16),
          AppButton(label: 'ফান্ড তৈরি', kind: AppButtonKind.current, busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}
