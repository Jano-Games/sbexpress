import '../../l10n/l10n.dart';
import '../api/api_client.dart';
import '../models/ledger_actions.dart';
import '../json_read.dart';
import '../models/shipment.dart';
import '../models/workspace.dart';
import '../money_payload.dart';

class ShipmentRepository {
  ShipmentRepository(this.api);

  final ApiClient api;

  Future<List<OperationalShipment>> listHub() async {
    final json = await api.getJson('/api/shipments');
    return [
      for (final row in requiredMapList(json, 'shipments'))
        OperationalShipment.fromJson(row)
    ];
  }

  Future<List<AdminShipment>> listAdmin() async {
    final json = await api.getJson('/api/shipments');
    return [
      for (final row in requiredMapList(json, 'shipments'))
        AdminShipment.fromJson(row)
    ];
  }

  Future<HubShipmentDetail> hubDetail(String code) async {
    final json = await api.getJson(_path(code));
    return HubShipmentDetail.fromJson(asJsonMap(json['shipment'], 'shipment'));
  }

  Future<AdminShipmentDetail> adminDetail(String code) async {
    final json = await api.getJson(_path(code));
    return AdminShipmentDetail.fromJson(
        asJsonMap(json['shipment'], 'shipment'));
  }

  /// Refused with a 400 once the shipment has an invoice, payments, costs,
  /// receipts or credit.
  Future<void> delete(String code) async {
    await api.deleteJson(_path(code));
  }

  Future<void> advance(String code) => api.postJson('${_path(code)}/advance');

  Future<void> weigh(String code, double kg) =>
      api.postJson('${_path(code)}/weigh', body: {'kg': kg});

  Future<void> pack(String code, int count) =>
      api.postJson('${_path(code)}/pack', body: {'count': count});

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
    return api.postJson('${_path(code)}/handover',
        body: {'confirmation': confirmation});
  }

  Future<void> setException(String code,
      {required String type, required String reason}) {
    return api.postJson('${_path(code)}/exception',
        body: {'type': type, 'reason': reason});
  }

  Future<String> create(IntakeDraft draft) async {
    final json = await api.postJson('/api/shipments', body: draft.toJson());
    return requiredString(json, 'code');
  }

  Future<InvoiceDocument> invoice(String code) async {
    final json = await api.getJson('${_path(code)}/invoice');
    return InvoiceDocument.fromJson(json);
  }

  Future<String> issueInvoice(
    String code,
    InvoiceDocument document, {
    String? revisionReason,
    bool confirmFree = false,
    String state = 'issued',
    String? pricingMode,
  }) async {
    final json = await api.postJson(
      '${_path(code)}/invoice',
      body: invoiceIssueBody(document,
          revisionReason: revisionReason,
          confirmFree: confirmFree,
          state: state,
          pricingMode: pricingMode),
      idempotent: true,
    );
    return requiredString(json, 'number');
  }

  /// Records money already received into a real ledger account. The amount and
  /// account name are chosen by the operator; nothing is filled in for them.
  Future<void> recordPayment(String code,
      {required double amount,
      required String accountName,
      String currency = 'BDT'}) {
    return api.postJson('${_path(code)}/payments', idempotent: true, body: {
      ...moneyPayload(amount, currency: currency),
      'method': accountName,
    });
  }

  Future<List<int>> invoicePdf(String code) {
    return api.getBytes('${_path(code)}/invoice.pdf');
  }

  Future<List<CreditNoteRecord>> creditNotes(String code) async {
    final json = await api.getJson('${_path(code)}/invoice-history');
    return [
      for (final row in requiredMapList(json, 'creditNotes'))
        CreditNoteRecord.fromJson(row)
    ];
  }

  Future<void> createCreditNote(String code,
      {required double amount, required String reason}) {
    return api.postJson('${_path(code)}/after-sales',
        idempotent: true,
        body: {'amount': roundMoney(amount), 'reason': reason});
  }

  Future<ShipmentCostSheet> costSheet(String code) async {
    final json = await api.getJson(_path(code));
    final shipment = asJsonMap(json['shipment'], 'shipment');
    return ShipmentCostSheet.fromJson(asJsonMap(shipment['costs'], 'costs'));
  }

  Future<void> recordCost(String code, Map<String, Object?> body) {
    return api.postJson('${_path(code)}/expenses',
        idempotent: true, body: body);
  }

  Future<void> voidCost(String code, String costId, String reason) {
    return api.postJson(
        '${_path(code)}/costs/${Uri.encodeComponent(costId)}/void',
        idempotent: true,
        body: {'reason': reason});
  }

  Future<TrackingLink> shareTracking(String code,
      {int days = 7, String scope = 'tracking_only'}) async {
    final json = await api.postJson('${_path(code)}/track-link', body: {
      'scope': scope,
      'days': days,
    });
    return TrackingLink(
        url: requiredString(json, 'url'),
        expiresAt: requiredString(json, 'expiresAt'));
  }

  /// Customer links made for this shipment, newest first.
  Future<List<SavedTrackLink>> trackLinks(String code) async {
    final json = await api.getJson('${_path(code)}/track-links');
    return [
      for (final row in requiredMapList(json, 'links'))
        SavedTrackLink.fromJson(row)
    ];
  }

  /// Turns off every customer link of this shipment.
  Future<void> revokeTracking(String code) async {
    await api.deleteJson('${_path(code)}/track-link');
  }

  String _path(String code) => '/api/shipments/${Uri.encodeComponent(code)}';
}

class TrackingLink {
  const TrackingLink({required this.url, required this.expiresAt});

  final String url;
  final String expiresAt;
}

/// A saved customer link: `active`, `expired` or `revoked`. [url] is null
/// for a link made before links could be shown again.
class SavedTrackLink {
  const SavedTrackLink(
      {required this.id,
      required this.url,
      required this.status,
      required this.expiresAt,
      required this.includesInvoice});

  final String id;
  final String? url;
  final String status;
  final String expiresAt;

  /// Shows the bill and payments as well as tracking.
  final bool includesInvoice;

  bool get active => status == 'active';

  factory SavedTrackLink.fromJson(Map<String, Object?> json) => SavedTrackLink(
      id: requiredString(json, 'id'),
      url: optionalString(json, 'url'),
      status: requiredString(json, 'status'),
      expiresAt: requiredString(json, 'expiresAt'),
      includesInvoice: json['includesInvoice'] == true);
}

/// The newest active link that can be shown, or null.
SavedTrackLink? newestActiveLink(List<SavedTrackLink> links) {
  for (final link in links) {
    if (link.active && link.url != null && link.url!.isNotEmpty) return link;
  }
  return null;
}

/// Shipment cost post. Settling an existing row always pays now from an account.
Map<String, Object?> shipmentExpenseBody({
  required String category,
  required double amount,
  required String currency,
  required String reason,
  String? label,
  String? accountName,
  String paymentTiming = 'now',
  String? costId,
  String? costField,
}) {
  if (paymentTiming == 'later' && (costId != null || costField != null)) {
    throw FormatException(tr('Choose an account to settle a due cost.'));
  }
  if (paymentTiming == 'now' &&
      (accountName == null || accountName.trim().isEmpty)) {
    throw FormatException(tr('Choose the account the money will come from.'));
  }
  return {
    'category': category,
    ...moneyPayload(amount, currency: currency),
    'reason': reason.trim(),
    if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
    if (paymentTiming == 'now') 'accountName': accountName!.trim(),
    'paymentTiming': paymentTiming == 'later' ? 'later' : 'now',
    if (costId != null) 'costId': costId,
    if (costField != null) 'costField': costField,
  };
}
