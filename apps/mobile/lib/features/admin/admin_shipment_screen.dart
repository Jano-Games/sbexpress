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
  const AdminShipmentScreen({super.key, required this.code, this.initialTab = 0});

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
      upload: (image, progress) => AppScope.of(context).media.uploadPhoto(widget.code, image, progress),
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
      final detail = await AppScope.of(context).shipments.adminDetail(widget.code);
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
      final link = await AppScope.of(context).shipments.shareTracking(widget.code);
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
      await _photos?.select(PickedPhoto(bytes: await file.readAsBytes(), name: file.name, mime: file.mimeType));
    } finally {
      await deletePickedPhotoFile(file.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      appBar: BackTitle(title: widget.code),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              for (final (index, label) in const [(0, 'সারসংক্ষেপ'), (1, 'বিল'), (2, 'ছবি')])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
                    child: _Tab(label: label, selected: _tab == index, onTap: () => setState(() => _tab = index)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading && detail == null) const LinearProgressIndicator(color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (detail != null && _tab == 0) _Summary(detail: detail, link: _link, onShare: _share),
          if (detail != null && _tab == 1) ...[
            _Bill(detail: detail),
            ShipmentMoneyPanel(code: widget.code, dueAmount: detail.dueAmount),
          ],
          if (detail != null && _tab == 2) _Photos(media: _media, photos: _photos, onPick: _pick, onToggle: _toggleShare),
        ],
      ),
    );
  }

  Future<void> _toggleShare(MediaItem item, bool shared) async {
    try {
      await AppScope.of(context).media.setShared(widget.code, item.reference, shared: shared);
      await _loadMedia();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    }
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.teal : AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: minTouchTarget),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.teal, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.detail, required this.link, required this.onShare});

  final AdminShipmentDetail detail;
  final String? link;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PaperCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(detail.supplierName ?? detail.supplierCode, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              Text(detail.supplierCode, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 8),
              StatusPill(label: banglaStatus(detail.status, detail.statusLabel)),
              const SizedBox(height: 8),
              Text(detail.description),
              if (detail.flightCode != null) Text('ফ্লাইট ${detail.flightCode} · ${detail.flightDate ?? ''}'),
              if (detail.flyerName != null) Text('ফ্লায়ার ${detail.flyerName}'),
              Text('বুকড ${formatKg(detail.bookedKg)} · মাপা ${detail.weighedKg == null ? 'হয়নি' : formatKg(detail.weighedKg!)}'),
              Text(detail.packedAt == null ? 'প্যাক হয়নি' : 'প্যাকেজ ${detail.packageCount}'),
              Text(detail.lastMile == null ? 'কুরিয়ার রেফারেন্স নেই' : '${detail.lastMile!.courier} · ${detail.lastMile!.ref}'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppButton(label: 'শুধু tracking লিংক', kind: AppButtonKind.current, onPressed: onShare),
        if (link != null) ...[
          const SizedBox(height: 8),
          PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(link!, style: const TextStyle(height: 1.35)),
                const SizedBox(height: 8),
                AppButton(label: 'লিংক কপি', kind: AppButtonKind.quiet, onPressed: () => Clipboard.setData(ClipboardData(text: link!))),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        const Text('ইনভয়েস ইস্যু ও ইনভয়েসসহ লিংক বিল ট্যাবে।', style: TextStyle(color: AppColors.muted, height: 1.35)),
      ],
    );
  }
}

class _Bill extends StatelessWidget {
  const _Bill({required this.detail});

  final AdminShipmentDetail detail;

  @override
  Widget build(BuildContext context) {
    final invoice = detail.invoice;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line('চার্জ', formatBdt(detail.charge)),
          _line('বিল', formatBdt(detail.billAmount)),
          _line('ছাড়', formatBdt(detail.discountAmount)),
          _line('পেইড', formatBdt(detail.paidAmount)),
          _line('বাকি', formatBdt(detail.dueAmount)),
          _line('স্ট্যাটাস', payStatusLabel(detail.payStatus)),
          _line('মেথড', detail.payMethod ?? '—'),
          _line('টার্ম', paymentTermsLabel(detail.paymentTerms)),
          if (detail.freeOfCharge) const Text('ফ্রি অব চার্জ'),
          const SizedBox(height: 8),
          Text('রেট ${detail.chargeCurrency} ${detail.chargeRate.toStringAsFixed(2)} / kg'),
          const Divider(height: 24),
          if (invoice == null)
            const Text('ইনভয়েস এখনো নেই।')
          else ...[
            Text('ইনভয়েস ${invoice.number}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('${invoice.state}${invoice.needsReview ? ' · রিভিউ দরকার' : ''}'),
            Text('মোট ${formatBdt(invoice.total)} · ছাড় ${formatBdt(invoice.discount)}'),
          ],
          if (detail.payments.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final payment in detail.payments) Text('${payment.method} · ${formatBdt(payment.amount)}'),
          ],
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Photos extends StatelessWidget {
  const _Photos({required this.media, required this.photos, required this.onPick, required this.onToggle});

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
        const Text('IMEI ছবি এই তালিকায় আসে না এবং কাস্টমারের সাথে শেয়ার হয় না।', style: TextStyle(color: AppColors.muted, height: 1.35)),
        const SizedBox(height: 8),
        if (list != null && !list.configured)
          const ErrorNote(message: 'স্টোরেজ এখনো তৈরি হয়নি। অ্যাডমিন স্টোরেজ সেটআপ শেষ করলে আপলোড চালু হবে।'),
        Row(
          children: [
            Expanded(child: AppButton(label: 'ক্যামেরা', kind: AppButtonKind.quiet, onPressed: list?.configured == false ? null : () => onPick(ImageSource.camera))),
            const SizedBox(width: 8),
            Expanded(child: AppButton(label: 'গ্যালারি', kind: AppButtonKind.quiet, onPressed: list?.configured == false ? null : () => onPick(ImageSource.gallery))),
          ],
        ),
        if (upload != null && upload.prepared != null) ...[
          const SizedBox(height: 8),
          const Text(locationStrippedNote, style: TextStyle(color: AppColors.muted)),
        ],
        if (upload != null && upload.busy)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(value: upload.progress == 0 ? null : upload.progress, color: AppColors.teal, backgroundColor: AppColors.tealSoft),
          ),
        if (upload != null && upload.error != null) ...[
          const SizedBox(height: 8),
          Text(upload.error!, style: const TextStyle(color: AppColors.danger, height: 1.35)),
          const SizedBox(height: 8),
          AppButton(label: 'একই ছবি আবার পাঠান', kind: AppButtonKind.teal, onPressed: upload.retry),
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
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(item.shared ? 'কাস্টমার দেখতে পাবে' : 'শুধু স্টাফ', style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 8),
                  AppButton(
                    label: item.shared ? 'শেয়ার বন্ধ' : 'কাস্টমারের সাথে শেয়ার',
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
