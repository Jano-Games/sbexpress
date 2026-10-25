import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/workspace.dart';
import '../../data/money_payload.dart';
import '../../data/share_bytes.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../pdf/pdf_bytes_screen.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/team_parts.dart';
import '../../widgets/ui.dart';
import 'money_format.dart';

class InvoiceEditorScreen extends StatefulWidget {
  const InvoiceEditorScreen({super.key, required this.code});

  final String code;

  @override
  State<InvoiceEditorScreen> createState() => _InvoiceEditorScreenState();
}

class _DraftLine {
  _DraftLine({required String label, required String amount, this.costId})
      : label = TextEditingController(text: label),
        amount = TextEditingController(text: amount);

  final TextEditingController label;
  final TextEditingController amount;
  final String? costId;

  void dispose() {
    label.dispose();
    amount.dispose();
  }
}

class _InvoiceEditorScreenState extends State<InvoiceEditorScreen> {
  InvoiceDocument? _invoice;
  final _lines = <_DraftLine>[];
  final _discount = TextEditingController();
  final _note = TextEditingController();
  final _reason = TextEditingController();
  String? _error;
  var _loading = true;
  var _busy = false;
  var _dirty = false;
  var _confirmFree = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    _discount.dispose();
    _note.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invoice = await AppScope.of(context).shipments.invoice(widget.code);
      if (!mounted) return;
      for (final line in _lines) {
        line.dispose();
      }
      _lines
        ..clear()
        ..addAll(invoice.lines.map((line) => _DraftLine(
            label: line.label,
            amount: _amountText(line.amount),
            costId: line.costId)));
      if (_lines.isEmpty) _lines.add(_DraftLine(label: '', amount: ''));
      _discount.text =
          invoice.discount == 0 ? '' : _amountText(invoice.discount);
      _note.text = invoice.note;
      _dirty = false;
      setState(() => _invoice = invoice);
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

  /// Sum of the lines, or null while one of them is not a number.
  double? _subtotal() {
    var sum = 0.0;
    for (final line in _lines) {
      final amount = parseMoney(line.amount.text);
      if (amount == null) return null;
      sum += amount;
    }
    return roundMoney(sum);
  }

  double? _discountValue() =>
      _discount.text.trim().isEmpty ? 0.0 : parseMoney(_discount.text);

  double? _total() {
    final sum = _subtotal();
    if (sum == null) return null;
    final discount = _discountValue();
    if (discount == null || discount < 0) return null;
    return roundMoney(sum - discount);
  }

  InvoiceDocument? _document() {
    final invoice = _invoice;
    if (invoice == null) return null;
    if (_lines.isEmpty || _lines.length > 30) {
      setState(() => _error = tr('Keep between 1 and 30 lines.'));
      return null;
    }
    final built = <InvoiceLine>[];
    for (final line in _lines) {
      final label = line.label.text.trim();
      final amount = parseMoney(line.amount.text);
      if (label.isEmpty || label.length > 160 || amount == null) {
        setState(
            () => _error = tr('Enter a name and an amount on every line.'));
        return null;
      }
      built.add(InvoiceLine(label: label, amount: amount, costId: line.costId));
    }
    final discount =
        _discount.text.trim().isEmpty ? 0.0 : parseMoney(_discount.text);
    final note = _note.text.trim();
    if (discount == null || discount < 0) {
      setState(() => _error = tr('Discount must be 0 or more.'));
      return null;
    }
    if (note.length > 300) {
      setState(() => _error = tr('Keep the note within 300 characters.'));
      return null;
    }
    final total = roundMoney(
        built.fold<double>(0, (sum, line) => sum + line.amount) - discount);
    if (total < 0) {
      setState(() => _error = tr('The invoice total cannot be negative.'));
      return null;
    }
    return InvoiceDocument(
      saved: invoice.saved,
      state: invoice.state,
      needsReview: invoice.needsReview,
      pricingMode: _dirty ? 'manual' : invoice.pricingMode,
      number: invoice.number,
      lines: built,
      discount: discount,
      note: note,
      total: total,
      paidAmount: invoice.paidAmount,
      dueAmount: invoice.dueAmount,
    );
  }

