import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../data/models/flow.dart';
import '../../data/models/ledger_actions.dart';
import '../../data/models/media_item.dart';
import '../../data/models/shipment.dart';
import '../../data/models/workspace.dart';
import '../../data/repositories/shipment_repository.dart';
import '../../data/share_bytes.dart';
import '../../data/uploads/flutter_heic.dart';
import '../../data/uploads/photo_tray.dart';
import '../../data/uploads/photo_upload.dart';
import '../../data/uploads/quick_uploads.dart';
import '../../data/uploads/signed_photos.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flight_parts.dart';
import '../../widgets/flow_parts.dart';
import '../../widgets/photo_parts.dart';
import '../../widgets/quick_parts.dart' show plainKg;
import '../../widgets/remove_parts.dart';
import '../../widgets/round7_parts.dart';
import '../../widgets/team_parts.dart' show AttentionNote;
import '../../widgets/ui.dart';
import '../finance/record_payment_sheet.dart';
import '../flights/flight_detail_screen.dart';
import '../pdf/pdf_bytes_screen.dart';
import 'add_cost_sheet.dart';
import 'credit_note_screen.dart';
import 'invoice_editor_screen.dart';
import 'money_format.dart';
import 'shipment_costs_screen.dart';

/// One shipment on one page: where it is, the bill and getting paid, its
/// profit, handling, the costs on the bill, the invoice the server keeps
/// up to date, the customer link and the booking. Photos have their own tab.
class AdminShipmentScreen extends StatefulWidget {
  const AdminShipmentScreen(
      {super.key, required this.code, this.initialTab = 0, this.pickPhotos});

  final String code;

  /// Camera or gallery; tests pass their own photos.
  final Future<List<PickedPhoto>> Function(FileSource source)? pickPhotos;

  /// 0 opens the overview, 1 the bill (at the top of the overview) and 2
  /// the photos.
  final int initialTab;

  @override
  State<AdminShipmentScreen> createState() => _AdminShipmentScreenState();
}

class _AdminShipmentScreenState extends State<AdminShipmentScreen> {
  AdminShipmentDetail? _detail;
  ShipmentMediaList? _media;
  InvoiceDocument? _invoice;
  List<SavedTrackLink>? _links;

  /// A link made here, shown when the saved links cannot be listed.
  SavedTrackLink? _made;
  String? _error;
  String? _invoiceError;
  String? _linkError;
  var _loading = true;
  var _deleting = false;
  var _invoiceBusy = false;
  var _linkBusy = false;
  var _confirmFree = false;
  var _tab = 0;
  final _reason = TextEditingController();

