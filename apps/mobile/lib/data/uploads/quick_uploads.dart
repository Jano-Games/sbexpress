import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/l10n.dart';
import '../repositories/flyer_repository.dart';
import '../repositories/media_repository.dart';
import 'flutter_heic.dart';
import 'image_prepare.dart';
import 'photo_upload.dart';
import 'picked_photo_file.dart';
import 'upload_queue.dart';

/// Picking and sending the files chosen on the quick-add forms.

/// Where a photo or document comes from.
enum FileSource { camera, gallery, pdf }

/// Picks photos with the system picker: one from the camera, any number
/// from the gallery. The picker's temp files are removed once read.
Future<List<PickedPhoto>> pickPhotos(FileSource source) async {
  final picker = ImagePicker();
  final files = source == FileSource.camera
      ? [
          if (await picker.pickImage(source: ImageSource.camera)
              case final file?)
            file
        ]
      : await picker.pickMultiImage();
  final photos = <PickedPhoto>[];
  for (final file in files) {
    try {
      photos.add(PickedPhoto(
          bytes: await file.readAsBytes(),
          name: file.name,
          mime: file.mimeType));
    } finally {
      await deletePickedPhotoFile(file.path);
    }
  }
  return photos;
}

/// One photo from the camera or gallery, or one PDF; null when cancelled.
Future<PickedPhoto?> pickDocument(FileSource source) async {
  if (source != FileSource.pdf) {
    final file = await ImagePicker().pickImage(
        source: source == FileSource.camera
            ? ImageSource.camera
            : ImageSource.gallery);
    if (file == null) return null;
    try {
      return PickedPhoto(
          bytes: await file.readAsBytes(),
          name: file.name,
          mime: file.mimeType);
    } finally {
      await deletePickedPhotoFile(file.path);
    }
  }
  final picked = await FilePicker.pickFiles(
      type: FileType.custom, allowedExtensions: const ['pdf']);
  if (picked.isEmpty) return null;
  final file = picked.single;
  return PickedPhoto(
      bytes: await file.readAsBytes(),
      name: file.name,
      mime: 'application/pdf');
}

bool isPdfFile(PickedPhoto file) =>
    file.mime == 'application/pdf' || file.name.toLowerCase().endsWith('.pdf');

/// A shipment photo; [deviceCategory] marks photos of that category's
/// devices. The photo is turned into a small JPEG once, before the first try.
UploadJob shipmentPhotoJob(
    MediaRepository media, String code, PickedPhoto photo,
    {String? deviceCategory}) {
  PreparedImage? prepared;
  return UploadJob(
      label: photo.name,
      group: deviceCategory,
      run: (progress) async {
        prepared ??= await prepareForUpload(photo.bytes,
            name: photo.name, mime: photo.mime, decodeHeic: flutterDecodeHeic);
        await media.uploadPhoto(code, prepared!, progress,
            deviceCategory: deviceCategory);
      });
}

/// A flyer document of [kind] (`student_id`, `visa`, `admission` …), sent
/// the way the flyer page sends it: PDFs as they are, photos as JPEG.
UploadJob flyerDocumentJob(
    FlyerRepository flyers, String name, String kind, PickedPhoto file) {
  PreparedImage? prepared;
  return UploadJob(
      label: file.name,
      group: kind,
      run: (progress) async {
        if (isPdfFile(file)) {
          await flyers.uploadPdf(
              name: name,
              kind: kind,
              filename: file.name,
              bytes: file.bytes,
              onProgress: progress);
          return;
        }
        prepared ??= await prepareForUpload(file.bytes,
            name: file.name, mime: file.mime, decodeHeic: flutterDecodeHeic);
        await flyers.uploadDocument(
            name: name, kind: kind, image: prepared!, onProgress: progress);
      });
}

/// Checks a picked PDF before it is queued; null when it can be sent.
String? pdfProblem(PickedPhoto file) {
  if (!isPdfFile(file)) return null;
  if (file.bytes.isEmpty) return tr('Empty files are not accepted.');
  if (file.bytes.length > imageUploadMaxBytes) {
    return tr('The PDF is over 10 MB. Choose a smaller file.');
  }
  return null;
}
