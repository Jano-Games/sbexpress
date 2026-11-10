import 'package:flutter/material.dart';

import '../../data/models/shipment.dart';
import '../../data/uploads/signed_photos.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/finance_parts.dart' show clockTime, shortDate;
import '../../widgets/flight_parts.dart' show LetterAvatar;
import '../../widgets/people_parts.dart';
import '../../widgets/photo_parts.dart' show StoredPhotoImage;
import '../../widgets/round7_parts.dart' show CardHead;
import '../../widgets/ui.dart';

/// Pieces of one model on one device line that went to the same customer.
class DeviceGroup {
  const DeviceGroup(
      {required this.item,
      required this.category,
      required this.model,
      required this.units,
      required this.unitIndexes});

  /// Index of the device line in the order.
  final int item;
  final String category;
  final String model;
  final List<DeviceUnit> units;

  /// Each unit's place on its line, for the device endpoints.
  final List<int> unitIndexes;

  DeviceUnit get first => units.first;
  int get missingPhotos => units.where((unit) => !unit.hasPiecePhoto).length;

  /// Next pieces with the same model and customer share one row.
  static List<DeviceGroup> of(List<AdminDeviceLine> lines) {
    final groups = <DeviceGroup>[];
    for (var item = 0; item < lines.length; item++) {
      final line = lines[item];
      for (var i = 0; i < line.units.length; i++) {
        final unit = line.units[i];
        final last = groups.isEmpty ? null : groups.last;
        if (last != null &&
            last.item == item &&
            last.first.model == unit.model &&
            last.first.customerCode == unit.customerCode) {
          last.units.add(unit);
          last.unitIndexes.add(i);
        } else {
          groups.add(DeviceGroup(
              item: item,
              category: line.category,
              model: unit.model,
              units: [unit],
              unitIndexes: [i]));
        }
      }
    }
    return groups;
  }
}

/// Every device piece: who ordered it, with a photo of each piece.
class OrderDevicesCard extends StatelessWidget {
  const OrderDevicesCard(
      {super.key,
      required this.detail,
      required this.loader,
      required this.busy,
      required this.onChangeOwner,
      required this.onAddPhoto,
      required this.onOpenPhoto});

  final AdminShipmentDetail detail;
  final SignedPhotoLoader loader;

  /// `item:unit` keys of the pieces whose photo is going up.
  final Set<String> busy;
  final ValueChanged<DeviceGroup> onChangeOwner;
  final void Function(DeviceGroup group, int index) onAddPhoto;
  final void Function(String reference) onOpenPhoto;

  @override
  Widget build(BuildContext context) {
    final groups = DeviceGroup.of(detail.devices);
    final pieces = groups.fold(0, (sum, group) => sum + group.units.length);
    final missing = groups.fold(0, (sum, group) => sum + group.missingPhotos);
    return PaperCard(
        key: const Key('order-devices'),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CardHead(
              title: tr('Devices'),
              subtitle: [
                trn(pieces, '{n} piece', '{n} pieces'),
                missing == 0
                    ? tr('all photos in')
                    : trn(missing, '{n} photo missing', '{n} photos missing'),
              ].join(' · ')),
          for (var i = 0; i < groups.length; i++)
            _row(groups[i], last: i == groups.length - 1),
        ]));
  }

  Widget _row(DeviceGroup group, {required bool last}) {
    final owner = group.first.customer;
    final own = group.first.customerCode == null;
    final orderName = detail.supplierName ?? detail.supplierCode;
    final name = own ? orderName : owner?.name ?? group.first.customerCode!;
    final meta = own
        ? tr("This order's customer")
        : owner == null
            ? group.first.customerCode!
            : [owner.code, if (owner.phone.isNotEmpty) owner.phone].join(' · ');
    final model = group.model.isEmpty ? group.category : group.model;
    final count = group.units.length;
    return Container(
        key: ValueKey('order-device-${group.item}-${group.unitIndexes.first}'),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: AppColors.lineSoft))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppColors.neutralSoft,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(_icon(group.category),
                  size: 20, color: AppColors.inkSoft)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(count > 1 ? '$model × $count' : model,
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(children: [
                  LetterAvatar(name,
                      size: 26,
                      color: own ? AppColors.primary : AppColors.primarySoft,
                      foreground: own ? Colors.white : AppColors.primaryInk),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(tr('For {name}', {'name': name}),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, height: 1.35)),
                        Text(meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: AppColors.muted)),
                      ])),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (var i = 0; i < count; i++) _slot(group, i),
                ]),
              ])),
          TextButton(
              key: ValueKey(
                  'order-device-owner-${group.item}-${group.unitIndexes.first}'),
              onPressed: () => onChangeOwner(group),
              child: Text(tr('Change'))),
        ]));
  }

  Widget _slot(DeviceGroup group, int i) {
    final unit = group.units[i];
    final key = '${group.item}:${group.unitIndexes[i]}';
    final label = group.units.length > 1 ? tr('Piece {n}', {'n': i + 1}) : null;
    if (busy.contains(key)) {
      return Container(
          width: 60,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: AppColors.neutralSoft,
              borderRadius: BorderRadius.circular(12)),
          child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5)));
    }
    final reference = unit.photoRef;
    return PiecePhotoSlot(
        key: ValueKey('order-piece-photo-$key'),
        size: 60,
        label: label,
        addLabel: label == null
            ? tr('Add photo')
            : tr('Add photo of piece {n}', {'n': i + 1}),
        image: reference == null || reference.isEmpty
            ? null
            : StoredPhotoImage(
                loader: loader, reference: reference, cacheWidth: 180),
        onTap: reference == null || reference.isEmpty
            ? () => onAddPhoto(group, i)
            : () => onOpenPhoto(reference));
  }
}

