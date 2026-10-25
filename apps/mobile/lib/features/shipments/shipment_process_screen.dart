import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/hub/hub_chain.dart';
import '../../data/models/flight.dart';
import '../../data/models/shipment.dart';
import '../../data/uploads/flutter_heic.dart';
import '../../data/uploads/image_prepare.dart';
import '../../data/uploads/picked_photo_file.dart';
import '../../data/uploads/photo_upload.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';
import '../imei/imei_guide_screen.dart';

class ShipmentProcessScreen extends StatefulWidget {
  const ShipmentProcessScreen({super.key, required this.code});

  final String code;

  @override
  State<ShipmentProcessScreen> createState() => _ShipmentProcessScreenState();
}

class _ShipmentProcessScreenState extends State<ShipmentProcessScreen> {
  HubShipmentDetail? _detail;
  String? _error;
  var _loading = true;
  var _busy = false;
  final _kg = TextEditingController();
  final _count = TextEditingController(text: '1');
  final _courier = TextEditingController(text: 'Pathao');
  final _ref = TextEditingController();
  final _reason = TextEditingController();
  final _confirmation = TextEditingController();
  final _holdReason = TextEditingController();
  var _mode = 'courier';
  PhotoUploadController? _photos;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _kg,
      _count,
      _courier,
      _ref,
      _reason,
      _confirmation,
      _holdReason
    ]) {
      controller.addListener(() {
        if (mounted) setState(() {});
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _photos ??= PhotoUploadController(
      decodeHeic: flutterDecodeHeic,
      upload: (image, onProgress) => AppScope.of(context)
          .media
          .uploadPhoto(widget.code, image, onProgress),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _photos?.dispose();
    _kg.dispose();
    _count.dispose();
    _courier.dispose();
    _ref.dispose();
    _reason.dispose();
    _confirmation.dispose();
    _holdReason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail =
          await AppScope.of(context).shipments.hubDetail(widget.code);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        if (detail.lastMile != null) {
          _mode = detail.lastMile!.mode;
          _courier.text = detail.lastMile!.courier;
          _ref.text = detail.lastMile!.ref;
        }
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

  void fail(String message) => setState(() => _error = message);

  void chooseMode(String mode) => setState(() => _mode = mode);

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      await _load();
    } on ApiException catch (error) {
      if (!mounted || error.status == 401) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final chain = detail == null ? null : chainForDetail(detail);
    final done = chain == null
        ? 0
        : HubChainStep.values
            .where((step) =>
                chain.visual(step) == HubStepVisual.done ||
                chain.visual(step) == HubStepVisual.skipped)
            .length;
    return WorkspaceScaffold(
        title: widget.code,
        root: false,
        subtitle: chain?.current == null
            ? 'হাব প্রসেসিং'
            : 'হাব প্রসেসিং · ধাপ ${chain!.current!.index + 1}/5',
        actions: [
          if (detail != null)
            Center(
                child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: StatusPill(
                        label: banglaStatus(detail.status, detail.statusLabel),
                        tone: shipmentStatusTone(detail.statusIndex)))),
        ],
        children: [
          if (_loading && detail == null) const LinearProgressIndicator(),
          if (_error != null) ...[
            ErrorNote(message: _error!, onRetry: _load),
          ],
          if (detail != null && chain != null) ...[
            _Facts(detail: detail),
            if (detail.deviceCount > 0) ...[
              const SizedBox(height: 12),
              AppButton(
                label: detail.devicePhotoCount < detail.deviceCount
                    ? 'IMEI ছবি নিন (${detail.devicePhotoCount}/${detail.deviceCount})'
                    : 'IMEI ছবি দেখুন',
                icon: Icons.qr_code_scanner_rounded,
                kind: AppButtonKind.tonal,
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            DeviceUnitsScreen(code: widget.code, hub: true))),
              ),
            ],
            if (chain.current == null) ...[
              const SizedBox(height: 12),
              PaperCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const SectionTitle(title: 'পরবর্তী কাজ'),
                    _Action(detail: detail, chain: chain, state: this),
                  ])),
            ],
            const SizedBox(height: 12),
            PaperCard(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        const Expanded(
                            child: Text('কাজের ধাপ',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700))),
                        Text('$done/5 সম্পন্ন',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.muted)),
                      ]),
                      const SizedBox(height: 14),
                      for (final step in HubChainStep.values)
                        _StepTile(
                            step: step,
                            chain: chain,
                            last: step == HubChainStep.handover,
                            child: chain.current == step
                                ? _Action(
                                    detail: detail, chain: chain, state: this)
                                : null),
                    ])),
            const SizedBox(height: 12),
            _Photos(controller: _photos, onPick: _pickPhoto),
          ],
        ]);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source);
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      await _photos?.select(
          PickedPhoto(bytes: bytes, name: file.name, mime: file.mimeType));
    } finally {
      await deletePickedPhotoFile(file.path);
    }
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.detail});

  final HubShipmentDetail detail;

  @override
  Widget build(BuildContext context) {
    final delta = detail.weightDelta;
    Widget fact(String label, String value) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, height: 1.35)),
        ]);
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: fact('কাস্টমার', detail.supplierCode)),
            const SizedBox(width: 16),
            Expanded(
                child: fact('পণ্য',
                    detail.description.isEmpty ? '—' : detail.description)),
          ]),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: fact(
                    detail.weighedKg == null ? 'বুকিং ওজন' : 'মাপা ওজন',
                    detail.weighedKg == null
                        ? formatKg(detail.bookedKg)
                        : '${formatKg(detail.weighedKg!)} (বুকিং ${formatKg(detail.bookedKg)})')),
            const SizedBox(width: 16),
            Expanded(
                child: fact(
                    'ফ্লাইট',
                    detail.flightCode == null
                        ? '—'
                        : [
                            displayFlightCode(detail.flightCode!),
                            if (detail.flightDate != null) detail.flightDate!
                          ].join(' · '))),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (delta != null)
              InfoChip(
                  icon: Icons.warning_amber_rounded,
                  label: formatWeightDelta(delta)!,
                  tone: ChipTone.red),
            if (detail.flyerName != null)
              InfoChip(
                  icon: Icons.person_outline_rounded,
                  label: 'ফ্লায়ার ${detail.flyerName}'),
            InfoChip(
                icon: Icons.inventory_2_outlined,
                label: detail.packedAt == null
                    ? 'প্যাক হয়নি'
                    : 'প্যাকেজ ${detail.packageCount}'),
            if (detail.hasCourierRef)
              InfoChip(
                  icon: Icons.local_shipping_outlined,
                  label:
                      '${detail.lastMile!.courier} · ${detail.lastMile!.ref}'),
            if (detail.deviceCount > 0)
              InfoChip(
                  icon: Icons.smartphone_rounded,
                  label:
                      'ডিভাইস ${detail.deviceCount} · ছবি ${detail.devicePhotoCount}/${detail.deviceCount}'),
            InfoChip(
                icon: Icons.photo_library_outlined,
                label: 'ছবি ${detail.photosCount}'),
            if (detail.exception != null)
              InfoChip(
                  icon: Icons.block_rounded,
                  label: 'এক্সসেপশন: ${detail.exception}',
                  tone: ChipTone.red),
          ]),
        ],
      ),
    );
  }
}

