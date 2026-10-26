import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/shipment.dart';
import '../../data/models/workspace.dart';
import '../../data/money_payload.dart';
import '../../data/share_bytes.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../pdf/pdf_bytes_screen.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/flight_parts.dart';
import '../../widgets/ui.dart';
import '../../widgets/account_picker.dart';
import 'credit_note_screen.dart';
import 'invoice_editor_screen.dart';
import 'money_format.dart';
import 'shipment_costs_screen.dart';

/// The Bill tab: invoice, recording a payment and the customer link, in one
/// scroll.
class ShipmentMoneyPanel extends StatefulWidget {
  const ShipmentMoneyPanel(
      {super.key,
      required this.code,
      required this.dueAmount,
      this.detail,
      this.onChanged});

  final String code;
  final double dueAmount;

  /// Adds the issue date and the payments to the invoice card.
  final AdminShipmentDetail? detail;
  final Future<void> Function()? onChanged;

  @override
  State<ShipmentMoneyPanel> createState() => _ShipmentMoneyPanelState();
}

class _ShipmentMoneyPanelState extends State<ShipmentMoneyPanel> {
  InvoiceDocument? _invoice;
  List<FinanceAccount> _accounts = const [];
  String? _error;
  String? _link;
  var _loading = true;
  var _busy = false;
  var _includeInvoice = false;
  var _days = 7;
  var _confirmFree = false;
  final _reason = TextEditingController();
  final _amount = TextEditingController();
  String? _account;

  static const _dayChoices = [7, 14, 30];

