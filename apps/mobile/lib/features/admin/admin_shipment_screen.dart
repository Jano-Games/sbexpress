import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight.dart';
import '../../data/models/flow.dart';
import '../../data/models/media_item.dart';
import '../../data/models/shipment.dart';
import '../../data/uploads/flutter_heic.dart';
import '../../data/uploads/image_prepare.dart';
import '../../data/uploads/picked_photo_file.dart';
import '../../data/uploads/photo_upload.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/finance_parts.dart' show monthName;
import '../../widgets/flight_parts.dart';
import '../../widgets/flow_parts.dart';
import '../../widgets/remove_parts.dart';
import '../../widgets/ui.dart';
import '../flights/flight_detail_screen.dart';
import 'add_cost_sheet.dart';
import 'money_format.dart';
import 'shipment_costs_screen.dart';
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
  var _deleting = false;
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

  Future<void> _addCost(AdminShipmentDetail detail, String category) async {
    final saved = await showAddCostSheet(context,
        code: widget.code,
        customer: detail.supplierName ?? detail.supplierCode,
        costs: detail.costTotal ?? detail.costsTotal ?? 0,
        bill: detail.billAmount,
        category: category);
    if (saved == true && mounted) await _load();
  }

  Future<void> _openCosts() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ShipmentCostsScreen(code: widget.code)));
    if (mounted) await _load();
  }

  Future<void> _openFlight(String code) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => FlightDetailScreen(code: code)));
    if (mounted) await _load();
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
    return WorkspaceScaffold(
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
          if (detail != null && _tab == 0) ...[
            _Summary(
                detail: detail,
                link: _link,
                onShare: _share,
                onOpenBill: () => setState(() => _tab = 1),
                onOpenFlight: detail.flightCode == null
                    ? null
                    : () => _openFlight(detail.flightCode!),
                onAddCost: (category) => _addCost(detail, category),
                onOpenCosts: _openCosts),
            const SizedBox(height: 20),
            QuietDeleteButton(
                key: const Key('shipment-delete'),
                label: tr('Delete shipment'),
                busy: _deleting,
                onPressed: _delete),
          ],
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

class _Summary extends StatelessWidget {
  const _Summary(
      {required this.detail,
      required this.link,
      required this.onShare,
      required this.onOpenBill,
      required this.onOpenFlight,
      required this.onAddCost,
      required this.onOpenCosts});
  final AdminShipmentDetail detail;
  final String? link;
  final VoidCallback onShare, onOpenBill, onOpenCosts;
  final VoidCallback? onOpenFlight;
  final ValueChanged<String> onAddCost;

  @override
  Widget build(BuildContext context) {
    final name = detail.supplierName ?? detail.supplierCode;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _StatusHero(detail: detail),
      const SizedBox(height: 12),
      _ChargeCard(detail: detail),
      const SizedBox(height: 12),
      _CostsCard(detail: detail, onAdd: onAddCost, onOpenAll: onOpenCosts),
      if (detail.costTotal != null) ...[
        const SizedBox(height: 12),
        _ProfitCard(detail: detail),
      ],
      const SizedBox(height: 12),
      _HandlingCard(detail: detail),
      const SizedBox(height: 12),
      LinkCard(
          icon: Icons.description_outlined,
          title: tr('Bill and payments'),
          lines: [_billLine(detail)],
          onTap: onOpenBill),
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

/// "INV-18 · on the October bill" for the bill row.
String _billLine(AdminShipmentDetail detail) {
  final invoice = detail.invoice;
  final number =
      invoice == null || invoice.number.isEmpty ? null : invoice.number;
  final month = detail.monthly ? _billMonth(detail) : null;
  if (number == null) {
    return month == null
        ? tr('No bill issued yet')
        : tr('Goes on the {month} bill', {'month': month});
  }
  return month == null
      ? number
      : tr(
          '{number} · on the {month} bill', {'number': number, 'month': month});
}

/// The month of the monthly bill this shipment goes on.
String? _billMonth(AdminShipmentDetail detail) {
  final source = detail.invoice?.issuedAt ?? detail.date;
  final date = DateTime.tryParse(source);
  return date == null ? null : monthName(date.month);
}

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

String _number(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

class _ChargeCard extends StatelessWidget {
  const _ChargeCard({required this.detail});
  final AdminShipmentDetail detail;

  @override
  Widget build(BuildContext context) => PaperCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('Charge'),
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
                    fontSize: 28,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()]))),
        Text(_chargeBasis(detail),
            style: const TextStyle(
                fontSize: 13, height: 1.4, color: AppColors.inkSoft)),
        const SizedBox(height: 12),
        FigureStrip(figures: [
          StripFigure(
              tr('Pays'),
              detail.freeOfCharge
                  ? tr('Free of charge')
                  : paymentTermsLabel(detail.paymentTerms),
              icon: detail.monthly
                  ? Icons.calendar_month_outlined
                  : Icons.local_shipping_outlined),
          StripFigure(tr('Paid'), formatBdt(detail.paidAmount),
              color: detail.paidAmount > 0 ? AppColors.ok : null),
          StripFigure(tr('Still due'), formatBdt(detail.dueAmount)),
        ]),
      ]));
}

