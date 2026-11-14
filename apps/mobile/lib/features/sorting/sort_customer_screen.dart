import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/sorting.dart';
import '../../data/uploads/flutter_heic.dart';
import '../../data/uploads/photo_tray.dart';
import '../../data/uploads/photo_upload.dart';
import '../../data/uploads/quick_uploads.dart';
import '../../data/uploads/signed_photos.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/quick_parts.dart' show MiniStepper, askPhotoSource;
import '../../widgets/ui.dart';
import '../shipments/shipment_process_screen.dart';
import 'sort_parts.dart';

const hubPickup = 'Hub pickup';

/// One customer's orders from one flight, as the hub sorts them: measured
/// weight, what arrived and photos for each order; packages, packing photos,
/// delivery partner, courier ID and a note for the customer. Then Send to
/// admin. After approval the hub adds the courier ID and confirms delivery.
class SortCustomerScreen extends StatefulWidget {
  const SortCustomerScreen(
      {super.key,
      required this.flightCode,
      required this.customer,
      this.pickPhotos});

  final String flightCode, customer;

  /// Camera or gallery; tests pass their own photos.
  final Future<List<PickedPhoto>> Function(FileSource source)? pickPhotos;

  @override
  State<SortCustomerScreen> createState() => _SortCustomerScreenState();
}

class _SortCustomerScreenState extends State<SortCustomerScreen> {
  SortBoard? _board;
  SortGroup? _group;
  String? _error;
  var _loading = true;
  var _sending = false;
  var _tried = false;
  var _savingRef = false;

