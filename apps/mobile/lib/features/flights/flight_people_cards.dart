import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/flight.dart';
import '../../data/uploads/signed_photos.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/finance_parts.dart' show clockTime, shortDate;
import '../../widgets/people_parts.dart';
import '../../widgets/round7_parts.dart' show CardHead;
import '../../widgets/ui.dart';

/// "21 Nov, 2:10 PM" from a server time.
String receivedWhen(String iso) {
  final at = DateTime.tryParse(iso)?.toLocal();
  return at == null ? '' : '${shortDate(at)}, ${clockTime(at)}';
}

bool _hasPhone(String phone) => phone.trim().isNotEmpty && phone.trim() != '—';

/// Admin: the flyers with their face photos, to add or change.
class FlyerFacesCard extends StatelessWidget {
  const FlyerFacesCard(
      {super.key,
      required this.flyers,
      required this.loader,
      required this.onPhoto});

  final List<FlyerOnFlight> flyers;
  final SignedPhotoLoader loader;
  final ValueChanged<FlyerOnFlight> onPhoto;

  @override
  Widget build(BuildContext context) => PaperCard(
      key: const Key('flight-flyer-faces'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardHead(
            title: tr('Flyers'),
            trailing: Text('${flyers.length}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted))),
        for (var i = 0; i < flyers.length; i++)
          _row(flyers[i], last: i == flyers.length - 1),
        const SizedBox(height: 4),
        Text(tr('The hub sees these photos to find the flyers at the airport. Use a face photo, not the passport page.'),
            style: const TextStyle(
                fontSize: 12, height: 1.4, color: AppColors.muted)),
      ]));

  Widget _row(FlyerOnFlight flyer, {required bool last}) {
    final has = flyer.photoRef != null && flyer.photoRef!.isNotEmpty;
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: AppColors.lineSoft))),
        child: Row(children: [
          PersonAvatar(flyer.name,
              photoRef: flyer.photoRef,
              loader: loader,
              size: 52,
              onTap: () => onPhoto(flyer)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(flyer.name,
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w600)),
                Text(
                    has
                        ? (_hasPhone(flyer.bdPhone) ? flyer.bdPhone : '')
                        : tr('No photo yet'),
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: has ? AppColors.muted : AppColors.accentInk)),
              ])),
          if (has)
            IconButton(
                key: ValueKey('flyer-photo-${flyer.name}'),
                tooltip: tr('Change photo of {name}', {'name': flyer.name}),
                onPressed: () => onPhoto(flyer),
                icon: const Icon(Icons.photo_camera_outlined,
                    color: AppColors.muted))
          else
            OutlinedButton.icon(
                key: ValueKey('flyer-photo-${flyer.name}'),
                onPressed: () => onPhoto(flyer),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    foregroundColor: AppColors.accentInk,
                    backgroundColor: AppColors.accentSoft,
                    side: const BorderSide(color: AppColors.accentLine),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.photo_camera_outlined, size: 17),
                label: Text(tr('Add photo'))),
        ]));
  }
}

/// Who received the flight's orders at the BD hub, with photo, count and
/// time.
class ReceivedByCard extends StatelessWidget {
  const ReceivedByCard(
      {super.key,
      required this.groups,
      required this.total,
      required this.loader,
      this.onAddPhoto});

  final List<ReceivedGroup> groups;

  /// Orders on the flight.
  final int total;
  final SignedPhotoLoader loader;

  /// Admin: add the photo of a receiver who has none.
  final ValueChanged<ReceivedGroup>? onAddPhoto;

