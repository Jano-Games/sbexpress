import '../api/api_client.dart';
import '../json_read.dart';
import '../models/media_item.dart';
import '../uploads/image_prepare.dart';
import '../uploads/upload_flow.dart';

class MediaRepository {
  MediaRepository(this.api);

  final ApiClient api;

  Future<ShipmentMediaList> list(String code) async {
    final json = await api.getJson('${_path(code)}/media');
    return ShipmentMediaList.fromJson(json);
  }

  /// [deviceCategory] ("Mobile", "Laptop" …) marks a photo of that
  /// category's devices; null is a parcel photo. Older servers ignore it.
  Future<String> uploadPhoto(
    String code,
    PreparedImage image,
    void Function(double progress) onProgress, {
    String? deviceCategory,
  }) {
    return transferPreparedUpload(
      file: image,
      onProgress: onProgress,
      reserve: (file) async {
        final json = await api.postJson('${_path(code)}/media/upload', body: {
          'name': file.filename,
          'contentType': file.contentType,
          'size': file.size,
          if (deviceCategory != null && deviceCategory.trim().isNotEmpty)
            'deviceCategory': deviceCategory.trim(),
        });
        return UploadReservation(
          reference: requiredString(json, 'reference'),
          uploadUrl: requiredString(json, 'uploadUrl'),
          expiresAt: requiredString(json, 'expiresAt'),
        );
      },
      put: (reservation, file, progress) {
        return api.putBytes(
            reservation.uploadUrl, file.bytes, file.contentType, progress);
      },
      complete: (reference) async {
        await api.postJson(
            '${_path(code)}/media/${Uri.encodeComponent(reference)}/complete');
      },
    );
  }

  Future<void> setShared(String code, String reference,
      {required bool shared}) {
    return api.patchJson(
        '${_path(code)}/media/${Uri.encodeComponent(reference)}',
        body: {'shared': shared});
  }

  /// Private IMEI photo. It is never marked shared with the customer.
  Future<String> uploadDevicePhoto({
    required String code,
    required int itemIndex,
    required int unitIndex,
    required PreparedImage image,
    required void Function(double progress) onProgress,
  }) {
    return transferPreparedUpload(
      file: image,
      onProgress: onProgress,
      reserve: (file) async {
        final json = await api.postJson('${_path(code)}/device-photo', body: {
          'itemIndex': itemIndex,
          'unitIndex': unitIndex,
          'name': file.filename,
          'contentType': file.contentType,
          'size': file.size,
        });
        return UploadReservation(
          reference: requiredString(json, 'reference'),
          uploadUrl: requiredString(json, 'uploadUrl'),
          expiresAt: requiredString(json, 'expiresAt'),
        );
      },
      put: (reservation, file, progress) => api.putBytes(
          reservation.uploadUrl, file.bytes, file.contentType, progress),
      complete: (reference) async {
        await api.postJson(
            '${_path(code)}/device-photo/${Uri.encodeComponent(reference)}/complete');
      },
    );
  }

  String _path(String code) => '/api/shipments/${Uri.encodeComponent(code)}';
}
