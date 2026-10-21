import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/ledger_actions.dart';
import '../../data/money_payload.dart';
import '../../theme/app_colors.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/ui.dart';
import 'money_format.dart';

class CreditNoteScreen extends StatefulWidget {
  const CreditNoteScreen({super.key, required this.code});

  final String code;

  @override
  State<CreditNoteScreen> createState() => _CreditNoteScreenState();
}

class _CreditNoteScreenState extends State<CreditNoteScreen> {
  List<CreditNoteRecord> _notes = const [];
  final _amount = TextEditingController();
  final _reason = TextEditingController();
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
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notes = await AppScope.of(context).shipments.creditNotes(widget.code);
      if (!mounted) return;
      setState(() => _notes = notes);
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

  Future<void> _save() async {
    final amount = parseMoney(_amount.text);
    final reason = _reason.text.trim();
    if (amount == null || amount <= 0 || reason.isEmpty || reason.length > 200) {
      setState(() => _error = 'ধনাত্মক অঙ্ক ও ১–২০০ অক্ষরের কারণ দিন।');
      return;
    }
    final ok = await confirmMoney(context, title: 'ক্রেডিট নোট', body: '${formatBdt(amount)} বিল থেকে কমবে। বেশি পেমেন্ট থাকলে কাস্টমার ক্রেডিটে যাবে।');
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).shipments.createCreditNote(widget.code, amount: amount, reason: reason);
      _amount.clear();
      _reason.clear();
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
    return Scaffold(
      appBar: BackTitle(title: widget.code),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(pageGutter, 8, pageGutter, 32),
        children: [
          const PageHeader(title: 'ক্রেডিট নোট', subtitle: 'ইস্যু করা বিল কমায়। ইনভয়েস এডিট করে মোট কমালেও নোট তৈরি হয়।'),
          if (_loading && _notes.isEmpty) const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ...[
            ErrorNote(message: _error!, onRetry: _load),
            const SizedBox(height: 12),
          ],
          if (_notes.isEmpty && !_loading)
            const EmptyNote(title: 'নোট নেই', body: 'বিল কমালে এখানে নম্বর দেখা যাবে।')
          else
            for (final note in _notes) ...[
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(note.number, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(note.reason, style: const TextStyle(color: AppColors.muted, height: 1.35)),
                    const SizedBox(height: 6),
                    KvRow(label: 'অঙ্ক', value: formatBdt(note.amount)),
                    KvRow(label: 'আগের মোট', value: formatBdt(note.previousTotal)),
                    KvRow(label: 'নতুন মোট', value: formatBdt(note.revisedTotal)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 8),
          const SectionTitle(title: 'নতুন নোট'),
          TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'অঙ্ক (BDT)')),
          const SizedBox(height: 8),
          TextField(controller: _reason, maxLength: 200, decoration: const InputDecoration(labelText: 'কারণ')),
          const SizedBox(height: 8),
          AppButton(label: 'ক্রেডিট নোট সেভ', kind: AppButtonKind.current, busy: _busy, onPressed: _save),
        ],
      ),
    );
  }
}