  FinanceAccount? get _selectedAccount {
    for (final account in _accounts) {
      if (account.name == _account) return account;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _reason.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scope = AppScope.of(context);
      final invoice = await scope.shipments.invoice(widget.code);
      final finance = await scope.finance.snapshot();
      if (!mounted) return;
      setState(() {
        _invoice = invoice;
        _accounts = finance.accounts;
      });
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

  Future<void> _issue() async {
    final invoice = _invoice;
    if (invoice == null) return;
    if (invoice.lines.isEmpty) {
      setState(() => _error =
          tr('The bill has no lines. Add charges in Lines and discount.'));
      return;
    }
    if (invoice.total == 0 && !_confirmFree) {
      setState(
          () => _error = tr('Confirm free of charge to issue a zero bill.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).shipments.issueInvoice(
            widget.code,
            invoice,
            revisionReason:
                _reason.text.trim().isEmpty ? null : _reason.text.trim(),
            confirmFree: invoice.total == 0 && _confirmFree,
          );
      await _load();
      if (mounted) await widget.onChanged?.call();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
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

  Future<void> _share(String scope) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final link = await AppScope.of(context)
          .shipments
          .shareTracking(widget.code, days: _days, scope: scope);
      if (!mounted) return;
      setState(() => _link = link.url);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    FinanceAccount? account;
    for (final row in _accounts) {
      if (row.name == _account) account = row;
    }
    final amount = parseMoney(_amount.text);
    if (account == null || amount == null || amount <= 0) {
      setState(() =>
          _error = tr('Choose an account and enter the amount received.'));
      return;
    }
    final chosen = account;
    final ok = await confirmMoney(context,
        title: tr('Record payment'),
        body: tr(
            '{amount} will be added to {account} as a payment for this shipment.',
            {
              'amount': formatMoney(amount, chosen.currency),
              'account': chosen.name
            }));
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.of(context).shipments.recordPayment(widget.code,
          amount: amount, accountName: chosen.name, currency: chosen.currency);
      _amount.clear();
      await _load();
      if (mounted) await widget.onChanged?.call();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (!mounted) return;
    await _load();
    if (mounted) await widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loading && invoice == null) const LinearProgressIndicator(),
        if (_error != null) ErrorNote(message: _error!, onRetry: _load),
        if (invoice != null) ...[
          _invoiceCard(invoice),
          const SizedBox(height: 12),
          _paymentCard(invoice),
          const SizedBox(height: 12),
          _shareCard(),
        ],
      ],
    );
  }

  (String, ChipTone) _state(InvoiceDocument invoice) {
    if (invoice.needsReview) return (tr('Needs review'), ChipTone.amber);
    if (invoice.issued) return (tr('Issued'), ChipTone.green);
    if (!invoice.saved || invoice.state == 'draft') {
      return (tr('Draft'), ChipTone.neutral);
    }
    return (invoice.state, ChipTone.neutral);
  }

  Widget _invoiceCard(InvoiceDocument invoice) {
    final detail = widget.detail;
    final (state, tone) = _state(invoice);
    final issuedAt = detail?.invoice?.issuedAt;
    final payments = detail?.payments ?? const <AdminPayment>[];
    final due = invoice.dueAmount;
    Widget line(String label, String value,
            {Color? color, bool strong = false, Color? labelColor}) =>
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: strong ? 15 : 14,
                          height: 1.4,
                          fontWeight:
                              strong ? FontWeight.w700 : FontWeight.w400,
                          color: labelColor ??
                              (strong ? AppColors.ink : AppColors.inkSoft)))),
              const SizedBox(width: 12),
              Text(value,
                  style: TextStyle(
                      fontSize: strong ? 15 : 14,
                      height: 1.4,
                      fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
                      color: color ?? AppColors.ink,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ]));
    return PaperCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const IconBadge(Icons.description_outlined),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(invoice.number.isEmpty ? tr('Invoice') : invoice.number,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
          const SizedBox(height: 2),
          Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusPill(label: state, tone: tone),
                if (invoice.issued && issuedAt != null && issuedAt.isNotEmpty)
                  Text(dayMonth(issuedAt),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted)),
              ]),
        ])),
        const SizedBox(width: 8),
        SquareIconButton(
            icon: Icons.visibility_outlined,
            tooltip: tr('View PDF'),
            onPressed: _busy ? null : _viewPdf),
        const SizedBox(width: 8),
        SquareIconButton(
            icon: Icons.share_outlined,
            tooltip: tr('Share PDF'),
            onPressed: _busy ? null : _pdf),
      ]),
      const Divider(height: 24),
      if (invoice.lines.isEmpty)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Text(tr('No lines yet.'),
                style: const TextStyle(color: AppColors.muted)))
      else
        for (final row in invoice.lines) line(row.label, formatBdt(row.amount)),
      if (invoice.discount != 0)
        line(tr('Discount'), '−${formatBdt(invoice.discount.abs())}',
            color: AppColors.ok),
      const Divider(height: 12),
      line(tr('Total'), formatBdt(invoice.total), strong: true),
      for (final payment in payments)
        line(
            [
              tr('Paid'),
              if (payment.method.isNotEmpty) payment.method,
              if (payment.at.isNotEmpty) dayMonth(payment.at),
            ].join(' · '),
            '−${formatBdt(payment.amount)}',
            color: AppColors.muted,
            labelColor: AppColors.muted),
      if (payments.isEmpty && invoice.paidAmount > 0)
        line(tr('Paid'), '−${formatBdt(invoice.paidAmount)}',
            color: AppColors.muted, labelColor: AppColors.muted),
      const SizedBox(height: 6),
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: due > 0 ? AppColors.dangerSoft : AppColors.okSoft,
              borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Expanded(
                child: Text(due > 0 ? tr('Balance due') : tr('Paid in full'),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: due > 0 ? AppColors.danger : AppColors.ok))),
            Text(formatBdt(due),
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: due > 0 ? AppColors.danger : AppColors.ok,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ])),
      if (!invoice.issued) ...[
        const SizedBox(height: 14),
        HintNote(
            text: tr(
                'Edit lines and discount to change it. Check the total before issuing.')),
        if (invoice.needsReview || invoice.saved) ...[
          const SizedBox(height: 12),
          TextField(
              controller: _reason,
              decoration: InputDecoration(
                  labelText: tr('Revision reason'),
                  helperText: tr('Changing an issued bill needs a reason'))),
        ],
        if (invoice.total == 0)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _confirmFree,
            onChanged: (value) => setState(() => _confirmFree = value ?? false),
            title: Text(tr('This shipment is free of charge')),
          ),
        const SizedBox(height: 12),
        AppButton(
            label: tr('Issue invoice'),
            icon: Icons.task_alt_rounded,
            kind: AppButtonKind.current,
            busy: _busy,
            onPressed: invoice.lines.isEmpty ? null : _issue),
      ],
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
            flex: 21,
            child: SmallOutlineButton(
                icon: Icons.edit_outlined,
                label: tr('Edit lines'),
                onPressed: () =>
                    _push(InvoiceEditorScreen(code: widget.code)))),
        const SizedBox(width: 8),
        Expanded(
            flex: 16,
            child: SmallOutlineButton(
                icon: Icons.request_quote_outlined,
                label: tr('Costs'),
                onPressed: () =>
                    _push(ShipmentCostsScreen(code: widget.code)))),
        const SizedBox(width: 8),
        Expanded(
            flex: 23,
            child: SmallOutlineButton(
                icon: Icons.note_alt_outlined,
                label: tr('Credit note'),
                onPressed: () => _push(CreditNoteScreen(code: widget.code)))),
      ]),
    ]));
  }

  Widget _paymentCard(InvoiceDocument invoice) {
    final account = _selectedAccount;
    final nothingDue = widget.dueAmount <= 0 && invoice.dueAmount <= 0;
    return PaperCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CardTitle(
          title: tr('Record payment'),
          subtitle: tr('Where the money arrived, and how much.')),
      const SizedBox(height: 14),
      if (_accounts.isEmpty)
        HintNote(
            text: tr(
                'Add bKash or a bank in Settings to create a fund. Then you can record payments here.'))
      else if (nothingDue)
        Row(children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 20, color: AppColors.ok),
          const SizedBox(width: 10),
          Expanded(
              child: Text(tr('Nothing is left to collect on this shipment.'),
                  style: const TextStyle(
                      fontSize: 14, height: 1.45, color: AppColors.inkSoft))),
        ])
      else ...[
        FieldLabel(tr('Received in')),
        AccountPicker(
            accounts: _accounts,
            selected: _account,
            onSelected: (account) => setState(() => _account = account.name)),
        FieldLabel(tr('Amount received ({currency})',
            {'currency': account?.currency ?? 'BDT'})),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: '0',
            prefixIcon: currencyPrefix(account?.currency ?? 'BDT'),
            prefixIconConstraints: currencyPrefixConstraints,
            helperText: account == null || account.currency == 'BDT'
                ? tr('{due} due. Amount in BDT.',
                    {'due': formatBdt(invoice.dueAmount)})
                : tr(
                    'Enter in {currency}. {due} BDT due; converted at the saved rate.',
                    {
                        'currency': account.currency,
                        'due': formatBdt(invoice.dueAmount)
                      }),
          ),
        ),
        const SizedBox(height: 14),
        AppButton(
            label: tr('Save payment'),
            icon: Icons.check_rounded,
            kind: AppButtonKind.current,
            busy: _busy,
            onPressed: _pay),
      ],
    ]));
  }

  Widget _shareCard() => PaperCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardTitle(
            title: tr('Share with customer'),
            subtitle: tr('Choose how long the customer link stays valid.')),
        const SizedBox(height: 14),
        ScreenTabs(
            labels: [tr('7 days'), tr('14 days'), tr('30 days')],
            index: _dayChoices.indexOf(_days),
            onChanged: (i) => setState(() => _days = _dayChoices[i])),
        const SizedBox(height: 4),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('Include invoice'),
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            subtitle: Text(tr('Shows the bill and payments with tracking'),
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            value: _includeInvoice,
            onChanged: _busy
                ? null
                : (value) => setState(() => _includeInvoice = value)),
        const SizedBox(height: 4),
        AppButton(
            label: tr('Create share link'),
            icon: Icons.link_rounded,
            kind: AppButtonKind.quiet,
            busy: _busy,
            onPressed: () =>
                _share(_includeInvoice ? 'invoice' : 'tracking_only')),
        if (_link != null) ...[
          const SizedBox(height: 12),
          LinkBox(url: _link!),
        ],
      ]));
}
