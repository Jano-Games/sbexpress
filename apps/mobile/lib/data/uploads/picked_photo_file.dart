import 'dart:io';

/// Removes the picker temp file, which still has the camera EXIF.
///
/// The prepared JPEG is already in memory. Failure to delete does not fail the upload.
Future<void> deletePickedPhotoFile(String? path) async {
  if (path == null || path.isEmpty) return;
  final file = File(path);
  try {
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    return;
  }
}