const _stepHints = {
  HubChainStep.weigh: ('ওজন মাপুন', 'স্কেলে মেপে kg-তে লিখুন'),
  HubChainStep.pack: ('প্যাক', 'প্যাকিং শেষ হলে কনফার্ম'),
  HubChainStep.courier: ('কুরিয়ার বা হাব পিকআপ', 'কীভাবে পৌঁছাবে বেছে নিন'),
  HubChainStep.dispatch: ('ডিসপ্যাচ', 'পার্সেল রওনা হলে কনফার্ম'),
  HubChainStep.handover: ('হ্যান্ডওভার', 'কাস্টমার বুঝে পেলে শেষ'),
};

/// One row of the vertical stepper. The current step carries its form.
class _StepTile extends StatelessWidget {
  const _StepTile(
      {required this.step,
      required this.chain,
      required this.last,
      this.child});

  final HubChainStep step;
  final HubChainSnapshot chain;
  final bool last;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final visual = chain.visual(step);
    final current = visual == HubStepVisual.current;
    final finished =
        visual == HubStepVisual.done || visual == HubStepVisual.skipped;
    final (title, hint) = _stepHints[step]!;
    final note = switch (visual) {
      HubStepVisual.waiting => hint,
      HubStepVisual.current => hint,
      HubStepVisual.done => 'হয়ে গেছে',
      HubStepVisual.skipped => 'হাব পিকআপ — ডিসপ্যাচ প্রযোজ্য নয়',
    };
    return Stack(children: [
      if (!last)
        Positioned(
            left: 15,
            top: 36,
            bottom: 4,
            child: Container(
                width: 2, color: finished ? AppColors.okSoft : AppColors.line)),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: current
                    ? AppColors.accentSoft
                    : finished
                        ? AppColors.okSoft
                        : AppColors.paper,
                border: Border.all(
                    color: current
                        ? AppColors.accent
                        : finished
                            ? AppColors.okSoft
                            : AppColors.field,
                    width: current ? 2 : 1.5)),
            child: finished
                ? const Icon(Icons.check_rounded, size: 18, color: AppColors.ok)
                : Text('${step.index + 1}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color:
                            current ? AppColors.accentInk : AppColors.muted))),
        const SizedBox(width: 14),
        Expanded(
            child: Padding(
                padding: EdgeInsets.only(top: 3, bottom: last ? 10 : 18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(title,
                                style: TextStyle(
                                    fontSize: current ? 16 : 15,
                                    fontWeight: current
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: finished || current
                                        ? AppColors.ink
                                        : AppColors.inkSoft)),
                            if (current)
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 1),
                                  decoration: BoxDecoration(
                                      color: AppColors.accentStrong,
                                      borderRadius: BorderRadius.circular(999)),
                                  child: const Text('এখন',
                                      style: TextStyle(
                                          fontSize: 11,
                                          height: 1.4,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white))),
                          ]),
                      Text(note,
                          style: TextStyle(
                              fontSize: 13,
                              color:
                                  finished ? AppColors.ok : AppColors.muted)),
                      if (child != null) ...[
                        const SizedBox(height: 12),
                        child!,
                      ],
                    ]))),
      ]),
    ]);
  }
}

