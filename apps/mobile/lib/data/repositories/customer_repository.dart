import '../api/api_client.dart';
import '../json_read.dart';
import '../models/customer.dart';
import '../models/customer_activity.dart';
import '../models/ledger_actions.dart';
import '../money_payload.dart';
import 'shipment_repository.dart';

class CustomerRepository {
  CustomerRepository(this.api);

  final ApiClient api;

  Future<List<CustomerSummary>> list() async {
    final json = await api.getJson('/api/suppliers');
    return [
      for (final row in requiredMapList(json, 'suppliers'))
        CustomerSummary.fromJson(row)
    ];
  }

  Future<CustomerDetail> detail(String code) async {
    final json = await api.getJson(_path(code));
    return CustomerDetail.fromJson(asJsonMap(json['supplier'], 'supplier'));
  }

  /// The code the next new customer gets. Older servers answer 404.
  Future<String> nextCode() async {
    final json = await api.getJson('/api/suppliers/next-code');
    return requiredString(json, 'code');
  }

  Future<String> create(CustomerDraft draft) async {
    final json = await api.postJson('/api/suppliers', body: draft.toJson());
    return requiredString(json, 'code');
  }

  Future<({List<StatementLinkInfo> links, StatementBalance balance})>
      statementLinks(String code, String month) async {
    final json = await api.getJson(
        '${_path(code)}/statement-links?month=${Uri.encodeQueryComponent(month)}');
    return (
      links: [
        for (final row in requiredMapList(json, 'links'))
          StatementLinkInfo.fromJson(row)
      ],
      balance: StatementBalance.fromJson(asJsonMap(json['balance'], 'balance')),
    );
  }

  Future<TrackingLink> createStatementLink(String code,
      {required String month, required int days, double? amount}) async {
    final json = await api.postJson('${_path(code)}/statement-link', body: {
      'month': month,
      'days': days,
      if (amount != null) 'amount': roundMoney(amount),
    });
    return TrackingLink(
        url: requiredString(json, 'url'),
        expiresAt: requiredString(json, 'expiresAt'));
  }

  Future<void> revokeStatementLinks(String code) async {
    await api.deleteJson('${_path(code)}/statement-link');
  }

  Future<List<StatementReceiptInfo>> statementReceipts(String code) async {
    final json = await api.getJson('${_path(code)}/statement-receipts');
    return [
      for (final row in requiredMapList(json, 'receipts'))
        StatementReceiptInfo.fromJson(row)
    ];
  }

  Future<void> approveStatementReceipt(String code, String reference) {
    return api.postJson(
        '${_path(code)}/statement-receipts/${Uri.encodeComponent(reference)}/approve',
        idempotent: true);
  }

  Future<void> rejectStatementReceipt(
      String code, String reference, String reason) {
    return api.postJson(
        '${_path(code)}/statement-receipts/${Uri.encodeComponent(reference)}/reject',
        body: {'reason': reason});
  }

  Future<CustomerActivityPage> activity(String code, {int page = 1}) async {
    final json = await api.getJson('${_path(code)}/activity?page=$page');
    return CustomerActivityPage.fromJson(json);
  }

  Future<double> creditBalance(String code) async {
    final json = await api.getJson('${_path(code)}/credits');
    return CustomerCreditBook.fromJson(json).balance;
  }

  Future<void> applyCredit(String code,
      {required String shipmentCode, required double amount}) {
    return api.postJson('${_path(code)}/apply-credit', idempotent: true, body: {
      'shipmentCode': shipmentCode,
      'amount': roundMoney(amount),
    });
  }

  Future<void> refundCredit(String code,
      {required double amount,
      required String accountName,
      required String currency,
      required String reason}) {
    return api.postJson('${_path(code)}/refunds', idempotent: true, body: {
      ...moneyPayload(amount, currency: currency),
      'accountName': accountName,
      'reason': reason,
    });
  }

  String _path(String code) => '/api/suppliers/${Uri.encodeComponent(code)}';
}
