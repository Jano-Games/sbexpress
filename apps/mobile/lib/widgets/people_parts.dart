import 'package:flutter/material.dart';

import '../data/api/api_exception.dart';
import '../data/repositories/photo_repository.dart';
import '../data/uploads/flutter_heic.dart';
import '../data/uploads/image_prepare.dart';
import '../data/uploads/photo_upload.dart';
import '../data/uploads/quick_uploads.dart';
import '../data/uploads/signed_photos.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import 'flight_parts.dart' show LetterAvatar;
import 'flow_parts.dart' show SheetHeader, showFlowSheet;
import 'photo_parts.dart' show StoredPhotoImage;
import 'team_parts.dart' show DashedOutline;

/// A person's face photo, or their first letter when there is none (or the
/// photo cannot be loaded).
class PersonAvatar extends StatelessWidget {
  const PersonAvatar(this.name,
      {super.key,
      required this.photoRef,
      required this.loader,
      this.size = 38,
      this.square = false,
      this.color = AppColors.primarySoft,
      this.foreground = AppColors.primaryInk,
      this.onTap});

  final String name;
  final String? photoRef;
  final SignedPhotoLoader? loader;
  final double size;

  /// Rounded square instead of a circle, for the big hub photos.
  final bool square;
  final Color color, foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reference = photoRef;
    final store = loader;
    final letter = LetterAvatar(name,
        size: size, square: square, color: color, foreground: foreground);
    if (reference == null || reference.isEmpty || store == null) {
      return Semantics(
          label: name,
          excludeSemantics: true,
          child: onTap == null
              ? letter
              : InkWell(
                  customBorder: square
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(size * 0.28))
                      : const CircleBorder(),
                  onTap: onTap,
                  child: letter));
    }
    final radius = square ? size * 0.22 : size / 2;
    return Semantics(
        image: true,
        label: tr('Photo of {name}', {'name': name}),
        excludeSemantics: true,
        child: SizedBox(
            width: size,
            height: size,
            child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: StoredPhotoImage(
                    key: ValueKey('face-$reference'),
                    loader: store,
                    reference: reference,
                    cacheWidth: (size * 3).round(),
                    onTap: onTap))));
  }
}

/// One device piece's photo square: the photo with its piece label, or an
/// orange dashed "Add photo" square.
class PiecePhotoSlot extends StatelessWidget {
  const PiecePhotoSlot(
      {super.key,
      required this.size,
      required this.onTap,
      this.image,
      this.label,
      this.onRemove,
      this.addLabel});

  final double size;

  /// The photo; null shows the empty "Add photo" square.
  final Widget? image;

  /// "Piece 2", when the model has more than one piece.
  final String? label;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  /// Read out for the empty square, e.g. "Add photo of piece 2".
  final String? addLabel;

  @override
  Widget build(BuildContext context) {
    final photo = image;
    if (photo == null) {
      final small = size < 70;
      return Semantics(
          button: true,
          label: addLabel ?? tr('Add photo'),
          excludeSemantics: true,
          child: SizedBox(
              width: size,
              height: size,
              child: DashedOutline(
                  radius: 12,
                  color: AppColors.accentLine,
                  background: AppColors.accentSoft,
                  child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_camera_outlined,
                                size: small ? 16 : 18,
                                color: AppColors.accentInk),
                            const SizedBox(height: 2),
                            Text(small ? tr('Add') : tr('Add photo'),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: small ? 10 : 11,
                                    height: 1.2,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accentInk)),
                            if (!small && label != null)
                              Text(label!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.2,
                                      color: AppColors.accentInk)),
                          ])))));
    }
    return SizedBox(
        width: size,
        height: size,
        child: Stack(fit: StackFit.expand, children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Material(
                  color: AppColors.neutralSoft,
                  child: InkWell(onTap: onTap, child: photo))),
          if (label != null)
            PositionedDirectional(
                start: 4,
                bottom: 4,
                child: IgnorePointer(
                    child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                            color: const Color(0xB80F172A),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(label!,
                            style: const TextStyle(
                                fontSize: 11,
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white))))),
          if (onRemove != null)
            PositionedDirectional(
                top: 0,
                end: 0,
                child: Tooltip(
                    message: tr('Remove photo'),
                    child: InkResponse(
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
        ]));
  }
}

enum _FaceAction { camera, gallery, remove }

/// Adds, replaces or removes the face photo of a flyer or staff member:
/// a sheet with Take a photo, Choose from gallery and Remove photo, then
/// the upload. Returns true when the photo changed.
Future<bool> changeFacePhoto(
  BuildContext context, {
  required PhotoRepository photos,
  required PhotoOwner type,
  required String owner,
  required String name,
  required String? photoRef,
  required SignedPhotoLoader loader,
  Future<List<PickedPhoto>> Function(FileSource source)? pick,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final has = photoRef != null && photoRef.isNotEmpty;
  final action = await showFlowSheet<_FaceAction>(
      context,
      (context) => SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SheetHeader(
                title: tr('Photo of {name}', {'name': name}),
                subtitle: type == PhotoOwner.flyer
                    ? tr(
                        'The hub uses it to find this flyer at the airport. Use a face photo, not the passport page.')
                    : tr(
                        'Shown on the flights and orders this person receives.')),
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: PersonAvatar(name,
                    key: const Key('face-sheet-current'),
                    photoRef: photoRef,
                    loader: loader,
                    size: 96)),
            ListTile(
                key: const Key('face-camera'),
                minTileHeight: 56,
                leading: const Icon(Icons.photo_camera_outlined,
                    color: AppColors.primary),
                title: Text(tr('Take a photo')),
                onTap: () => Navigator.of(context).pop(_FaceAction.camera)),
            ListTile(
                key: const Key('face-gallery'),
                minTileHeight: 56,
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.primary),
                title: Text(tr('Choose from gallery')),
                onTap: () => Navigator.of(context).pop(_FaceAction.gallery)),
            if (has)
              ListTile(
                  key: const Key('face-remove'),
                  minTileHeight: 56,
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.danger),
                  title: Text(tr('Remove photo'),
                      style: const TextStyle(color: AppColors.danger)),
                  onTap: () => Navigator.of(context).pop(_FaceAction.remove)),
            const SizedBox(height: 12),
          ])));
  if (action == null || !context.mounted) return false;
  try {
    if (action == _FaceAction.remove) {
      await photos.remove(type, owner);
      messenger.showSnackBar(SnackBar(content: Text(tr('Photo removed'))));
      return true;
    }
    final picked = await (pick ?? pickPhotos)(
        action == _FaceAction.camera ? FileSource.camera : FileSource.gallery);
    if (picked.isEmpty) return false;
    messenger.showSnackBar(SnackBar(content: Text(tr('Saving the photo…'))));
    final photo = picked.first;
    final image = await prepareForUpload(photo.bytes,
        name: photo.name, mime: photo.mime, decodeHeic: flutterDecodeHeic);
    await photos.upload(
        type: type, owner: owner, image: image, onProgress: (_) {});
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tr('Photo saved'))));
    return true;
  } on ApiException catch (error) {
    messenger.hideCurrentSnackBar();
    if (error.status != 401) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  } catch (error) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error.toString())));
  }
  return false;
}

/// "Admin" or "Hub manager" for a history line or a receiver.
String staffRoleLabel(String? role) => switch (role) {
      'admin' => tr('Admin'),
      'hub' => tr('Hub manager'),
      _ => '',
    };