class _Action extends StatelessWidget {
  const _Action(
      {required this.detail, required this.chain, required this.state});

  final HubShipmentDetail detail;
  final HubChainSnapshot chain;
  final _ShipmentProcessScreenState state;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).shipments;
    if (chain.blockedByException) {
      final canResume = detail.exception == 'on_hold' ||
          detail.exception == 'delivery_failed';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('চেইন থেমে আছে। চালু করতে কারণ লিখুন।'),
          const SizedBox(height: 8),
          if (canResume) ...[
            TextField(
                controller: state._holdReason,
                decoration: const InputDecoration(labelText: 'কারণ')),
            const SizedBox(height: 8),
            AppButton(
              label: 'আবার চালু করুন',
              kind: AppButtonKind.current,
              busy: state._busy,
              onPressed: state._holdReason.text.trim().length < 3
                  ? null
                  : () => state._run(() => repo.setException(detail.code,
                      type: 'resume', reason: state._holdReason.text.trim())),
            ),
          ],
        ],
      );
    }
    if (chain.waitingOnCustoms) {
      return const EmptyNote(
          title: 'কাস্টমসের অপেক্ষা',
          body: 'কাস্টমস ক্লিয়ার হলে হাবে গ্রহণ করা যাবে।');
    }
    if (chain.notAtHub) {
      return const EmptyNote(
          title: 'এখনো ঢাকা হাবে নয়', body: 'এই শিপমেন্ট হাব চেইনে ঢোকেনি।');
    }
    if (chain.needsReceive) {
      return AppButton(
        label: 'হাবে গ্রহণ করুন',
        kind: AppButtonKind.current,
        busy: state._busy,
        onPressed: () => state._run(() => repo.advance(detail.code)),
      );
    }
    if (chain.delivered) {
      return const EmptyNote(
          title: 'হ্যান্ডওভার হয়ে গেছে', body: 'এই শিপমেন্টের হাব চেইন শেষ।');
    }
    final current = chain.current;
    if (current == null) return const SizedBox.shrink();
    switch (current) {
      case HubChainStep.weigh:
        return Column(
          children: [
            TextField(
              controller: state._kg,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, height: 1.3),
              decoration: InputDecoration(
                  labelText: 'মাপা ওজন (kg)',
                  hintText: '0.0',
                  suffixText: 'kg',
                  helperText:
                      'বুকিং ${formatKg(detail.bookedKg)} · ডিভাইস-অনলি হলে ০'),
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'ওজন সেভ করুন',
              kind: AppButtonKind.current,
              busy: state._busy,
              onPressed: () {
                final kg = double.tryParse(state._kg.text.trim());
                if (kg == null || kg < 0) {
                  state.fail('সঠিক ওজন দিন। ০ গ্রহণযোগ্য।');
                  return;
                }
                state._run(() => repo.weigh(detail.code, kg));
              },
            ),
          ],
        );
      case HubChainStep.pack:
        return Column(
          children: [
            TextField(
              controller: state._count,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'প্যাকেজ সংখ্যা'),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'প্যাক কনফার্ম করুন',
              kind: AppButtonKind.current,
              busy: state._busy,
              onPressed: () {
                final count = int.tryParse(state._count.text.trim());
                if (count == null || count < 1) {
                  state.fail('প্যাকেজ সংখ্যা অন্তত ১।');
                  return;
                }
                state._run(() => repo.pack(detail.code, count));
              },
            ),
          ],
        );
      case HubChainStep.courier:
        return _CourierForm(detail: detail, state: state);
      case HubChainStep.dispatch:
        return AppButton(
          label: 'ডিসপ্যাচ কনফার্ম করুন',
          kind: AppButtonKind.current,
          busy: state._busy,
          onPressed: () => state._run(() => repo.dispatch(detail.code)),
        );
      case HubChainStep.handover:
        return Column(
          children: [
            TextField(
              controller: state._confirmation,
              decoration: InputDecoration(
                  labelText: detail.lastMile?.isPickup == true
                      ? 'কে নিল'
                      : 'ডেলিভারি কনফার্মেশন'),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'হ্যান্ডওভার কনফার্ম করুন',
              kind: AppButtonKind.current,
              busy: state._busy,
              onPressed: state._confirmation.text.trim().length < 3
                  ? null
                  : () => state._run(() => repo.handover(
                      detail.code, state._confirmation.text.trim())),
            ),
          ],
        );
    }
  }
}