/// The usual four costs as a checklist, other costs and the total.
class _CostsCard extends StatelessWidget {
  const _CostsCard(
      {required this.detail, required this.onAdd, required this.onOpenAll});
  final AdminShipmentDetail detail;
  final ValueChanged<String> onAdd;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final usual = detail.usualCosts;
    final total = detail.costTotal ?? detail.costsTotal;
    final usualSum =
        usual == null ? 0.0 : usual.fold(0.0, (sum, cost) => sum + cost.amount);
    final other = total == null ? 0.0 : total - usualSum;
    final done = usual == null ? 0 : usualCostsAdded(usual);
    return PaperCard(
        padding: EdgeInsets.zero,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: CardTitle(
                        title: tr('Costs'),
                        subtitle: usual == null
                            ? null
                            : tr('The usual four, plus anything extra'))),
                if (usual != null) ...[
                  const SizedBox(width: 8),
                  Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: done >= usual.length
                          ? FlowChip(
                              label: tr('All {n} added', {'n': usual.length}),
                              tone: ChipTone.green)
                          : FlowChip(
                              label: tr('{done} of {total} added',
                                  {'done': done, 'total': usual.length}),
                              tone: detail.statusIndex >= dhakaHubIndex
                                  ? ChipTone.amber
                                  : ChipTone.neutral)),
                ],
              ])),
          if (usual != null)
            for (var i = 0; i < usual.length; i++)
              _CostLine(
                  cost: usual[i],
                  last: i == usual.length - 1 && other <= 0.001,
                  onAdd: () => onAdd(usual[i].category),
                  onOpen: onOpenAll),
          if (usual != null && other > 0.001)
            InkWell(
                onTap: onOpenAll,
                child: Container(
                    constraints: const BoxConstraints(minHeight: 52),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      const _CostMark(done: true, other: true),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(tr('Other costs'),
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600))),
                      Text(formatBdt(other),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()])),
                    ]))),
          Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(children: [
                TextButton.icon(
                    key: const Key('costs-other'),
                    onPressed: () =>
                        onAdd(usual == null ? 'courier' : 'others'),
                    style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        textStyle: const TextStyle(
                            fontFamily: 'HindSiliguri',
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                        usual == null ? tr('Add cost') : tr('Other cost'))),
                const Spacer(),
                TextButton(
                    key: const Key('costs-all'),
                    onPressed: onOpenAll,
                    child: Text(tr('All costs'))),
              ])),
          if (total != null)
            Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Expanded(
                      child: Text(tr('Total costs'),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700))),
                  Text(formatBdt(total),
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()])),
                ]))
          else
            const SizedBox(height: 12),
        ]));
  }
}

/// Green tick for an added cost, an orange dashed ring for a missing one.
class _CostMark extends StatelessWidget {
  const _CostMark({required this.done, this.other = false});
  final bool done, other;

