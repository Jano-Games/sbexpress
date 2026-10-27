import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models/media_item.dart';
import '../data/uploads/image_prepare.dart';
import '../data/uploads/photo_tray.dart';
import '../data/uploads/quick_uploads.dart' show FileSource;
import '../data/uploads/signed_photos.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import 'flight_parts.dart' show RowCard;
import 'ui.dart';

/// Camera and Gallery buttons, then the picked photos as square previews
/// with Upload and Clear. Nothing is sent before Upload.
class PhotoTray extends StatelessWidget {
  const PhotoTray(
      {super.key,
      required this.tray,
      required this.onPick,
      this.enabled = true,
      this.showPickers = true,
      this.group});
  final PhotoTrayController tray;
  final void Function(FileSource source) onPick;
  final bool enabled;

  /// False when the screen draws its own Camera and Gallery buttons.
  final bool showPickers;

  /// What the photos are of, shown in the viewer.
  final String? group;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: tray,
      builder: (context, _) {
        final photos = tray.photos;
        final busy = tray.uploading;
        final problems = [
          for (final photo in photos)
            if (photo.error != null) photo
        ];
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showPickers)
                Row(children: [
                  Expanded(
                      child: AppButton(
                          key: const Key('photo-camera'),
                          label: tr('Camera'),
                          icon: Icons.photo_camera_outlined,
                          kind: AppButtonKind.quiet,
                          onPressed: enabled && !busy
                              ? () => onPick(FileSource.camera)
                              : null)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: AppButton(
                          key: const Key('photo-gallery'),
                          label: tr('Gallery'),
                          icon: Icons.image_outlined,
                          kind: AppButtonKind.quiet,
                          onPressed: enabled && !busy
                              ? () => onPick(FileSource.gallery)
                              : null)),
                ]),
              if (photos.isNotEmpty) ...[
                if (showPickers) const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                      child: Text(tr('Not uploaded yet'),
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkSoft))),
                  const SizedBox(width: 8),
                  Text(trn(photos.length, '{n} photo', '{n} photos'),
                      style: const TextStyle(
                          fontSize: 13, height: 1.4, color: AppColors.muted)),
                ]),
                const SizedBox(height: 8),
                LayoutBuilder(builder: (context, box) {
                  const gap = 8.0;
                  final columns = box.maxWidth >= 300 ? 4 : 3;
                  final size = (box.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(spacing: gap, runSpacing: gap, children: [
                    for (var i = 0; i < photos.length; i++)
                      SizedBox(
                          key: ValueKey('tray-photo-${photos[i].id}'),
                          width: size,
                          height: size,
                          child: _TrayTile(
                              photo: photos[i],
                              onRemove:
                                  busy ? null : () => tray.remove(photos[i]),
                              onOpen: () => _open(context, photos, i))),
                  ]);
                }),
                for (final photo in problems) ...[
                  const SizedBox(height: 10),
                  _TrayProblem(
                      photo: photo,
                      onRetry: photo.state == TrayPhotoState.failed && !busy
                          ? () => tray.retry(photo)
                          : null),
                ],
                if (tray.locationStripped) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.location_off_outlined,
                        size: 16, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(locationStrippedNote,
                            style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: AppColors.muted))),
                  ]),
                ],
                const SizedBox(height: 12),
                AppButton(
                    key: const Key('tray-upload'),
                    label: tray.single
                        ? tr('Upload photo')
                        : trn(tray.sendable, 'Upload {n} photo',
                            'Upload {n} photos'),
                    icon: Icons.cloud_upload_outlined,
                    kind: AppButtonKind.current,
                    busy: busy,
                    onPressed: enabled && tray.sendable > 0 && !tray.preparing
                        ? tray.uploadAll
                        : null),
                const SizedBox(height: 4),
                Center(
                    child: TextButton(
                        key: const Key('tray-clear'),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.muted,
                            minimumSize: const Size(64, 44),
                            textStyle: const TextStyle(
                                fontFamily: 'HindSiliguri',
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        onPressed: busy ? null : tray.clear,
                        child: Text(tr('Clear')))),
              ],
            ]);
      });

  void _open(BuildContext context, List<TrayPhoto> photos, int index) {
    final shown = [
      for (final photo in photos)
        if (photo.prepared != null) photo
    ];
    final at = shown.indexOf(photos[index]);
    if (at < 0) return;
    showPhotoViewer(context,
        photos: [
          for (final photo in shown)
            ViewerPhoto.local(photo.prepared!.bytes,
                group: group ?? tr('Not uploaded yet'))
        ],
        initial: at);
  }
}