  /// Picked photos wait here until Upload.
  PhotoTrayController? _tray;
  SignedPhotoLoader? _photos;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab >= 2 ? 1 : 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = AppScope.of(context).media;
    _photos ??= media.photoLoader(widget.code);
    _tray ??= PhotoTrayController(
        decodeHeic: flutterDecodeHeic,
        upload: (image, progress) =>
            media.uploadPhoto(widget.code, image, progress),
        onUploaded: _loadMedia);
  }

  @override
  void dispose() {
    _tray?.dispose();
    _photos?.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail =
          await AppScope.of(context).shipments.adminDetail(widget.code);
      if (!mounted) return;
      setState(() => _detail = detail);
      await Future.wait([_loadInvoice(), _loadLinks(), _loadMedia()]);
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

  Future<void> _loadMedia() async {
    try {
      final media = await AppScope.of(context).media.list(widget.code);
      if (!mounted) return;
      setState(() => _media = media);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    }
  }

  /// The server makes and issues the invoice by itself; opening the
  /// shipment issues an older one.
  Future<void> _loadInvoice() async {
    try {
      final invoice = await AppScope.of(context).shipments.invoice(widget.code);
      if (!mounted) return;
      setState(() {
        _invoice = invoice;
        _invoiceError = null;
      });
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _invoiceError = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _invoiceError = error.toString());
    }
  }

  Future<void> _loadLinks() async {
    try {
      final links =
          await AppScope.of(context).shipments.trackLinks(widget.code);
      if (!mounted) return;
      setState(() {
        _links = links;
        _linkError = null;
      });
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() {
        if (error.status == 404) {
          // A server that cannot list saved links: show the one made here.
          _links = const [];
          _linkError = null;
        } else {
          _linkError = error.message;
        }
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _linkError = error.message);
    }
  }

  Future<void> _pick(FileSource source) async {
    final photos = await (widget.pickPhotos ?? pickPhotos)(source);
    if (!mounted) return;
    await _tray?.add(photos);
  }

  /// The viewer at [index]: swipe through the photos as the grid shows
  /// them, with "Show to customer" on each.
  Future<void> _openPhoto(List<MediaItem> ordered, int index) {
    return showPhotoViewer(context,
        photos: [
          for (final item in ordered)
            ViewerPhoto.stored(item.reference,
                group: photoGroupLabel(item.deviceCategory),
                shared: item.shared)
        ],
        initial: index,
        loader: _photos,
        onShare: (i, shared) => _share(ordered[i], shared));
  }

  /// Saves the switch in the viewer; false when the server refused.
  Future<bool> _share(MediaItem item, bool shared) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.of(context)
          .media
          .setShared(widget.code, item.reference, shared: shared);
      await _loadMedia();
      return true;
    } on ApiException catch (error) {
      if (error.status != 401) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
      return false;
    }
  }

  Future<void> _toggleShare(MediaItem item, bool shared) async {
    try {
      await AppScope.of(context)
          .media
          .setShared(widget.code, item.reference, shared: shared);
      await _loadMedia();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) await _load();
  }

  Future<void> _recordPayment(AdminShipmentDetail detail) async {
    final bill = HandedOverBill(
        code: detail.code,
        supplierCode: detail.supplierCode,
        supplierName: detail.supplierName ?? detail.supplierCode,
        supplierPhone: '',
        amount: detail.dueAmount,
        deliveredOn: detail.lastMile?.handedOverAt ?? '',
        days: 0,
        overdue: false);
    final saved = await showRecordPaymentSheet(context,
        bill: bill, monthly: detail.monthly);
    if (saved == true && mounted) await _load();
  }

  Future<void> _addCost(AdminShipmentDetail detail) async {
    final saved = await showAddCostSheet(context,
        code: widget.code,
        customer: detail.supplierName ?? detail.supplierCode,
        bill: detail.billAmount);
    if (saved == true && mounted) await _load();
  }

  Future<List<int>?> _loadPdf() async {
    setState(() {
      _invoiceBusy = true;
      _invoiceError = null;
    });
    try {
      return await AppScope.of(context).shipments.invoicePdf(widget.code);
    } on ApiException catch (error) {
      if (mounted && error.status != 401) {
        setState(() => _invoiceError = error.message);
      }
      return null;
    } catch (error) {
      if (mounted) setState(() => _invoiceError = error.toString());
      return null;
    } finally {
      if (mounted) setState(() => _invoiceBusy = false);
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

  Future<void> _sharePdf() async {
    final bytes = await _loadPdf();
    if (!mounted || bytes == null) return;
    try {
      await shareBytes(
          bytes: bytes,
          filename: 'invoice-${widget.code}.pdf',
          mimeType: 'application/pdf');
    } catch (error) {
      if (!mounted) return;
      setState(() => _invoiceError = error.toString());
    }
  }

  /// Issues [invoice] as it is: confirms a hand-edited bill that needs
  /// review (with a reason), or issues a draft an older server left.
  Future<void> _issue(InvoiceDocument invoice, {required bool review}) async {
    final reason = _reason.text.trim();
    if (review && reason.isEmpty) {
      setState(() => _invoiceError =
          tr('Enter a reason when changing an issued invoice.'));
      return;
    }
    if (invoice.lines.isEmpty) {
      setState(() => _invoiceError =
          tr('The bill has no lines. Add charges in Lines and discount.'));
      return;
    }
    if (invoice.total == 0 && !_confirmFree) {
      setState(() =>
          _invoiceError = tr('Confirm free of charge to issue a zero bill.'));
      return;
    }
    setState(() {
      _invoiceBusy = true;
      _invoiceError = null;
    });
    try {
      await AppScope.of(context).shipments.issueInvoice(widget.code, invoice,
          revisionReason: reason.isEmpty ? null : reason,
          confirmFree: invoice.total == 0 && _confirmFree);
      _reason.clear();
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _invoiceError = error.message);
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _invoiceError = error.message);
    } finally {
      if (mounted) setState(() => _invoiceBusy = false);
    }
  }

  /// The link the card shows: the newest active saved one, else one made
  /// here.
  SavedTrackLink? get _shownLink {
    final listed = newestActiveLink(_links ?? const []);
    return listed ?? _made;
  }

  /// Makes a new link and lists it; the error message when it fails.
  Future<String?> _makeLink(int days, bool withBill) async {
    final scope = withBill ? 'invoice' : 'tracking_only';
    try {
      final link = await AppScope.of(context)
          .shipments
          .shareTracking(widget.code, days: days, scope: scope);
      if (!mounted) return null;
      setState(() => _made = SavedTrackLink(
          id: '',
          url: link.url,
          status: 'active',
          expiresAt: link.expiresAt,
          includesInvoice: withBill));
      await _loadLinks();
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<void> _newLink(AdminShipmentDetail detail) async {
    final withBill = _invoice?.issued == true;
    await showFlowSheet<bool>(
        context,
        (_) => _NewLinkSheet(
            code: widget.code,
            customer: detail.supplierName ?? detail.supplierCode,
            withBill: withBill,
            onMake: (days) => _makeLink(days, withBill)));
  }

  Future<void> _turnOffLink() async {
    final ok = await confirmRemoval(context,
        title: tr('Turn off the customer link?'),
        body: tr(
            'The customer can no longer open it. You can make a new link any time.'),
        action: tr('Turn off'));
    if (!ok || !mounted) return;
    setState(() {
      _linkBusy = true;
      _linkError = null;
    });
    try {
      await AppScope.of(context).shipments.revokeTracking(widget.code);
      _made = null;
      await _loadLinks();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _linkError = error.message);
    } finally {
      if (mounted) setState(() => _linkBusy = false);
    }
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('Link copied'))));
  }

  Future<void> _shareLink(String url) async {
    try {
      await shareText(url);
    } catch (_) {
      // No share sheet on this device: copy it instead.
      await _copy(url);
    }
  }

  /// The server refuses once the shipment has an invoice, payments, costs,
  /// receipts or credit, and says which.
  Future<void> _delete() {
    final shipments = AppScope.of(context).shipments;
    return confirmAndDelete(context,
        title: tr('Delete shipment'),
        question: tr('Delete shipment {code}? This cannot be undone.',
            {'code': widget.code}),
        refusedTitle: tr('This shipment cannot be deleted'),
        delete: () => shipments.delete(widget.code),
        onBusy: (busy) {
          if (mounted) setState(() => _deleting = busy);
        });
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final photos = _media?.media.length ?? detail?.photosCount ?? 0;
    return PhotoTrayGuard(
        tray: _tray,
        child: WorkspaceScaffold(
            title: widget.code,
            subtitle: detail == null
                ? tr('Shipment details and finance')
                : [
                    detail.supplierName ?? detail.supplierCode,
                    if (detail.flightCode != null)
                      displayFlightCode(detail.flightCode!),
                    if (detail.flyerName != null)
                      tr('flyer {name}', {'name': detail.flyerName}),
                  ].join(' · '),
            onRefresh: _load,
            actions: [
              if (detail != null)
                Center(
                    child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: detail.dueAmount > 0
                                ? StatusPill(
                                    label: tr('{amount} due', {
                                      'amount': formatBdt(detail.dueAmount)
                                    }),
                                    tone: ChipTone.amber)
                                : StatusPill(
                                    label: payStatusLabel(detail.payStatus),
                                    tone: payTone(detail.payStatus))))),
            ],
            toolbar: ScreenTabs(labels: [
              tr('Overview'),
              tr('Photos · {n}', {'n': photos})
            ], index: _tab, onChanged: (i) => setState(() => _tab = i)),
            children: [
              if (_loading && detail == null) const LinearProgressIndicator(),
              if (_error != null) ErrorNote(message: _error!, onRetry: _load),
              if (detail != null && _tab == 0) ..._overview(detail),
              if (detail != null && _tab == 1)
                _Photos(
                    media: _media,
                    tray: _tray!,
                    loader: _photos!,
                    onPick: _pick,
                    onOpen: _openPhoto,
                    onToggle: _toggleShare),
            ]));
  }

  /// Every card of the overview, in the design's order.
  List<Widget> _overview(AdminShipmentDetail detail) {
    const gap = SizedBox(height: 12);
    final profit = detail.profitBreakdown != null || detail.costTotal != null;
    return [
      _StatusHero(detail: detail),
      gap,
      _BillCard(
          detail: detail,
          onRecord: detail.dueAmount > 0 && !detail.freeOfCharge
              ? () => _recordPayment(detail)
              : null),
      if (profit) ...[gap, _ProfitCard(detail: detail)],
      gap,
      _HandlingCard(detail: detail),
      gap,
      _BillCostsCard(
          detail: detail,
          onAdd: () => _addCost(detail),
          onOpen: () => _push(ShipmentCostsScreen(code: widget.code))),
      gap,
      _invoiceCard(detail),
      gap,
      _linkCard(detail),
      gap,
      _BookingCard(
          detail: detail,
          onOpenFlight: detail.flightCode == null
              ? null
              : () => _push(FlightDetailScreen(code: detail.flightCode!))),
      const SizedBox(height: 20),
      QuietDeleteButton(
          key: const Key('shipment-delete'),
          label: tr('Delete shipment'),
          busy: _deleting,
          onPressed: _delete),
    ];
  }

  /// The invoice the server makes and keeps issued: its lines, what was
  /// paid and what is left, with PDF, Share and Edit.
  Widget _invoiceCard(AdminShipmentDetail detail) {
    final invoice = _invoice;
    if (invoice == null) {
      return PaperCard(
          key: const Key('shipment-invoice'),
          child: _invoiceError == null
              ? const LinearProgressIndicator()
              : ErrorNote(message: _invoiceError!, onRetry: _loadInvoice));
    }
    final draft = !invoice.needsReview && !invoice.issued;
    final (state, tone) = invoice.needsReview
        ? (tr('Needs review'), ChipTone.amber)
        : invoice.issued
            ? (tr('Issued'), ChipTone.green)
            : (tr('Draft'), ChipTone.neutral);
    final payments = detail.payments.length;
    final due = invoice.dueAmount;
    return PaperCard(
        key: const Key('shipment-invoice'),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CardHead(
              title: invoice.number.isEmpty ? tr('Invoice') : invoice.number,
              subtitle: invoice.pricingMode == 'manual'
                  ? tr('Edited by hand · check it when the charge changes')
                  : tr(
                      'Made automatically · updates when the charge or costs change'),
              trailing: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: StatusPill(label: state, tone: tone))),
          const SizedBox(height: 6),
          if (invoice.lines.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(tr('No lines yet.'),
                    style: const TextStyle(color: AppColors.muted)))
          else
            for (final line in invoice.lines)
              MoneyRow(
                  label: line.label,
                  value: formatBdt(line.amount),
                  valueWeight: FontWeight.w400),
          if (invoice.discount != 0)
            MoneyRow(
                label: tr('Discount'),
                value: '−${formatBdt(invoice.discount.abs())}',
                color: AppColors.ok),
          const Divider(height: 9, color: AppColors.lineSoft),
          MoneyRow(
              label: tr('Total'),
              value: formatBdt(invoice.total),
              strong: true),
          if (invoice.paidAmount > 0)
            MoneyRow(
                label: payments > 0
                    ? trn(payments, 'Paid · {n} payment', 'Paid · {n} payments')
                    : tr('Paid'),
                value: '−${formatBdt(invoice.paidAmount)}',
                color: AppColors.ok),
          MoneyRow(
              label: due > 0 ? tr('Balance due') : tr('Paid in full'),
              value: formatBdt(due),
              strong: true,
              color: due > 0 ? AppColors.accentInk : AppColors.ok),
          if (invoice.needsReview) ...[
            const SizedBox(height: 10),
            AttentionNote(
                text: tr(
                    'Pricing needs review. Enter a reason if you change it.')),
            const SizedBox(height: 10),
            TextField(
                key: const Key('invoice-review-reason'),
                controller: _reason,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: tr('Revision reason'))),
            const SizedBox(height: 10),
            AppButton(
                key: const Key('invoice-confirm'),
                label: tr('Confirm the bill'),
                icon: Icons.task_alt_rounded,
                kind: AppButtonKind.current,
                busy: _invoiceBusy,
                onPressed: () => _issue(invoice, review: true)),
          ],
          if (draft) ...[
            const SizedBox(height: 10),
            Text(tr('This server still keeps the bill as a draft.'),
                style: const TextStyle(
                    fontSize: 13, height: 1.45, color: AppColors.muted)),
            if (invoice.total == 0)
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _confirmFree,
                  onChanged: (value) =>
                      setState(() => _confirmFree = value ?? false),
                  title: Text(tr('This shipment is free of charge'))),
            const SizedBox(height: 8),
            AppButton(
                key: const Key('invoice-issue'),
                label: tr('Issue invoice'),
                icon: Icons.task_alt_rounded,
                kind: AppButtonKind.quiet,
                busy: _invoiceBusy,
                onPressed: invoice.lines.isEmpty
                    ? null
                    : () => _issue(invoice, review: false)),
          ],
          if (_invoiceError != null) ...[
            const SizedBox(height: 10),
            ErrorNote(message: _invoiceError!),
          ],
          const SizedBox(height: 10),
          ActionRow(children: [
            QuietAction(
                key: const Key('invoice-pdf'),
                icon: Icons.visibility_outlined,
                label: tr('PDF'),
                onPressed: _invoiceBusy ? null : _viewPdf),
            QuietAction(
                key: const Key('invoice-share'),
                icon: Icons.share_outlined,
                label: tr('Share'),
                onPressed: _invoiceBusy ? null : _sharePdf),
            QuietAction(
                key: const Key('invoice-edit'),
                icon: Icons.edit_outlined,
                label: tr('Edit'),
                onPressed: () => _push(InvoiceEditorScreen(code: widget.code))),
          ]),
          Align(
              alignment: AlignmentDirectional.centerStart,
              child: LinkText(
                  key: const Key('invoice-credit-note'),
                  label: tr('Credit note'),
                  chevron: true,
                  onTap: () => _push(CreditNoteScreen(code: widget.code)))),
        ]));
  }

  /// The customer link stays on the shipment once it is made.
  Widget _linkCard(AdminShipmentDetail detail) {
    final link = _shownLink;
    final url = link?.url;
    return PaperCard(
        key: const Key('shipment-link'),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (link != null && url != null) ...[
            CardHead(
                title: tr('Customer link'),
                subtitle: [
                  link.includesInvoice
                      ? tr('Tracking and bill')
                      : tr('Tracking only'),
                  tr('valid until {date}', {'date': dayMonth(link.expiresAt)}),
                ].join(' · '),
                trailing: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child:
                        StatusPill(label: tr('Active'), tone: ChipTone.green))),
            const SizedBox(height: 10),
            UrlBox(url: url),
            const SizedBox(height: 10),
            ActionRow(children: [
              QuietAction(
                  key: const Key('link-copy'),
                  icon: Icons.copy_rounded,
                  label: tr('Copy'),
                  onPressed: () => _copy(url)),
              QuietAction(
                  key: const Key('link-share'),
                  icon: Icons.share_outlined,
                  label: tr('Share'),
                  tinted: true,
                  onPressed: () => _shareLink(url)),
            ]),
            const SizedBox(height: 4),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(tr('Made once, stays here.'),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              LinkText(
                  key: const Key('link-new'),
                  label: tr('Make a new link'),
                  onTap: () => _newLink(detail)),
              const Text('·',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
              TextButton(
                  key: const Key('link-off'),
                  onPressed: _linkBusy ? null : _turnOffLink,
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      textStyle: const TextStyle(
                          fontFamily: 'HindSiliguri',
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  child: Text(tr('Turn off'))),
            ]),
          ] else ...[
            CardHead(
                title: tr('Customer link'),
                subtitle: tr('A link that shows where the parcel is.')),
            const SizedBox(height: 12),
            if (_links == null && _linkError == null)
              const LinearProgressIndicator()
            else
              AppButton(
                  key: const Key('link-create'),
                  label: tr('Create customer link'),
                  icon: Icons.link_rounded,
                  kind: AppButtonKind.quiet,
                  busy: _linkBusy,
                  onPressed: () => _newLink(detail)),
          ],
          if (_linkError != null) ...[
            const SizedBox(height: 10),
            ErrorNote(message: _linkError!, onRetry: _loadLinks),
          ],
        ]));
  }
}

