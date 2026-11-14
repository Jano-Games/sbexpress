import 'package:flutter/material.dart';

import '../../data/models/hub_flight.dart';
import '../../data/models/sorting.dart';
import '../../data/uploads/photo_tray.dart';
import '../../data/uploads/signed_photos.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/photo_parts.dart';

/// Shared pieces of the hub sorting and admin approval screens.

ChipTone sortStateTone(SortState state) => switch (state) {
      SortState.toSort => ChipTone.blue,
      SortState.sentBack => ChipTone.amber,
      SortState.waitingAdmin => ChipTone.neutral,
      SortState.inDelivery ||
      SortState.readyPickup ||
      SortState.delivered =>
        ChipTone.green,
      SortState.problem => ChipTone.red,
      SortState.notReceived => ChipTone.neutral,
    };

IconData? sortStateIcon(SortState state) => switch (state) {
      SortState.sentBack => Icons.undo_rounded,
      SortState.waitingAdmin => Icons.schedule_rounded,
      SortState.inDelivery => Icons.local_shipping_outlined,
      SortState.readyPickup => Icons.storefront_outlined,
      SortState.delivered => Icons.task_alt_rounded,
      SortState.problem => Icons.warning_amber_rounded,
      _ => null,
    };

class SortStatePill extends StatelessWidget {
  const SortStatePill({super.key, required this.state});

  final SortState state;

  @override
  Widget build(BuildContext context) {
    final colors = toneColors(sortStateTone(state));
    final icon = sortStateIcon(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
          color: colors.background, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: colors.foreground),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(state.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: colors.foreground,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  height: 1.4)),
        ),
      ]),
    );
  }
}

/// The first letter of the customer on a soft square.
class CustomerMark extends StatelessWidget {
  const CustomerMark({super.key, required this.name, this.size = 44});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = name.trim();
    // The hub sees codes like "C-14": the number tells them apart, the
    // shared letter does not.
    final number = RegExp(r'^[A-Za-z]+-?(\d{1,3})$').firstMatch(text);
    final letter = number != null
        ? number.group(1)!
        : text.isEmpty
            ? '?'
            : text[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(size * 0.28)),
      child: Text(letter,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
              fontSize: size * (letter.length > 2 ? 0.3 : 0.38),
              fontWeight: FontWeight.w700,
              color: AppColors.primaryInk)),
    );
  }
}

String kgText(double kg) => '${kg.toStringAsFixed(1)} kg';

/// "0.4 kg more than booked", "Same as booked", "0.3 kg less than booked".
String weightVersusBooked(double measured, double booked) {
  final diff = measured - booked;
  if (diff.abs() < 0.05) return tr('Same as booked');
  final kg = diff.abs().toStringAsFixed(1);
  return diff > 0
      ? tr('{kg} kg more than booked', {'kg': kg})
      : tr('{kg} kg less than booked', {'kg': kg});
}

/// Short form for a pill: "0.4 kg more", "Same", "0.3 kg less".
String weightPill(double measured, double booked) {
  final diff = measured - booked;
  if (diff.abs() < 0.05) return tr('Same');
  final kg = diff.abs().toStringAsFixed(1);
  return diff > 0
      ? tr('{kg} kg more', {'kg': kg})
      : tr('{kg} kg less', {'kg': kg});
}

/// "2 orders · 14.2 kg booked".
String groupLine(SortGroup g) => [
      trn(g.orders.length, '{n} order', '{n} orders'),
      tr('{kg} booked', {'kg': kgText(g.bookedKg)}),
    ].join(' · ');

/// "SH-41 · garments".
String orderTitle(SortOrder o) =>
    o.what.isEmpty ? o.code : '${o.code} · ${o.what}';

