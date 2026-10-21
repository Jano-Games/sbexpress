import 'dart:typed_data';

import '../api/api_client.dart';
import '../json_read.dart';
import '../models/flyer.dart';
import '../uploads/image_prepare.dart';
import '../uploads/upload_flow.dart';

class FlyerRepository {
  FlyerRepository(this.api);

  final ApiClient api;

  Future<List<FlyerSummary>> list({bool includeArchived = false}) async {
    final path = includeArchived ? '/api/flyers?includeArchived=1' : '/api/flyers';
    final json = await api.getJson(path);
    return [for (final row in requiredMapList(json, 'flyers')) FlyerSummary.fromJson(row)];
  }

  Future<FlyerDetail> detail(String name) async {
    final json = await api.getJson(_path(name));
    return FlyerDetail.fromJson(asJsonMap(json['flyer'], 'flyer'));
  }

  Future<String> create(FlyerDraft draft) async {
    final json = await api.postJson('/api/flyers', body: draft.toJson());
    return requiredString(json, 'name');
  }

  Future<void> archive(String name, {required bool archived}) async {
    await api.postJson('${_path(name)}/archive', body: {'archived': archived});
  }

  Future<FlyerDocumentList> documents(String name) async {
    final json = await api.getJson('${_path(name)}/documents');
    return FlyerDocumentList.fromJson(json);
  }

  Future<String> documentUrl(String name, String reference) async {
    final json = await api.getJson('${_path(name)}/documents/${Uri.encodeComponent(reference)}/url');
    return requiredString(json, 'url');
  }

  Future<String> uploadPdf({
    required String name,
    required String kind,
    required String filename,
    required Uint8List bytes,
    required void Function(double progress) onProgress,
  }) {
    if (bytes.isEmpty) throw const FormatException('খালি ফাইল নেওয়া যায় না।');
    if (bytes.length > imageUploadMaxBytes) throw const FormatException('PDF ১০ MB-এর বেশি। আরও ছোট ফাইল দিন।');
    final safe = filename.toLowerCase().endsWith('.pdf') ? filename : '$filename.pdf';
    final file = PreparedImage(bytes: bytes, filename: safe, contentType: 'application/pdf');
    return transferPreparedUpload(
      file: file,
      onProgress: onProgress,
      reserve: (file) async {
        final json = await api.postJson('${_path(name)}/documents/upload', body: {
          'kind': kind,
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
      put: (reservation, file, progress) => api.putBytes(reservation.uploadUrl, file.bytes, file.contentType, progress),
      complete: (reference) async {
        await api.postJson('${_path(name)}/documents/${Uri.encodeComponent(reference)}/complete');
      },
    );
  }

  Future<void> setVerified(String name, String reference, {required bool verified}) async {
    await api.patchJson('${_path(name)}/documents/${Uri.encodeComponent(reference)}/verification', body: {'verified': verified});
  }

  Future<String> uploadDocument({
    required String name,
    required String kind,
    required PreparedImage image,
    required void Function(double progress) onProgress,
  }) {
    return transferPreparedUpload(
      file: image,
      onProgress: onProgress,
      reserve: (file) async {
        final json = await api.postJson('${_path(name)}/documents/upload', body: {
          'kind': kind,
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
      put: (reservation, file, progress) => api.putBytes(reservation.uploadUrl, file.bytes, file.contentType, progress),
      complete: (reference) async {
        await api.postJson('${_path(name)}/documents/${Uri.encodeComponent(reference)}/complete');
      },
    );
  }

  String _path(String name) => '/api/flyers/${Uri.encodeComponent(name)}';
}