  final _kg = <String, TextEditingController>{};
  final _arrived = <String, TextEditingController>{};
  final _goods = <String, PhotoTrayController>{};
  PhotoTrayController? _packing;
  var _packages = 1;
  String? _partner;
  final _courier = TextEditingController();
  final _note = TextEditingController();
  final _ref = TextEditingController();
  var _filled = false;
  SignedPhotoLoader? _photos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _photos ??= AppScope.of(context)
        .media
        .ordersLoader((reference) => _group?.photoOrders[reference]);
  }

  @override
  void dispose() {
    for (final c in [
      ..._kg.values,
      ..._arrived.values,
      _courier,
      _note,
      _ref
    ]) {
      c.dispose();
    }
    for (final t in _goods.values) {
      t.dispose();
    }
    _packing?.dispose();
    _photos?.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final board = await AppScope.of(context).sorting.board(widget.flightCode);
      if (!mounted) return;
      final group = board.group(widget.customer);
      setState(() {
        _board = board;
        _group = group;
        if (group != null) _fill(group, board);
      });
    } on ApiException catch (error) {
      if (mounted && error.status != 401) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted && !quiet) setState(() => _loading = false);
    }
  }

  /// Starts the form from what is saved; later reloads keep what was typed.
  void _fill(SortGroup group, SortBoard board) {
    final media = AppScope.of(context).media;
    final sortable = [
      for (final o in group.orders)
        if (o.state.sortable) o
    ];
    for (final o in sortable) {
      _kg.putIfAbsent(o.code, () {
        final c = TextEditingController(
            text: o.weighedKg == null ? '' : _plain(o.weighedKg!));
        c.addListener(_changed);
        return c;
      });
      _arrived.putIfAbsent(o.code, () {
        final c = TextEditingController(text: o.arrivedNote);
        c.addListener(_changed);
        return c;
      });
      _goods.putIfAbsent(
          o.code,
          () => PhotoTrayController(
              decodeHeic: flutterDecodeHeic,
              upload: (image, onProgress) => media
                  .uploadPhoto(o.code, image, onProgress, purpose: 'goods'),
              onUploaded: () => _load(quiet: true)));
    }
    if (sortable.isNotEmpty) {
      final lead = sortable.first.code;
      _packing ??= PhotoTrayController(
          decodeHeic: flutterDecodeHeic,
          upload: (image, onProgress) =>
              media.uploadPhoto(lead, image, onProgress, purpose: 'packing'),
          onUploaded: () => _load(quiet: true));
    }
    if (_filled) return;
    _filled = true;
    _packages = group.packages > 0
        ? group.packages
        : (sortable.isEmpty ? 1 : sortable.length);
    final saved = group.partner;
    _partner = saved != null &&
            board.partners.any((p) => p.toLowerCase() == saved.toLowerCase())
        ? board.partners
            .firstWhere((p) => p.toLowerCase() == saved.toLowerCase())
        : null;
    _courier.text = group.courierRef ?? '';
    _ref.text = group.courierRef ?? '';
    _note.text = group.hubNote;
    _courier.addListener(_changed);
    _ref.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  static String _plain(double kg) =>
      kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toString();

  double? _kgOf(String code) {
    final v =
        double.tryParse((_kg[code]?.text ?? '').trim().replaceAll(',', '.'));
    return v == null || v <= 0 || v > 9999 ? null : v;
  }

  Future<void> _addPhotos(PhotoTrayController tray) async {
    final source = await askPhotoSource(context);
    if (source == null || !mounted) return;
    final photos = await (widget.pickPhotos ?? pickPhotos)(source);
    if (!mounted || photos.isEmpty) return;
    await tray.add(photos);
    await tray.uploadAll();
  }

  bool get _uploading =>
      _goods.values.any((t) => t.uploading || t.preparing) ||
      (_packing?.uploading ?? false) ||
      (_packing?.preparing ?? false);

  Future<void> _send(SortGroup group) async {
    setState(() => _tried = true);
    final sortable = [
      for (final o in group.orders)
        if (o.state.sortable) o
    ];
    final missing = sortable.any((o) =>
        _kgOf(o.code) == null ||
        (_arrived[o.code]?.text.trim().length ?? 0) < 2);
    if (missing || _partner == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_partner == null && !missing
              ? tr('Pick the delivery partner')
              : tr('Fill in the weight and what arrived for each order'))));
      return;
    }
    if (_uploading) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Wait for the photos to finish'))));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await AppScope.of(context).sorting.sort(
            widget.flightCode,
            widget.customer,
            orders: [
              for (final o in sortable)
                SortLine(
                    code: o.code,
                    kg: _kgOf(o.code)!,
                    arrived: _arrived[o.code]!.text.trim()),
            ],
            packages: _packages,
            partner: _partner!,
            courierRef: _partner == hubPickup ? null : _courier.text,
            note: _note.text,
          );
      messenger.showSnackBar(SnackBar(content: Text(tr('Sent to the admin'))));
      if (mounted) {
        setState(() => _tried = false);
        await _load();
      }
    } on ApiException catch (error) {
      if (error.status != 401) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _saveRef() async {
    final ref = _ref.text.trim();
    if (ref.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _savingRef = true);
    try {
      await AppScope.of(context)
          .sorting
          .courierRef(widget.flightCode, widget.customer, ref);
      messenger.showSnackBar(SnackBar(content: Text(tr('Courier ID saved'))));
      if (mounted) await _load(quiet: true);
    } on ApiException catch (error) {
      if (error.status != 401) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _savingRef = false);
    }
  }

  Future<void> _delivered() async {
    final confirmation = await showDialog<String>(
        context: context, builder: (_) => const _DeliveredDialog());
    if (confirmation == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await AppScope.of(context)
          .sorting
          .delivered(widget.flightCode, widget.customer, confirmation);
      messenger.showSnackBar(SnackBar(content: Text(tr('Delivery confirmed'))));
      if (mounted) await _load();
    } on ApiException catch (error) {
      if (error.status != 401) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openOrder(String code) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ShipmentProcessScreen(code: code)));
    if (mounted) await _load(quiet: true);
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final board = _board;
    final sortable = group?.state.sortable ?? false;
    final flightLine = board == null || group == null
        ? null
        : '${board.flight.number} · ${trn(group.orders.length, '{n} order', '{n} orders')}';
    return WorkspaceScaffold(
      title: group == null
          ? widget.customer
          : sortable
              ? tr('Sort · {who}', {'who': group.who})
              : group.who,
      subtitle: flightLine,
      actions: [
        if (group != null && !sortable)
          Center(
              child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SortStatePill(state: group.state))),
      ],
      onRefresh: _load,
      footer: group == null
          ? null
          : sortable
              ? _Footer(
                  button: AppButton(
                      key: const Key('sort-send'),
                      label: tr('Send to admin'),
                      icon: Icons.send_rounded,
                      busy: _sending,
                      onPressed: _sending ? null : () => _send(group)),
                  caption: tr(
                      'Admin checks the weight and photos before it goes out.'))
              : group.state.outForDelivery
                  ? _Footer(
                      button: AppButton(
                          key: const Key('sort-delivered'),
                          label: tr('Confirm delivered'),
                          icon: Icons.check_rounded,
                          busy: _sending,
                          onPressed: _sending ? null : _delivered),
                      caption: tr(
                          'Write who received it. The admin gets a notification.'))
                  : null,
      children: [
        if (_loading && group == null) const LinearProgressIndicator(),
        if (_error != null) ErrorNote(message: _error!, onRetry: _load),
        if (!_loading && board != null && group == null)
          EmptyNote(
              icon: Icons.person_search_outlined,
              title: tr('Customer not on this flight'),
              body: tr('Go back and open the flight again.')),
        if (group != null && board != null)
          ...sortable ? _form(group, board) : _readOnly(group),
      ],
    );
  }

  List<Widget> _form(SortGroup group, SortBoard board) {
    final sortable = [
      for (final o in group.orders)
        if (o.state.sortable) o
    ];
    final waiting = [
      for (final o in group.orders)
        if (!o.state.sortable) o
    ];
    return [
      if (group.state == SortState.sentBack) ...[
        SortBanner(
            tone: ChipTone.amber,
            icon: Icons.undo_rounded,
            title: tr('Sent back by {by}',
                {'by': group.sentBackBy ?? tr('the admin')}),
            body: group.sentBackNote,
            footnote:
                group.sentBackAt == null ? null : whenText(group.sentBackAt!)),
        const SizedBox(height: 12),
      ],
      PaperCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CustomerMark(name: group.who),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(group.who,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              Text(groupLine(group),
                  style:
                      const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      for (final o in sortable) ...[
        _OrderForm(
          order: o,
          kg: _kg[o.code]!,
          arrived: _arrived[o.code]!,
          tray: _goods[o.code]!,
          loader: _photos!,
          tried: _tried,
          measured: _kgOf(o.code),
          onAddPhoto: () => _addPhotos(_goods[o.code]!),
        ),
        const SizedBox(height: 12),
      ],
      if (waiting.isNotEmpty) ...[
        SurfaceGroup(children: [
          for (final o in waiting)
            ListTile(
              onTap: () => _openOrder(o.code),
              title: Text(orderTitle(o),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(o.state == SortState.problem
                  ? tr('Has a problem. Open the order to see it.')
                  : tr('Not at the hub yet. Sort it when it arrives.')),
              trailing: SortStatePill(state: o.state),
            ),
        ]),
        const SizedBox(height: 12),
      ],
      const SizedBox(height: 10),
      SectionTitle(
          title: tr('Delivery'),
          action: sortable.length < 2
              ? null
              : Text(
                  sortable.length == 2
                      ? tr('for both orders')
                      : tr('for all {n} orders', {'n': sortable.length}),
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.muted))),
      PaperCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Packages'),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(tr('After packing'),
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.muted)),
                  ]),
            ),
            MiniStepper(
                key: const Key('sort-packages'),
                value: _packages,
                onLess:
                    _packages > 1 ? () => setState(() => _packages--) : null,
                onMore:
                    _packages < 99 ? () => setState(() => _packages++) : null),
          ]),
          const SizedBox(height: 16),
          _Label(tr('Packing photos')),
          SortPhotoStrip(
              stored: [for (final p in group.packingPhotos) p.reference],
              loader: _photos!,
              group: tr('Packing photos'),
              tray: _packing,
              addKey: const Key('sort-packing-add'),
              onAdd: _packing == null ? null : () => _addPhotos(_packing!)),
          const SizedBox(height: 16),
          _Label(tr('Delivery partner')),
          if (board.partners.isEmpty)
            Text(
                tr('No delivery partners yet. Ask the admin to add them in Settings.'),
                style: const TextStyle(color: AppColors.muted))
          else
            ChoiceChips(
                key: const Key('sort-partner'),
                options: [
                  for (final p in board.partners)
                    (value: p, label: p == hubPickup ? tr(hubPickup) : p)
                ],
                selected: _partner ?? '',
                onSelected: (p) => setState(() => _partner = p)),
          if (_tried && _partner == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(tr('Pick the delivery partner'),
                  style:
                      const TextStyle(color: AppColors.danger, fontSize: 12.5)),
            ),
          if (_partner != hubPickup) ...[
            const SizedBox(height: 16),
            TextField(
                key: const Key('sort-courier'),
                controller: _courier,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                    labelText: tr('Courier ID'),
                    hintText: tr('Add now or after booking'),
                    helperText: tr(
                        'Optional. You can add it until the order is delivered.'),
                    helperMaxLines: 2)),
          ],
          const SizedBox(height: 16),
          TextField(
              key: const Key('sort-note'),
              controller: _note,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: InputDecoration(
                  labelText: tr('Notes'),
                  hintText:
                      tr('e.g. Customer asked for delivery after 5 pm.'))),
        ]),
      ),
    ];
  }

  List<Widget> _readOnly(SortGroup group) {
    final state = group.state;
    final pickup = group.pickup;
    final orders = trn(group.orders.length, '{n} order', '{n} orders');
    return [
      switch (state) {
        SortState.waitingAdmin => SortBanner(
            tone: ChipTone.neutral,
            icon: Icons.schedule_rounded,
            title: tr('Waiting for admin'),
            body: tr(
                'Sent {when}. You get a notification when the admin approves it or sends it back.',
                {
                  'when':
                      group.sortedAt == null ? '' : whenText(group.sortedAt!)
                })),
        SortState.inDelivery || SortState.readyPickup => SortBanner(
            tone: ChipTone.green,
            icon: Icons.check_rounded,
            title: group.approvedAt == null
                ? tr('Approved')
                : tr('Approved by {by} at {time}', {
                    'by': group.approvedBy ?? tr('the admin'),
                    'time': clockText(group.approvedAt!)
                  }),
            body: pickup
                ? tr(
                    '{orders} ready for pickup at the hub. Confirm when the customer collects them.',
                    {
                        'orders': orders
                      })
                : tr(
                    '{orders} In delivery with {partner}. Add the courier ID when you have it.',
                    {'orders': orders, 'partner': group.partner ?? ''})),
        SortState.delivered => SortBanner(
            tone: ChipTone.green,
            icon: Icons.task_alt_rounded,
            title: tr('Delivered'),
            body: tr('The customer has these orders.')),
        SortState.problem => SortBanner(
            tone: ChipTone.red,
            icon: Icons.warning_amber_rounded,
            title: tr('An order has a problem'),
            body: tr('Open the order to see what happened.')),
        _ => SortBanner(
            tone: ChipTone.neutral,
            icon: Icons.inventory_2_outlined,
            title: tr('Not received yet'),
            body: tr('Receive the flight first, then sort this customer.')),
      },
      if (state != SortState.notReceived) ...[
        const SizedBox(height: 18),
        SectionTitle(title: tr('Delivery')),
        PaperCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              IconBadge(
                  pickup
                      ? Icons.storefront_outlined
                      : Icons.local_shipping_outlined,
                  tone: ChipTone.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          group.partner == null
                              ? tr('No partner yet')
                              : pickup
                                  ? tr(hubPickup)
                                  : group.partner!,
                          style: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w700)),
                      Text(trn(group.packages, '{n} package', '{n} packages'),
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.muted)),
                    ]),
              ),
            ]),
            if (!pickup &&
                (state == SortState.waitingAdmin || state.outForDelivery)) ...[
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: TextField(
                      key: const Key('sort-ref'),
                      controller: _ref,
                      decoration: InputDecoration(labelText: tr('Courier ID'))),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                      key: const Key('sort-ref-save'),
                      onPressed: _savingRef ||
                              _ref.text.trim().isEmpty ||
                              _ref.text.trim() == (group.courierRef ?? '')
                          ? null
                          : _saveRef,
                      child: Text(tr('Save'))),
                ),
              ]),
            ] else if (group.courierRef != null) ...[
              const Divider(height: 24),
              SortFactRow(label: tr('Courier ID'), value: group.courierRef!),
            ],
            if (group.hubNote.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.sticky_note_2_outlined,
                      size: 16, color: AppColors.muted),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(group.hubNote,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: AppColors.inkSoft)),
                ),
              ]),
            ],
            if (group.packingPhotos.isNotEmpty) ...[
              const SizedBox(height: 14),
              _Label(tr('Packing photos')),
              SortPhotoStrip(
                  stored: [for (final p in group.packingPhotos) p.reference],
                  loader: _photos!,
                  group: tr('Packing photos'),
                  size: 56),
            ],
          ]),
        ),
      ],
      const SizedBox(height: 18),
      SectionTitle(
          title: tr('Orders'),
          action: group.measuredKg <= 0
              ? null
              : Text(kgText(group.measuredKg),
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.muted))),
      SurfaceGroup(children: [
        for (final o in group.orders)
          InkWell(
            onTap: () => _openOrder(o.code),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(orderTitle(o),
                                  style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700)),
                              Text(
                                  [
                                    kgText(o.weighedKg ?? o.bookedKg),
                                    if (o.arrivedNote.isNotEmpty) o.arrivedNote,
                                  ].join(' · '),
                                  style: const TextStyle(
                                      fontSize: 12.5, color: AppColors.muted)),
                            ]),
                      ),
                      const SizedBox(width: 8),
                      SortStatePill(state: o.state),
                    ]),
                    if (o.goodsPhotos.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SortPhotoStrip(
                          stored: o.goodsPhotos,
                          loader: _photos!,
                          group: tr('Photos of the goods'),
                          size: 52),
                    ],
                  ]),
            ),
          ),
      ]),
    ];
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.button, required this.caption});

  final Widget button;
  final String caption;

  @override
  Widget build(BuildContext context) => ActionFooter(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          button,
          const SizedBox(height: 6),
          Text(caption,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      );
}