/// "Pays after delivery", "Pays monthly" or "Free of charge".
String _termsLabel(AdminShipmentDetail detail) => detail.freeOfCharge
    ? tr('Free of charge')
    : detail.monthly
        ? tr('Pays monthly')
        : tr('Pays after delivery');

/// "4.0 kg × ৳950 + 2 Mobile pieces × ৳500".
String _chargeBasis(AdminShipmentDetail detail) {
  String money(double value, String currency) =>
      '${currency == 'CNY' ? '¥' : '৳'}${_number(value)}';
  return [
    if (detail.bookedKg > 0 || detail.devices.isEmpty)
      '${detail.bookedKg.toStringAsFixed(1)} kg × ${money(detail.chargeRate, detail.chargeCurrency)}',
    for (final line in detail.devices)
      if (line.count > 0)
        tr('{n} {name} pieces × {rate}', {
          'n': line.count,
          'name': line.category,
          'rate': money(line.rate, line.currency)
        }),
  ].join(' + ');
}

/// What the bill is made of: "Charge ৳4,800 + costs on the bill ৳300", or
/// how the charge is worked out when nothing else is on it.
String _billBasis(AdminShipmentDetail detail) {
  final costs = detail.billCostTotal;
  final charge = detail.profitBreakdown?.charge ?? detail.charge;
  return [
    if (costs > 0.001)
      tr('Charge {charge} + costs on the bill {costs}',
          {'charge': formatBdt(charge), 'costs': formatBdt(costs)})
    else
      _chargeBasis(detail),
    if (detail.discountAmount > 0.001)
      tr('{amount} discount', {'amount': formatBdt(detail.discountAmount)}),
  ].join(' · ');
}

