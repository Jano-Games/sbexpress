import '../json_read.dart';

/// A customer still owing money ten or more days after the parcel was
/// handed over (after delivery) or after the month ended (monthly).
class LatePayment {
  const LatePayment({
    required this.kind,
    required this.customerCode,
    required this.customerName,
    required this.amount,
    required this.days,
    this.shipmentCode,
    this.since,
    this.month,
    this.monthLabel,
  });

  /// `after_delivery` or `monthly`.
  final String kind;
  final String customerCode;
  final String customerName;
  final double amount;

  /// Whole days since the handover or since the month's last day.
  final int days;

  /// After delivery: the shipment and when it was handed over.
  final String? shipmentCode;
  final String? since;

  /// Monthly: `YYYY-MM` and the server's "September 2026".
  final String? month;
  final String? monthLabel;

  bool get monthly => kind == 'monthly';

  factory LatePayment.fromJson(Map<String, Object?> json) => LatePayment(
        kind: requiredString(json, 'kind'),
        customerCode: requiredString(json, 'customerCode'),
        customerName: requiredString(json, 'customerName'),
        amount: requiredDouble(json, 'amount'),
        days: requiredInt(json, 'days'),
        shipmentCode: _text(json['shipmentCode']),
        since: _text(json['since']),
        month: _text(json['month']),
        monthLabel: _text(json['monthLabel']),
      );
}

String? _text(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