  @override
  Widget build(BuildContext context) {
    final received = groups.fold(0, (sum, group) => sum + group.count);
    return PaperCard(
        key: const Key('flight-received-by'),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CardHead(
              title: tr('Received at the BD hub'),
              trailing: Text(
                  tr('{n} of {total} orders', {'n': received, 'total': total}),
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.muted))),
          for (var i = 0; i < groups.length; i++)
            _row(groups[i], last: i == groups.length - 1),
        ]));
  }

  Widget _row(ReceivedGroup group, {required bool last}) {
    final role = staffRoleLabel(group.role);
    final noPhoto = group.photoRef == null || group.photoRef!.isEmpty;
    final add = onAddPhoto;
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: AppColors.lineSoft))),
        child: Row(children: [
          PersonAvatar(group.name,
              photoRef: group.photoRef, loader: loader, size: 48),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(group.name,
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w600)),
                Text(
                    [if (role.isNotEmpty) role, receivedWhen(group.at)]
                        .where((part) => part.isNotEmpty)
                        .join(' · '),
                    style: const TextStyle(
                        fontSize: 12, height: 1.4, color: AppColors.muted)),
                if (noPhoto && add != null && group.userId != null)
                  TextButton(
                      key: ValueKey('received-add-photo-${group.userId}'),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      onPressed: () => add(group),
                      child: Text(tr('Add a photo'))),
              ])),
          const SizedBox(width: 8),
          StatusPill(
              label: trn(group.count, '{n} order', '{n} orders'),
              tone: ChipTone.green),
        ]));
  }
}

/// Hub: the flyers arriving, with big face photos, phone and call.
class WhoIsComingCard extends StatelessWidget {
  const WhoIsComingCard(
      {super.key, required this.flyers, required this.loader});

  final List<FlyerOnFlight> flyers;
  final SignedPhotoLoader loader;

  @override
  Widget build(BuildContext context) => PaperCard(
      key: const Key('hub-who-is-coming'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardHead(
            title: tr('Who is coming'),
            trailing: Text(trn(flyers.length, '{n} flyer', '{n} flyers'),
                style: const TextStyle(fontSize: 13, color: AppColors.muted))),
        if (flyers.isEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(tr('No flyer assigned to this flight yet'),
                  style: const TextStyle(color: AppColors.muted)))
        else
          for (var i = 0; i < flyers.length; i++)
            _ComingRow(
                flyer: flyers[i], loader: loader, last: i == flyers.length - 1),
      ]));
}

class _ComingRow extends StatelessWidget {
  const _ComingRow(
      {required this.flyer, required this.loader, required this.last});

  final FlyerOnFlight flyer;
  final SignedPhotoLoader loader;
  final bool last;

  Future<void> _call(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final phone = flyer.bdPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    var opened = false;
    try {
      opened = await launchUrl(Uri(scheme: 'tel', path: phone));
    } catch (_) {
      opened = false;
    }
    if (opened) return;
    // No phone app: the number is copied instead.
    await Clipboard.setData(ClipboardData(text: flyer.bdPhone));
    messenger.showSnackBar(SnackBar(content: Text(tr('Number copied'))));
  }

  @override
  Widget build(BuildContext context) {
    final has = flyer.photoRef != null && flyer.photoRef!.isNotEmpty;
    final phone = _hasPhone(flyer.bdPhone);
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            border: last
                ? null
                : const Border(bottom: BorderSide(color: AppColors.lineSoft))),
        child: Row(children: [
          PersonAvatar(flyer.name,
              photoRef: flyer.photoRef,
              loader: loader,
              size: 84,
              square: true,
              color: AppColors.neutralSoft,
              foreground: AppColors.faint),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(flyer.name,
                    style: const TextStyle(
                        fontSize: 17,
                        height: 1.3,
                        fontWeight: FontWeight.w700)),
                Text(phone ? flyer.bdPhone : tr('Carrying in luggage'),
                    style: const TextStyle(
                        fontSize: 14, height: 1.4, color: AppColors.inkSoft)),
                if (!has)
                  Text(tr('No photo yet'),
                      style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.accentInk)),
              ])),
          if (phone)
            IconButton.filled(
                key: ValueKey('call-${flyer.name}'),
                tooltip: tr('Call {name}', {'name': flyer.name}),
                style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: AppColors.okSoft,
                    foregroundColor: AppColors.ok),
                onPressed: () => _call(context),
                icon: const Icon(Icons.call_rounded, size: 22)),
        ]));
  }
}
