import '../json_read.dart';

class ReconciliationAccount {
  const ReconciliationAccount({
    required this.name,
    required this.currency,
    required this.balance,
    required this.recordedNetMovement,
    required this.impliedOpeningBalance,
  });

  final String name;
  final String currency;
  final double balance;
  final double recordedNetMovement;
  final double impliedOpeningBalance;

  factory ReconciliationAccount.fromJson(Map<String, Object?> json) {
    return ReconciliationAccount(
      name: requiredString(json, 'name'),
      currency: requiredString(json, 'currency'),
      balance: requiredDouble(json, 'balance'),
      recordedNetMovement: requiredDouble(json, 'recordedNetMovement'),
      impliedOpeningBalance: requiredDouble(json, 'impliedOpeningBalance'),
    );
  }
}

class MissingPosting {
  const MissingPosting({required this.kind, required this.reference, required this.amount});

  final String kind;
  final String reference;
  final double amount;

  factory MissingPosting.fromJson(Map<String, Object?> json) {
    return MissingPosting(
      kind: requiredString(json, 'kind'),
      reference: requiredString(json, 'reference'),
      amount: requiredDouble(json, 'amount'),
    );
  }
}

class ShipmentDifference {
  const ShipmentDifference({
    required this.code,
    required this.allocatedPaid,
    required this.ledgerPaid,
    required this.difference,
  });

  final String code;
  final double allocatedPaid;
  final double ledgerPaid;
  final double difference;

  factory ShipmentDifference.fromJson(Map<String, Object?> json) {
    return ShipmentDifference(
      code: requiredString(json, 'code'),
      allocatedPaid: requiredDouble(json, 'allocatedPaid'),
      ledgerPaid: requiredDouble(json, 'ledgerPaid'),
      difference: requiredDouble(json, 'difference'),
    );
  }
}

class ReconciliationReport {
  const ReconciliationReport({
    required this.accounts,
    required this.missingPostings,
    required this.shipmentDifferences,
    required this.note,
  });

  final List<ReconciliationAccount> accounts;
  final List<MissingPosting> missingPostings;
  final List<ShipmentDifference> shipmentDifferences;
  final String note;

  factory ReconciliationReport.fromJson(Map<String, Object?> json) {
    return ReconciliationReport(
      accounts: [for (final row in requiredMapList(json, 'accounts')) ReconciliationAccount.fromJson(row)],
      missingPostings: [for (final row in requiredMapList(json, 'missingPostings')) MissingPosting.fromJson(row)],
      shipmentDifferences: [for (final row in requiredMapList(json, 'shipmentDifferences')) ShipmentDifference.fromJson(row)],
      note: requiredString(json, 'note'),
    );
  }
}
