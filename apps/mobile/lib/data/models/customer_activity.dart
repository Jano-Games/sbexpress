import '../json_read.dart';

class CustomerActivityEntry {
  const CustomerActivityEntry({
    required this.id,
    required this.label,
    required this.kind,
    required this.amount,
    required this.sourceCurrency,
    required this.sourceAmount,
    required this.sourceFxRate,
    required this.at,
    required this.reference,
    required this.shipmentCode,
    required this.accountName,
    required this.reason,
    required this.canReverse,
    required this.reversalKind,
  });

  final String id;
  final String label;
  final String kind;
  final double amount;
  final String sourceCurrency;
  final double sourceAmount;
  final double sourceFxRate;
  final String at;
  final String reference;
  final String? shipmentCode;
  final String? accountName;
  final String reason;
  final bool canReverse;
  final String reversalKind;

  factory CustomerActivityEntry.fromJson(Map<String, Object?> json) {
    return CustomerActivityEntry(
      id: requiredString(json, 'id'),
      label: requiredString(json, 'label'),
      kind: requiredString(json, 'kind'),
      amount: requiredDouble(json, 'amount'),
      sourceCurrency: requiredString(json, 'sourceCurrency'),
      sourceAmount: requiredDouble(json, 'sourceAmount'),
      sourceFxRate: requiredDouble(json, 'sourceFxRate'),
      at: requiredString(json, 'at'),
      reference: requiredString(json, 'reference'),
      shipmentCode: requiredNullableString(json, 'shipmentCode'),
      accountName: requiredNullableString(json, 'accountName'),
      reason: requiredString(json, 'reason'),
      canReverse: requiredBool(json, 'canReverse'),
      reversalKind: requiredString(json, 'reversalKind'),
    );
  }
}

class CustomerActivityPage {
  const CustomerActivityPage({
    required this.entries,
    required this.page,
    required this.total,
    required this.limit,
  });

  final List<CustomerActivityEntry> entries;
  final int page;
  final int total;
  final int limit;

  factory CustomerActivityPage.fromJson(Map<String, Object?> json) {
    return CustomerActivityPage(
      entries: [for (final row in requiredMapList(json, 'entries')) CustomerActivityEntry.fromJson(row)],
      page: requiredInt(json, 'page'),
      total: requiredInt(json, 'total'),
      limit: requiredInt(json, 'limit'),
    );
  }
}

String activityLabel(String label) {
  switch (label) {
    case 'Payment':
      return 'পেমেন্ট';
    case 'Customer advance':
      return 'অগ্রিম';
    case 'Refund':
      return 'রিফান্ড';
    case 'Credit applied':
      return 'ক্রেডিট প্রয়োগ';
    case 'Credit adjustment':
      return 'ক্রেডিট সমন্বয়';
    default:
      return label;
  }
}
