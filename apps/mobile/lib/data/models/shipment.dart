import '../json_read.dart';

/// Keys the hub UI must not read. The branch snapshot may still send
/// `paymentTerms`, `freeOfCharge`, and `receiptStatus`; they are ignored.
const Set<String> hubOmittedKeys = {
  'charge',
  'billAmount',
  'discountAmount',
  'paidAmount',
  'dueAmount',
  'payStatus',
  'payMethod',
  'paymentTerms',
  'freeOfCharge',
  'receiptStatus',
  'chargeRate',
  'chargeCurrency',
  'rate',
  'rates',
  'pricingRates',
  'cnFare',
  'bdFare',
  'customsTax',
  'afterSalesFee',
  'profit',
  'costs',
  'invoice',
  'payments',
  'receipt',
  'receiptHistory',
  'bill',
  'supplierName',
};

class LastMileBooking {
  const LastMileBooking({
    required this.courier,
    required this.ref,
    required this.mode,
    required this.bookedAt,
    required this.dispatchedAt,
    required this.handedOverAt,
  });

  final String courier;
  final String ref;
  final String mode;
  final String? bookedAt;
  final String? dispatchedAt;
  final String? handedOverAt;

  bool get isPickup => mode == 'pickup';

  factory LastMileBooking.fromJson(Map<String, Object?> json) {
    return LastMileBooking(
      courier: requiredString(json, 'courier'),
      ref: requiredString(json, 'ref'),
      mode: requiredString(json, 'mode'),
      bookedAt: requiredNullableString(json, 'bookedAt'),
      dispatchedAt: requiredNullableString(json, 'dispatchedAt'),
      handedOverAt: requiredNullableString(json, 'handedOverAt'),
    );
  }

  static LastMileBooking? fromNullable(Object? value) {
    if (value == null) return null;
    return LastMileBooking.fromJson(asJsonMap(value, 'lastMile'));
  }
}

class ShipmentLogEntry {
  const ShipmentLogEntry({required this.actor, required this.message, required this.at});

  final String actor;
  final String message;
  final String at;

  factory ShipmentLogEntry.fromJson(Map<String, Object?> json) {
    return ShipmentLogEntry(
      actor: requiredString(json, 'actor'),
      message: requiredString(json, 'message'),
      at: requiredString(json, 'at'),
    );
  }
}

class DeviceUnit {
  const DeviceUnit({required this.model, required this.serial, required this.serialPhotoRef});

  final String model;
  final String serial;
  final String? serialPhotoRef;

  bool get hasPhoto => serialPhotoRef != null && serialPhotoRef!.isNotEmpty;

  factory DeviceUnit.fromJson(Map<String, Object?> json) {
    return DeviceUnit(
      model: json.containsKey('model') ? asString(json['model'], 'model') : '',
      serial: json.containsKey('serial') ? asString(json['serial'], 'serial') : '',
      serialPhotoRef: json.containsKey('serialPhotoRef') ? asNullableString(json['serialPhotoRef'], 'serialPhotoRef') : null,
    );
  }

  Map<String, Object?> toDisplayMap() => {
        'model': model,
        'serial': serial,
        'hasPhoto': hasPhoto,
      };
}

class HubDeviceLine {
  const HubDeviceLine({required this.category, required this.count, required this.units});

  final String category;
  final int count;
  final List<DeviceUnit> units;

  factory HubDeviceLine.fromJson(Map<String, Object?> json) {
    final units = json.containsKey('units') ? asMapList(json['units'], 'units') : const <Map<String, Object?>>[];
    return HubDeviceLine(
      category: json.containsKey('category') ? asString(json['category'], 'category') : '',
      count: json.containsKey('count') ? asInt(json['count'], 'count') : 0,
      units: [for (final unit in units) DeviceUnit.fromJson(unit)],
    );
  }

