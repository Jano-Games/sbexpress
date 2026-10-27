import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../uploads/photo_upload.dart';
import 'mrz.dart';

/// Reads all the text on the photo at [imagePath], on the device.
typedef ReadText = Future<String> Function(String imagePath);

/// Reads the name lines of a picked passport or visa photo; null when they
/// cannot be read. Tests replace it.
typedef ScanTravelDocument = Future<MrzReading?> Function(PickedPhoto photo);

/// Google ML Kit's Latin text recognizer. The model ships inside the app, so
/// it works offline and the photo never leaves the phone for the reading.
Future<String> readTextOnDevice(String imagePath) async {
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result =
        await recognizer.processImage(InputImage.fromFilePath(imagePath));
    return result.text;
  } finally {
    await recognizer.close();
  }
}

/// Reads the MRZ of [photo] with [readText]. The reader needs a file while
/// the picker hands over bytes (and has deleted its own copy), so the photo
/// is written to a private temp folder and deleted again right after.
/// Only the reading is returned; the text itself is not kept.
Future<MrzReading?> scanTravelDocument(PickedPhoto photo,
    {ReadText readText = readTextOnDevice}) async {
  final folder = await Directory.systemTemp.createTemp('sbx-scan-');
  try {
    final file = File('${folder.path}${Platform.pathSeparator}'
        'scan${_extension(photo.name)}');
    await file.writeAsBytes(photo.bytes, flush: true);
    return readMrz(await readText(file.path));
  } finally {
    try {
      await folder.delete(recursive: true);
    } on FileSystemException {
      // The system clears its temp folder; the scan result is unaffected.
    }
  }
}

String _extension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return '.jpg';
  final ext = name.substring(dot).toLowerCase();
  return RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(ext) ? ext : '.jpg';
}