String _number(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

/// The bill, how it is paid, Paid and Still due, and "Record payment".
class _BillCard extends StatelessWidget {
  const _BillCard({required this.detail, required this.onRecord});
  final AdminShipmentDetail detail;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) => PaperCard(
      key: const Key('shipment-bill'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LayoutBuilder(builder: (context, box) {
          final terms =
              StatusPill(label: _termsLabel(detail), tone: ChipTone.neutral);
          // Large text on a narrow phone puts the terms under the amount.
          final scale = MediaQuery.textScalerOf(context).scale(100) / 100;
          final narrow = box.maxWidth / scale < 300;
          final amount =
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('Bill'),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted)),
            FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(formatBdt(detail.billAmount),
                    maxLines: 1,
                    style: const TextStyle(
                        fontSize: 30,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()]))),
            const SizedBox(height: 2),
            Text(_billBasis(detail),
                style: const TextStyle(
                    fontSize: 12, height: 1.4, color: AppColors.muted)),
            if (narrow) ...[const SizedBox(height: 6), terms],
          ]);
          if (narrow) return amount;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: amount),
            const SizedBox(width: 8),
            ConstrainedBox(
                constraints: BoxConstraints(maxWidth: box.maxWidth * 0.45),
                child: terms),
          ]);
        }),
        const SizedBox(height: 12),
        IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
              child: SoftFigure(
                  label: tr('Paid'),
                  value: formatBdt(detail.paidAmount),
                  tone: ChipTone.green)),
          const SizedBox(width: 8),
          Expanded(
              child: SoftFigure(
                  label: tr('Still due'),
                  value: formatBdt(detail.dueAmount),
                  tone: detail.dueAmount > 0
                      ? ChipTone.amber
                      : ChipTone.neutral)),
        ])),
        if (onRecord != null) ...[
          const SizedBox(height: 12),
          AppButton(
              key: const Key('shipment-record-payment'),
              label: tr('Record payment'),
              icon: Icons.add_rounded,
              kind: AppButtonKind.current,
              onPressed: onRecord),
        ],
      ]));
}

