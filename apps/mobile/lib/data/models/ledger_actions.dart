import '../../l10n/l10n.dart';
import '../json_read.dart';

class ShipmentCostItem {
  const ShipmentCostItem({
    required this.id,
    required this.name,
    required this.category,
    required this.amount,
    required this.paidAmount,
    required this.dueAmount,
    required this.costField,
    required this.voidedAt,
  });

  final String id;
  final String name;
  final String category;
  final double amount;
  final double paidAmount;
  final double dueAmount;
  final String? costField;
  final String? voidedAt;

  bool get voided => voidedAt != null;
  bool get legacyField =>
      costField == 'cnFare' ||
      costField == 'bdFare' ||
      costField == 'customsTax';

  factory ShipmentCostItem.fromJson(Map<String, Object?> json) {
    return ShipmentCostItem(
      id: requiredString(json, 'id'),
      name: requiredString(json, 'name'),
      category: requiredString(json, 'category'),
      amount: requiredDouble(json, 'amount'),
      paidAmount: requiredDouble(json, 'paidAmount'),
      dueAmount: requiredDouble(json, 'dueAmount'),
      costField: json.containsKey('costField')
          ? requiredNullableString(json, 'costField')
          : null,
      voidedAt: json.containsKey('voidedAt')
          ? requiredNullableString(json, 'voidedAt')
          : null,
    );
  }
}

class ShipmentCostSheet {
  const ShipmentCostSheet(
      {required this.items, required this.total, required this.unpaid});

  final List<ShipmentCostItem> items;
  final double total;
  final Map<String, double> unpaid;

  factory ShipmentCostSheet.fromJson(Map<String, Object?> json) {
    final unpaidRaw = asJsonMap(json['unpaidCosts'], 'unpaidCosts');
    return ShipmentCostSheet(
      items: [
        for (final row in requiredMapList(json, 'items'))
          ShipmentCostItem.fromJson(row)
      ],
      total: requiredDouble(json, 'total'),
      unpaid: {
        for (final entry in unpaidRaw.entries)
          entry.key: asDouble(entry.value, entry.key)
      },
    );
  }
}

class CreditNoteRecord {
  const CreditNoteRecord({
    required this.number,
    required this.amount,
    required this.reason,
    required this.previousTotal,
    required this.revisedTotal,
    required this.at,
  });

  final String number;
  final double amount;
  final String reason;
  final double previousTotal;
  final double revisedTotal;
  final String at;

  factory CreditNoteRecord.fromJson(Map<String, Object?> json) {
    return CreditNoteRecord(
      number: requiredString(json, 'number'),
      amount: requiredDouble(json, 'amount'),
      reason: requiredString(json, 'reason'),
      previousTotal: requiredDouble(json, 'previousTotal'),
      revisedTotal: requiredDouble(json, 'revisedTotal'),
      at: requiredString(json, 'at'),
    );
  }
}

class StatementLinkInfo {
  const StatementLinkInfo(
      {required this.id,
      required this.url,
      required this.status,
      required this.expiresAt});

  final String id;
  final String? url;
  final String status;
  final String expiresAt;

  factory StatementLinkInfo.fromJson(Map<String, Object?> json) {
    return StatementLinkInfo(
      id: requiredString(json, 'id'),
      url: requiredNullableString(json, 'url'),
      status: requiredString(json, 'status'),
      expiresAt: requiredString(json, 'expiresAt'),
    );
  }
}

class StatementBalance {
  const StatementBalance(
      {required this.billed, required this.paid, required this.due});

  final double billed;
  final double paid;
  final double due;

  factory StatementBalance.fromJson(Map<String, Object?> json) {
    return StatementBalance(
      billed: requiredDouble(json, 'billed'),
      paid: requiredDouble(json, 'paid'),
      due: requiredDouble(json, 'due'),
    );
  }
}

class StatementReceiptInfo {
  const StatementReceiptInfo({
    required this.reference,
    required this.amount,
    required this.method,
    required this.status,
    required this.reason,
    required this.month,
  });

  final String reference;
  final double amount;
  final String method;
  final String status;
  final String reason;
  final String month;

  factory StatementReceiptInfo.fromJson(Map<String, Object?> json) {
    return StatementReceiptInfo(
      reference: requiredString(json, 'reference'),
      amount: requiredDouble(json, 'amount'),
      method: requiredString(json, 'method'),
      status: requiredString(json, 'status'),
      reason: json['reason'] == null ? '' : requiredString(json, 'reason'),
      month: requiredString(json, 'month'),
    );
  }
}

class CustomerCreditBook {
  const CustomerCreditBook({required this.balance});

  final double balance;

  factory CustomerCreditBook.fromJson(Map<String, Object?> json) {
    return CustomerCreditBook(balance: requiredDouble(json, 'balance'));
  }
}

class LedgerEntry {
  const LedgerEntry({
    required this.recordId,
    required this.reversalKind,
    required this.canReverse,
    required this.description,
    required this.account,
    required this.currency,
    required this.amount,
    required this.at,
  });

  final String recordId;
  final String reversalKind;
  final bool canReverse;
  final String description;
  final String? account;
  final String currency;
  final double amount;
  final String at;

  factory LedgerEntry.fromJson(Map<String, Object?> json) {
    return LedgerEntry(
      recordId: requiredString(json, 'recordId'),
      reversalKind: requiredString(json, 'reversalKind'),
      canReverse: requiredBool(json, 'canReverse'),
      description: requiredString(json, 'description'),
      account: requiredNullableString(json, 'account'),
      currency: requiredString(json, 'currency'),
      amount: requiredDouble(json, 'amount'),
      at: requiredString(json, 'at'),
    );
  }
}

Map<String, String> get costCategories => <String, String>{
      'ticket': tr('Ticket'),
      'packaging': tr('Packaging'),
      'courier': tr('Courier'),
      'salary': tr('Service'),
      'transport': tr('Transport'),
      'customs': tr('Customs'),
      'others': tr('Other'),
    };
