import '../json_read.dart';
import 'shipment.dart';

class CustomerSummary {
  const CustomerSummary({
    required this.code,
    required this.name,
    required this.phone,
    required this.address,
    required this.terms,
    required this.orderCount,
    required this.deliveredCount,
    required this.shippedKg,
    required this.billed,
    required this.paid,
    required this.balance,
    required this.creditBalance,
    required this.pricingPending,
    required this.discountTotal,
    this.archivedAt,
  });

  final String code;
  final String name;
  final String phone;
  final String address;
  final String terms;
  final int orderCount;
  final int deliveredCount;
  final double shippedKg;
  final double billed;
  final double paid;
  final double balance;
  final double creditBalance;
  final int pricingPending;
  final double discountTotal;

  /// When the customer was archived; null while active and on an older
  /// server, which does not send it.
  final String? archivedAt;

  bool get archived => archivedAt != null;

  factory CustomerSummary.fromJson(Map<String, Object?> json) {
    return CustomerSummary(
      code: requiredString(json, 'code'),
      name: requiredString(json, 'name'),
      phone: requiredString(json, 'phone'),
      address: requiredString(json, 'address'),
      terms: requiredString(json, 'terms'),
      orderCount: requiredInt(json, 'orderCount'),
      deliveredCount: requiredInt(json, 'deliveredCount'),
      shippedKg: requiredDouble(json, 'shippedKg'),
      billed: requiredDouble(json, 'billed'),
      paid: requiredDouble(json, 'paid'),
      balance: requiredDouble(json, 'balance'),
      creditBalance: requiredDouble(json, 'creditBalance'),
      pricingPending: requiredInt(json, 'pricingPending'),
      discountTotal: requiredDouble(json, 'discountTotal'),
      archivedAt: optionalString(json, 'archivedAt'),
    );
  }
}

class CustomerPayment {
  const CustomerPayment(
      {required this.code,
      required this.method,
      required this.amount,
      required this.at});

  final String code;
  final String method;
  final double amount;
  final String at;

  factory CustomerPayment.fromJson(Map<String, Object?> json) {
    return CustomerPayment(
      code: requiredString(json, 'code'),
      method: requiredString(json, 'method'),
      amount: requiredDouble(json, 'amount'),
      at: requiredString(json, 'at'),
    );
  }
}

class CustomerInvoice {
  const CustomerInvoice({
    required this.number,
    required this.shipmentCode,
    required this.total,
    required this.discount,
    required this.issuedAt,
  });

  final String number;
  final String shipmentCode;
  final double total;
  final double discount;
  final String issuedAt;

  factory CustomerInvoice.fromJson(Map<String, Object?> json) {
    return CustomerInvoice(
      number: requiredString(json, 'number'),
      shipmentCode: requiredString(json, 'shipmentCode'),
      total: requiredDouble(json, 'total'),
      discount: requiredDouble(json, 'discount'),
      issuedAt: requiredString(json, 'issuedAt'),
    );
  }
}

class CustomerDetail extends CustomerSummary {
  const CustomerDetail({
    required super.code,
    required super.name,
    required super.phone,
    required super.address,
    required super.terms,
    required super.orderCount,
    required super.deliveredCount,
    required super.shippedKg,
    required super.billed,
    required super.paid,
    required super.balance,
    required super.creditBalance,
    required super.pricingPending,
    required super.discountTotal,
    super.archivedAt,
    required this.orders,
    required this.payments,
    required this.invoices,
  });

  final List<AdminShipment> orders;
  final List<CustomerPayment> payments;
  final List<CustomerInvoice> invoices;

  factory CustomerDetail.fromJson(Map<String, Object?> json) {
    final base = CustomerSummary.fromJson(json);
    return CustomerDetail(
      code: base.code,
      name: base.name,
      phone: base.phone,
      address: base.address,
      terms: base.terms,
      orderCount: base.orderCount,
      deliveredCount: base.deliveredCount,
      shippedKg: base.shippedKg,
      billed: base.billed,
      paid: base.paid,
      balance: base.balance,
      creditBalance: base.creditBalance,
      pricingPending: base.pricingPending,
      discountTotal: base.discountTotal,
      archivedAt: base.archivedAt,
      orders: [
        for (final row in requiredMapList(json, 'orders'))
          AdminShipment.fromJson(row)
      ],
      payments: [
        for (final row in requiredMapList(json, 'payments'))
          CustomerPayment.fromJson(row)
      ],
      invoices: [
        for (final row in requiredMapList(json, 'invoices'))
          CustomerInvoice.fromJson(row)
      ],
    );
  }
}

class CustomerDraft {
  const CustomerDraft(
      {required this.name,
      this.phone,
      this.address,
      required this.terms,
      this.code});

  final String name;
  final String? phone;
  final String? address;
  final String terms;

  /// A code the operator typed; null lets the server pick the next free one.
  final String? code;

  Map<String, Object?> toJson() {
    final body = <String, Object?>{'name': name, 'terms': terms};
    final codeText = code?.trim() ?? '';
    if (codeText.isNotEmpty) body['code'] = codeText;
    final phoneText = phone?.trim() ?? '';
    final addressText = address?.trim() ?? '';
    if (phoneText.isNotEmpty) body['phone'] = phoneText;
    if (addressText.isNotEmpty) body['address'] = addressText;
    return body;
  }
}
