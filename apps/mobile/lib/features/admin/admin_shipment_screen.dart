import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/media_item.dart';
import '../../data/models/shipment.dart';
import '../../data/uploads/flutter_heic.dart';
import '../../data/uploads/image_prepare.dart';
import '../../data/uploads/picked_photo_file.dart';
import '../../data/uploads/photo_upload.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import 'money_format.dart';
import 'shipment_money_panel.dart';

class AdminShipmentScreen extends StatefulWidget {
  const AdminShipmentScreen(
      {super.key, required this.code, this.initialTab = 0});

  final String code;
  final int initialTab;

  @override
  State<AdminShipmentScreen> createState() => _AdminShipmentScreenState();
}

class _AdminShipmentScreenState extends State<AdminShipmentScreen> {
  AdminShipmentDetail? _detail;
  ShipmentMediaList? _media;
  String? _error;
  String? _link;
  var _loading = true;
  var _tab = 0;
  PhotoUploadController? _photos;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _photos ??= PhotoUploadController(
      decodeHeic: flutterDecodeHeic,
      upload: (image, progress) =>
          AppScope.of(context).media.uploadPhoto(widget.code, image, progress),
    )..addListener(() {
        if (mounted) setState(() {});
        if (_photos?.done == true) _loadMedia();
      });
  }

  @override
  void dispose() {
    _photos?.dispose();
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
      await _loadMedia();
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

  Future<void> _share() async {
    try {
      final link =
          await AppScope.of(context).shipments.shareTracking(widget.code);
      if (!mounted) return;
      setState(() => _link = link.url);
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    }
  }

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source);
    if (file == null) return;
    try {
      await _photos?.select(PickedPhoto(
          bytes: await file.readAsBytes(),
          name: file.name,
          mime: file.mimeType));
    } finally {
      await deletePickedPhotoFile(file.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return WorkspaceScaffold(
        title: widget.code,
        subtitle: tr('Shipment details and finance'),
        toolbar: ScreenTabs(
            labels: [tr('Summary'), tr('Bill'), tr('Photos')],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i)),
        children: [
          if (_loading && detail == null)
            const LinearProgressIndicator(
                color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (detail != null && _tab == 0)
            _Summary(detail: detail, link: _link, onShare: _share),
          if (detail != null && _tab == 1) ...[
            _Bill(detail: detail),
            ShipmentMoneyPanel(
                code: widget.code,
                dueAmount: detail.dueAmount,
                onChanged: _load),
          ],
          if (detail != null && _tab == 2)
            _Photos(
                media: _media,
                photos: _photos,
                onPick: _pick,
                onToggle: _toggleShare),
        ]);
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
}

class _Summary extends StatelessWidget {
  const _Summary(
      {required this.detail, required this.link, required this.onShare});
  final AdminShipmentDetail detail;
  final String? link;
  final VoidCallback onShare;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        PaperCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StatusPill(
              label: banglaStatus(detail.status, detail.statusLabel),
              tone: shipmentStatusTone(detail.statusIndex)),
          const SizedBox(height: 12),
          Text(detail.supplierName ?? detail.supplierCode,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 22)),
          const SizedBox(height: 4),
          Text(detail.description,
              style: const TextStyle(color: AppColors.muted)),
          const Divider(),
          KvRow(label: tr('Customer code'), value: detail.supplierCode),
          KvRow(
              label: tr('Flight'),
              value: detail.flightCode ?? tr('Not assigned')),
          if (detail.flightDate != null)
            KvRow(label: tr('Flight date'), value: detail.flightDate!),
          KvRow(
              label: tr('Flyer'),
              value: detail.flyerName ?? tr('Not assigned')),
        ])),
        const SizedBox(height: 24),
        SectionTitle(title: tr('Handling and delivery')),
        PaperCard(
            child: Column(children: [
          KvRow(label: tr('Booked weight'), value: formatKg(detail.bookedKg)),
          KvRow(
              label: tr('Measured weight'),
              value: detail.weighedKg == null
                  ? tr('Not weighed yet')
                  : formatKg(detail.weighedKg!)),
          KvRow(
              label: tr('Packing'),
              value: detail.packedAt == null
                  ? tr('Not packed')
                  : trn(detail.packageCount, '{n} package', '{n} packages')),
          KvRow(
              label: tr('Courier'),
              value: detail.lastMile?.courier ?? tr('Not booked')),
          if (detail.lastMile != null)
            KvRow(label: tr('Reference'), value: detail.lastMile!.ref),
        ])),
        const SizedBox(height: 20),
        AppButton(
            label: tr('Share tracking link'),
            icon: Icons.link_rounded,
            kind: AppButtonKind.quiet,
            onPressed: onShare),
        if (link != null) ...[
          const SizedBox(height: 12),
          PaperCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                SelectableText(link!,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 12),
                AppButton(
                    label: tr('Copy link'),
                    icon: Icons.copy_rounded,
                    kind: AppButtonKind.quiet,
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: link!))),
              ])),
        ],
        const SizedBox(height: 10),
        Text(tr('For a link with the invoice, open the Bill tab.'),
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ]);
}

