import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../data/models/media_item.dart';
import '../../data/models/shipment.dart';
import '../../data/uploads/flutter_heic.dart';
import '../../data/uploads/image_prepare.dart';
import '../../data/uploads/picked_photo_file.dart';
import '../../data/uploads/photo_upload.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flight_parts.dart';
import '../../widgets/ui.dart';
import '../flights/flight_detail_screen.dart';
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

  Future<void> _openFlight(String code) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => FlightDetailScreen(code: code)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return WorkspaceScaffold(
        title: widget.code,
        subtitle: tr('Shipment details and finance'),
        onRefresh: _load,
        actions: [
          if (detail != null && _tab != 1)
            Center(
                child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: detail.dueAmount > 0
                            ? StatusPill(
                                label: tr('{amount} due',
                                    {'amount': formatBdt(detail.dueAmount)}),
                                tone: ChipTone.amber)
                            : StatusPill(
                                label: payStatusLabel(detail.payStatus),
                                tone: payTone(detail.payStatus))))),
        ],
        toolbar: ScreenTabs(
            labels: [tr('Summary'), tr('Bill'), tr('Photos')],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i)),
        children: [
          if (_loading && detail == null) const LinearProgressIndicator(),
          if (_error != null) ErrorNote(message: _error!, onRetry: _load),
          if (detail != null && _tab == 0)
            _Summary(
                detail: detail,
                link: _link,
                onShare: _share,
                onOpenBill: () => setState(() => _tab = 1),
                onOpenFlight: detail.flightCode == null
                    ? null
                    : () => _openFlight(detail.flightCode!)),
          if (detail != null && _tab == 1) ...[
            _DueHero(detail: detail),
            const SizedBox(height: 12),
            ShipmentMoneyPanel(
                code: widget.code,
                dueAmount: detail.dueAmount,
                detail: detail,
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
        padding: const EdgeInsets.all(18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(tr('Status'),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted)),
                  Text(banglaStatus(detail.status, detail.statusLabel),
                      style: const TextStyle(
                          fontSize: 21,
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
          const SizedBox(height: 14),
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

class _Summary extends StatelessWidget {
  const _Summary(
      {required this.detail,
      required this.link,
      required this.onShare,
      required this.onOpenBill,
      required this.onOpenFlight});
  final AdminShipmentDetail detail;
  final String? link;
  final VoidCallback onShare, onOpenBill;
  final VoidCallback? onOpenFlight;

  @override
  Widget build(BuildContext context) {
    final name = detail.supplierName ?? detail.supplierCode;
    final weighed = detail.weighedKg;
    final delta = formatWeightDelta(detail.weightDelta);
    final courier = detail.lastMile;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _StatusHero(detail: detail),
      const SizedBox(height: 12),
      PaperCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardTitle(title: tr('Booking'), size: 15),
        const SizedBox(height: 14),
        Row(children: [
          LetterAvatar.customer(name),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.3)),
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
        ]),
      ])),
      const SizedBox(height: 12),
      PaperCard(
          padding: const EdgeInsets.only(bottom: 4),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: CardTitle(
                    title: tr('Handling and delivery'),
                    subtitle: tr('Filled in by the Dhaka hub after landing'),
                    size: 15)),
            IconValueRow(
                icon: Icons.scale_outlined,
                label: tr('Measured weight'),
                done: weighed != null,
                value: weighed == null
                    ? tr('Not weighed yet')
                    : [formatKg(weighed), if (delta != null) delta]
                        .join(' · ')),
            const Divider(height: 1, color: AppColors.lineSoft),
            IconValueRow(
                icon: Icons.inventory_2_outlined,
                label: tr('Packing'),
                done: detail.packedAt != null,
                value: detail.packedAt == null
                    ? tr('Not packed')
                    : trn(detail.packageCount, '{n} package', '{n} packages')),
            const Divider(height: 1, color: AppColors.lineSoft),
            IconValueRow(
                icon: Icons.local_shipping_outlined,
                label: tr('Courier'),
                done: courier != null,
                value: courier == null
                    ? tr('Not booked')
                    : [
                        courier.courier,
                        if (courier.ref.trim().isNotEmpty) courier.ref
                      ].join(' · ')),
          ])),
      const SizedBox(height: 12),
      PaperCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardTitle(title: tr('Tracking for the customer'), size: 15),
        Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: '${tr('A link that shows where the parcel is.')} '),
              WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                      onTap: onOpenBill,
                      child: Text(
                          tr('For a link with the invoice, open the Bill tab.'),
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)))),
            ]),
            style: const TextStyle(
                fontSize: 13, height: 1.45, color: AppColors.muted)),
        const SizedBox(height: 12),
        AppButton(
            label: tr('Share tracking link'),
            icon: Icons.link_rounded,
            kind: AppButtonKind.quiet,
            onPressed: onShare),
        if (link != null) ...[
          const SizedBox(height: 12),
          LinkBox(url: link!),
        ],
      ])),
    ]);
  }
}