  Map<String, Object?> toDisplayMap() => {
        'category': category,
        'count': count,
        'units': [for (final unit in units) unit.toDisplayMap()],
      };
}

class AdminDeviceLine {
  const AdminDeviceLine({
    required this.category,
    required this.count,
    required this.rate,
    required this.currency,
    required this.units,
  });

  final String category;
  final int count;
  final double rate;
  final String currency;
  final List<DeviceUnit> units;

  factory AdminDeviceLine.fromJson(Map<String, Object?> json) {
    final units = json.containsKey('units') ? asMapList(json['units'], 'units') : const <Map<String, Object?>>[];
    return AdminDeviceLine(
      category: json.containsKey('category') ? asString(json['category'], 'category') : '',
      count: json.containsKey('count') ? asInt(json['count'], 'count') : 0,
      rate: json.containsKey('rate') ? asDouble(json['rate'], 'rate') : 0,
      currency: json.containsKey('currency') ? asString(json['currency'], 'currency') : 'BDT',
      units: [for (final unit in units) DeviceUnit.fromJson(unit)],
    );
  }
}

/// Operational shipment fields. No money and no Low-2 payment keys.
class OperationalShipment {
  const OperationalShipment({
    required this.code,
    required this.supplierCode,
    required this.flightCode,
    required this.flightDate,
    required this.bookedKg,
    required this.weighedKg,
    required this.effectiveKg,
    required this.weightDelta,
    required this.description,
    required this.categories,
    required this.status,
    required this.statusIndex,
    required this.statusLabel,
    required this.exception,
    required this.exceptionReason,
    required this.date,
  });

  final String code;
  final String supplierCode;
  final String? flightCode;
  final String? flightDate;
  final double bookedKg;
  final double? weighedKg;
  final double effectiveKg;
  final double? weightDelta;
  final String description;
  final List<String> categories;
  final String status;
  final int statusIndex;
  final String statusLabel;
  final String? exception;
  final String exceptionReason;
  final String date;

  factory OperationalShipment.fromJson(Map<String, Object?> json) {
    return OperationalShipment(
      code: requiredString(json, 'code'),
      supplierCode: requiredString(json, 'supplierCode'),
      flightCode: requiredNullableString(json, 'flightCode'),
      flightDate: requiredNullableString(json, 'flightDate'),
      bookedKg: requiredDouble(json, 'bookedKg'),
      weighedKg: requiredNullableDouble(json, 'weighedKg'),
      effectiveKg: requiredDouble(json, 'effectiveKg'),
      weightDelta: requiredNullableDouble(json, 'weightDelta'),
      description: requiredString(json, 'description'),
      categories: requiredStringList(json, 'categories'),
      status: requiredString(json, 'status'),
      statusIndex: requiredInt(json, 'statusIndex'),
      statusLabel: requiredString(json, 'statusLabel'),
      exception: requiredNullableString(json, 'exception'),
      exceptionReason: json.containsKey('exceptionReason') ? asString(json['exceptionReason'], 'exceptionReason') : '',
      date: requiredString(json, 'date'),
    );
  }

  Map<String, Object?> toDisplayMap() => {
        'code': code,
        'supplierCode': supplierCode,
        'flightCode': flightCode,
        'flightDate': flightDate,
        'bookedKg': bookedKg,
        'weighedKg': weighedKg,
        'effectiveKg': effectiveKg,
        'weightDelta': weightDelta,
        'description': description,
        'categories': categories,
        'status': status,
        'statusIndex': statusIndex,
        'statusLabel': statusLabel,
        'exception': exception,
        'exceptionReason': exceptionReason,
        'date': date,
      };
}