  @override
  Widget build(BuildContext context) => done
      ? Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
              color: other ? AppColors.neutralSoft : AppColors.okSoft,
              shape: BoxShape.circle),
          child: Icon(other ? Icons.more_horiz_rounded : Icons.check_rounded,
              size: 15, color: other ? AppColors.inkSoft : AppColors.ok))
      : const SizedBox(
          width: 26, height: 26, child: CustomPaint(painter: _DashedRing()));
}

class _DashedRing extends CustomPainter {
  const _DashedRing();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = (Offset.zero & size).deflate(1);
    const dashes = 10;
    const sweep = 3.14159265 * 2 / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.6, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRing oldDelegate) => false;
}

class _CostLine extends StatelessWidget {
  const _CostLine(
      {required this.cost,
      required this.last,
      required this.onAdd,
      required this.onOpen});
  final UsualCost cost;
  final bool last;
  final VoidCallback onAdd, onOpen;

  @override
  Widget build(BuildContext context) {
    final label = usualCostLabel(cost.category);
    final body = Container(
        constraints: BoxConstraints(minHeight: cost.added ? 52 : 60),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: AppColors.lineSoft))),
        child: Row(children: [
          _CostMark(done: cost.added),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w600)),
                if (!cost.added)
                  Text(tr('Not added yet'),
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accentInk)),
              ])),
          const SizedBox(width: 8),
          if (cost.added)
            Text(formatBdt(cost.amount),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()]))
          else
            Semantics(
                label: tr('Add {cost} cost', {'cost': label}),
                excludeSemantics: true,
                child: OutlinedButton.icon(
                    key: ValueKey('cost-add-${cost.category}'),
                    onPressed: onAdd,
                    style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.accentSoft,
                        foregroundColor: AppColors.accentInk,
                        minimumSize: const Size(48, 44),
                        padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
                        side: const BorderSide(
                            color: AppColors.accent, width: 1.5),
                        textStyle: const TextStyle(
                            fontFamily: 'HindSiliguri',
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(tr('Add')))),
        ]));
    return cost.added ? InkWell(onTap: onOpen, child: body) : body;
  }
}

/// Navy card: charge − this shipment's costs = its profit.
class _ProfitCard extends StatelessWidget {
  const _ProfitCard({required this.detail});
  final AdminShipmentDetail detail;

  @override
  Widget build(BuildContext context) {
    final costs = detail.costTotal ?? 0;
    final profit = detail.profitBeforeTicket ?? (detail.billAmount - costs);
    final missing = [
      for (final cost in detail.usualCosts ?? const <UsualCost>[])
        if (!cost.added) usualCostLabel(cost.category)
    ];
    Widget figure(String label, String value, {bool end = false}) => Column(
            crossAxisAlignment:
                end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, height: 1.35, color: heroSoft)),
              FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: end ? FontWeight.w700 : FontWeight.w600,
                          color: Colors.white,
                          fontFeatures: const [FontFeature.tabularFigures()]))),
            ]);
    const sign = TextStyle(fontSize: 17, color: heroSoft);
    return MoneyHero(
        label: tr('Profit on this shipment'),
        amount: formatBdt(profit),
        amountSize: 32,
        children: [
          Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0x24FFFFFF)))),
              child: Row(children: [
                Expanded(
                    child: figure(tr('Charge'), formatBdt(detail.billAmount))),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('−', style: sign)),
                Expanded(child: figure(tr('Costs'), formatBdt(costs))),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('=', style: sign)),
                Expanded(
                    child: figure(tr('Profit'), formatBdt(profit), end: true)),
              ])),
          if (missing.isNotEmpty)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.info_outline_rounded,
                      size: 16, color: Color(0xFFFFC79E))),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(
                      tr('Not added yet: {costs}. The profit goes down when they are.',
                          {'costs': missing.join(', ')}),
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Color(0xCCFFFFFF)))),
            ]),
        ]);
  }
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