/// Charge less the shipment's share of the flight costs. An older server
/// sends no breakdown: then it is the charge less this shipment's costs, as
/// before.
class _ProfitCard extends StatelessWidget {
  const _ProfitCard({required this.detail});
  final AdminShipmentDetail detail;

  @override
  Widget build(BuildContext context) {
    final breakdown = detail.profitBreakdown;
    final double profit;
    final List<Widget> rows;
    if (breakdown != null) {
      profit = breakdown.profit;
      final flight = detail.flightCode == null
          ? null
          : displayFlightCode(detail.flightCode!);
      rows = [
        MoneyRow(label: tr('Charge'), value: formatBdt(breakdown.charge)),
        MoneyRow(
            label: tr('Share of flight costs'),
            note: flight == null
                ? tr('Not on a flight yet')
                : breakdown.flightKg > 0
                    ? tr('{kg} of {total} kg on {flight}', {
                        'kg': breakdown.shareKg.toStringAsFixed(1),
                        'total': plainKg(breakdown.flightKg),
                        'flight': flight
                      })
                    : null,
            value: '−${formatBdt(breakdown.flightCostShare)}'),
        if (breakdown.otherCosts > 0.001)
          MoneyRow(
              label: tr('Other costs (not on the bill)'),
              value: '−${formatBdt(breakdown.otherCosts)}'),
        if (breakdown.billCosts > 0.001)
          MoneyRow(
              label: tr('Costs on the bill'),
              value: tr('{amount} in, {amount} out',
                  {'amount': formatBdt(breakdown.billCosts)}),
              color: AppColors.muted,
              valueWeight: FontWeight.w400),
      ];
    } else {
      final costs = detail.costTotal ?? 0;
      profit = detail.profitBeforeTicket ?? (detail.billAmount - costs);
      rows = [
        MoneyRow(label: tr('Charge'), value: formatBdt(detail.billAmount)),
        MoneyRow(label: tr('Costs'), value: '−${formatBdt(costs)}'),
      ];
    }
    return PaperCard(
        key: const Key('shipment-profit'),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Text(tr('Profit on this shipment'),
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Text(formatBdt(profit),
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: profit < 0 ? AppColors.danger : AppColors.ok,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
          const SizedBox(height: 4),
          ...rows,
          const SizedBox(height: 4),
          Text(tr('Ticket and flyer money are counted on the flight.'),
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: AppColors.muted)),
        ]));
  }
}

