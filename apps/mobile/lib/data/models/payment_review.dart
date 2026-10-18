import '../json_read.dart';

class ScreenshotMeta {
  const ScreenshotMeta({required this.reference, required this.name, required this.contentType, required this.size});

  final String reference;
  final String name;
  final String contentType;
  final int size;

  factory ScreenshotMeta.fromJson(Map<String, Object?> json) {
    return ScreenshotMeta(
      reference: requiredString(json, 'reference'),
      name: requiredString(json, 'name'),
      contentType: requiredString(json, 'contentType'),
      size: requiredInt(json, 'size'),
    );
  }
}

enum ReviewKind { shipment, statement }

class PaymentReviewItem {
  const PaymentReviewItem({
    required this.kind,
    required this.recordLabel,
    required this.supplierCode,
    required this.supplierName,
    required this.method,
    required this.amount,
    required this.sourceCurrency,
    required this.sourceAmount,
    required this.txnRef,
    required this.date,
    required this.screenshot,
    required this.approvePath,
    required this.rejectPath,
  });

  final ReviewKind kind;
  final String recordLabel;
  final String supplierCode;
  final String supplierName;
  final String method;
  final double amount;
  final String sourceCurrency;
  final double sourceAmount;
  final String txnRef;
  final String date;
  final ScreenshotMeta? screenshot;
  final String approvePath;
  final String rejectPath;

  bool get hasScreenshot => screenshot != null;

  factory PaymentReviewItem.shipment(Map<String, Object?> json) {
    final code = requiredString(json, 'code');
    return PaymentReviewItem(
      kind: ReviewKind.shipment,
      recordLabel: code,
      supplierCode: requiredString(json, 'supplierCode'),
      supplierName: requiredString(json, 'supplierName'),
      method: requiredString(json, 'method'),
      amount: requiredDouble(json, 'amount'),
      sourceCurrency: requiredString(json, 'sourceCurrency'),
      sourceAmount: requiredDouble(json, 'sourceAmount'),
      txnRef: requiredString(json, 'txnRef'),
      date: requiredString(json, 'date'),
      screenshot: _screenshot(json),
      approvePath: '/api/shipments/${Uri.encodeComponent(code)}/receipt/approve',
      rejectPath: '/api/shipments/${Uri.encodeComponent(code)}/receipt/reject',
    );
  }

  factory PaymentReviewItem.statement(Map<String, Object?> json) {
    final supplierCode = requiredString(json, 'supplierCode');
    final reference = requiredString(json, 'reference');
    return PaymentReviewItem(
      kind: ReviewKind.statement,
      recordLabel: requiredString(json, 'month'),
      supplierCode: supplierCode,
      supplierName: requiredString(json, 'supplierName'),
      method: requiredString(json, 'method'),
      amount: requiredDouble(json, 'amount'),
      sourceCurrency: requiredString(json, 'sourceCurrency'),
      sourceAmount: requiredDouble(json, 'sourceAmount'),
      txnRef: requiredString(json, 'txnRef'),
      date: requiredString(json, 'date'),
      screenshot: _screenshot(json),
      approvePath: '/api/suppliers/${Uri.encodeComponent(supplierCode)}/statement-receipts/${Uri.encodeComponent(reference)}/approve',
      rejectPath: '/api/suppliers/${Uri.encodeComponent(supplierCode)}/statement-receipts/${Uri.encodeComponent(reference)}/reject',
    );
  }
}

ScreenshotMeta? _screenshot(Map<String, Object?> json) {
  requireKey(json, 'screenshot');
  final value = json['screenshot'];
  if (value == null) return null;
  return ScreenshotMeta.fromJson(asJsonMap(value, 'screenshot'));
}

class PaymentReviewQueue {
  const PaymentReviewQueue({required this.shipments, required this.statements});

  final List<PaymentReviewItem> shipments;
  final List<PaymentReviewItem> statements;

  List<PaymentReviewItem> get all => [...shipments, ...statements];

  factory PaymentReviewQueue.fromJson(Map<String, Object?> json) {
    return PaymentReviewQueue(
      shipments: [for (final item in requiredMapList(json, 'queue')) PaymentReviewItem.shipment(item)],
      statements: [for (final item in requiredMapList(json, 'statements')) PaymentReviewItem.statement(item)],
    );
  }
}

/// Approval looks at the transfer. A missing screenshot does not block it.
bool canApprovePayment(PaymentReviewItem item) {
  switch (item.kind) {
    case ReviewKind.shipment:
    case ReviewKind.statement:
      return true;
  }
}
