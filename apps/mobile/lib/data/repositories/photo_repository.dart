import '../api/api_client.dart';
import '../json_read.dart';
import '../uploads/image_prepare.dart';
import '../uploads/signed_photos.dart';
import '../uploads/upload_flow.dart';

/// Whose face a photo shows.
enum PhotoOwner {
  /// A flyer, named by their full name.
  flyer,

  /// A staff member (admin or hub manager), named by their user id.
  user,
}

/// Face photos of flyers and staff. The hub uses them to recognise who is
/// arriving and to see who received an order. Admins add and remove them;
/// the hub can only look.
class PhotoRepository {
  PhotoRepository(this.api, {SignedUrlCache? links})
      : _links = links ?? SignedUrlCache();

  final ApiClient api;
  final SignedUrlCache _links;

  /// Sends [image] as the new photo of [owner], replacing the one before.
  /// Returns the new photo's reference.
  Future<String> upload({
    required PhotoOwner type,
    required String owner,
    required PreparedImage image,
    required void Function(double progress) onProgress,
  }) {
    return transferPreparedUpload(
      file: image,
      onProgress: onProgress,
      reserve: (file) async {
        final json = await api.postJson('/api/photos/upload', body: {
          'ownerType': type.name,
          'owner': owner,
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
        await api
            .postJson('/api/photos/${Uri.encodeComponent(reference)}/complete');
      },
    );
  }

  /// Removes the photo of [owner]; they show their first letter again.
  Future<void> remove(PhotoOwner type, String owner) =>
      api.deleteJson('/api/photos/${type.name}/${Uri.encodeComponent(owner)}');

  /// A signed link to one photo, reused until shortly before it expires.
  Future<String> url(String reference) => _links.get(reference, () async {
        final json = await api
            .getJson('/api/photos/${Uri.encodeComponent(reference)}/url');
        return requiredString(json, 'url');
      });

  /// Loads face photos for one screen.
  SignedPhotoLoader loader() => SignedPhotoLoader(
      link: url, forget: _links.forget, download: api.getSignedBytes);
}
