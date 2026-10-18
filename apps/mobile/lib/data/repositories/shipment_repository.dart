import '../api/api_client.dart';
import '../json_read.dart';
import '../models/shipment.dart';

class ShipmentRepository {
  ShipmentRepository(this.api);

  final ApiClient api;

  Future<List<OperationalShipment>> listHub() async {
    final json = await api.getJson('/api/shipments');
    return [for (final row in requiredMapList(json, 'shipments')) OperationalShipment.fromJson(row)];
  }

  Future<List<AdminShipment>> listAdmin() async {
    final json = await api.getJson('/api/shipments');
    return [for (final row in requiredMapList(json, 'shipments')) AdminShipment.fromJson(row)];
  }

  Future<HubShipmentDetail> hubDetail(String code) async {
    final json = await api.getJson(_path(code));
    return HubShipmentDetail.fromJson(asJsonMap(json['shipment'], 'shipment'));
  }

  Future<AdminShipmentDetail> adminDetail(String code) async {
    final json = await api.getJson(_path(code));
    return AdminShipmentDetail.fromJson(asJsonMap(json['shipment'], 'shipment'));
  }

  Future<void> advance(String code) => api.postJson('${_path(code)}/advance');

  Future<void> weigh(String code, double kg) => api.postJson('${_path(code)}/weigh', body: {'kg': kg});

  Future<void> pack(String code, int count) => api.postJson('${_path(code)}/pack', body: {'count': count});

  Future<void> bookLastMile({
    required String code,
    required String courier,
    required String ref,
    required String mode,
    String? reason,
  }) {
    return api.postJson('${_path(code)}/last-mile', body: {
      'courier': courier,
      'ref': ref,
      'mode': mode,
      if (reason != null) 'reason': reason,
    });
  }

  Future<void> dispatch(String code) => api.postJson('${_path(code)}/dispatch');

  Future<void> handover(String code, String confirmation) {
    return api.postJson('${_path(code)}/handover', body: {'confirmation': confirmation});
  }

  Future<void> setException(String code, {required String type, required String reason}) {
    return api.postJson('${_path(code)}/exception', body: {'type': type, 'reason': reason});
  }

  Future<TrackingLink> shareTracking(String code, {int days = 7}) async {
    final json = await api.postJson('${_path(code)}/track-link', body: {
      'scope': 'tracking_only',
      'days': days,
    });
    return TrackingLink(url: requiredString(json, 'url'), expiresAt: requiredString(json, 'expiresAt'));
  }

  String _path(String code) => '/api/shipments/${Uri.encodeComponent(code)}';
}

class TrackingLink {
  const TrackingLink({required this.url, required this.expiresAt});

  final String url;
  final String expiresAt;
}
