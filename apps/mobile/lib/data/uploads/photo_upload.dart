import 'package:flutter/foundation.dart';

import '../../l10n/l10n.dart';
import 'image_prepare.dart';
import 'upload_flow.dart';

class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.name, this.mime});

  final Uint8List bytes;
  final String name;
  final String? mime;
}

class PhotoUploadController extends ChangeNotifier {
  PhotoUploadController({
    required this.upload,
    Future<Uint8List> Function(Uint8List heic)? decodeHeic,
  }) : _decodeHeic = decodeHeic ?? _missingHeicDecoder;

  final Future<void> Function(
      PreparedImage image, void Function(double progress) onProgress) upload;
  final Future<Uint8List> Function(Uint8List heic) _decodeHeic;

  PickedPhoto? original;
  PreparedImage? prepared;
  double progress = 0;
  String? error;
  bool busy = false;
  bool done = false;

  Future<void> select(PickedPhoto photo) async {
    original = photo;
    prepared = null;
    done = false;
    error = null;
    progress = 0;
    notifyListeners();
    await _prepareAndUpload();
  }

  Future<void> retry() async {
    final photo = original;
    if (photo == null || busy) return;
    error = null;
    done = false;
    notifyListeners();
    if (prepared != null) {
      await _uploadPrepared();
      return;
    }
    await _prepareAndUpload();
  }

  Future<void> _prepareAndUpload() async {
    final photo = original;
    if (photo == null) return;
    busy = true;
    notifyListeners();
    try {
      prepared = await prepareForUpload(photo.bytes,
          name: photo.name, mime: photo.mime, decodeHeic: _decodeHeic);
      error = null;
    } catch (error) {
      this.error = describeUploadError(error);
      busy = false;
      notifyListeners();
      return;
    }
    await _uploadPrepared();
  }

  Future<void> _uploadPrepared() async {
    final image = prepared;
    if (image == null) return;
    busy = true;
    progress = 0;
    notifyListeners();
    try {
      await upload(image, (value) {
        progress = value;
        notifyListeners();
      });
      done = true;
      error = null;
      progress = 1;
    } catch (error) {
      this.error = describeUploadError(error);
      done = false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

Future<Uint8List> _missingHeicDecoder(Uint8List bytes) async {
  throw FormatException(tr(
      'This HEIC photo could not be converted to JPEG on this device. Export it as JPEG and try again.'));
}
