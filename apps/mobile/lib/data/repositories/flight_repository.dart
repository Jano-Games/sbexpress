import '../api/api_client.dart';
import '../json_read.dart';
import '../models/flight.dart';

class FlightRepository {
  FlightRepository(this.api);

  final ApiClient api;

  Future<List<FlightSummary>> list() async {
    final json = await api.getJson('/api/flights');
    return [for (final row in requiredMapList(json, 'flights')) FlightSummary.fromJson(row)];
  }

  Future<FlightDetail> detail(String code) async {
    final json = await api.getJson(_path(code));
    return FlightDetail.fromJson(asJsonMap(json['flight'], 'flight'));
  }

  Future<String> create(FlightDraft draft) async {
    final json = await api.postJson('/api/flights', body: draft.toJson());
    return requiredString(json, 'code');
  }

  Future<void> assignFlyer(String code, String name) async {
    await api.postJson('${_path(code)}/flyers', body: {'name': name});
  }

  String _path(String code) => '/api/flights/${Uri.encodeComponent(code)}';
}
