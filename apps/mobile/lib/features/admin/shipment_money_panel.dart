import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/finance_snapshot.dart';
import '../../data/models/workspace.dart';
import '../../data/money_payload.dart';
import '../../data/share_bytes.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../pdf/pdf_bytes_screen.dart';
import '../../widgets/money_confirm.dart';
import '../../widgets/ui.dart';
import '../../widgets/account_picker.dart';
import 'credit_note_screen.dart';
import 'invoice_editor_screen.dart';
import 'money_format.dart';
import 'shipment_costs_screen.dart';

class ShipmentMoneyPanel extends StatefulWidget {
  const ShipmentMoneyPanel(
      {super.key, required this.code, required this.dueAmount, this.onChanged});

  final String code;
  final double dueAmount;
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
  var _section = 0;
  var _includeInvoice = false;
  var _days = 7;
  var _confirmFree = false;
  final _reason = TextEditingController();
  final _amount = TextEditingController();
  String? _account;

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

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_loading && invoice == null)
          const LinearProgressIndicator(
              color: AppColors.teal, backgroundColor: AppColors.tealSoft),
        if (_error != null) ...[
          const SizedBox(height: 8),
          ErrorNote(message: _error!, onRetry: _load),
        ],
        if (invoice != null) ...[
          const SizedBox(height: 20),
          ScreenTabs(
              labels: [tr('Invoice'), tr('Payment'), tr('Share link')],
              index: _section,
              onChanged: (i) => setState(() => _section = i)),
          const SizedBox(height: 16),
          if (_section == 0) ...[
            const SizedBox(height: 12),
            SectionTitle(
                title: tr('Invoice'),
                subtitle: tr(
                    'Edit lines and discount to change it. Check the total before issuing.')),
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(invoice.number,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(invoice.issued ? tr('Invoice issued') : invoice.state,
                      style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 8),
                  if (invoice.lines.isEmpty) Text(tr('No lines yet.')),
                  for (final line in invoice.lines)
                    KvRow(label: line.label, value: formatBdt(line.amount)),
                  KvRow(
                      label: tr('Discount'),
                      value: formatBdt(invoice.discount)),
                  KvRow(label: tr('Total'), value: formatBdt(invoice.total)),
                  KvRow(
                      label: tr('Balance due'),
                      value: formatBdt(invoice.dueAmount),
                      valueColor: invoice.dueAmount > 0
                          ? AppColors.danger
                          : AppColors.ok),
                ],
              ),
            ),
            if (!invoice.issued) ...[
              const SizedBox(height: 8),
              if (invoice.needsReview || invoice.saved)
                TextField(
                    controller: _reason,
                    decoration: InputDecoration(
                        labelText: tr('Revision reason'),
                        helperText:
                            tr('Changing an issued bill needs a reason'))),
              if (invoice.total == 0) ...[
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _confirmFree,
                  onChanged: (value) =>
                      setState(() => _confirmFree = value ?? false),
                  title: Text(tr('This shipment is free of charge')),
                ),
              ],
              AppButton(
                  label: tr('Issue invoice'),
                  kind: AppButtonKind.current,
                  busy: _busy,
                  onPressed: invoice.lines.isEmpty ? null : _issue),
            ],
            const SizedBox(height: 8),
            AppButton(
              label: tr('Lines and discount'),
              kind: AppButtonKind.teal,
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => InvoiceEditorScreen(code: widget.code)));
                if (mounted) await _load();
              },
            ),
            const SizedBox(height: 8),
            AppButton(
                label: tr('View PDF'),
                kind: AppButtonKind.quiet,
                busy: _busy,
                onPressed: _viewPdf),
            const SizedBox(height: 8),
            AppButton(
                label: tr('Share PDF'),
                kind: AppButtonKind.quiet,
                busy: _busy,
                onPressed: _pdf),
            const SizedBox(height: 8),
            AppButton(
              label: tr('Costs'),
              kind: AppButtonKind.quiet,
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => ShipmentCostsScreen(code: widget.code))),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: tr('Credit note'),
              kind: AppButtonKind.quiet,
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => CreditNoteScreen(code: widget.code))),
            ),
          ],
          if (_section == 2) ...[
            const SizedBox(height: 12),
            SectionTitle(
                title: tr('Share'),
                subtitle: tr('Choose how long the customer link stays valid.')),
            ChoiceChips(
              options: [
                (value: '7', label: tr('7 days')),
                (value: '14', label: tr('14 days')),
                (value: '30', label: tr('30 days'))
              ],
              selected: '$_days',
              onSelected: (value) => setState(() => _days = int.parse(value)),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Include invoice')),
                subtitle: Text(tr('Shows the bill and payments with tracking')),
                value: _includeInvoice,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _includeInvoice = value)),
            AppButton(
                label: tr('Create share link'),
                icon: Icons.link_rounded,
                busy: _busy,
                onPressed: () =>
                    _share(_includeInvoice ? 'invoice' : 'tracking_only')),
            if (_link != null) ...[
              const SizedBox(height: 8),
              PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_link!, style: const TextStyle(height: 1.35)),
                    const SizedBox(height: 8),
                    AppButton(
                        label: tr('Copy link'),
                        kind: AppButtonKind.quiet,
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: _link!))),
                  ],
                ),
              ),
            ],
          ],
          if (_section == 1) ...[
            const SizedBox(height: 16),
            SectionTitle(
                title: tr('Record payment'),
                subtitle: tr(
                    'Enter the account the money reached and the amount that arrived.')),
            if (_accounts.isEmpty)
              EmptyNote(
                  title: tr('No receiving accounts'),
                  body: tr(
                      'Add bKash or a bank in Settings to create a fund. Then you can record payments here.'))
            else if (widget.dueAmount <= 0 && invoice.dueAmount <= 0)
              EmptyNote(
                  title: tr('Nothing due'),
                  body: tr('Nothing is left to collect on this shipment.'))
            else ...[
              AccountPicker(
                  accounts: _accounts,
                  selected: _account,
                  onSelected: (account) =>
                      setState(() => _account = account.name)),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: tr('Amount received ({currency})',
                      {'currency': _selectedAccount?.currency ?? 'BDT'}),
                  helperText: _selectedAccount == null ||
                          _selectedAccount!.currency == 'BDT'
                      ? tr('{due} due. Amount in BDT.',
                          {'due': formatBdt(invoice.dueAmount)})
                      : tr(
                          'Enter in {currency}. {due} BDT due; converted at the saved rate.',
                          {
                              'currency': _selectedAccount!.currency,
                              'due': formatBdt(invoice.dueAmount)
                            }),
                ),
              ),
              const SizedBox(height: 8),
              AppButton(
                  label: tr('Save payment'),
                  kind: AppButtonKind.current,
                  busy: _busy,
                  onPressed: _pay),
            ],
          ],
        ],
      ],
    );
  }
}