class _TrayTile extends StatelessWidget {
  const _TrayTile(
      {required this.photo, required this.onRemove, required this.onOpen});
  final TrayPhoto photo;
  final VoidCallback? onRemove;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final prepared = photo.prepared;
    final failed = photo.state == TrayPhotoState.failed ||
        photo.state == TrayPhotoState.unusable;
    final uploading = photo.state == TrayPhotoState.uploading;
    return Stack(fit: StackFit.expand, children: [
      ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ColoredBox(
              color: AppColors.neutralSoft,
              child: prepared == null
                  ? photo.state == TrayPhotoState.preparing
                      ? const Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                      : const Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: AppColors.danger))
                  : Image(
                      image: ResizeImage(MemoryImage(prepared.bytes),
                          width: 300, policy: ResizeImagePolicy.fit),
                      fit: BoxFit.cover,
                      gaplessPlayback: true))),
      if (prepared != null)
        Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: onOpen)),
      if (failed)
        IgnorePointer(
            child: DecoratedBox(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.danger, width: 2)))),
      if (uploading)
        IgnorePointer(
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: const Color(0x8C18212F),
                    borderRadius: BorderRadius.circular(10)),
                child: Center(
                    child: SizedBox(
                        width: 34,
                        height: 34,
                        child: Semantics(
                            label: tr('Uploading photos'),
                            child: CircularProgressIndicator(
                                key: ValueKey('tray-ring-${photo.id}'),
                                strokeWidth: 3,
                                color: Colors.white,
                                backgroundColor: const Color(0x40FFFFFF),
                                value: photo.progress > 0
                                    ? photo.progress
                                    : null)))))),
      if (failed)
        const PositionedDirectional(
            bottom: 6,
            start: 6,
            child: IgnorePointer(
                child: CircleAvatar(
                    radius: 11,
                    backgroundColor: AppColors.danger,
                    child: Icon(Icons.priority_high_rounded,
                        size: 15, color: Colors.white)))),
      if (!uploading)
        PositionedDirectional(
            top: 0,
            end: 0,
            child: Tooltip(
                message: tr('Remove photo'),
                child: InkResponse(
                    key: ValueKey('tray-remove-${photo.id}'),
                    onTap: onRemove,
                    radius: 18,
                    child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                            child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                    color: Color(0xB318212F),
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.close_rounded,
                                    size: 14, color: Colors.white))))))),
    ]);
  }
}

/// A photo that did not upload or cannot be read: its preview, the
/// reason and, for an upload failure, Try again.
class _TrayProblem extends StatelessWidget {
  const _TrayProblem({required this.photo, required this.onRetry});
  final TrayPhoto photo;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final prepared = photo.prepared;
    final retry = photo.state == TrayPhotoState.failed;
    return Container(
        padding: EdgeInsetsDirectional.fromSTEB(10, 10, 10, retry ? 2 : 10),
        decoration: BoxDecoration(
            color: AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(controlRadius)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                  width: 36,
                  height: 36,
                  child: prepared == null
                      ? const ColoredBox(
                          color: AppColors.card,
                          child: Icon(Icons.broken_image_outlined,
                              size: 18, color: AppColors.danger))
                      : Image(
                          image: ResizeImage(MemoryImage(prepared.bytes),
                              width: 72, policy: ResizeImagePolicy.fit),
                          fit: BoxFit.cover))),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(photo.error ?? '',
                    key: ValueKey('tray-error-${photo.id}'),
                    style: const TextStyle(
                        fontSize: 13, height: 1.4, color: AppColors.danger)),
                if (retry)
                  TextButton.icon(
                      key: ValueKey('tray-retry-${photo.id}'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          minimumSize: const Size(48, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          textStyle: const TextStyle(
                              fontFamily: 'HindSiliguri',
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(tr('Try again'))),
              ])),
        ]));
  }
}

