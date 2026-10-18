import '../json_read.dart';

class MediaItem {
  const MediaItem({
    required this.reference,
    required this.name,
    required this.contentType,
    required this.size,
    required this.shared,
  });

  final String reference;
  final String name;
  final String contentType;
  final int size;
  final bool shared;

  bool get isImage => contentType.startsWith('image/');

  factory MediaItem.fromJson(Map<String, Object?> json) {
    return MediaItem(
      reference: requiredString(json, 'reference'),
      name: requiredString(json, 'name'),
      contentType: requiredString(json, 'contentType'),
      size: requiredInt(json, 'size'),
      shared: requiredBool(json, 'shared'),
    );
  }
}

class ShipmentMediaList {
  const ShipmentMediaList({required this.configured, required this.media});

  final bool configured;
  final List<MediaItem> media;

  factory ShipmentMediaList.fromJson(Map<String, Object?> json) {
    return ShipmentMediaList(
      configured: requiredBool(json, 'configured'),
      media: [for (final item in requiredMapList(json, 'media')) MediaItem.fromJson(item)],
    );
  }
}