/// Navy "Amount due" hero on the Bill tab.
class _DueHero extends StatelessWidget {
  const _DueHero({required this.detail});
  final AdminShipmentDetail detail;

  @override
  Widget build(BuildContext context) => MoneyHero(
          label: tr('Amount due'),
          amount: formatBdt(detail.dueAmount),
          amountSize: 32,
          trailing: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: StatusPill(
                  label: detail.freeOfCharge
                      ? tr('Free of charge')
                      : payStatusLabel(detail.payStatus),
                  tone: detail.freeOfCharge
                      ? ChipTone.green
                      : payTone(detail.payStatus))),
          children: [
            HeroFigures(figures: [
              HeroFigure(tr('Total bill'), formatBdt(detail.billAmount)),
              HeroFigure(tr('Paid'), formatBdt(detail.paidAmount)),
              HeroFigure(tr('Terms'), paymentTermsLabel(detail.paymentTerms)),
            ]),
          ]);
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
        Row(children: [
          Expanded(
              child: AppButton(
                  label: tr('Camera'),
                  icon: Icons.photo_camera_outlined,
                  kind: AppButtonKind.quiet,
                  onPressed: off ? null : () => onPick(ImageSource.camera))),
          const SizedBox(width: 10),
          Expanded(
              child: AppButton(
                  label: tr('Gallery'),
                  icon: Icons.image_outlined,
                  kind: AppButtonKind.quiet,
                  onPressed: off ? null : () => onPick(ImageSource.gallery))),
        ]),
        if (upload != null && upload.prepared != null) ...[
          const SizedBox(height: 10),
          Text(locationStrippedNote,
              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
        if (upload != null && upload.busy)
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: MeterBar(
                  value: upload.progress == 0 ? 0.05 : upload.progress,
                  height: 6)),
        if (upload != null && upload.error != null) ...[
          const SizedBox(height: 10),
          Text(upload.error!,
              style: const TextStyle(color: AppColors.danger, height: 1.35)),
          const SizedBox(height: 8),
          AppButton(
              label: tr('Send the same photo again'),
              icon: Icons.refresh_rounded,
              kind: AppButtonKind.tonal,
              onPressed: upload.retry),
        ],
      ])),
      const SizedBox(height: 16),
      if (list == null || list.media.isEmpty)
        EmptyNote(
            icon: Icons.photo_outlined,
            title: tr('No photos'),
            body: tr('Photos you add will appear here.'))
      else ...[
        SectionTitle(title: trn(list.media.length, '{n} photo', '{n} photos')),
        RowCard(children: [
          for (final item in list.media)
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  const IconBadge(Icons.image_outlined, tone: ChipTone.neutral),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        Text(
                            item.shared
                                ? tr('Visible to customer')
                                : tr('Staff only'),
                            style: TextStyle(
                                fontSize: 13,
                                color: item.shared
                                    ? AppColors.ok
                                    : AppColors.muted)),
                      ])),
                  Semantics(
                      label: item.shared
                          ? tr('Stop sharing')
                          : tr('Share with customer'),
                      child: Switch(
                          value: item.shared,
                          onChanged: (value) => onToggle(item, value))),
                ])),
        ]),
      ],
    ]);
  }
}