/// Asks before leaving a screen whose tray still holds photos, and keeps
/// the screen open unless they are discarded.
class PhotoTrayGuard extends StatelessWidget {
  const PhotoTrayGuard({super.key, required this.tray, required this.child});
  final PhotoTrayController? tray;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tray = this.tray;
    if (tray == null) return child;
    return ListenableBuilder(
        listenable: tray,
        builder: (context, child) => PopScope(
            canPop: tray.isEmpty,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              final discard = await confirmDiscardPhotos(context, tray.count);
              if (!discard || !context.mounted) return;
              final navigator = Navigator.of(context);
              if (navigator.canPop()) navigator.pop();
            },
            child: child!),
        child: child);
  }
}

/// "Discard 2 photos that were not uploaded?"; true to leave without them.
Future<bool> confirmDiscardPhotos(BuildContext context, int count) async {
  final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
            scrollable: true,
            title: Text(trn(count, 'Discard {n} photo that was not uploaded?',
                'Discard {n} photos that were not uploaded?')),
            content: Text(tr(
                'They are only on this phone. Upload them first to keep them.')),
            actions: [
              TextButton(
                  key: const Key('tray-discard-cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(tr('Keep photos'))),
              FilledButton(
                  key: const Key('tray-discard-confirm'),
                  style:
                      FilledButton.styleFrom(backgroundColor: AppColors.danger),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(tr('Discard'))),
            ],
          ));
  return answer ?? false;
}

/// A stored photo: a soft placeholder while it loads, then the image; a
/// broken tile with "Tap to retry" when it fails.
class StoredPhotoImage extends StatefulWidget {
  const StoredPhotoImage(
      {super.key,
      required this.loader,
      required this.reference,
      this.fit = BoxFit.cover,
      this.cacheWidth,
      this.dark = false,
      this.onTap});
  final SignedPhotoLoader loader;
  final String reference;
  final BoxFit fit;

  /// Tapping a loaded or loading photo; a broken one retries instead.
  final VoidCallback? onTap;

  /// Decoded width for thumbnails; null decodes at full size.
  final int? cacheWidth;

  /// White on black, for the full-screen viewer.
  final bool dark;

  @override
  State<StoredPhotoImage> createState() => _StoredPhotoImageState();
}

class _StoredPhotoImageState extends State<StoredPhotoImage> {
  Uint8List? _bytes;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(StoredPhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference != widget.reference ||
        oldWidget.loader != widget.loader) {
      _start();
    }
  }

  void _start() {
    _bytes = widget.loader.cached(widget.reference);
    _failed = false;
    if (_bytes == null) _load();
  }

  Future<void> _load() async {
    final reference = widget.reference;
    if (_failed) setState(() => _failed = false);
    try {
      final bytes = await widget.loader.load(reference);
      if (!mounted || reference != widget.reference) return;
      setState(() => _bytes = bytes);
    } catch (_) {
      if (!mounted || reference != widget.reference) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      final ImageProvider image = widget.cacheWidth == null
          ? MemoryImage(bytes)
          : ResizeImage(MemoryImage(bytes),
              width: widget.cacheWidth, policy: ResizeImagePolicy.fit);
      return _tappable(Image(
          key: ValueKey('photo-image-${widget.reference}'),
          image: image,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stack) => _broken(null)));
    }
    if (_failed) return _broken(_load);
    return _tappable(Container(
        key: ValueKey('photo-loading-${widget.reference}'),
        color: widget.dark ? Colors.black : AppColors.neutralSoft,
        alignment: Alignment.center,
        child: widget.dark
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : const Icon(Icons.image_outlined,
                size: 22, color: AppColors.faint)));
  }

  Widget _tappable(Widget child) => widget.onTap == null
      ? child
      : GestureDetector(
          behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: child);

  Widget _broken(VoidCallback? retry) {
    final ink = widget.dark ? Colors.white : AppColors.muted;
    return Material(
        key: ValueKey('photo-broken-${widget.reference}'),
        color: widget.dark ? Colors.black : AppColors.neutralSoft,
        child: InkWell(
            onTap: retry,
            child: Padding(
                padding: const EdgeInsets.all(6),
                child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.broken_image_outlined,
                      size: widget.dark ? 40 : 22, color: ink),
                  if (retry != null) ...[
                    const SizedBox(height: 4),
                    Flexible(
                        child: Text(tr('Tap to retry'),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: widget.dark ? 14 : 11,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                                color: ink))),
                  ],
                ])))));
  }
}