class _Bill extends StatelessWidget {
  const _Bill({required this.detail});
  final AdminShipmentDetail detail;
  @override
  Widget build(BuildContext context) => PaperCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(tr('Amount due'),
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 12))),
          StatusPill(
              label: payStatusLabel(detail.payStatus),
              tone: payTone(detail.payStatus))
        ]),
        const SizedBox(height: 8),
        Text(formatBdt(detail.dueAmount),
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w600, height: 1.2)),
        const Divider(height: 28),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: AmountLabel(
                  label: tr('Total bill'),
                  value: formatBdt(detail.billAmount),
                  size: 17)),
          const SizedBox(width: 12),
          Expanded(
              child: AmountLabel(
                  label: tr('Paid'),
                  value: formatBdt(detail.paidAmount),
                  size: 17)),
        ]),
        const SizedBox(height: 12),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text(tr('Charge and payment details'),
                style: const TextStyle(fontSize: 13)),
            shape: const Border(),
            collapsedShape: const Border(),
            children: [
              KvRow(label: tr('Charge'), value: formatBdt(detail.charge)),
              KvRow(
                  label: tr('Discount'),
                  value: formatBdt(detail.discountAmount)),
              KvRow(
                  label: tr('Rate per kg'),
                  value:
                      '${detail.chargeCurrency} ${detail.chargeRate.toStringAsFixed(2)}'),
              KvRow(label: tr('Method'), value: detail.payMethod ?? '—'),
              KvRow(
                  label: tr('Terms'),
                  value: paymentTermsLabel(detail.paymentTerms)),
              if (detail.freeOfCharge) Text(tr('Free of charge')),
              if (detail.invoice != null)
                KvRow(
                    label: tr('Invoice'),
                    value:
                        '${detail.invoice!.number}${detail.invoice!.needsReview ? ' · ${tr('Needs review')}' : ''}'),
              for (final payment in detail.payments)
                KvRow(label: payment.method, value: formatBdt(payment.amount)),
            ]),
      ]));
}

class _Photos extends StatelessWidget {
  const _Photos(
      {required this.media,
      required this.photos,
      required this.onPick,
      required this.onToggle});

  final ShipmentMediaList? media;
  final PhotoUploadController? photos;
  final Future<void> Function(ImageSource source) onPick;
  final Future<void> Function(MediaItem item, bool shared) onToggle;

  @override
  Widget build(BuildContext context) {
    final list = media;
    final upload = photos;
    return Column(
      children: [
        Text(
            tr('IMEI photos are not listed here and are never shared with the customer.'),
            style: const TextStyle(color: AppColors.muted, height: 1.35)),
        const SizedBox(height: 8),
        if (list != null && !list.configured)
          ErrorNote(
              message: tr(
                  'Storage is not set up yet. Uploads will turn on once an admin finishes storage setup.')),
        Row(
          children: [
            Expanded(
                child: AppButton(
                    label: tr('Camera'),
                    kind: AppButtonKind.quiet,
                    onPressed: list?.configured == false
                        ? null
                        : () => onPick(ImageSource.camera))),
            const SizedBox(width: 8),
            Expanded(
                child: AppButton(
                    label: tr('Gallery'),
                    kind: AppButtonKind.quiet,
                    onPressed: list?.configured == false
                        ? null
                        : () => onPick(ImageSource.gallery))),
          ],
        ),
        if (upload != null && upload.prepared != null) ...[
          const SizedBox(height: 8),
          Text(locationStrippedNote,
              style: const TextStyle(color: AppColors.muted)),
        ],
        if (upload != null && upload.busy)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(
                value: upload.progress == 0 ? null : upload.progress,
                color: AppColors.teal,
                backgroundColor: AppColors.tealSoft),
          ),
        if (upload != null && upload.error != null) ...[
          const SizedBox(height: 8),
          Text(upload.error!,
              style: const TextStyle(color: AppColors.danger, height: 1.35)),
          const SizedBox(height: 8),
          AppButton(
              label: tr('Send the same photo again'),
              kind: AppButtonKind.teal,
              onPressed: upload.retry),
        ],
        const SizedBox(height: 12),
        if (list == null || list.media.isEmpty)
          EmptyNote(
              title: tr('No photos'),
              body: tr('Photos you add will appear here.'))
        else
          for (final item in list.media) ...[
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                      item.shared
                          ? tr('Visible to customer')
                          : tr('Staff only'),
                      style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 8),
                  AppButton(
                    label: item.shared
                        ? tr('Stop sharing')
                        : tr('Share with customer'),
                    kind: AppButtonKind.teal,
                    onPressed: () => onToggle(item, !item.shared),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}
