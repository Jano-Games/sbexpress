import 'dart:convert';

import '../api/api_client.dart';
import '../api/api_exception.dart';
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

  /// Refused with a 400 while the flight has bookings, a ticket cost or
  /// payments.
  Future<void> delete(String code) async {
    await api.deleteJson(_path(code));
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

  /// Records what each flyer has paid, one payment at a time, after the
  /// flight's ticket and split are saved. The amounts are BDT. Returns the
  /// payments that were not recorded with the reason; [onProgress] gets how
  /// many are done. A signed-out session stops at once.
  Future<List<({FlyerPaid row, String reason})>> recordFlyerPayments(
      String code, List<FlyerPaid> rows,
      {required String accountName,
      void Function(int done)? onProgress}) async {
    final failed = <({FlyerPaid row, String reason})>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      try {
        await recordFlyerPayment(code,
            amount: row.amount,
            accountName: accountName,
            currency: 'BDT',
            flyerName: row.name);
      } on ApiException catch (error) {
        if (error.status == 401) rethrow;
        failed.add((row: row, reason: error.message));
      } catch (error) {
        failed.add((row: row, reason: error.toString()));
      }
      onProgress?.call(i + 1);
    }
    return failed;
  }

  /// Adds a cost for the whole flight. Exactly one of [accountName] (paid
  /// now, money leaves it) or [payLater] (saved unpaid). An older server
  /// answers 404.
  Future<FlightCost> addCost(String code,
      {required String category,
      String? label,
      required double amount,
      String? accountName,
      bool payLater = false}) async {
    final json = await api.postJson('${_path(code)}/costs',
        idempotent: true,
        body: flightCostBody(
            category: category,
            label: label,
            amount: amount,
            accountName: accountName,
            payLater: payLater));
    final cost = json['cost'];
    return FlightCost.fromJson(asJsonMap(cost, 'cost'));
  }

  /// Pays a flight cost saved as pay later from [accountName]. An older
  /// server answers 404.
  Future<void> payCost(String code, String id,
      {required String accountName}) async {
    await api.postJson('${_path(code)}/costs/${Uri.encodeComponent(id)}/pay',
        idempotent: true, body: {'accountName': accountName.trim()});
  }

  /// Reverses a flight cost; posted money is never hard-deleted.
  Future<void> removeCost(String code, String id) async {
    await api.deleteJson('${_path(code)}/costs/${Uri.encodeComponent(id)}');
  }

  String _path(String code) => '/api/flights/${Uri.encodeComponent(code)}';
}

/// `POST /flights/:code/costs`. Paid now names the account; pay later sends
/// `payLater: true` and no account.
Map<String, Object?> flightCostBody(
    {required String category,
    String? label,
    required double amount,
    String? accountName,
    bool payLater = false}) {
  final name = label?.trim() ?? '';
  final account = accountName?.trim() ?? '';
  if (!payLater && account.isEmpty) {
    throw const FormatException('Choose the paying account');
  }
  return {
    'category': flightCostCategories.contains(category) ? category : 'others',
    if (name.isNotEmpty)
      'label': name.length > 60 ? name.substring(0, 60) : name,
    'amount': roundMoney(amount),
    if (payLater) 'payLater': true else 'accountName': account,
  };
}

/// One flyer's money toward their part of the ticket, in BDT.
typedef FlyerPaid = ({String name, double amount});

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