/// The groups photos are shown in: parcel photos first, then one group per
/// device category in the order they first appear.
List<(String, List<MediaItem>)> photoGroups(List<MediaItem> media) {
  final groups = <String?, List<MediaItem>>{null: []};
  for (final item in media) {
    final category = item.deviceCategory?.trim();
    final key = category == null || category.isEmpty ? null : category;
    (groups[key] ??= []).add(item);
  }
  return [
    for (final MapEntry(:key, :value) in groups.entries)
      if (value.isNotEmpty) (photoGroupLabel(key), value)
  ];
}

/// "Parcel photos" or "Mobile photos", "Laptop photos" …
String photoGroupLabel(String? category) => category == null
    ? tr('Parcel photos')
    : tr('{name} photos', {'name': category});

/// The stored photos of a shipment as a 3-column grid per group, loaded
/// from signed links. An older server without links, or storage that is
/// not set up, gets the plain list instead.
class StoredPhotoGrid extends StatelessWidget {
  const StoredPhotoGrid(
      {super.key,
      required this.media,
      required this.loader,
      required this.onOpen,
      this.configured = true,
      this.onToggle});
  final List<MediaItem> media;
  final SignedPhotoLoader loader;
  final bool configured;

  /// Opens the viewer at [index] of [ordered], the photos as shown.
  final void Function(List<MediaItem> ordered, int index) onOpen;

  /// Admin only: shares a photo with the customer or stops it.
  final Future<void> Function(MediaItem item, bool shared)? onToggle;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) {
      return EmptyNote(
          icon: Icons.photo_outlined,
          title: tr('No photos'),
          body: tr('Photos you add will appear here.'));
    }
    return ListenableBuilder(
        listenable: loader,
        builder: (context, _) {
          final title =
              SectionTitle(title: trn(media.length, '{n} photo', '{n} photos'));
          if (!configured || loader.unsupported) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  if (configured) ...[
                    HintNote(
                        key: const Key('photos-need-update'),
                        text: tr('The server needs an update to show photos.')),
                    const SizedBox(height: 10),
                  ],
                  _PhotoRows(media: media, onToggle: onToggle),
                ]);
          }
          final groups = photoGroups(media);
          final ordered = [for (final (_, items) in groups) ...items];
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                PaperCard(
                    key: const Key('photo-grid'),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var g = 0; g < groups.length; g++) ...[
                            if (g > 0) const SizedBox(height: 16),
                            _GroupHead(
                                label: groups[g].$1,
                                count: groups[g].$2.length),
                            const SizedBox(height: 8),
                            _Grid(
                                items: groups[g].$2,
                                loader: loader,
                                onOpen: (item) =>
                                    onOpen(ordered, ordered.indexOf(item))),
                          ],
                        ])),
              ]);
        });
  }
}

class _GroupHead extends StatelessWidget {
  const _GroupHead({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Text.rich(
      TextSpan(children: [
        TextSpan(text: label),
        TextSpan(
            text: ' · $count',
            style: const TextStyle(
                fontWeight: FontWeight.w400, color: AppColors.muted)),
      ]),
      style: const TextStyle(
          fontSize: 14, height: 1.35, fontWeight: FontWeight.w700));
}

class _Grid extends StatelessWidget {
  const _Grid(
      {required this.items, required this.loader, required this.onOpen});
  final List<MediaItem> items;
  final SignedPhotoLoader loader;
  final void Function(MediaItem item) onOpen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        const gap = 8.0;
        final size = (box.maxWidth - gap * 2) / 3;
        final width = (size * MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(96, 600)
            .toInt();
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final item in items)
            SizedBox(
                key: ValueKey('photo-tile-${item.reference}'),
                width: size,
                height: size,
                child: Semantics(
                    button: true,
                    label: item.name,
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(fit: StackFit.expand, children: [
                          StoredPhotoImage(
                              loader: loader,
                              reference: item.reference,
                              cacheWidth: width,
                              onTap: () => onOpen(item)),
                          if (item.shared)
                            PositionedDirectional(
                                start: 5,
                                bottom: 5,
                                end: 5,
                                child: _SharedBadge(compact: size < 96)),
                        ])))),
        ]);
      });
}