  Future<void> _save(String state) async {
    final invoice = _invoice;
    final document = _document();
    if (invoice == null || document == null) return;
    if (state == 'draft' && invoice.state == 'issued') {
      setState(() => _error = tr('An issued invoice cannot go back to draft.'));
      return;
    }
    final changed = (document.total - invoice.total).abs() > 0.001;
    final needsReason = invoice.saved &&
        invoice.state == 'issued' &&
        (invoice.needsReview || changed);
    final reason = _reason.text.trim();
    if (needsReason && reason.isEmpty) {
      setState(
          () => _error = tr('Enter a reason when changing an issued invoice.'));
      return;
    }
    if (state == 'issued' && document.total == 0 && !_confirmFree) {
      setState(
          () => _error = tr('Confirm free of charge to issue a zero invoice.'));
      return;
    }
    if (state == 'issued') {
      final lower =
          invoice.state == 'issued' && document.total < invoice.total - 0.001;
      final ok = await confirmMoney(
        context,
        title: lower
            ? tr('A credit note will be created')
            : tr('Issue this invoice'),
        body: lower
            ? tr(
                'The total goes from {from} to {to}. The difference is kept as a credit note.',
                {
                    'from': formatBdt(invoice.total),
                    'to': formatBdt(document.total)
                  })
            : tr('A total of {total} will be issued.',
                {'total': formatBdt(document.total)}),
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).shipments.issueInvoice(
            widget.code,
            document,
            revisionReason: reason.isEmpty ? null : reason,
            confirmFree: state == 'issued' && document.total == 0,
            state: state,
            pricingMode: document.pricingMode,
          );
      if (!mounted) return;
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<int>?> _loadPdf() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      return await AppScope.of(context).shipments.invoicePdf(widget.code);
    } on ApiException catch (error) {
      if (mounted && error.status != 401) {
        setState(() => _error = error.message);
      }
      return null;
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _viewPdf() async {
    final bytes = await _loadPdf();
    if (!mounted || bytes == null) return;
    await openPdf(context,
        title: widget.code,
        filename: 'invoice-${widget.code}.pdf',
        bytes: bytes);
  }

  Future<void> _pdf() async {
    final bytes = await _loadPdf();
    if (!mounted || bytes == null) return;
    try {
      await shareBytes(
          bytes: bytes,
          filename: 'invoice-${widget.code}.pdf',
          mimeType: 'application/pdf');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  void _edited([String _ = '']) => setState(() => _dirty = true);

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;
    final total = _total();
    final issued = invoice?.state == 'issued';
    final pill = invoice == null
        ? null
        : invoice.needsReview
            ? StatusPill(label: tr('Needs review'), tone: ChipTone.amber)
            : issued
                ? StatusPill(label: tr('Issued'), tone: ChipTone.green)
                : StatusPill(label: tr('Draft'), tone: ChipTone.neutral);
    return WorkspaceScaffold(
        title: tr('Invoice'),
        subtitle: tr('Shipment {code}', {'code': widget.code}),
        root: false,
        actions: [
          if (pill != null)
            Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(child: pill)),
        ],
        footer: invoice == null
            ? null
            : FooterActions(
                error: _error,
                child: issued
                    ? AppButton(
                        label: tr('Issue revision'),
                        icon: Icons.check_rounded,
                        kind: AppButtonKind.current,
                        busy: _busy,
                        onPressed: () => _save('issued'))
                    : Row(children: [
                        Expanded(
                            flex: 10,
                            child: AppButton(
                                label: tr('Save draft'),
                                icon: Icons.save_outlined,
                                kind: AppButtonKind.quiet,
                                busy: _busy,
                                onPressed: () => _save('draft'))),
                        const SizedBox(width: 10),
                        Expanded(
                            flex: 14,
                            child: AppButton(
                                label: total == null
                                    ? tr('Issue')
                                    : tr('Issue {amount}',
                                        {'amount': _shortBdt(total)}),
                                icon: Icons.check_rounded,
                                kind: AppButtonKind.current,
                                busy: _busy,
                                onPressed: () => _save('issued'))),
                      ])),
        children: [
          if (_loading && invoice == null) const LinearProgressIndicator(),
          if (invoice == null && _error != null)
            ErrorNote(message: _error!, onRetry: _load),
          if (invoice != null) ...[
            _StateSteps(issued: issued),
            const SizedBox(height: 6),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                    tr(
                        'Issuing locks the total. Lowering it later creates a credit note.'),
                    style: const TextStyle(
                        fontSize: 13, height: 1.5, color: AppColors.muted))),
            const SizedBox(height: 14),
            if (invoice.needsReview) ...[
              AttentionNote(
                  text: tr(
                      'Pricing needs review. Enter a reason if you change it.')),
              const SizedBox(height: 14),
            ],
            _invoiceCard(invoice, total),
            if (issued || invoice.needsReview) ...[
              const SizedBox(height: 14),
              FormCard(children: [
                LabeledField(
                    label: tr('Revision reason'),
                    child: TextField(
                        controller: _reason,
                        textCapitalization: TextCapitalization.sentences)),
              ]),
            ],
            if (total == 0) ...[
              const SizedBox(height: 14),
              PaperCard(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  border: _confirmFree
                      ? null
                      : const BorderSide(
                          color: AppColors.accentLine, width: 1.5),
                  child: CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _confirmFree,
                    onChanged: (value) =>
                        setState(() => _confirmFree = value ?? false),
                    title: Text(tr('This shipment is free of charge'),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  )),
            ],
            const SizedBox(height: 14),
            FormCard(children: [
              LabeledField(
                  label: tr('Note'),
                  child: TextField(
                      controller: _note,
                      onChanged: _edited,
                      maxLength: 300,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: AppButton(
                      label: tr('View PDF'),
                      icon: Icons.visibility_outlined,
                      kind: AppButtonKind.quiet,
                      busy: _busy,
                      onPressed: _viewPdf)),
              const SizedBox(width: 10),
              Expanded(
                  child: AppButton(
                      label: tr('Share PDF'),
                      icon: Icons.share_outlined,
                      kind: AppButtonKind.quiet,
                      busy: _busy,
                      onPressed: _pdf)),
            ]),
            const SizedBox(height: 14),
            TipNote(
                text: tr(
                    'After issuing, any change needs a revision reason. A ৳0 invoice can only be issued once you tick "free of charge".')),
          ],
        ]);
  }

  Widget _invoiceCard(InvoiceDocument invoice, double? total) {
    final subtotal = _subtotal();
    final discount = _discountValue();
    final lineCount = _lines.length;
    const header = TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted);
    return PaperCard(
        radius: heroRadius,
        padding: EdgeInsets.zero,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: AppColors.lineSoft))),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(tr('Invoice').toUpperCase(),
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: AppColors.muted)),
                      Text(invoice.number,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.3)),
                    ])),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(tr('Shipment'),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                  Text(widget.code,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ]),
              ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
              child: Row(children: [
                Expanded(flex: 8, child: Text(tr('Item'), style: header)),
                const SizedBox(width: 6),
                Expanded(
                    flex: 5,
                    child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Text(tr('Amount (BDT)'),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: header))),
                const SizedBox(width: 48),
              ])),
          for (var i = 0; i < _lines.length; i++)
            Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                decoration: i == _lines.length - 1
                    ? null
                    : const BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: AppColors.lineSoft))),
                child: Row(children: [
                  Expanded(
                      flex: 8,
                      child: TextField(
                          controller: _lines[i].label,
                          onChanged: _edited,
                          style: const TextStyle(fontSize: 14),
                          decoration:
                              _cellDecoration(tr('Line {n}', {'n': i + 1})))),
                  const SizedBox(width: 6),
                  Expanded(
                      flex: 5,
                      child: TextField(
                          controller: _lines[i].amount,
                          onChanged: _edited,
                          textAlign: TextAlign.right,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                          decoration: _cellDecoration('0.00'))),
                  IconButton(
                      tooltip: tr('Remove line'),
                      color: AppColors.muted,
                      onPressed: _lines.length > 1
                          ? () => setState(() {
                                _lines.removeAt(i).dispose();
                                _dirty = true;
                              })
                          : null,
                      icon: const Icon(Icons.close_rounded, size: 18)),
                ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
              child: Row(children: [
                Expanded(
                    child: DashedOutline(
                        radius: 10,
                        color: const Color(0xFFC3CAD5),
                        background: const Color(0xFFF8FAFC),
                        child: InkWell(
                            onTap: _lines.length < 30
                                ? () => setState(() {
                                      _lines.add(
                                          _DraftLine(label: '', amount: ''));
                                      _dirty = true;
                                    })
                                : null,
                            child: Container(
                                constraints:
                                    const BoxConstraints(minHeight: 44),
                                alignment: Alignment.center,
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_rounded,
                                          size: 17,
                                          color: _lines.length < 30
                                              ? AppColors.primary
                                              : AppColors.faint),
                                      const SizedBox(width: 6),
                                      Text(tr('Add line'),
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: _lines.length < 30
                                                  ? AppColors.primary
                                                  : AppColors.faint)),
                                    ]))))),
                const SizedBox(width: 10),
                Text(tr('{n} of 30', {'n': lineCount}),
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted)),
              ])),
          Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.lineSoft))),
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: Text(tr('Subtotal'),
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.inkSoft))),
                  Text(subtotal == null ? '—' : formatBdt(subtotal),
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()])),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(tr('Discount'),
                            style: const TextStyle(
                                fontSize: 14, color: AppColors.inkSoft)),
                        Text(tr('Leave blank for 0'),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted)),
                      ])),
                  const SizedBox(width: 12),
                  SizedBox(
                      width: 132,
                      child: TextField(
                          controller: _discount,
                          onChanged: _edited,
                          textAlign: TextAlign.right,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                          decoration: _cellDecoration('0.00').copyWith(
                              prefixIcon: fieldSign('−৳', size: 14),
                              prefixIconConstraints: fieldSignConstraints))),
                ]),
              ])),
          Container(
              color: AppColors.navy,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(tr('Total'),
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xB8FFFFFF))),
                      FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(total == null ? '—' : formatBdt(total),
                              maxLines: 1,
                              style: const TextStyle(
                                  fontSize: 30,
                                  height: 1.15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontFeatures: [
                                    FontFeature.tabularFigures()
                                  ]))),
                    ])),
                const SizedBox(width: 12),
                Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                        [
                          trn(lineCount, '{n} line', '{n} lines'),
                          if (discount != null && discount > 0)
                            tr('{amount} discount',
                                {'amount': _shortBdt(discount)}),
                        ].join('\n'),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: Color(0xB8FFFFFF)))),
              ])),
        ]));
  }

  InputDecoration _cellDecoration(String hint) => InputDecoration(
      isDense: true,
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      border: _cellBorder(AppColors.field, 1),
      enabledBorder: _cellBorder(AppColors.field, 1),
      focusedBorder: _cellBorder(AppColors.primary, 2));

  OutlineInputBorder _cellBorder(Color color, double width) =>
      OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: width));
}