class _CourierForm extends StatelessWidget {
  const _CourierForm({required this.detail, required this.state});

  final HubShipmentDetail detail;
  final _ShipmentProcessScreenState state;

  @override
  Widget build(BuildContext context) {
    final repo = AppScope.of(context).shipments;
    final correcting = detail.hasCourierRef;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: _Mode(
                    label: 'কুরিয়ার',
                    selected: state._mode == 'courier',
                    onTap: () => state.chooseMode('courier'))),
            const SizedBox(width: 8),
            Expanded(
                child: _Mode(
                    label: 'হাব পিকআপ',
                    selected: state._mode == 'pickup',
                    onTap: () => state.chooseMode('pickup'))),
          ],
        ),
        const SizedBox(height: 8),
        if (state._mode == 'courier')
          TextField(
              controller: state._courier,
              decoration: const InputDecoration(labelText: 'কুরিয়ার সার্ভিস')),
        const SizedBox(height: 8),
        TextField(
            controller: state._ref,
            decoration:
                const InputDecoration(labelText: 'বুকিং / পিকআপ রেফারেন্স')),
        if (correcting) ...[
          const SizedBox(height: 8),
          TextField(
              controller: state._reason,
              decoration: const InputDecoration(labelText: 'বদলের কারণ')),
        ],
        const SizedBox(height: 8),
        AppButton(
          label: correcting ? 'বুকিং আপডেট করুন' : 'কুরিয়ার বুক করুন',
          kind: AppButtonKind.current,
          busy: state._busy,
          onPressed: () {
            final ref = state._ref.text.trim();
            final courier = state._mode == 'pickup'
                ? 'Hub pickup'
                : state._courier.text.trim();
            if (ref.isEmpty ||
                courier.isEmpty ||
                (correcting && state._reason.text.trim().length < 3)) {
              state.fail('রেফারেন্স দিন। বদল হলে অন্তত ৩ অক্ষরের কারণ লাগে।');
              return;
            }
            state._run(() => repo.bookLastMile(
                  code: detail.code,
                  courier: courier,
                  ref: ref,
                  mode: state._mode,
                  reason: correcting ? state._reason.text.trim() : null,
                ));
          },
        ),
      ],
    );
  }
}

class _Mode extends StatelessWidget {
  const _Mode(
      {required this.label, required this.selected, required this.onTap});

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
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.teal),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? Colors.white : AppColors.teal,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _Photos extends StatelessWidget {
  const _Photos({required this.controller, required this.onPick});

  final PhotoUploadController? controller;
  final Future<void> Function(ImageSource source) onPick;

  @override
  Widget build(BuildContext context) {
    final upload = controller;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('শিপমেন্ট ছবি',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('প্যাকেজ ও পণ্যের ছবি যোগ করুন।',
              style: TextStyle(color: AppColors.muted, height: 1.35)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: AppButton(
                      label: 'ক্যামেরা',
                      kind: AppButtonKind.quiet,
                      onPressed: () => onPick(ImageSource.camera))),
              const SizedBox(width: 8),
              Expanded(
                  child: AppButton(
                      label: 'গ্যালারি',
                      kind: AppButtonKind.quiet,
                      onPressed: () => onPick(ImageSource.gallery))),
            ],
          ),
          if (upload != null && upload.prepared != null) ...[
            const SizedBox(height: 8),
            const Text(locationStrippedNote,
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
          if (upload != null && upload.busy) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
                value: upload.progress == 0 ? null : upload.progress,
                color: AppColors.teal,
                backgroundColor: AppColors.tealSoft),
          ],
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
          if (upload != null && upload.done)
            const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('ছবি যোগ হয়েছে।')),
        ],
      ),
    );
  }
}
