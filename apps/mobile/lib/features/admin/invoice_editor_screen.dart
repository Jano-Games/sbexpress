import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/workspace.dart';
import '../../data/money_payload.dart';
import '../../data/share_bytes.dart';
import '../../theme/app_colors.dart';
import '../pdf/pdf_bytes_screen.dart';
import '../../widgets/money_confirm.dart';
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
            amount: line.amount.toString(),
            costId: line.costId)));
      if (_lines.isEmpty) _lines.add(_DraftLine(label: '', amount: ''));
      _discount.text = invoice.discount == 0 ? '' : invoice.discount.toString();
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

  double? _total() {
    var sum = 0.0;
    for (final line in _lines) {
      final amount = parseMoney(line.amount.text);
      if (amount == null) return null;
      sum += amount;
    }
    final discount =
        _discount.text.trim().isEmpty ? 0.0 : parseMoney(_discount.text);
    if (discount == null || discount < 0) return null;
    return roundMoney(sum - discount);
  }

  InvoiceDocument? _document() {
    final invoice = _invoice;
    if (invoice == null) return null;
    if (_lines.isEmpty || _lines.length > 30) {
      setState(() => _error = '১ থেকে ৩০টি লাইন রাখুন।');
      return null;
    }
    final built = <InvoiceLine>[];
    for (final line in _lines) {
      final label = line.label.text.trim();
      final amount = parseMoney(line.amount.text);
      if (label.isEmpty || label.length > 160 || amount == null) {
        setState(() => _error = 'প্রতিটি লাইনে নাম ও অঙ্ক দিন।');
        return null;
      }
      built.add(InvoiceLine(label: label, amount: amount, costId: line.costId));
    }
    final discount =
        _discount.text.trim().isEmpty ? 0.0 : parseMoney(_discount.text);
    final note = _note.text.trim();
    if (discount == null || discount < 0) {
      setState(() => _error = 'ছাড় ০ বা তার বেশি হতে হবে।');
      return null;
    }
    if (note.length > 300) {
      setState(() => _error = 'নোট ৩০০ অক্ষরের মধ্যে রাখুন।');
      return null;
    }
    final total = roundMoney(
        built.fold<double>(0, (sum, line) => sum + line.amount) - discount);
    if (total < 0) {
      setState(() => _error = 'ইনভয়েস ঋণাত্মক হতে পারে না।');
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
      setState(() => _error = 'ইস্যু করা ইনভয়েস আবার ড্রাফট করা যায় না।');
      return;
    }
    final changed = (document.total - invoice.total).abs() > 0.001;
    final needsReason = invoice.saved &&
        invoice.state == 'issued' &&
        (invoice.needsReview || changed);
    final reason = _reason.text.trim();
    if (needsReason && reason.isEmpty) {
      setState(() => _error = 'ইস্যু করা বিল বদলালে কারণ লিখুন।');
      return;
    }
    if (state == 'issued' && document.total == 0 && !_confirmFree) {
      setState(
          () => _error = 'শূন্য বিল ইস্যু করতে ফ্রি অব চার্জ নিশ্চিত করুন।');
      return;
    }
    if (state == 'issued') {
      final lower =
          invoice.state == 'issued' && document.total < invoice.total - 0.001;
      final ok = await confirmMoney(
        context,
        title: lower ? 'ক্রেডিট নোট তৈরি হবে' : 'ইনভয়েস ইস্যু',
        body: lower
            ? 'মোট ${formatBdt(invoice.total)} থেকে ${formatBdt(document.total)} হবে। পার্থক্য ক্রেডিট নোট হিসেবে থাকবে।'
            : 'মোট ${formatBdt(document.total)} ইস্যু হবে।',
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

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;
    final total = _total();
    final issued = invoice?.state == 'issued';
    return WorkspaceScaffold(
        title: 'ইনভয়েস লাইন',
        root: false,
        subtitle: widget.code,
        children: [
          const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                  'লাইন ও ছাড় এখানে। ইস্যু করলে মোট লক হয়; কমানো হলে ক্রেডিট নোট তৈরি হয়।',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.muted, height: 1.5))),
          if (_loading && invoice == null)
            const LinearProgressIndicator(
                color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ...[
            ErrorNote(message: _error!),
            const SizedBox(height: 12),
          ],
          if (invoice != null) ...[
            Text(invoice.number,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(issued ? 'ইস্যু হয়েছে' : 'ড্রাফট',
                style: const TextStyle(color: AppColors.muted)),
            if (invoice.needsReview)
              const Text('দাম রিভিউ দরকার। বদলালে কারণ লিখুন।',
                  style: TextStyle(color: AppColors.danger, height: 1.35)),
            const SizedBox(height: 12),
            const SectionTitle(title: 'লাইন'),
            for (var i = 0; i < _lines.length; i++) ...[
              TextField(
                controller: _lines[i].label,
                onChanged: (_) => setState(() => _dirty = true),
                decoration: InputDecoration(labelText: 'লাইন ${i + 1}'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _lines[i].amount,
                onChanged: (_) => setState(() => _dirty = true),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'অঙ্ক (BDT)'),
              ),
              if (_lines.length > 1)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() {
                      _lines.removeAt(i).dispose();
                      _dirty = true;
                    }),
                    child: const Text('লাইন সরান'),
                  ),
                ),
              const SizedBox(height: 8),
            ],
            if (_lines.length < 30)
              AppButton(
                label: 'লাইন যোগ',
                kind: AppButtonKind.quiet,
                onPressed: () => setState(() {
                  _lines.add(_DraftLine(label: '', amount: ''));
                  _dirty = true;
                }),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _discount,
              onChanged: (_) => setState(() => _dirty = true),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'ছাড় (BDT)', helperText: 'খালি রাখলে ০'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              onChanged: (_) => setState(() => _dirty = true),
              maxLength: 300,
              decoration: const InputDecoration(labelText: 'নোট'),
            ),
            const SizedBox(height: 8),
            PaperCard(
                child: KvRow(
                    label: 'মোট',
                    value: total == null ? '—' : formatBdt(total))),
            if (issued || invoice.needsReview) ...[
              const SizedBox(height: 8),
              TextField(
                  controller: _reason,
                  decoration:
                      const InputDecoration(labelText: 'রিভিশনের কারণ')),
            ],
            if (total == 0) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _confirmFree,
                onChanged: (value) =>
                    setState(() => _confirmFree = value ?? false),
                title: const Text('এই শিপমেন্ট ফ্রি অব চার্জ'),
              ),
            ],
            const SizedBox(height: 8),
            if (!issued) ...[
              AppButton(
                  label: 'ড্রাফট সেভ',
                  kind: AppButtonKind.quiet,
                  busy: _busy,
                  onPressed: () => _save('draft')),
              const SizedBox(height: 8),
            ],
            AppButton(
                label: issued ? 'ইস্যু আপডেট' : 'ইস্যু করুন',
                kind: AppButtonKind.current,
                busy: _busy,
                onPressed: () => _save('issued')),
            const SizedBox(height: 8),
            AppButton(
                label: 'PDF দেখুন',
                kind: AppButtonKind.teal,
                busy: _busy,
                onPressed: _viewPdf),
            const SizedBox(height: 8),
            AppButton(
                label: 'PDF শেয়ার',
                kind: AppButtonKind.quiet,
                busy: _busy,
                onPressed: _pdf),
          ],
        ]);
  }
}