String clockText(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "14:55" today, "yesterday 18:20", or "Thu 12 Nov".
String whenText(DateTime t) {
  final day =
      FlightDay.parse(DateTime(t.year, t.month, t.day).toIso8601String());
  if (day == null) return clockText(t);
  if (day.daysAway == 0) return clockText(t);
  if (day.daysAway == -1) {
    return tr('yesterday {time}', {'time': clockText(t)});
  }
  return day.shortLabel;
}

/// Small square photos: the stored ones, the ones being sent, and an Add
/// square when [onAdd] is given.
class SortPhotoStrip extends StatelessWidget {
  const SortPhotoStrip({
    super.key,
    required this.stored,
    required this.loader,
    required this.group,
    this.tray,
    this.onAdd,
    this.addKey,
    this.labels = const {},
    this.size = 64,
  });

  final List<String> stored;
  final SignedPhotoLoader loader;

  /// What the photos are of, shown in the viewer.
  final String group;
  final PhotoTrayController? tray;
  final VoidCallback? onAdd;
  final Key? addKey;

  /// A caption on some photos, e.g. "Mobile 1".
  final Map<String, String> labels;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget square(Widget child) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: size, height: size, child: child),
        );
    final local = tray;
    return ListenableBuilder(
      listenable: local ?? const AlwaysStoppedAnimation(0),
      builder: (context, _) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < stored.length; i++)
          square(Stack(fit: StackFit.expand, children: [
            StoredPhotoImage(
                loader: loader,
                reference: stored[i],
                cacheWidth: 200,
                onTap: () => showPhotoViewer(context,
                        loader: loader,
                        initial: i,
                        photos: [
                          for (final r in stored)
                            ViewerPhoto.stored(r, group: group)
                        ])),
            if (labels[stored[i]] case final label?)
              Positioned(
                left: 4,
                bottom: 4,
                child: IgnorePointer(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: const Color(0xCC18212F),
                        borderRadius: BorderRadius.circular(5)),
                    child: Text(label,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
          ])),
        if (local != null)
          for (final photo in local.photos)
            square(_TrayPhotoTile(photo: photo, tray: local)),
        if (onAdd != null)
          Semantics(
            button: true,
            label: tr('Add photo'),
            excludeSemantics: true,
            child: InkWell(
              key: addKey,
              onTap: local?.uploading == true ? null : onAdd,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accentLine)),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.photo_camera_outlined,
                          size: 19, color: AppColors.accentInk),
                      const SizedBox(height: 2),
                      Text(tr('Add'),
                          textScaler: TextScaler.noScaling,
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentInk)),
                    ]),
              ),
            ),
          ),
      ]),
    );
  }
}

class _TrayPhotoTile extends StatelessWidget {
  const _TrayPhotoTile({required this.photo, required this.tray});

  final TrayPhoto photo;
  final PhotoTrayController tray;

  @override
  Widget build(BuildContext context) {
    final prepared = photo.prepared;
    final failed = photo.state == TrayPhotoState.failed;
    final unusable = photo.state == TrayPhotoState.unusable;
    return Stack(fit: StackFit.expand, children: [
      if (prepared != null)
        Image.memory(prepared.bytes, fit: BoxFit.cover, cacheWidth: 200)
      else
        const ColoredBox(color: AppColors.neutralSoft),
      if (photo.state == TrayPhotoState.uploading ||
          photo.state == TrayPhotoState.preparing)
        ColoredBox(
          color: const Color(0x66000000),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                  value: photo.state == TrayPhotoState.uploading &&
                          photo.progress > 0
                      ? photo.progress
                      : null),
            ),
          ),
        ),
      if (failed || unusable)
        Material(
          color: const Color(0x99B3343B),
          child: InkWell(
            onTap: failed ? () => tray.retry(photo) : () => tray.remove(photo),
            child: Center(
              child: Icon(failed ? Icons.refresh_rounded : Icons.close_rounded,
                  color: Colors.white,
                  semanticLabel: failed ? tr('Try again') : tr('Remove')),
            ),
          ),
        ),
    ]);
  }
}

/// A label and a value on one line, the value on the right.
class SortFactRow extends StatelessWidget {
  const SortFactRow({super.key, required this.label, required this.value});

  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 104,
            child: Text(label,
                style: const TextStyle(fontSize: 13.5, color: AppColors.muted)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 14, height: 1.4, fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

/// A coloured note with an icon: sent back, approved, waiting.
class SortBanner extends StatelessWidget {
  const SortBanner(
      {super.key,
      required this.tone,
      required this.icon,
      required this.title,
      this.body,
      this.footnote});

  final ChipTone tone;
  final IconData icon;
  final String title;
  final String? body, footnote;

  @override
  Widget build(BuildContext context) {
    final colors = toneColors(tone);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
          color: colors.background, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: colors.foreground),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: colors.foreground)),
            if (body != null && body!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(body!,
                  style: const TextStyle(
                      fontSize: 13.5, height: 1.45, color: AppColors.inkSoft)),
            ],
            if (footnote != null) ...[
              const SizedBox(height: 4),
              Text(footnote!,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ]),
        ),
      ]),
    );
  }
}
