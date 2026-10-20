import '../json_read.dart';
import 'shipment.dart';

class NextFlightCard {
  const NextFlightCard({required this.code, required this.date, required this.bookedKg, required this.spaceKg});

  final String code;
  final String date;
  final double bookedKg;
  final double spaceKg;

  factory NextFlightCard.fromJson(Map<String, Object?> json) {
    return NextFlightCard(
      code: requiredString(json, 'code'),
      date: requiredString(json, 'date'),
      bookedKg: requiredDouble(json, 'bookedKg'),
      spaceKg: requiredDouble(json, 'spaceKg'),
    );
  }
}

class OverviewFlight {
  const OverviewFlight({
    required this.code,
    required this.date,
    required this.flyers,
    required this.bookedKg,
    required this.spaceKg,
    required this.status,
    required this.shipmentCount,
  });

  final String code;
  final String date;
  final List<String> flyers;
  final double bookedKg;
  final double spaceKg;
  final String status;
  final int shipmentCount;

  factory OverviewFlight.fromJson(Map<String, Object?> json) {
    return OverviewFlight(
      code: requiredString(json, 'code'),
      date: requiredString(json, 'date'),
      flyers: requiredStringList(json, 'flyers'),
      bookedKg: requiredDouble(json, 'bookedKg'),
      spaceKg: requiredDouble(json, 'spaceKg'),
      status: requiredString(json, 'status'),
      shipmentCount: requiredInt(json, 'shipmentCount'),
    );
  }
}

class OverviewNotice {
  const OverviewNotice({required this.tag, required this.text});

  final String tag;
  final String text;

  factory OverviewNotice.fromJson(Map<String, Object?> json) {
    return OverviewNotice(tag: requiredString(json, 'tag'), text: requiredString(json, 'text'));
  }
}

class AdminOverview {
  const AdminOverview({
    required this.weekLabel,
    required this.todayLabel,
    required this.rate,
    required this.cashBdt,
    required this.cashCny,
    required this.cashWorth,
    required this.received,
    required this.expenses,
    required this.net,
    required this.profit,
    required this.unpaid,
    required this.reviewCount,
    required this.openTodoCount,
    required this.nextFlight,
    required this.notices,
    required this.flights,
    required this.activeShipmentCount,
    required this.activeShipments,
  });

  final String weekLabel;
  final String todayLabel;
  final double rate;
  final double cashBdt;
  final double cashCny;
  final double cashWorth;
  final double received;
  final double expenses;
  final double net;
  final double profit;
  final double unpaid;
  final int reviewCount;
  final int openTodoCount;
  final NextFlightCard? nextFlight;
  final List<OverviewNotice> notices;
  final List<OverviewFlight> flights;
  final int activeShipmentCount;
  final List<AdminShipment> activeShipments;

  factory AdminOverview.fromJson(Map<String, Object?> json) {
    final cash = asJsonMap(json['cash'], 'cash');
    final next = json['nextFlight'];
    return AdminOverview(
      weekLabel: requiredString(json, 'weekLabel'),
      todayLabel: requiredString(json, 'todayLabel'),
      rate: requiredDouble(json, 'rate'),
      cashBdt: requiredDouble(cash, 'bdt'),
      cashCny: requiredDouble(cash, 'cny'),
      cashWorth: requiredDouble(cash, 'worth'),
      received: requiredDouble(json, 'received'),
      expenses: requiredDouble(json, 'expenses'),
      net: requiredDouble(json, 'net'),
      profit: requiredDouble(json, 'profit'),
      unpaid: requiredDouble(json, 'unpaid'),
      reviewCount: requiredInt(json, 'reviewCount'),
      openTodoCount: requiredInt(json, 'openTodoCount'),
      nextFlight: next == null ? null : NextFlightCard.fromJson(asJsonMap(next, 'nextFlight')),
      notices: [for (final row in requiredMapList(json, 'notices')) OverviewNotice.fromJson(row)],
      flights: [for (final row in requiredMapList(json, 'flights')) OverviewFlight.fromJson(row)],
      activeShipmentCount: requiredInt(json, 'activeShipmentCount'),
      activeShipments: [for (final row in requiredMapList(json, 'activeShipments')) AdminShipment.fromJson(row)],
    );
  }
}