/// "Courier · paid from Dhaka cash" or "Courier · Pay later · unpaid".
String _billCostDetail(ShipmentCostItem item) {
  final String paid;
  if (item.dueAmount <= 0.001) {
    paid = item.accountName == null
        ? tr('Paid')
        : tr('paid from {account}', {'account': item.accountName});
  } else if (item.paidAmount <= 0.001) {
    paid = tr('Pay later · unpaid');
  } else {
    paid = tr('{amount} still to pay', {'amount': formatBdt(item.dueAmount)});
  }
  return [costCategoryLabel(item.category), paid].join(' · ');
}

/// What was added to the customer's bill: they pay these back.
class _BillCostsCard extends StatelessWidget {
  const _BillCostsCard(
      {required this.detail, required this.onAdd, required this.onOpen});
  final AdminShipmentDetail detail;
  final VoidCallback onAdd, onOpen;

  @override
  Widget build(BuildContext context) {
    final costs = detail.billCosts;
    final any = detail.costItems?.isNotEmpty ?? false;
    return PaperCard(
        key: const Key('shipment-bill-costs'),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CardHead(
              title: tr('Costs on the bill'),
              subtitle: tr('The customer pays these'),
              trailing:
                  AddButton(key: const Key('bill-cost-add'), onPressed: onAdd)),
          const SizedBox(height: 4),
          if (costs.isEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(tr('Nothing added to this bill yet.'),
                    style: const TextStyle(
                        fontSize: 13, height: 1.45, color: AppColors.muted)))
          else
            for (var i = 0; i < costs.length; i++)
              CostLine(
                  key: ValueKey('bill-cost-${costs[i].id}'),
                  icon: usualCostIcon(costs[i].category),
                  title: costs[i].name,
                  detail: _billCostDetail(costs[i]),
                  amount: formatBdt(costs[i].amount),
                  divider: i < costs.length - 1,
                  onTap: onOpen),
          if (any)
            Align(
                alignment: AlignmentDirectional.centerEnd,
                child: LinkText(
                    key: const Key('costs-all'),
                    label: tr('All costs'),
                    chevron: true,
                    onTap: onOpen)),
        ]));
  }
}

/// Who the shipment is for and how it was booked.
class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.detail, required this.onOpenFlight});
  final AdminShipmentDetail detail;
  final VoidCallback? onOpenFlight;

  @override
  Widget build(BuildContext context) {
    final name = detail.supplierName ?? detail.supplierCode;
    return PaperCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CardTitle(title: tr('Booking'), size: 15),
      const SizedBox(height: 14),
      Row(children: [
        LetterAvatar.customer(name),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, height: 1.3)),
          Text(
              [
                tr('Customer {code}', {'code': detail.supplierCode}),
                if (detail.description.isNotEmpty) detail.description,
              ].join(' · '),
              style: const TextStyle(
                  fontSize: 13, color: AppColors.muted, height: 1.4)),
        ])),
      ]),
      const Divider(height: 28),
      FactGrid(facts: [
        Fact(
            tr('Flight'),
            detail.flightCode == null
                ? tr('Not assigned')
                : displayFlightCode(detail.flightCode!),
            onTap: onOpenFlight),
        Fact(tr('Flight date'),
            detail.flightDate == null ? '—' : shortDay(detail.flightDate!)),
        Fact(tr('Flyer'), detail.flyerName ?? tr('Not assigned')),
        Fact(tr('Booked weight'), formatKg(detail.bookedKg)),
        if (detail.categories.isNotEmpty)
          Fact(tr('Categories'), detail.categories.join(', ')),
        for (final line in detail.devices)
          if (line.count > 0)
            Fact(line.category, trn(line.count, '{n} piece', '{n} pieces')),
        Fact(tr('Booked on'), dayMonth(detail.date)),
      ]),
    ]));
  }
}

