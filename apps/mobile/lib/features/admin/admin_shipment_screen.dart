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
        subtitle: 'শিপমেন্টের তথ্য ও হিসাব',
        toolbar: ScreenTabs(
            labels: const ['সারসংক্ষেপ', 'বিল', 'ছবি'],
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
          KvRow(label: 'কাস্টমার কোড', value: detail.supplierCode),
          KvRow(
              label: 'ফ্লাইট', value: detail.flightCode ?? 'অ্যাসাইন করা হয়নি'),
          if (detail.flightDate != null)
            KvRow(label: 'ফ্লাইটের তারিখ', value: detail.flightDate!),
          KvRow(
              label: 'ফ্লায়ার',
              value: detail.flyerName ?? 'অ্যাসাইন করা হয়নি'),
        ])),
        const SizedBox(height: 24),
        const SectionTitle(title: 'হ্যান্ডলিং ও ডেলিভারি'),
        PaperCard(
            child: Column(children: [
          KvRow(label: 'বুকিংয়ের ওজন', value: formatKg(detail.bookedKg)),
          KvRow(
              label: 'মাপা ওজন',
              value: detail.weighedKg == null
                  ? 'এখনও মাপা হয়নি'
                  : formatKg(detail.weighedKg!)),
          KvRow(
              label: 'প্যাকিং',
              value: detail.packedAt == null
                  ? 'বাকি'
                  : '${detail.packageCount} প্যাকেজ'),
          KvRow(
              label: 'কুরিয়ার',
              value: detail.lastMile?.courier ?? 'বুক করা হয়নি'),
          if (detail.lastMile != null)
            KvRow(label: 'রেফারেন্স', value: detail.lastMile!.ref),
        ])),
        const SizedBox(height: 20),
        AppButton(
            label: 'Tracking link শেয়ার',
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
                    label: 'লিংক কপি',
                    icon: Icons.copy_rounded,
                    kind: AppButtonKind.quiet,
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: link!))),
              ])),
        ],
        const SizedBox(height: 10),
        const Text('ইনভয়েসসহ লিংকের জন্য বিল ট্যাব খুলুন।',
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
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
          const Expanded(
              child: Text('বকেয়া',
                  style: TextStyle(color: AppColors.muted, fontSize: 12))),
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
                  label: 'মোট বিল',
                  value: formatBdt(detail.billAmount),
                  size: 17)),
          const SizedBox(width: 12),
          Expanded(
              child: AmountLabel(
                  label: 'পেইড',
                  value: formatBdt(detail.paidAmount),
                  size: 17)),
        ]),
        const SizedBox(height: 12),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('চার্জ ও পেমেন্টের বিবরণ',
                style: TextStyle(fontSize: 13)),
            shape: const Border(),
            collapsedShape: const Border(),
            children: [
              KvRow(label: 'চার্জ', value: formatBdt(detail.charge)),
              KvRow(label: 'ছাড়', value: formatBdt(detail.discountAmount)),
              KvRow(
                  label: 'প্রতি kg রেট',
                  value:
                      '${detail.chargeCurrency} ${detail.chargeRate.toStringAsFixed(2)}'),
              KvRow(label: 'মেথড', value: detail.payMethod ?? '—'),
              KvRow(
                  label: 'টার্ম',
                  value: paymentTermsLabel(detail.paymentTerms)),
              if (detail.freeOfCharge) const Text('ফ্রি অব চার্জ'),
              if (detail.invoice != null)
                KvRow(
                    label: 'ইনভয়েস',
                    value:
                        '${detail.invoice!.number}${detail.invoice!.needsReview ? ' · রিভিউ দরকার' : ''}'),
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
        const Text(
            'IMEI ছবি এই তালিকায় আসে না এবং কাস্টমারের সাথে শেয়ার হয় না।',
            style: TextStyle(color: AppColors.muted, height: 1.35)),
        const SizedBox(height: 8),
        if (list != null && !list.configured)
          const ErrorNote(
              message:
                  'স্টোরেজ এখনো তৈরি হয়নি। অ্যাডমিন স্টোরেজ সেটআপ শেষ করলে আপলোড চালু হবে।'),
        Row(
          children: [
            Expanded(
                child: AppButton(
                    label: 'ক্যামেরা',
                    kind: AppButtonKind.quiet,
                    onPressed: list?.configured == false
                        ? null
                        : () => onPick(ImageSource.camera))),
            const SizedBox(width: 8),
            Expanded(
                child: AppButton(
                    label: 'গ্যালারি',
                    kind: AppButtonKind.quiet,
                    onPressed: list?.configured == false
                        ? null
                        : () => onPick(ImageSource.gallery))),
          ],
        ),
        if (upload != null && upload.prepared != null) ...[
          const SizedBox(height: 8),
          const Text(locationStrippedNote,
              style: TextStyle(color: AppColors.muted)),
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
              label: 'একই ছবি আবার পাঠান',
              kind: AppButtonKind.teal,
              onPressed: upload.retry),
        ],
        const SizedBox(height: 12),
        if (list == null || list.media.isEmpty)
          const EmptyNote(title: 'ছবি নেই', body: 'যোগ করলে এখানে দেখা যাবে।')
        else
          for (final item in list.media) ...[
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(item.shared ? 'কাস্টমার দেখতে পাবে' : 'শুধু স্টাফ',
                      style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 8),
                  AppButton(
                    label:
                        item.shared ? 'শেয়ার বন্ধ' : 'কাস্টমারের সাথে শেয়ার',
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
