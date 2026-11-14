import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/sorting.dart';
import '../../data/uploads/signed_photos.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flow_parts.dart' show SheetHeader, showFlowSheet;
import '../../widgets/ui.dart';
import '../admin/admin_shipment_screen.dart';
import '../admin/money_format.dart';
import 'sort_parts.dart';

/// The admin checks one sorted customer: booked against measured weight, the
/// bill, the photos and the delivery facts. Approve or send back.
class ApproveCustomerScreen extends StatefulWidget {
  const ApproveCustomerScreen(
      {super.key, required this.flightCode, required this.customer});

  final String flightCode, customer;

  @override
  State<ApproveCustomerScreen> createState() => _ApproveCustomerScreenState();
}

class _ApproveCustomerScreenState extends State<ApproveCustomerScreen> {
  SortBoard? _board;
  SortGroup? _group;
  String? _error;
  var _loading = true;
  var _busy = false;
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
    _photos?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final board = await AppScope.of(context).sorting.board(widget.flightCode);
      if (mounted) {
        setState(() {
          _board = board;
          _group = board.group(widget.customer);
        });
      }
    } on ApiException catch (error) {
      if (mounted && error.status != 401) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(SortGroup group) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await AppScope.of(context)
          .sorting
          .approve(widget.flightCode, widget.customer);
      messenger.showSnackBar(SnackBar(
          content: Text(group.pickup
              ? tr('Approved. Ready for pickup at the hub.')
              : tr('Approved. In delivery with {partner}.',
                  {'partner': group.partner ?? ''}))));
      if (mounted) Navigator.of(context).maybePop();
    } on ApiException catch (error) {
      if (error.status != 401) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendBack(SortGroup group) async {
    final note = await showFlowSheet<String>(
        context, (_) => SendBackSheet(group: group));
    if (note == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await AppScope.of(context)
          .sorting
          .sendBack(widget.flightCode, widget.customer, note);
      messenger
          .showSnackBar(SnackBar(content: Text(tr('Sent back to the hub'))));
      if (mounted) Navigator.of(context).maybePop();
    } on ApiException catch (error) {
      if (error.status != 401) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final board = _board;
    final waiting = group?.state == SortState.waitingAdmin;
    return WorkspaceScaffold(
      title: group?.who ?? widget.customer,
      subtitle: board == null || group == null
          ? null
          : '${board.flight.number} · ${trn(group.orders.length, '{n} order', '{n} orders')}',
      actions: [
        if (group != null)
          Center(
              child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SortStatePill(state: group.state))),
      ],
      onRefresh: _load,
      footer: group == null || !waiting
          ? null
          : ActionFooter(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  // Its own width, so the label never wraps; Approve takes
                  // the rest.
                  OutlinedButton.icon(
                      key: const Key('approve-send-back'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          foregroundColor: AppColors.accentInk,
                          side: const BorderSide(color: AppColors.accentLine)),
                      onPressed: _busy ? null : () => _sendBack(group),
                      icon: const Icon(Icons.undo_rounded, size: 19),
                      label: Text(tr('Send back'), maxLines: 1)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                        key: const Key('approve-approve'),
                        label: tr('Approve'),
                        icon: Icons.check_rounded,
                        busy: _busy,
                        onPressed: _busy ? null : () => _approve(group)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(
                    group.pickup
                        ? tr(
                            'Approve makes the orders ready for pickup and tells the hub.')
                        : tr(
                            'Approve moves the orders to In delivery and tells the hub.'),
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
      children: [
        if (_loading && group == null) const LinearProgressIndicator(),
        if (_error != null) ErrorNote(message: _error!, onRetry: _load),
        if (!_loading && board != null && group == null)
          EmptyNote(
              icon: Icons.person_search_outlined,
              title: tr('Customer not on this flight'),
              body: tr('Go back and open the flight again.')),
        if (group != null) ..._body(group),
      ],
    );
  }

  List<Widget> _body(SortGroup group) {
    final money = group.money;
    final address = [
      if ((group.customerAddress ?? '').isNotEmpty) group.customerAddress!,
      if ((group.customerPhone ?? '').isNotEmpty) group.customerPhone!,
    ].join(' · ');
    return [
      if (group.state == SortState.sentBack) ...[
        SortBanner(
            tone: ChipTone.amber,
            icon: Icons.undo_rounded,
            title: tr('Sent back to the hub'),
            body: group.sentBackNote,
            footnote: [
              if (group.sentBackBy != null) group.sentBackBy!,
              if (group.sentBackAt != null) whenText(group.sentBackAt!),
            ].join(' · ')),
        const SizedBox(height: 12),
      ],
      if (group.state.outForDelivery || group.state == SortState.delivered) ...[
        SortBanner(
            tone: ChipTone.green,
            icon: Icons.check_rounded,
            title: group.state == SortState.delivered
                ? tr('Delivered')
                : group.approvedAt == null
                    ? tr('Approved')
                    : tr('Approved by {by} at {time}', {
                        'by': group.approvedBy ?? '',
                        'time': clockText(group.approvedAt!)
                      })),
        const SizedBox(height: 12),
      ],
      if (group.sortedBy != null)
        PaperCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CustomerMark(name: group.sortedBy!, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Sorted by {name}', {'name': group.sortedBy!}),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    if (group.sortedAt != null)
                      Text(
                          tr('Dhaka hub · {when}',
                              {'when': whenText(group.sortedAt!)}),
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.muted)),
                  ]),
            ),
          ]),
        ),
      const SizedBox(height: 20),
      SectionTitle(
          title: tr('Orders'),
          action: Text(tr('{kg} measured', {'kg': kgText(group.measuredKg)}),
              style: const TextStyle(fontSize: 13, color: AppColors.muted))),
      PaperCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < group.orders.length; i++) ...[
            if (i > 0) const Divider(height: 28),
            _OrderCheck(
                order: group.orders[i],
                loader: _photos!,
                onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            AdminShipmentScreen(code: group.orders[i].code)))),
          ],
          if (money != null) ...[
            const Divider(height: 28),
            Row(children: [
              Expanded(
                child: Text(tr('Total bill'),
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w700)),
              ),
              Flexible(
                child: Text(
                    tr('{bill} · due {due}',
                        {'bill': taka(money.bill), 'due': taka(money.due)}),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w700)),
              ),
            ]),
          ],
        ]),
      ),
      const SizedBox(height: 20),
      SectionTitle(title: tr('Delivery')),
      PaperCard(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SortFactRow(
              label: tr('Partner'),
              value: group.partner == null
                  ? tr('Not picked')
                  : group.pickup
                      ? tr('Hub pickup')
                      : group.partner!),
          if (!group.pickup)
            SortFactRow(
                label: tr('Courier ID'),
                value: group.courierRef ?? tr('Not added yet')),
          SortFactRow(label: tr('Packages'), value: '${group.packages}'),
          if (address.isNotEmpty)
            SortFactRow(label: tr('Deliver to'), value: address),
          if (group.hubNote.isNotEmpty)
            SortFactRow(label: tr('Notes'), value: group.hubNote),
          if (group.packingPhotos.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(tr('Packing photos'),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SortPhotoStrip(
                stored: [for (final p in group.packingPhotos) p.reference],
                loader: _photos!,
                group: tr('Packing photos'),
                size: 56),
          ],
        ]),
      ),
    ];
  }
}

