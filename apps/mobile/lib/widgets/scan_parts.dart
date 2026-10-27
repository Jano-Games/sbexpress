import 'package:flutter/material.dart';

import '../data/scan/mrz.dart';
import '../data/uploads/quick_uploads.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import 'team_parts.dart';
import 'ui.dart';

/// The passport and visa scan on the new flyer form.

/// The scan card at the top of the form: Camera / Gallery, then "Reading…",
/// then a quiet note, or the unreadable message with the attach choices.
class DocumentScanCard extends StatelessWidget {
  const DocumentScanCard(
      {super.key,
      required this.onScan,
      required this.onAttach,
      this.reading = false,
      this.unreadable = false,
      this.note});
  final ValueChanged<FileSource> onScan;

  /// Attaches the photo that could not be read as this document.
  final ValueChanged<TravelDocument> onAttach;
  final bool reading;

  /// The last photo could not be read.
  final bool unreadable;

  /// Shown after a scan, e.g. "Filled from the passport · check the spelling".
  final String? note;

  @override
  Widget build(BuildContext context) => PaperCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const IconBadge(Icons.document_scanner_outlined, size: 44),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(tr('Scan passport or visa'),
                    style: const TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        fontWeight: FontWeight.w700)),
                Text(tr('Fills the name and adds the photo to Documents'),
                    style: const TextStyle(
                        fontSize: 12, height: 1.4, color: AppColors.muted)),
              ])),
        ]),
        const SizedBox(height: 12),
        if (reading)
          const _ReadingRow()
        else
          Row(children: [
            Expanded(
                child: SmallActionButton(
                    key: const Key('scan-camera'),
                    label: tr('Camera'),
                    icon: Icons.photo_camera_outlined,
                    tonal: true,
                    onPressed: () => onScan(FileSource.camera))),
            const SizedBox(width: 8),
            Expanded(
                child: SmallActionButton(
                    key: const Key('scan-gallery'),
                    label: tr('Gallery'),
                    icon: Icons.image_outlined,
                    onPressed: () => onScan(FileSource.gallery))),
          ]),
        if (note case final note?) ...[
          const SizedBox(height: 12),
          Row(
              key: const Key('scan-note'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.check_circle_outline_rounded,
                        size: 18, color: AppColors.ok)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(note,
                        style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                            color: AppColors.inkSoft))),
              ]),
        ],
        if (unreadable) ...[
          const SizedBox(height: 12),
          AttentionNote(
              key: const Key('scan-unreadable'),
              text: tr(
                  "Couldn't read the lines at the bottom of the page. Try a sharper photo, or type the name.")),
          const SizedBox(height: 10),
          SmallActionButton(
              key: const Key('scan-attach-passport'),
              label: tr('Attach as passport'),
              icon: Icons.book_outlined,
              onPressed: () => onAttach(TravelDocument.passport)),
          const SizedBox(height: 8),
          SmallActionButton(
              key: const Key('scan-attach-visa'),
              label: tr('Attach as visa'),
              icon: Icons.travel_explore_outlined,
              onPressed: () => onAttach(TravelDocument.visa)),
        ],
      ]));
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow();

  @override
  Widget build(BuildContext context) => Container(
      key: const Key('scan-reading'),
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(controlRadius)),
      child: Row(children: [
        const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(tr('Reading…'),
                style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryInk))),
      ]));
}

/// Asks before the scanned name replaces a name already typed in.
Future<bool> confirmScannedName(BuildContext context,
    {required TravelDocument kind, required String name}) async {
  final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
            scrollable: true,
            title: Text(tr('Replace the typed name?')),
            content: Text(kind == TravelDocument.passport
                ? tr('The passport shows {name}.', {'name': name})
                : tr('The visa shows {name}.', {'name': name})),
            actions: [
              TextButton(
                  key: const Key('scan-keep'),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(tr('Keep typed name'))),
              FilledButton(
                  key: const Key('scan-replace'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(tr('Replace'))),
            ],
          ));
  return answer ?? false;
}

/// The note under the scan buttons once a photo went to Documents.
String scanNote(TravelDocument kind, {required bool filled}) =>
    switch ((kind, filled)) {
      (TravelDocument.passport, true) =>
        tr('Filled from the passport · check the spelling'),
      (TravelDocument.visa, true) =>
        tr('Filled from the visa · check the spelling'),
      (TravelDocument.passport, false) => tr('Passport added to Documents'),
      (TravelDocument.visa, false) => tr('Visa added to Documents'),
    };