class SetupStatus {
  const SetupStatus({
    required this.rateConfirmed,
    required this.accounts,
    required this.paymentMethods,
    required this.users,
    required this.storageConfigured,
    required this.cleanupEnabled,
    required this.lastCleanupAt,
  });

  final bool rateConfirmed;
  final int accounts;
  final int paymentMethods;
  final int users;
  final bool storageConfigured;
  final bool cleanupEnabled;
  final String? lastCleanupAt;

  factory SetupStatus.fromJson(Map<String, Object?> json) {
    return SetupStatus(
      rateConfirmed: requiredBool(json, 'rateConfirmed'),
      accounts: requiredInt(json, 'accounts'),
      paymentMethods: requiredInt(json, 'paymentMethods'),
      users: requiredInt(json, 'users'),
      storageConfigured: requiredBool(json, 'storageConfigured'),
      cleanupEnabled: requiredBool(json, 'cleanupEnabled'),
      lastCleanupAt: requiredNullableString(json, 'lastCleanupAt'),
    );
  }
}

class SettingsSnapshot {
  const SettingsSnapshot({required this.rate, required this.threshold, required this.pcsRates});

  final double rate;
  final double threshold;
  final Map<String, double> pcsRates;

  factory SettingsSnapshot.fromJson(Map<String, Object?> json) {
    final rates = asJsonMap(json['pcsRates'], 'pcsRates');
    final parsed = <String, double>{};
    for (final entry in rates.entries) {
      parsed[entry.key] = asDouble(entry.value, entry.key);
    }
    return SettingsSnapshot(
      rate: requiredDouble(json, 'rate'),
      threshold: requiredDouble(json, 'threshold'),
      pcsRates: parsed,
    );
  }
}

class PayMethodInfo {
  const PayMethodInfo({
    required this.id,
    required this.kind,
    required this.provider,
    required this.label,
    required this.number,
    required this.bankName,
    required this.accountName,
    required this.enabled,
    required this.currency,
  });

  final String id;
  final String kind;
  final String provider;
  final String label;
  final String number;
  final String bankName;
  final String accountName;
  final bool enabled;
  final String currency;

  String get title {
    if (kind == 'bank_account') {
      final bank = bankName.trim().isEmpty ? 'Bank' : bankName;
      final holder = accountName.trim();
      return holder.isEmpty ? bank : '$bank · $holder';
    }
    final name = label.trim().isEmpty ? provider : '$provider · $label';
    return name;
  }

  String get detail => kind == 'bank_account' ? accountName : number;

  factory PayMethodInfo.fromJson(Map<String, Object?> json) {
    return PayMethodInfo(
      id: requiredString(json, 'id'),
      kind: requiredString(json, 'kind'),
      provider: requiredString(json, 'provider'),
      label: requiredString(json, 'label'),
      number: requiredString(json, 'number'),
      bankName: requiredString(json, 'bankName'),
      accountName: requiredString(json, 'accountName'),
      enabled: requiredBool(json, 'enabled'),
      currency: requiredString(json, 'currency'),
    );
  }
}

class StaffAccount {
  const StaffAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final bool active;

  factory StaffAccount.fromJson(Map<String, Object?> json) {
    return StaffAccount(
      id: requiredString(json, 'id'),
      name: requiredString(json, 'name'),
      email: requiredString(json, 'email'),
      role: requiredString(json, 'role'),
      active: requiredBool(json, 'active'),
    );
  }
}

class InvoiceLine {
  const InvoiceLine({required this.label, required this.amount});

  final String label;
  final double amount;

  Map<String, Object?> toJson() => {'label': label, 'amount': amount};

  factory InvoiceLine.fromJson(Map<String, Object?> json) {
    return InvoiceLine(label: requiredString(json, 'label'), amount: requiredDouble(json, 'amount'));
  }
}