/// Picks how long a new customer link stays valid and makes it.
class _NewLinkSheet extends StatefulWidget {
  const _NewLinkSheet(
      {required this.code,
      required this.customer,
      required this.withBill,
      required this.onMake});
  final String code, customer;
  final bool withBill;

  /// Returns the error message, or null once the link is made.
  final Future<String?> Function(int days) onMake;

  @override
  State<_NewLinkSheet> createState() => _NewLinkSheetState();
}

class _NewLinkSheetState extends State<_NewLinkSheet> {
  static const _choices = [7, 14, 30];
  var _days = 7;
  var _busy = false;
  String? _error;

  Future<void> _make() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onMake(_days);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetHeader(
            title: tr('New customer link'),
            subtitle: '${widget.code} · ${widget.customer}'),
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SheetLabel(tr('Valid for')),
                  ScreenTabs(
                      labels: [tr('7 days'), tr('14 days'), tr('30 days')],
                      index: _choices.indexOf(_days),
                      onChanged: (i) => setState(() => _days = _choices[i])),
                  const SizedBox(height: 14),
                  NoteBox(
                      icon: widget.withBill
                          ? Icons.description_outlined
                          : Icons.local_shipping_outlined,
                      tone: widget.withBill ? ChipTone.green : ChipTone.neutral,
                      title: widget.withBill
                          ? tr('Tracking and bill')
                          : tr('Tracking only'),
                      body: widget.withBill
                          ? tr(
                              'The customer sees where the parcel is, the bill and what is paid.')
                          : tr(
                              'The customer sees where the parcel is. The bill joins once it is issued.')),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    ErrorNote(message: _error!),
                  ],
                  const SizedBox(height: 16),
                  AppButton(
                      key: const Key('link-make'),
                      label: tr('Make link'),
                      icon: Icons.link_rounded,
                      kind: AppButtonKind.current,
                      busy: _busy,
                      onPressed: _make),
                ])),
      ]));
}

/// Where each pipeline status sits: China hub, flight, Dhaka hub, delivery.
const _pipelineGroups = [
  (label: 'China hub', from: 0, count: 3),
  (label: 'Flight', from: 3, count: 2),
  (label: 'Dhaka hub', from: 5, count: 2),
  (label: 'Delivery', from: 7, count: 2),
];

const _pipeline = [
  'pending',
  'received_cn_hub',
  'ready_for_shipment',
  'in_transit',
  'customs_cleared',
  'received_bd_hub',
  'ready_for_last_mile',
  'out_for_delivery',
  'delivered',
];

String _groupLabel(String label) => switch (label) {
      'China hub' => tr('China hub'),
      'Flight' => tr('Flight'),
      'Dhaka hub' => tr('Dhaka hub'),
      _ => tr('Delivery'),
    };

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.detail});
  final AdminShipmentDetail detail;

  @override
  Widget build(BuildContext context) {
    final total = _pipeline.length;
    final index = detail.statusIndex.clamp(0, total - 1);
    final done = index >= total - 1;
    final next = done ? null : _pipeline[index + 1];
    final nextLabel = next == null ? null : banglaStatus(next, next);
    final flight = detail.flightCode == null
        ? null
        : displayFlightCode(detail.flightCode!);
    final hint = done
        ? tr('Delivered to the customer.')
        : next == 'in_transit' && flight != null
            ? tr('Next: {status}, when {flight} departs',
                {'status': nextLabel, 'flight': flight})
            : tr('Next: {status}', {'status': nextLabel});
    return PaperCard(
        radius: heroRadius,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(banglaStatus(detail.status, detail.statusLabel),
                      style: const TextStyle(
                          fontSize: 18,
                          height: 1.3,
                          fontWeight: FontWeight.w700)),
                  Text(hint,
                      style: const TextStyle(
                          fontSize: 13, height: 1.45, color: AppColors.muted)),
                ])),
            const SizedBox(width: 10),
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: StatusPill(
                    label: tr('Step {step} of {total}',
                        {'step': index + 1, 'total': total}),
                    tone: done ? ChipTone.green : ChipTone.blue)),
          ]),
          if (detail.exception != null) ...[
            const SizedBox(height: 10),
            Align(
                alignment: Alignment.centerLeft,
                child: InfoChip(
                    icon: Icons.block_rounded,
                    label: [
                      tr('Exception: {type}', {'type': detail.exception}),
                      if (detail.exceptionReason.isNotEmpty)
                        detail.exceptionReason
                    ].join(' · '),
                    tone: ChipTone.red)),
          ],
          const SizedBox(height: 10),
          Semantics(
              label: tr('Step {step} of {total}',
                  {'step': index + 1, 'total': total}),
              excludeSemantics: true,
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final group in _pipelineGroups) ...[
                  if (group.from > 0) const SizedBox(width: 4),
                  Expanded(
                      flex: group.count,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              for (var i = group.from;
                                  i < group.from + group.count;
                                  i++) ...[
                                if (i > group.from) const SizedBox(width: 4),
                                Expanded(child: _Segment(state: i - index)),
                              ]
                            ]),
                            const SizedBox(height: 6),
                            WordFitText(_groupLabel(group.label),
                                maxLines: 2,
                                style: TextStyle(
                                    fontSize: 12,
                                    height: 1.3,
                                    fontWeight: index >= group.from &&
                                            index < group.from + group.count
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: index >= group.from &&
                                            index < group.from + group.count
                                        ? AppColors.primaryInk
                                        : AppColors.muted)),
                          ])),
                ]
              ])),
        ]));
  }
}