/// Editable amount with two decimals, e.g. 3800.00; longer fractions stay.
String _amountText(double value) {
  final fixed = value.toStringAsFixed(2);
  return double.parse(fixed) == value ? fixed : value.toString();
}

/// Whole taka without ".00", for buttons and short summaries.
String _shortBdt(double value) {
  final text = formatBdt(value);
  return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
}

/// Draft → Issued, with the lock on the step that freezes the total.
class _StateSteps extends StatelessWidget {
  const _StateSteps({required this.issued});
  final bool issued;

  @override
  Widget build(BuildContext context) {
    Widget dot(String number, {required bool current, required bool done}) =>
        Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? AppColors.ok
                    : current
                        ? AppColors.primary
                        : null,
                border: current || done
                    ? null
                    : Border.all(color: AppColors.muted, width: 2)),
            child: done
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : Text(number,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: current ? Colors.white : AppColors.muted)));
    TextStyle label(bool current) => TextStyle(
        fontSize: 14,
        fontWeight: current ? FontWeight.w700 : FontWeight.w600,
        color: current ? AppColors.primaryInk : AppColors.muted);
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          dot('1', current: !issued, done: issued),
          const SizedBox(width: 8),
          Text(tr('Draft'), style: label(!issued)),
          const SizedBox(width: 10),
          Expanded(
              child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                      color: issued ? AppColors.ok : AppColors.field,
                      borderRadius: BorderRadius.circular(1)))),
          const SizedBox(width: 10),
          dot('2', current: issued, done: false),
          const SizedBox(width: 8),
          Text(tr('Issued'), style: label(issued)),
          const SizedBox(width: 4),
          Icon(Icons.lock_outline_rounded,
              size: 15, color: issued ? AppColors.primaryInk : AppColors.muted),
        ]));
  }
}
