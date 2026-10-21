import '../api/api_client.dart';
import '../json_read.dart';
import '../models/flight.dart';
import '../money_payload.dart';

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

  Future<void> settleTicket(String code, String accountName) {
    return api.patchJson(_path(code), body: {'accountName': accountName});
  }

  Future<void> allocateContributions(String code, List<({String name, double contribution, double legacyPaid})> rows) {
    return api.postJson('${_path(code)}/settlements', idempotent: true, body: contributionBody(rows));
  }

  Future<void> recordFlyerPayment(String code, {required double amount, required String accountName, required String currency, required String flyerName}) {
    return api.postJson('${_path(code)}/payments', idempotent: true, body: {
      ...moneyPayload(amount, currency: currency),
      'method': accountName,
      'flyerName': flyerName,
    });
  }

  String _path(String code) => '/api/flights/${Uri.encodeComponent(code)}';
}

Map<String, Object?> contributionBody(List<({String name, double contribution, double legacyPaid})> rows) {
  return {
    'allocations': [
      for (final row in rows)
        {
          'name': row.name,
          'contribution': roundMoney(row.contribution),
          'legacyPaid': roundMoney(row.legacyPaid),
        },
    ],
  };
}
