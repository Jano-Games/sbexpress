import 'dart:convert';

import '../api/api_client.dart';
import '../json_read.dart';
import '../models/flight.dart';
import '../models/hub_flight.dart';
import '../models/ticket_import.dart';
import '../money_payload.dart';

class FlightRepository {
  FlightRepository(this.api);

  final ApiClient api;

  Future<List<FlightSummary>> list() async {
    final json = await api.getJson('/api/flights');
    return [
      for (final row in requiredMapList(json, 'flights'))
        FlightSummary.fromJson(row)
    ];
  }

  Future<FlightDetail> detail(String code) async {
    final json = await api.getJson(_path(code));
    return FlightDetail.fromJson(asJsonMap(json['flight'], 'flight'));
  }

  /// Reads an e-ticket PDF into flight drafts; the file is not stored.
  Future<TicketImport> readTicket(List<int> pdfBytes) async {
    final json = await api.postJson('/api/flights/ticket',
        body: {'file': base64Encode(pdfBytes)});
    return TicketImport.fromJson(json);
  }

  Future<String> createFromTicket(TicketFlightDraft draft, String flyer) async {
    final json = await api.postJson('/api/flights', body: draft.toJson(flyer));
    return requiredString(json, 'code');
  }

  /// Hub-safe schedule: no fare, ticket cost or booking revenue.
  Future<HubFlightSchedule> hubSchedule() async {
    final json = await api.getJson('/api/flights/hub');
    return HubFlightSchedule.fromJson(json);
  }

  Future<HubFlightDetail> hubDetail(String code) async {
    final json =
        await api.getJson('/api/flights/hub/${Uri.encodeComponent(code)}');
    return HubFlightDetail.fromJson(asJsonMap(json['flight'], 'flight'));
  }

  Future<String> create(FlightDraft draft) async {
    final json = await api.postJson('/api/flights', body: draft.toJson());
    return requiredString(json, 'code');
  }

  Future<void> assignFlyer(String code, String name) async {
    await api.postJson('${_path(code)}/flyers', body: {'name': name});
  }

  /// Saves the ticket cost and our share of it. Moves no money.
  Future<void> updateTicket(String code,
      {required double actualCost, required double agencyShare}) {
    return api.patchJson(_path(code), body: {
      'actualCost': roundMoney(actualCost),
      'agencyShare': roundMoney(agencyShare),
    });
  }

  Future<void> removeFlyer(String code, String name) async {
    await api.deleteJson('${_path(code)}/flyers/${Uri.encodeComponent(name)}');
  }

  Future<void> settleTicket(String code, String accountName) {
    return api.patchJson(_path(code), body: {'accountName': accountName});
  }

  Future<void> allocateContributions(String code,
      List<({String name, double contribution, double legacyPaid})> rows) {
    return api.postJson('${_path(code)}/settlements',
        idempotent: true, body: contributionBody(rows));
  }

  Future<void> recordFlyerPayment(String code,
      {required double amount,
      required String accountName,
      required String currency,
      required String flyerName}) {
    return api.postJson('${_path(code)}/payments', idempotent: true, body: {
      ...moneyPayload(amount, currency: currency),
      'method': accountName,
      'flyerName': flyerName,
    });
  }

  String _path(String code) => '/api/flights/${Uri.encodeComponent(code)}';
}

Map<String, Object?> contributionBody(
    List<({String name, double contribution, double legacyPaid})> rows) {
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