class _SharedBadge extends StatelessWidget {
  const _SharedBadge({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = tr('Customer can see');
    const icon = Icon(Icons.visibility_outlined, size: 13, color: Colors.white);
    return Align(
        alignment: AlignmentDirectional.bottomStart,
        child: IgnorePointer(
            child: Semantics(
                label: label,
                excludeSemantics: true,
                child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: compact ? 4 : 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppColors.ok,
                        borderRadius: BorderRadius.circular(999)),
                    child: compact
                        ? icon
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            icon,
                            const SizedBox(width: 4),
                            Flexible(
                                child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(label,
                                        maxLines: 1,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            height: 1.2,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white)))),
                          ])))));
  }
}

/// Today's list: each photo's name and who can see it.
class _PhotoRows extends StatelessWidget {
  const _PhotoRows({required this.media, required this.onToggle});
  final List<MediaItem> media;
  final Future<void> Function(MediaItem item, bool shared)? onToggle;

  @override
  Widget build(BuildContext context) => RowCard(children: [
        for (final item in media)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                          [
                            photoGroupLabel(item.deviceCategory),
                            item.shared
                                ? tr('Visible to customer')
                                : tr('Staff only'),
                          ].join(' · '),
                          style: TextStyle(
                              fontSize: 13,
                              color: item.shared
                                  ? AppColors.ok
                                  : AppColors.muted)),
                    ])),
                if (onToggle != null)
                  Semantics(
                      label: item.shared
                          ? tr('Stop sharing')
                          : tr('Share with customer'),
                      child: Switch(
                          value: item.shared,
                          onChanged: (value) => onToggle!(item, value))),
              ])),
      ]);
}

/// One photo in the full-screen viewer: bytes on this phone, or a stored
/// reference loaded through the viewer's loader.
class ViewerPhoto {
  const ViewerPhoto.local(Uint8List this.bytes, {required this.group})
      : reference = null,
        shared = null;
  const ViewerPhoto.stored(String this.reference,
      {required this.group, this.shared})
      : bytes = null;

  final Uint8List? bytes;
  final String? reference;

  /// "Parcel photos", "Mobile photos", a document kind …
  final String group;

  /// Whether the customer can see it; null hides the switch.
  final bool? shared;
}

/// Opens [photos] full screen at [initial]: swipe between them, pinch to
/// zoom. With [onShare] each stored photo has a "Show to customer" switch;
/// it returns false when the change was not saved.
Future<void> showPhotoViewer(BuildContext context,
    {required List<ViewerPhoto> photos,
    int initial = 0,
    SignedPhotoLoader? loader,
    Future<bool> Function(int index, bool shared)? onShare}) {
  if (photos.isEmpty) return Future.value();
  return Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => PhotoViewerScreen(
          photos: photos,
          initial: initial.clamp(0, photos.length - 1),
          loader: loader,
          onShare: onShare)));
}

