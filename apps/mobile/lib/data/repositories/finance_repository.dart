import '../api/api_client.dart';
import '../json_read.dart';
import '../models/finance_snapshot.dart';
import '../models/ledger_actions.dart';
import '../models/reconciliation.dart';
import '../money_payload.dart';

class FinanceRepository {
  FinanceRepository(this.api);

  final ApiClient api;

  Future<FinanceSnapshot> snapshot({String period = 'week'}) async {
    final json = await api.getJson('/api/finance?period=${Uri.encodeQueryComponent(period)}');
    return FinanceSnapshot.fromJson(json);
  }

  Future<List<LedgerEntry>> ledger({String period = 'all'}) async {
    final json = await api.getJson('/api/finance/ledger?period=${Uri.encodeQueryComponent(period)}&limit=50');
    return [for (final row in requiredMapList(json, 'entries')) LedgerEntry.fromJson(row)];
  }

  Future<void> transfer({
    required String from,
    required String to,
    required double amount,
    required String note,
    double? receivedAmount,
  }) {
    return api.postJson('/api/finance/transfers', idempotent: true, body: transferBody(
      from: from,
      to: to,
      amount: amount,
      note: note,
      reference: newIdempotencyKey(),
      receivedAmount: receivedAmount,
    ));
  }

  Future<void> createAccount({required String name, required String kind, required String currency, double balance = 0}) {
    return api.postJson('/api/finance/accounts', body: accountBody(name: name, kind: kind, currency: currency, balance: balance));
  }

  Future<ReconciliationReport> reconciliation() async {
    final json = await api.getJson('/api/finance/reconciliation');
    return ReconciliationReport.fromJson(json);
  }

  Future<void> recordIncome({required double amount, required String accountName, required String currency, required String note, String kind = 'income'}) {
    return api.postJson('/api/finance/incomes', idempotent: true, body: {
      ...moneyPayload(amount, currency: currency),
      'method': accountName,
      'note': note,
      'kind': kind,
    });
  }

  Future<void> recordOfficeExpense({
    required String category,
    required double amount,
    required String reason,
    required String accountName,
    required String currency,
  }) {
    return api.postJson('/api/finance/expenses', idempotent: true, body: {
      ...moneyPayload(amount, currency: currency),
      'category': category,
      'reason': reason,
      'accountName': accountName,
    });
  }

  Future<void> reverse({required String kind, required String id, required String reason}) {
    return api.postJson('/api/finance/reverse', idempotent: true, body: {'kind': kind, 'id': id, 'reason': reason});
  }
}

Map<String, Object?> accountBody({
  required String name,
  required String kind,
  required String currency,
  double balance = 0,
}) {
  return {
    'name': name.trim(),
    'kind': kind,
    'currency': currency,
    'balance': roundMoney(balance),
  };
}

Map<String, Object?> transferBody({
  required String from,
  required String to,
  required double amount,
  required String note,
  required String reference,
  double? receivedAmount,
}) {
  return {
    'from': from,
    'to': to,
    'amount': roundMoney(amount),
    'note': note.trim(),
    'reference': reference,
    if (receivedAmount != null) 'receivedAmount': roundMoney(receivedAmount),
  };
}
