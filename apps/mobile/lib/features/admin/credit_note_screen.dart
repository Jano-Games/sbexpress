import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/ledger_actions.dart';
import '../../data/money_payload.dart';
import '../../l10n/l10n.dart';
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
      final notes =
          await AppScope.of(context).shipments.creditNotes(widget.code);
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
    if (amount == null ||
        amount <= 0 ||
        reason.isEmpty ||
        reason.length > 200) {
      setState(() => _error =
          tr('Enter a positive amount and a reason of 1–200 characters.'));
      return;
    }
    final ok = await confirmMoney(context,
        title: tr('Credit note'),
        body: tr(
            '{amount} will come off the bill. Any overpayment goes to customer credit.',
            {'amount': formatBdt(amount)}));
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context)
          .shipments
          .createCreditNote(widget.code, amount: amount, reason: reason);
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
    return WorkspaceScaffold(
        title: tr('Credit note'),
        root: false,
        subtitle: widget.code,
        footer: ActionFooter(
            child: AppButton(
                label: tr('Save credit note'),
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: _save)),
        children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                  tr(
                      'Reduces an issued bill. Lowering the total by editing the invoice also creates a note.'),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          if (_loading && _notes.isEmpty)
            const LinearProgressIndicator(
                color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ...[
            ErrorNote(message: _error!, onRetry: _load),
            const SizedBox(height: 12),
          ],
          if (_notes.isEmpty && !_loading)
            EmptyNote(
                title: tr('No credit notes'),
                body: tr('Note numbers appear here when a bill is reduced.'))
          else
            for (final note in _notes) ...[
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(note.number,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(note.reason,
                        style: const TextStyle(
                            color: AppColors.muted, height: 1.35)),
                    const SizedBox(height: 6),
                    KvRow(label: tr('Amount'), value: formatBdt(note.amount)),
                    KvRow(
                        label: tr('Previous total'),
                        value: formatBdt(note.previousTotal)),
                    KvRow(
                        label: tr('New total'),
                        value: formatBdt(note.revisedTotal)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 8),
          SectionTitle(title: tr('New note')),
          TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: tr('Amount (BDT)'))),
          const SizedBox(height: 8),
          TextField(
              controller: _reason,
              maxLength: 200,
              decoration: InputDecoration(labelText: tr('Reason'))),
        ]);
  }
}