IconData _icon(String category) {
  final lower = category.toLowerCase();
  if (lower.contains('laptop')) return Icons.laptop_rounded;
  if (lower.contains('mobile') || lower.contains('phone')) {
    return Icons.smartphone_rounded;
  }
  return Icons.devices_other_rounded;
}

/// The order's history, newest first, with the photo and role of whoever
/// took each step.
class OrderHistoryCard extends StatefulWidget {
  const OrderHistoryCard(
      {super.key, required this.entries, required this.loader});

  final List<ShipmentLogEntry> entries;
  final SignedPhotoLoader? loader;

  @override
  State<OrderHistoryCard> createState() => _OrderHistoryCardState();
}

class _OrderHistoryCardState extends State<OrderHistoryCard> {
  static const _first = 6;
  var _all = false;

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final shown = _all ? entries : entries.take(_first).toList();
    return PaperCard(
        key: const Key('order-history'),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CardHead(
              title: tr('History'),
              subtitle: tr('Who did each step, newest first')),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text(tr('Nothing yet.'),
                style: const TextStyle(color: AppColors.muted))
          else
            for (var i = 0; i < shown.length; i++)
              _HistoryLine(
                  entry: shown[i],
                  loader: widget.loader,
                  dot: i == 0 ? AppColors.ok : AppColors.field,
                  last: i == shown.length - 1),
          if (entries.length > _first)
            Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                    key: const Key('order-history-more'),
                    onPressed: () => setState(() => _all = !_all),
                    child: Text(_all
                        ? tr('Show less')
                        : tr('Show all {n}', {'n': entries.length})))),
        ]));
  }
}

class _HistoryLine extends StatelessWidget {
  const _HistoryLine(
      {required this.entry,
      required this.loader,
      required this.dot,
      required this.last});

  final ShipmentLogEntry entry;
  final SignedPhotoLoader? loader;
  final Color dot;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final role = staffRoleLabel(entry.actorRole);
    final at = DateTime.tryParse(entry.at)?.toLocal();
    return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
          width: 16,
          child: Column(children: [
            Container(
                margin: const EdgeInsets.only(top: 3),
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            if (!last)
              Expanded(
                  child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 2),
                      color: AppColors.line)),
          ])),
      const SizedBox(width: 12),
      Expanded(
          child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Text(historyTitle(entry.message),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600))),
                          if (at != null) ...[
                            const SizedBox(width: 8),
                            Text('${shortDate(at)}, ${clockTime(at)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: AppColors.muted)),
                          ],
                        ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      PersonAvatar(entry.actor,
                          photoRef: entry.actorPhotoRef,
                          loader: loader,
                          size: 26),
                      const SizedBox(width: 8),
                      Flexible(
                          child: Text.rich(
                              TextSpan(children: [
                                TextSpan(text: entry.actor),
                                if (role.isNotEmpty)
                                  TextSpan(
                                      text: ' · $role',
                                      style: const TextStyle(
                                          color: AppColors.muted)),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  color: AppColors.inkSoft))),
                    ]),
                  ]))),
    ]));
  }
}

/// "Status → Received at BD Hub" reads as "Received at BD Hub".
String historyTitle(String message) {
  const prefix = 'Status → ';
  return message.startsWith(prefix)
      ? tr(message.substring(prefix.length))
      : message;
}