class InvoiceDocument {
  const InvoiceDocument({
    required this.saved,
    required this.state,
    required this.needsReview,
    required this.pricingMode,
    required this.number,
    required this.lines,
    required this.discount,
    required this.note,
    required this.total,
    required this.paidAmount,
    required this.dueAmount,
  });

  final bool saved;
  final String state;
  final bool needsReview;
  final String pricingMode;
  final String number;
  final List<InvoiceLine> lines;
  final double discount;
  final String note;
  final double total;
  final double paidAmount;
  final double dueAmount;

  bool get issued => saved && state == 'issued' && !needsReview;

  factory InvoiceDocument.fromJson(Map<String, Object?> json) {
    final invoice = asJsonMap(json['invoice'], 'invoice');
    final lines = requiredMapList(invoice, 'lines');
    return InvoiceDocument(
      saved: requiredBool(json, 'saved'),
      state: requiredString(invoice, 'state'),
      needsReview: requiredBool(invoice, 'needsReview'),
      pricingMode: requiredString(invoice, 'pricingMode'),
      number: requiredString(invoice, 'number'),
      lines: [for (final row in lines) InvoiceLine.fromJson(row)],
      discount: requiredDouble(invoice, 'discount'),
      note: requiredString(invoice, 'note'),
      total: requiredDouble(invoice, 'total'),
      paidAmount: requiredDouble(invoice, 'paidAmount'),
      dueAmount: requiredDouble(invoice, 'dueAmount'),
    );
  }
}

/// Issues the bill the API already calculated. No extra line is added here.
Map<String, Object?> invoiceIssueBody(InvoiceDocument document, {String? revisionReason, bool confirmFree = false}) {
  if (document.lines.isEmpty) {
    throw const FormatException('Invoice has no lines');
  }
  return {
    'lines': [for (final line in document.lines) line.toJson()],
    'discount': document.discount,
    'note': document.note,
    'state': 'issued',
    'pricingMode': document.pricingMode == 'automatic' || document.pricingMode == 'manual' ? document.pricingMode : 'automatic',
    if (revisionReason != null && revisionReason.trim().isNotEmpty) 'revisionReason': revisionReason.trim(),
    if (confirmFree) 'confirmFree': true,
  };
}

class IntakePiece {
  const IntakePiece({required this.category, required this.count, required this.rate, required this.currency, required this.units});

  final String category;
  final int count;
  final double rate;
  final String currency;
  final List<({String model, String serial})> units;

  Map<String, Object?> toJson() => {
        'category': category,
        'count': count,
        'rate': rate,
        'currency': currency,
        'units': [
          for (final unit in units) {'model': unit.model, 'serial': unit.serial},
        ],
      };
}

class IntakeDraft {
  const IntakeDraft({
    required this.supplierCode,
    required this.categories,
    this.flightCode,
    this.flyerName,
    required this.bookedKg,
    required this.chargeRate,
    required this.chargeCurrency,
    required this.description,
    required this.paymentTerms,
    required this.pieces,
  });

  final String supplierCode;
  final List<String> categories;
  final String? flightCode;
  final String? flyerName;
  final double bookedKg;
  final double chargeRate;
  final String chargeCurrency;
  final String description;
  final String paymentTerms;
  final List<IntakePiece> pieces;

  Map<String, Object?> toJson() {
    final body = <String, Object?>{
      'supplierCode': supplierCode,
      'categories': categories,
      'bookedKg': bookedKg,
      'chargeRate': chargeRate,
      'chargeCurrency': chargeCurrency,
      'description': description,
      'paymentTerms': paymentTerms,
      'pcsItems': [for (final piece in pieces) piece.toJson()],
    };
    final flight = flightCode?.trim() ?? '';
    final flyer = flyerName?.trim() ?? '';
    if (flight.isNotEmpty) body['flightCode'] = flight;
    if (flyer.isNotEmpty) body['flyerName'] = flyer;
    return body;
  }
}