class HubShipmentDetail extends OperationalShipment {
  const HubShipmentDetail({
    required super.code,
    required super.supplierCode,
    required super.flightCode,
    required super.flightDate,
    required super.bookedKg,
    required super.weighedKg,
    required super.effectiveKg,
    required super.weightDelta,
    required super.description,
    required super.categories,
    required super.status,
    required super.statusIndex,
    required super.statusLabel,
    required super.exception,
    required super.exceptionReason,
    required super.date,
    required this.packageCount,
    required this.packedAt,
    required this.photosCount,
    required this.hasVideo,
    required this.serials,
    required this.devices,
    required this.lastMile,
    required this.flyerName,
    required this.log,
  });

  final int packageCount;
  final String? packedAt;
  final int photosCount;
  final bool hasVideo;
  final List<String> serials;
  final List<HubDeviceLine> devices;
  final LastMileBooking? lastMile;
  final String? flyerName;
  final List<ShipmentLogEntry> log;

  int get deviceCount => devices.fold(0, (sum, line) => sum + line.count);

  int get devicePhotoCount => devices.fold(0, (sum, line) => sum + line.units.where((unit) => unit.hasPhoto).length);

  bool get hasCourierRef => lastMile != null && lastMile!.ref.trim().isNotEmpty;

  factory HubShipmentDetail.fromJson(Map<String, Object?> json) {
    final base = OperationalShipment.fromJson(json);
    return HubShipmentDetail(
      code: base.code,
      supplierCode: base.supplierCode,
      flightCode: base.flightCode,
      flightDate: base.flightDate,
      bookedKg: base.bookedKg,
      weighedKg: base.weighedKg,
      effectiveKg: base.effectiveKg,
      weightDelta: base.weightDelta,
      description: base.description,
      categories: base.categories,
      status: base.status,
      statusIndex: base.statusIndex,
      statusLabel: base.statusLabel,
      exception: base.exception,
      exceptionReason: base.exceptionReason,
      date: base.date,
      packageCount: requiredInt(json, 'packageCount'),
      packedAt: requiredNullableString(json, 'packedAt'),
      photosCount: requiredInt(json, 'photosCount'),
      hasVideo: requiredBool(json, 'hasVideo'),
      serials: requiredStringList(json, 'serials'),
      devices: [for (final item in requiredMapList(json, 'pcsItems')) HubDeviceLine.fromJson(item)],
      lastMile: LastMileBooking.fromNullable(json.containsKey('lastMile') ? json['lastMile'] : throw const FormatException('Missing lastMile')),
      flyerName: requiredNullableString(json, 'flyerName'),
      log: [for (final item in requiredMapList(json, 'log')) ShipmentLogEntry.fromJson(item)],
    );
  }

  @override
  Map<String, Object?> toDisplayMap() => {
        ...super.toDisplayMap(),
        'packageCount': packageCount,
        'packedAt': packedAt,
        'photosCount': photosCount,
        'hasVideo': hasVideo,
        'deviceCount': deviceCount,
        'devicePhotoCount': devicePhotoCount,
        'courierRef': lastMile?.ref,
        'courierName': lastMile?.courier,
        'deliveryMode': lastMile?.mode,
        'flyerName': flyerName,
        'devices': [for (final line in devices) line.toDisplayMap()],
      };
}

class InvoiceSnapshot {
  const InvoiceSnapshot({
    required this.state,
    required this.needsReview,
    required this.number,
    required this.total,
    required this.discount,
    required this.issuedAt,
  });

  final String state;
  final bool needsReview;
  final String number;
  final double total;
  final double discount;
  final String issuedAt;

  factory InvoiceSnapshot.fromJson(Map<String, Object?> json) {
    return InvoiceSnapshot(
      state: requiredString(json, 'state'),
      needsReview: requiredBool(json, 'needsReview'),
      number: requiredString(json, 'number'),
      total: requiredDouble(json, 'total'),
      discount: requiredDouble(json, 'discount'),
      issuedAt: requiredString(json, 'issuedAt'),
    );
  }
}

class AdminPayment {
  const AdminPayment({required this.method, required this.amount, required this.at, required this.reference});

