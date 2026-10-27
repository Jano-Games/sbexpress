import 'package:flutter/foundation.dart';

/// A photo or file as the picker returned it, before it is prepared.
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.name, this.mime});

  final Uint8List bytes;
  final String name;
  final String? mime;
}