class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen(
      {super.key,
      required this.photos,
      this.initial = 0,
      this.loader,
      this.onShare});
  final List<ViewerPhoto> photos;
  final int initial;
  final SignedPhotoLoader? loader;
  final Future<bool> Function(int index, bool shared)? onShare;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final _pages = PageController(initialPage: widget.initial);
  late var _index = widget.initial;
  late final _shared = [for (final photo in widget.photos) photo.shared];
  var _zoomed = false;
  var _saving = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _toggle(bool value) async {
    final index = _index;
    final onShare = widget.onShare;
    if (onShare == null || _saving) return;
    final before = _shared[index];
    setState(() {
      _shared[index] = value;
      _saving = true;
    });
    final saved = await onShare(index, value);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!saved) _shared[index] = before;
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.photos.length;
    final photo = widget.photos[_index];
    final shared = _shared[_index];
    final canShare = widget.onShare != null && shared != null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(children: [
              PageView.builder(
                  key: const Key('viewer-pages'),
                  controller: _pages,
                  physics: _zoomed
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  itemCount: total,
                  onPageChanged: (index) => setState(() {
                        _index = index;
                        _zoomed = false;
                      }),
                  itemBuilder: (context, index) => _ZoomPage(
                      photo: widget.photos[index],
                      loader: widget.loader,
                      onZoom: (zoomed) {
                        if (index == _index && zoomed != _zoomed) {
                          setState(() => _zoomed = zoomed);
                        }
                      })),
              Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: DecoratedBox(
                      decoration: const BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xB3000000), Color(0x00000000)])),
                      child: SafeArea(
                          bottom: false,
                          child: Padding(
                              padding: const EdgeInsets.fromLTRB(4, 4, 16, 16),
                              child: Row(children: [
                                IconButton(
                                    key: const Key('viewer-close'),
                                    tooltip: tr('Close'),
                                    color: Colors.white,
                                    onPressed: () =>
                                        Navigator.of(context).maybePop(),
                                    icon: const Icon(Icons.close_rounded)),
                                const SizedBox(width: 4),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(
                                          tr('{n} of {total}', {
                                            'n': _index + 1,
                                            'total': total
                                          }),
                                          key: const Key('viewer-position'),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              height: 1.3,
                                              fontWeight: FontWeight.w700)),
                                      Text(photo.group,
                                          key: const Key('viewer-group'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: Color(0xCCFFFFFF),
                                              fontSize: 13,
                                              height: 1.4)),
                                    ])),
                              ]))))),
              if (canShare)
                Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: SafeArea(
                        top: false,
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Material(
                                color: const Color(0xE6151B26),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                    padding:
                                        const EdgeInsets.fromLTRB(16, 8, 10, 8),
                                    child: Row(children: [
                                      Icon(
                                          shared
                                              ? Icons.visibility_outlined
                                              : Icons.lock_outline_rounded,
                                          size: 20,
                                          color: shared
                                              ? const Color(0xFF7FD3A5)
                                              : const Color(0xCCFFFFFF)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(tr('Show to customer'),
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    height: 1.35,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            Text(
                                                shared
                                                    ? tr('Customer can see')
                                                    : tr('Staff only'),
                                                style: const TextStyle(
                                                    color: Color(0xB3FFFFFF),
                                                    fontSize: 12,
                                                    height: 1.4)),
                                          ])),
                                      Switch(
                                          key: const Key('viewer-share'),
                                          value: shared,
                                          onChanged: _saving ? null : _toggle),
                                    ])))))),
            ])));
  }
}

class _ZoomPage extends StatefulWidget {
  const _ZoomPage(
      {required this.photo, required this.loader, required this.onZoom});
  final ViewerPhoto photo;
  final SignedPhotoLoader? loader;
  final void Function(bool zoomed) onZoom;

  @override
  State<_ZoomPage> createState() => _ZoomPageState();
}

class _ZoomPageState extends State<_ZoomPage> {
  final _zoom = TransformationController();

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _report() => widget.onZoom(_zoom.value.getMaxScaleOnAxis() > 1.01);

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final loader = widget.loader;
    // Decoded at twice the screen width: sharp when zoomed, without
    // holding every photo at full size.
    final width = (MediaQuery.sizeOf(context).width *
            MediaQuery.devicePixelRatioOf(context) *
            2)
        .round()
        .clamp(400, 4000)
        .toInt();
    final Widget image = photo.bytes != null
        ? Image(
            image: ResizeImage(MemoryImage(photo.bytes!),
                width: width, policy: ResizeImagePolicy.fit),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, error, stack) => const Icon(
                Icons.broken_image_outlined,
                size: 40,
                color: Colors.white))
        : loader == null || photo.reference == null
            ? const Icon(Icons.broken_image_outlined,
                size: 40, color: Colors.white)
            : StoredPhotoImage(
                loader: loader,
                reference: photo.reference!,
                fit: BoxFit.contain,
                cacheWidth: width,
                dark: true);
    return InteractiveViewer(
        transformationController: _zoom,
        minScale: 1,
        maxScale: 5,
        onInteractionEnd: (_) => _report(),
        child: SizedBox.expand(child: image));
  }
}