  final String method;
  final double amount;
  final String at;
  final String reference;

  factory AdminPayment.fromJson(Map<String, Object?> json) {
    return AdminPayment(
      method: requiredString(json, 'method'),
      amount: requiredDouble(json, 'amount'),
      at: requiredString(json, 'at'),
      reference: json.containsKey('reference') ? asString(json['reference'], 'reference') : '',
    );
  }
}

class AdminShipment extends OperationalShipment {
  const AdminShipment({
    required super.code,
    required super.supplierCode,
    required super.flightCode,
    required super.flightDate,
    required super.bookedKg,
    required super.weighedKg,
    required super.effectiveKg,
    required super.weightDelta,
    required super.description,
    required super.categories,
    required super.status,
    required super.statusIndex,
    required super.statusLabel,
    required super.exception,
    required super.exceptionReason,
    required super.date,
    required this.supplierName,
    required this.charge,
    required this.billAmount,
    required this.discountAmount,
    required this.paidAmount,
    required this.dueAmount,
    required this.payStatus,
    required this.payMethod,
    required this.paymentTerms,
    required this.freeOfCharge,
    required this.receiptStatus,
  });

  final String? supplierName;
  final double charge;
  final double billAmount;
  final double discountAmount;
  final double paidAmount;
  final double dueAmount;
  final String payStatus;
  final String? payMethod;
  final String paymentTerms;
  final bool freeOfCharge;
  final String? receiptStatus;

  factory AdminShipment.fromJson(Map<String, Object?> json) {
    final base = OperationalShipment.fromJson(json);
    return AdminShipment(
      code: base.code,
      supplierCode: base.supplierCode,
      flightCode: base.flightCode,
      flightDate: base.flightDate,
      bookedKg: base.bookedKg,
      weighedKg: base.weighedKg,
      effectiveKg: base.effectiveKg,
      weightDelta: base.weightDelta,
      description: base.description,
      categories: base.categories,
      status: base.status,
      statusIndex: base.statusIndex,
      statusLabel: base.statusLabel,
      exception: base.exception,
      exceptionReason: base.exceptionReason,
      date: base.date,
      supplierName: requiredNullableString(json, 'supplierName'),
      charge: requiredDouble(json, 'charge'),
      billAmount: requiredDouble(json, 'billAmount'),
      discountAmount: requiredDouble(json, 'discountAmount'),
      paidAmount: requiredDouble(json, 'paidAmount'),
      dueAmount: requiredDouble(json, 'dueAmount'),
      payStatus: requiredString(json, 'payStatus'),
      payMethod: requiredNullableString(json, 'payMethod'),
      paymentTerms: requiredString(json, 'paymentTerms'),
      freeOfCharge: requiredBool(json, 'freeOfCharge'),
      receiptStatus: requiredNullableString(json, 'receiptStatus'),
    );
  }
}

class AdminShipmentDetail extends AdminShipment {
  const AdminShipmentDetail({
    required super.code,
    required super.supplierCode,
    required super.flightCode,
    required super.flightDate,
    required super.bookedKg,
    required super.weighedKg,
    required super.effectiveKg,
    required super.weightDelta,
    required super.description,
    required super.categories,
    required super.status,
    required super.statusIndex,
    required super.statusLabel,
    required super.exception,
    required super.exceptionReason,
    required super.date,
    required super.supplierName,
    required super.charge,
    required super.billAmount,
    required super.discountAmount,
    required super.paidAmount,
    required super.dueAmount,
    required super.payStatus,
    required super.payMethod,
    required super.paymentTerms,
    required super.freeOfCharge,
    required super.receiptStatus,
    required this.chargeRate,
    required this.chargeCurrency,
    required this.packageCount,
    required this.packedAt,
    required this.photosCount,
    required this.hasVideo,
    required this.devices,
    required this.lastMile,
    required this.flyerName,
    required this.log,
    required this.invoice,
    required this.payments,
  });