/// "৳8,880" without paisa when it is a whole amount.
String taka(double value) {
  final text = formatBdt(value);
  return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
}

class _OrderCheck extends StatelessWidget {
  const _OrderCheck(
      {required this.order, required this.loader, required this.onOpen});

  final SortOrder order;
  final SignedPhotoLoader loader;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final o = order;
    final measured = o.weighedKg;
    final changed = o.bill != null &&
        o.bookedBill != null &&
        (o.bill! - o.bookedBill!).abs() >= 1;
    Widget tile(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
            decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(12)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    maxLines: 1,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        onTap: onOpen,
        child: Row(children: [
          Expanded(
            child: Text(orderTitle(o),
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          if (measured != null)
            StatusPill(
                label: weightPill(measured, o.bookedKg),
                tone: o.weightDelta != null
                    ? ChipTone.amber
                    : (measured - o.bookedKg).abs() < 0.05
                        ? ChipTone.green
                        : ChipTone.blue)
          else
            SortStatePill(state: o.state),
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        tile(tr('Booked'), kgText(o.bookedKg)),
        const SizedBox(width: 8),
        tile(tr('Measured'), measured == null ? '—' : kgText(measured)),
        if (o.bill != null) ...[
          const SizedBox(width: 8),
          tile(tr('Bill'), taka(o.bill!)),
        ],
      ]),
      if (o.bill != null) ...[
        const SizedBox(height: 6),
        Text(
            changed
                ? tr('Bill was {amount} at the booked weight',
                    {'amount': taka(o.bookedBill!)})
                : tr('Bill unchanged'),
            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
      if (o.arrivedNote.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(o.arrivedNote, style: const TextStyle(fontSize: 14, height: 1.45)),
      ],
      if (o.goodsPhotos.isNotEmpty) ...[
        const SizedBox(height: 10),
        SortPhotoStrip(
            stored: o.goodsPhotos,
            loader: loader,
            group: tr('Photos of the goods'),
            size: 56),
      ],
    ]);
  }
}

/// Why the customer goes back to the hub. Returns the note, or null.
class SendBackSheet extends StatefulWidget {
  const SendBackSheet({super.key, required this.group});

  final SortGroup group;

  @override
  State<SendBackSheet> createState() => _SendBackSheetState();
}

class _SendBackSheetState extends State<SendBackSheet> {
  final _note = TextEditingController();
  final _reasons = <String>{};

  static const _options = [
    'Weight looks wrong',
    'Photo missing',
    'Wrong partner'
  ];

  @override
  void initState() {
    super.initState();
    _note.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  String get _message => [
        for (final r in _options)
          if (_reasons.contains(r)) tr(r),
        if (_note.text.trim().isNotEmpty) _note.text.trim(),
      ].join('. ');

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final ok = _message.length >= 3;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(
                  title: tr('Send back to the hub?'),
                  subtitle:
                      '${g.who} · ${trn(g.orders.length, '{n} order', '{n} orders')}'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(spacing: 8, runSpacing: 4, children: [
                        for (final r in _options)
                          FilterChip(
                              label: Text(tr(r)),
                              selected: _reasons.contains(r),
                              showCheckmark: false,
                              onSelected: (on) => setState(() =>
                                  on ? _reasons.add(r) : _reasons.remove(r))),
                      ]),
                      const SizedBox(height: 12),
                      TextField(
                          key: const Key('send-back-note'),
                          controller: _note,
                          autofocus: true,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 500,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                              labelText: tr('What needs fixing?'),
                              hintText: tr(
                                  'e.g. SH-42 needs a photo with the carton open.'))),
                      Text(tr('The hub gets this note. The orders stay at the hub until they are sent again.'),
                          style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.45,
                              color: AppColors.muted)),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                          key: const Key('send-back-confirm'),
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              backgroundColor: AppColors.accentStrong),
                          onPressed: ok
                              ? () => Navigator.pop(context, _message)
                              : null,
                          icon: const Icon(Icons.undo_rounded, size: 19),
                          label: Text(tr('Send back'))),
                    ]),
              ),
            ]),
      ),
    );
  }
}