class _OrderForm extends StatelessWidget {
  const _OrderForm({
    required this.order,
    required this.kg,
    required this.arrived,
    required this.tray,
    required this.loader,
    required this.tried,
    required this.measured,
    required this.onAddPhoto,
  });

  final SortOrder order;
  final TextEditingController kg, arrived;
  final PhotoTrayController tray;
  final SignedPhotoLoader loader;
  final bool tried;
  final double? measured;
  final VoidCallback onAddPhoto;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final booked = [
      tr('Booked {kg}', {'kg': kgText(o.bookedKg)}),
      if (o.what.isNotEmpty) o.what,
    ].join(' · ');
    final kgMissing = tried && measured == null;
    final arrivedMissing = tried && arrived.text.trim().length < 2;
    return PaperCard(
      key: Key('sort-order-${o.code}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.code,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              Text(booked,
                  style:
                      const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ]),
          ),
          StatusPill(label: tr('At the hub'), tone: ChipTone.green),
        ]),
        const SizedBox(height: 14),
        TextField(
            key: Key('sort-kg-${o.code}'),
            controller: kg,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
                labelText: tr('Measured weight'),
                suffixText: 'kg',
                errorText: kgMissing ? tr('Enter the weight') : null,
                helperText: measured == null
                    ? null
                    : weightVersusBooked(measured!, o.bookedKg))),
        const SizedBox(height: 12),
        TextField(
            key: Key('sort-arrived-${o.code}'),
            controller: arrived,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
                labelText: tr('What arrived'),
                hintText: tr('e.g. 3 cartons of ladies kurtis'),
                errorText: arrivedMissing ? tr('Write what arrived') : null)),
        const SizedBox(height: 14),
        Text(tr('Photos of the goods'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SortPhotoStrip(
            stored: o.goodsPhotos,
            loader: loader,
            group: tr('Photos of the goods'),
            tray: tray,
            addKey: Key('sort-photo-add-${o.code}'),
            onAdd: onAddPhoto),
      ]),
    );
  }
}

class _DeliveredDialog extends StatefulWidget {
  const _DeliveredDialog();

  @override
  State<_DeliveredDialog> createState() => _DeliveredDialogState();
}

class _DeliveredDialogState extends State<_DeliveredDialog> {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _text.text.trim().length >= 3;
    return AlertDialog(
      title: Text(tr('Who received it?')),
      content: TextField(
          key: const Key('sort-delivered-who'),
          controller: _text,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
              hintText: tr('e.g. Received by the owner at the shop'))),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(tr('Cancel'))),
        FilledButton(
            key: const Key('sort-delivered-confirm'),
            onPressed:
                ok ? () => Navigator.pop(context, _text.text.trim()) : null,
            child: Text(tr('Confirm delivered'))),
      ],
    );
  }
}
