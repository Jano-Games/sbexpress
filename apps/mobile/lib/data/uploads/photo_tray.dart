import 'package:flutter/foundation.dart';

import '../../l10n/l10n.dart';
import 'image_prepare.dart';
import 'photo_upload.dart';
import 'upload_flow.dart';

enum TrayPhotoState {
  /// Being turned into a small JPEG.
  preparing,

  /// Ready to upload.
  ready,
  uploading,

  /// The upload failed; it can be sent again.
  failed,

  /// The file could not be read as a photo; it can only be removed.
  unusable,
}

/// One picked photo waiting in the tray.
class TrayPhoto {
  TrayPhoto(this.original) : id = _next++;

  static var _next = 0;

  /// Stable within the app run, for widget keys.
  final int id;
  final PickedPhoto original;

  /// The JPEG that is shown and sent, without location data.
  PreparedImage? prepared;
  TrayPhotoState state = TrayPhotoState.preparing;
  double progress = 0;
  String? error;

  bool get sendable =>
      state == TrayPhotoState.ready || state == TrayPhotoState.failed;
}

/// Photos picked on a screen wait here as previews. Nothing is uploaded
/// until [uploadAll]; then they go one by one, each leaving the tray once it
/// is stored, while a failed one stays with its error to try again.
class PhotoTrayController extends ChangeNotifier {
  PhotoTrayController(
      {required this.upload,
      Future<Uint8List> Function(Uint8List heic)? decodeHeic,
      this.single = false,
      this.onUploaded})
      : _decodeHeic = decodeHeic ?? _noHeicDecoder;

  /// Sends one prepared photo, reporting progress from 0 to 1.
  final Future<void> Function(
      PreparedImage image, void Function(double progress) onProgress) upload;
  final Future<Uint8List> Function(Uint8List heic) _decodeHeic;

  /// Holds one photo at a time; a new pick replaces it (IMEI photos).
  final bool single;

  /// Called after each photo is stored, e.g. to reload the list.
  final void Function()? onUploaded;

  final _photos = <TrayPhoto>[];
  var _uploading = false;
  var _disposed = false;
  var _uploaded = 0;

  List<TrayPhoto> get photos => List.unmodifiable(_photos);
  int get count => _photos.length;
  bool get isEmpty => _photos.isEmpty;
  bool get uploading => _uploading;

  /// Photos stored since this tray opened.
  int get uploadedCount => _uploaded;
  bool get preparing =>
      _photos.any((photo) => photo.state == TrayPhotoState.preparing);

  /// Photos the Upload button sends.
  int get sendable => _photos.where((photo) => photo.sendable).length;

  /// Whether a shown preview had its location data removed.
  bool get locationStripped => _photos.any((photo) => photo.prepared != null);

  /// Adds [picked] as previews and prepares each, in order.
  Future<void> add(List<PickedPhoto> picked) async {
    if (picked.isEmpty || (single && _uploading)) return;
    final added = [
      for (final photo in single ? [picked.last] : picked) TrayPhoto(photo)
    ];
    if (single) _photos.clear();
    _photos.addAll(added);
    _notify();
    for (final photo in added) {
      try {
        photo.prepared = await prepareForUpload(photo.original.bytes,
            name: photo.original.name,
            mime: photo.original.mime,
            decodeHeic: _decodeHeic);
        photo.state = TrayPhotoState.ready;
      } catch (error) {
        photo
          ..state = TrayPhotoState.unusable
          ..error = describeUploadError(error);
      }
      if (_disposed) return;
      _notify();
    }
  }

  /// Takes a photo out of the tray; one being sent stays.
  void remove(TrayPhoto photo) {
    if (photo.state == TrayPhotoState.uploading) return;
    if (_photos.remove(photo)) _notify();
  }

  /// Empties the tray unless an upload is running.
  void clear() {
    if (_uploading || _photos.isEmpty) return;
    _photos.clear();
    _notify();
  }

  /// Sends every ready or failed photo, one after another, in tray order.
  Future<void> uploadAll() async {
    if (_uploading || preparing) return;
    final queue = [..._photos.where((photo) => photo.sendable)];
    if (queue.isEmpty) return;
    await _run(queue);
  }

  /// Sends one failed photo again.
  Future<void> retry(TrayPhoto photo) async {
    if (_uploading || photo.state != TrayPhotoState.failed) return;
    await _run([photo]);
  }

  Future<void> _run(List<TrayPhoto> queue) async {
    _uploading = true;
    _notify();
    try {
      for (final photo in queue) {
        if (_disposed) return;
        if (!_photos.contains(photo)) continue;
        await _send(photo);
      }
    } finally {
      _uploading = false;
      _notify();
    }
  }

  Future<void> _send(TrayPhoto photo) async {
    photo
      ..state = TrayPhotoState.uploading
      ..progress = 0
      ..error = null;
    _notify();
    try {
      await upload(photo.prepared!, (value) {
        photo.progress = value;
        _notify();
      });
      _photos.remove(photo);
      _uploaded++;
      _notify();
      if (!_disposed) onUploaded?.call();
    } catch (error) {
      photo
        ..state = TrayPhotoState.failed
        ..progress = 0
        ..error = describeUploadError(error);
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

Future<Uint8List> _noHeicDecoder(Uint8List bytes) async {
  throw FormatException(tr(
      'This HEIC photo could not be converted to JPEG on this device. Export it as JPEG and try again.'));
}
