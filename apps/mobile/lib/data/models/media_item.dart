import '../json_read.dart';

class MediaItem {
  const MediaItem({
    required this.reference,
    required this.name,
    required this.contentType,
    required this.size,
    required this.shared,
    this.deviceCategory,
  });

  final String reference;
  final String name;
  final String contentType;
  final int size;
  final bool shared;

  /// "Mobile", "Laptop" … for photos of a category's devices; null for
  /// parcel photos and on servers that do not send it.
  final String? deviceCategory;

  bool get isImage => contentType.startsWith('image/');

  factory MediaItem.fromJson(Map<String, Object?> json) {
    return MediaItem(
      reference: requiredString(json, 'reference'),
      name: requiredString(json, 'name'),
      contentType: requiredString(json, 'contentType'),
      size: requiredInt(json, 'size'),
      shared: requiredBool(json, 'shared'),
      deviceCategory: json['deviceCategory'] is String
          ? json['deviceCategory']! as String
          : null,
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
      media: [
        for (final item in requiredMapList(json, 'media'))
          MediaItem.fromJson(item)
      ],
    );
  }
}
