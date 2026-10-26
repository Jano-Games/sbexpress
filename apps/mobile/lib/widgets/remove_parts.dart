import 'package:flutter/material.dart';

import '../data/api/api_exception.dart';
import '../data/data_changes.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import 'finance_parts.dart' show localTime, shortDate;
import 'ui.dart';

/// Deleting, archiving and restoring flights, shipments, flyers and
/// customers: the quiet delete button, the archive and restore controls and
/// the dialogs around them. Only admins reach these screens.

/// Asks before a delete or an archive. [destructive] paints the action red.
Future<bool> confirmRemoval(BuildContext context,
    {required String title,
    required String body,
    required String action,
    bool destructive = true}) async {
  final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
            scrollable: true,
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(tr('Go back'))),
              FilledButton(
                  key: const Key('remove-confirm'),
                  style: FilledButton.styleFrom(
                      backgroundColor:
                          destructive ? AppColors.danger : AppColors.primary),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(action)),
            ],
          ));
  return answer ?? false;
}

/// Says why the server kept something, in its own words. With
/// [offerArchive] the operator can archive it from the dialog; the result is
/// true when they choose that.
Future<bool> showRemovalNotice(BuildContext context,
    {required String title,
    required String message,
    bool offerArchive = false}) async {
  final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
            scrollable: true,
            title: Text(title),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, key: const Key('remove-reason')),
                  if (offerArchive) ...[
                    const SizedBox(height: 12),
                    Text(tr('Archiving hides it from lists and new bookings. History stays.'),
                        style: const TextStyle(
                            fontSize: 14, height: 1.5, color: AppColors.muted)),
                  ],
                ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(tr('Close'))),
              if (offerArchive)
                FilledButton(
                    key: const Key('remove-archive-instead'),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(tr('Archive instead'))),
            ],
          ));
  return answer ?? false;
}

/// Confirms with [question], deletes and goes back to the screen before,
/// which reloads. A refusal shows the server's reason under
/// [refusedTitle]; with [archiveInstead] (flyers and customers) the
/// operator can archive right there. [onBusy] wraps the request only.
Future<void> confirmAndDelete(BuildContext context,
    {required String title,
    required String question,
    required String refusedTitle,
    required Future<void> Function() delete,
    Future<void> Function()? archiveInstead,
    ValueChanged<bool>? onBusy}) async {
  final ok = await confirmRemoval(context,
      title: title, body: question, action: tr('Delete'));
  if (!ok || !context.mounted) return;
  onBusy?.call(true);
  try {
    await delete();
  } on ApiException catch (error) {
    onBusy?.call(false);
    if (!context.mounted || error.status == 401) return;
    final refused = error.status == 400;
    final archive = await showRemovalNotice(context,
        title: refused ? refusedTitle : tr('Not deleted'),
        message: error.message,
        offerArchive: refused && archiveInstead != null);
    if (archive && context.mounted) await archiveInstead!();
    return;
  }
  onBusy?.call(false);
  notifyDataChanged();
  if (context.mounted) Navigator.of(context).pop();
}

/// Archives [name] after a confirm, or restores at once, and reports a
/// failure in a dialog. [outdated] replaces the message when an older
/// server answers 404. Returns whether the change went through.
Future<bool> changeArchived(BuildContext context,
    {required bool archived,
    required String name,
    required Future<void> Function() send,
    bool confirm = true,
    String? outdated,
    ValueChanged<bool>? onBusy}) async {
  if (archived && confirm) {
    final ok = await confirmRemoval(context,
        title: tr('Archive {name}?', {'name': name}),
        body: tr('Hidden from lists and new bookings; history stays.'),
        action: tr('Archive'),
        destructive: false);
    if (!ok || !context.mounted) return false;
  }
  onBusy?.call(true);
  try {
    await send();
  } on ApiException catch (error) {
    onBusy?.call(false);
    if (!context.mounted || error.status == 401) return false;
    await showRemovalNotice(context,
        title: archived ? tr('Not archived') : tr('Not restored'),
        message:
            error.status == 404 && outdated != null ? outdated : error.message);
    return false;
  }
  onBusy?.call(false);
  notifyDataChanged();
  return true;
}

/// Muted red text button at the end of a detail page, e.g. "Delete flight".
class QuietDeleteButton extends StatelessWidget {
  const QuietDeleteButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => Center(
      child: TextButton.icon(
          style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              textStyle: const TextStyle(
                  fontFamily: 'HindSiliguri',
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          onPressed: busy ? null : onPressed,
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.delete_outline_rounded, size: 19),
          label: Text(label, textAlign: TextAlign.center)));
}

/// The end of an active flyer or customer page: archive with what it does,
/// then the quiet delete. An archived one shows only the delete; it is
/// restored from [ArchivedBanner].
class ProfileEndActions extends StatelessWidget {
  const ProfileEndActions(
      {super.key,
      required this.archived,
      required this.archiveLabel,
      required this.deleteLabel,
      required this.onArchive,
      required this.onDelete,
      this.archiving = false,
      this.deleting = false});
  final bool archived, archiving, deleting;
  final String archiveLabel, deleteLabel;
  final VoidCallback onArchive, onDelete;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!archived) ...[
          AppButton(
              key: const Key('profile-archive'),
              label: archiveLabel,
              icon: Icons.archive_outlined,
              kind: AppButtonKind.quiet,
              busy: archiving,
              onPressed: deleting ? null : onArchive),
          const SizedBox(height: 8),
          Text(tr('Hidden from lists and new bookings; history stays.'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, height: 1.45, color: AppColors.muted)),
          const SizedBox(height: 10),
        ],
        QuietDeleteButton(
            key: const Key('profile-delete'),
            label: deleteLabel,
            busy: deleting,
            onPressed: archiving ? null : onDelete),
      ]);
}

/// Grey note at the top of an archived flyer or customer, with Restore.
class ArchivedBanner extends StatelessWidget {
  const ArchivedBanner(
      {super.key,
      required this.archivedAt,
      required this.restoreLabel,
      required this.onRestore,
      this.busy = false});
  final String? archivedAt;
  final String restoreLabel;
  final VoidCallback onRestore;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final when = archivedAt == null ? null : localTime(archivedAt!);
    return Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
            color: AppColors.neutralSoft,
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(color: AppColors.line)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.archive_outlined,
                    size: 20, color: AppColors.inkSoft)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      when == null
                          ? tr('Archived')
                          : tr('Archived {date}', {'date': shortDate(when)}),
                      style: const TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(tr('Hidden from lists and new bookings; history stays.'),
                      style: const TextStyle(
                          fontSize: 13, height: 1.45, color: AppColors.muted)),
                ])),
          ]),
          const SizedBox(height: 12),
          AppButton(
              key: const Key('profile-restore'),
              label: restoreLabel,
              icon: Icons.unarchive_outlined,
              kind: AppButtonKind.tonal,
              busy: busy,
              onPressed: onRestore),
        ]));
  }
}

/// "Active · 4" and "Archived · 1" for the list switch; plain words until
/// the list has loaded.
List<String> activeArchivedLabels({int? active, int? archived}) => [
      active == null ? tr('Active') : tr('Active · {n}', {'n': active}),
      archived == null ? tr('Archived') : tr('Archived · {n}', {'n': archived}),
    ];
