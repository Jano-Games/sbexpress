import '../json_read.dart';
import 'shipment.dart';

/// Airline number without the internal booking suffix (`BG305-20261020-ab12cd`).
String displayFlightCode(String code) {
  return code.replaceAll(RegExp(r'-\d{8}-[a-z0-9]+$', caseSensitive: false), '').replaceAll('+', '-');
}

class FlightSettlement {
  const FlightSettlement({required this.name, required this.contribution, required this.paidAmount});

  final String name;
  final double contribution;
  final double paidAmount;

  double get due => (contribution - paidAmount).clamp(0, double.infinity);

  factory FlightSettlement.fromJson(Map<String, Object?> json) {
    return FlightSettlement(
      name: requiredString(json, 'name'),
      contribution: requiredDouble(json, 'contribution'),
      paidAmount: requiredDouble(json, 'paidAmount'),
    );
  }
}

class FlightSummary {
  const FlightSummary({
    required this.code,
    required this.date,
    required this.depTime,
    required this.arrTime,
    required this.via,
    required this.fare,
    required this.actualCost,
    required this.agencyShare,
    required this.flyerDue,
    required this.ticketPaid,
    required this.ticketDue,
    required this.spaceKg,
    required this.mobiles,
    required this.laptops,
    required this.bookedKg,
    required this.leftKg,
    required this.status,
    required this.statusLabel,
    required this.flyers,
    required this.shipmentCount,
    required this.revenue,
    required this.scheduleNeedsConfirmation,
    required this.settlements,
  });

  final String code;
  final String date;
  final String depTime;
  final String arrTime;
  final String via;
  final double fare;
  final double actualCost;
  final double agencyShare;
  final double flyerDue;
  final double ticketPaid;
  final double ticketDue;
  final int spaceKg;
  final int mobiles;
  final int laptops;
  final double bookedKg;
  final double leftKg;
  final String status;
  final String statusLabel;
  final List<String> flyers;
  final int shipmentCount;
  final double revenue;
  final bool scheduleNeedsConfirmation;
  final List<FlightSettlement> settlements;

  String get displayCode => displayFlightCode(code);

  double get fill {
    if (spaceKg <= 0) return 0;
    final ratio = bookedKg / spaceKg;
    if (ratio < 0) return 0;
    if (ratio > 1) return 1;
    return ratio;
  }

  factory FlightSummary.fromJson(Map<String, Object?> json) {
    return FlightSummary(
      code: requiredString(json, 'code'),
      date: requiredString(json, 'date'),
      depTime: requiredString(json, 'depTime'),
      arrTime: requiredString(json, 'arrTime'),
      via: requiredString(json, 'via'),
      fare: requiredDouble(json, 'fare'),
      actualCost: requiredDouble(json, 'actualCost'),
      agencyShare: requiredDouble(json, 'agencyShare'),
      flyerDue: requiredDouble(json, 'flyerDue'),
      ticketPaid: requiredDouble(json, 'ticketPaid'),
      ticketDue: requiredDouble(json, 'ticketDue'),
      spaceKg: requiredInt(json, 'spaceKg'),
      mobiles: requiredInt(json, 'mobiles'),
      laptops: requiredInt(json, 'laptops'),
      bookedKg: requiredDouble(json, 'bookedKg'),
      leftKg: requiredDouble(json, 'leftKg'),
      status: requiredString(json, 'status'),
      statusLabel: requiredString(json, 'statusLabel'),
      flyers: requiredStringList(json, 'flyers'),
      shipmentCount: requiredInt(json, 'shipmentCount'),
      revenue: requiredDouble(json, 'revenue'),
      scheduleNeedsConfirmation: requiredBool(json, 'scheduleNeedsConfirmation'),
      settlements: [for (final row in requiredMapList(json, 'settlements')) FlightSettlement.fromJson(row)],
    );
  }
}

class FlyerOnFlight {
  const FlyerOnFlight({required this.name, required this.bdPhone, required this.initial});

  final String name;
  final String bdPhone;
  final String initial;

  factory FlyerOnFlight.fromJson(Map<String, Object?> json) {
    return FlyerOnFlight(
      name: requiredString(json, 'name'),
      bdPhone: requiredString(json, 'bdPhone'),
      initial: requiredString(json, 'initial'),
    );
  }
}

class FlightDetail {
  const FlightDetail({required this.summary, required this.flyerDetails, required this.bookings});

  final FlightSummary summary;
  final List<FlyerOnFlight> flyerDetails;
  final List<AdminShipment> bookings;

  factory FlightDetail.fromJson(Map<String, Object?> json) {
    return FlightDetail(
      summary: FlightSummary.fromJson(json),
      flyerDetails: [for (final row in requiredMapList(json, 'flyerDetails')) FlyerOnFlight.fromJson(row)],
      bookings: [for (final row in requiredMapList(json, 'bookings')) AdminShipment.fromJson(row)],
    );
  }
}

class FlightDraft {
  const FlightDraft({
    required this.airlineCode,
    required this.date,
    required this.flyerNames,
    required this.spaceKg,
    required this.mobiles,
    required this.laptops,
    required this.actualCost,
    required this.agencyShare,
  });

  final String airlineCode;
  final String date;
  final List<String> flyerNames;
  final int spaceKg;
  final int mobiles;
  final int laptops;
  final double actualCost;
  final double agencyShare;

  /// Ticket cash is not posted here. A paying account is chosen on the web
  /// when money actually leaves a fund.
  Map<String, Object?> toJson() => {
        'code': airlineCode,
        'date': date,
        'flyerNames': flyerNames,
        'spaceKg': spaceKg,
        'mobiles': mobiles,
        'laptops': laptops,
        'actualCost': actualCost,
        'agencyShare': agencyShare,
      };
}