/// One pipeline step: negative is done, 0 is the current step.
class _Segment extends StatelessWidget {
  const _Segment({required this.state});
  final int state;

  @override
  Widget build(BuildContext context) => Container(
      height: 6,
      decoration: BoxDecoration(
          color: state <= 0 ? AppColors.primary : AppColors.line,
          borderRadius: BorderRadius.circular(3),
          boxShadow: state == 0
              ? const [BoxShadow(color: AppColors.primarySoft, spreadRadius: 3)]
              : null));
}

/// The Dhaka hub steps as four marks: weighed, packed, courier, handover.
class _HandlingCard extends StatelessWidget {
  const _HandlingCard({required this.detail});
  final AdminShipmentDetail detail;

  @override
  Widget build(BuildContext context) {
    final weighed = detail.weighedKg;
    final delta = formatWeightDelta(detail.weightDelta);
    final courier = detail.lastMile;
    final handed =
        courier?.handedOverAt != null || detail.status == 'delivered';
    final steps = [
      (
        icon: Icons.scale_outlined,
        label: tr('Weighed'),
        value: weighed == null
            ? tr('Not yet')
            : [formatKg(weighed), if (delta != null) delta].join(' · '),
        done: weighed != null
      ),
      (
        icon: Icons.inventory_2_outlined,
        label: tr('Packed'),
        value: detail.packedAt == null
            ? tr('Not yet')
            : trn(detail.packageCount, '{n} package', '{n} packages'),
        done: detail.packedAt != null
      ),
      (
        icon: Icons.local_shipping_outlined,
        label: tr('Courier'),
        value: courier == null
            ? tr('Not booked')
            : courier.isPickup
                ? tr('Pickup')
                : courier.courier,
        done: courier != null
      ),
      (
        icon: Icons.how_to_reg_outlined,
        label: tr('Handover'),
        value: handed ? tr('Done') : tr('Waiting'),
        done: handed
      ),
    ];
    return PaperCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: Text(tr('Handling and delivery'),
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            Flexible(
                child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(tr('Dhaka hub steps'),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.muted)))),
          ]),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final step in steps)
              Expanded(
                  child: Semantics(
                      label: '${step.label}: ${step.value}',
                      excludeSemantics: true,
                      child: Column(children: [
                        Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                                color: step.done
                                    ? AppColors.okSoft
                                    : AppColors.card,
                                shape: BoxShape.circle,
                                border: step.done
                                    ? null
                                    : Border.all(
                                        color: AppColors.field, width: 2)),
                            child: Icon(
                                step.done ? Icons.check_rounded : step.icon,
                                size: 15,
                                color: step.done
                                    ? AppColors.ok
                                    : AppColors.muted)),
                        const SizedBox(height: 4),
                        WordFitText(step.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                color: AppColors.muted)),
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(step.value,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13,
                                    height: 1.3,
                                    fontWeight: FontWeight.w600,
                                    color: step.done
                                        ? AppColors.ink
                                        : AppColors.inkSoft))),
                      ]))),
          ]),
        ]));
  }
}

class _Photos extends StatelessWidget {
  const _Photos(
      {required this.media,
      required this.tray,
      required this.loader,
      required this.onPick,
      required this.onOpen,
      required this.onToggle});

  final ShipmentMediaList? media;
  final PhotoTrayController tray;
  final SignedPhotoLoader loader;
  final void Function(FileSource source) onPick;
  final void Function(List<MediaItem> ordered, int index) onOpen;
  final Future<void> Function(MediaItem item, bool shared) onToggle;

  @override
  Widget build(BuildContext context) {
    final list = media;
    final off = list?.configured == false;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PaperCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardHeading(
            icon: Icons.photo_library_outlined,
            title: tr('Shipment photos'),
            subtitle: tr(
                'IMEI photos are not listed here and are never shared with the customer.')),
        const SizedBox(height: 14),
        if (off)
          ErrorNote(
              message: tr(
                  'Storage is not set up yet. Uploads will turn on once an admin finishes storage setup.')),
        PhotoTray(
            tray: tray,
            onPick: onPick,
            enabled: !off,
            group: tr('Parcel photos')),
      ])),
      const SizedBox(height: 16),
      StoredPhotoGrid(
          media: list?.media ?? const [],
          loader: loader,
          configured: !off,
          onOpen: onOpen,
          onToggle: onToggle),
    ]);
  }
}