  final double chargeRate;
  final String chargeCurrency;
  final int packageCount;
  final String? packedAt;
  final int photosCount;
  final bool hasVideo;
  final List<AdminDeviceLine> devices;
  final LastMileBooking? lastMile;
  final String? flyerName;
  final List<ShipmentLogEntry> log;
  final InvoiceSnapshot? invoice;
  final List<AdminPayment> payments;

  factory AdminShipmentDetail.fromJson(Map<String, Object?> json) {
    final row = AdminShipment.fromJson(json);
    final invoiceValue = json.containsKey('invoice') ? json['invoice'] : throw const FormatException('Missing invoice');
    return AdminShipmentDetail(
      code: row.code,
      supplierCode: row.supplierCode,
      flightCode: row.flightCode,
      flightDate: row.flightDate,
      bookedKg: row.bookedKg,
      weighedKg: row.weighedKg,
      effectiveKg: row.effectiveKg,
      weightDelta: row.weightDelta,
      description: row.description,
      categories: row.categories,
      status: row.status,
      statusIndex: row.statusIndex,
      statusLabel: row.statusLabel,
      exception: row.exception,
      exceptionReason: row.exceptionReason,
      date: row.date,
      supplierName: row.supplierName,
      charge: row.charge,
      billAmount: row.billAmount,
      discountAmount: row.discountAmount,
      paidAmount: row.paidAmount,
      dueAmount: row.dueAmount,
      payStatus: row.payStatus,
      payMethod: row.payMethod,
      paymentTerms: row.paymentTerms,
      freeOfCharge: row.freeOfCharge,
      receiptStatus: row.receiptStatus,
      chargeRate: requiredDouble(json, 'chargeRate'),
      chargeCurrency: requiredString(json, 'chargeCurrency'),
      packageCount: requiredInt(json, 'packageCount'),
      packedAt: requiredNullableString(json, 'packedAt'),
      photosCount: requiredInt(json, 'photosCount'),
      hasVideo: requiredBool(json, 'hasVideo'),
      devices: [for (final item in requiredMapList(json, 'pcsItems')) AdminDeviceLine.fromJson(item)],
      lastMile: LastMileBooking.fromNullable(json.containsKey('lastMile') ? json['lastMile'] : throw const FormatException('Missing lastMile')),
      flyerName: requiredNullableString(json, 'flyerName'),
      log: [for (final item in requiredMapList(json, 'log')) ShipmentLogEntry.fromJson(item)],
      invoice: invoiceValue == null ? null : InvoiceSnapshot.fromJson(asJsonMap(invoiceValue, 'invoice')),
      payments: [for (final item in requiredMapList(json, 'payments')) AdminPayment.fromJson(item)],
    );
  }
}

String banglaStatus(String status, String apiLabel) {
  switch (status) {
    case 'pending':
      return 'অপেক্ষমাণ';
    case 'received_cn_hub':
      return 'চায়না হাবে এসেছে';
    case 'ready_for_shipment':
      return 'পাঠানোর জন্য প্রস্তুত';
    case 'in_transit':
      return 'পথে আছে';
    case 'customs_cleared':
      return 'কাস্টমস ক্লিয়ার';
    case 'received_bd_hub':
      return 'ঢাকা হাবে';
    case 'ready_for_last_mile':
      return 'লাস্ট মাইলের জন্য প্রস্তুত';
    case 'out_for_delivery':
      return 'ডেলিভারিতে বেরিয়েছে';
    case 'delivered':
      return 'ডেলিভারি হয়েছে';
    default:
      return apiLabel;
  }
}

String formatKg(double value) => '${value.toStringAsFixed(1)} kg';

String? formatWeightDelta(double? delta) {
  if (delta == null) return null;
  final sign = delta > 0 ? '+' : '';
  return 'Δ $sign${delta.toStringAsFixed(1)} kg';
}
