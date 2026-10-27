import '../json_read.dart';
import 'shipment.dart';

/// Airline number without the internal booking suffix (`BG305-20261020-ab12cd`).
String displayFlightCode(String code) {
  return code
      .replaceAll(RegExp(r'-\d{8}-[a-z0-9]+$', caseSensitive: false), '')
      .replaceAll('+', '-');
}

class FlightSettlement {
  const FlightSettlement(
      {required this.name,
      required this.contribution,
      required this.paidAmount});

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
    required this.ticketRefundDue,
    required this.unallocatedFlyerPaid,
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
    this.from,
    this.to,
    this.totalShipmentCosts,
    this.margin,
    this.fromTicket = false,
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
  final double ticketRefundDue;
  final double unallocatedFlyerPaid;
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

  /// First departure and last arrival place from the itinerary legs; null
  /// when the server sends no legs.
  final String? from;
  final String? to;

  /// Costs of this flight's shipments, and charges − those costs − our
  /// ticket share. The detail sends them; list rows may not.
  final double? totalShipmentCosts;
  final double? margin;

  /// A leg was read from an e-ticket.
  final bool fromTicket;

  /// The flyers' part of the ticket: what we do not pay.
  double get flyersShare => actualCost - agencyShare;

  String get displayCode => displayFlightCode(code);

  /// "Via KMG Kunming" without the prefix; null for a direct flight.
  String? get stopLabel {
    final trimmed = via.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'direct') return null;
    return trimmed.replaceFirst(RegExp(r'^via\s+', caseSensitive: false), '');
  }

  double get fill {
    if (spaceKg <= 0) return 0;
    final ratio = bookedKg / spaceKg;
    if (ratio < 0) return 0;
    if (ratio > 1) return 1;
    return ratio;
  }

  factory FlightSummary.fromJson(Map<String, Object?> json) {
    final legs = json.containsKey('legs')
        ? asMapList(json['legs'], 'legs')
        : const <Map<String, Object?>>[];
    return FlightSummary(
      from: legs.isEmpty ? null : _legPlace(legs.first, 'fromCity', 'fromIata'),
      to: legs.isEmpty ? null : _legPlace(legs.last, 'toCity', 'toIata'),
      fromTicket: legs.any((leg) => leg['source'] == 'ticket'),
      totalShipmentCosts: optionalDouble(json, 'totalShipmentCosts'),
      margin: optionalDouble(json, 'margin'),
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
      ticketRefundDue: json.containsKey('ticketRefundDue')
          ? requiredDouble(json, 'ticketRefundDue')
          : 0,
      unallocatedFlyerPaid: json.containsKey('unallocatedFlyerPaid')
          ? requiredDouble(json, 'unallocatedFlyerPaid')
          : 0,
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
      scheduleNeedsConfirmation:
          requiredBool(json, 'scheduleNeedsConfirmation'),
      settlements: [
        for (final row in requiredMapList(json, 'settlements'))
          FlightSettlement.fromJson(row)
      ],
    );
  }
}

/// City, else airport code, of one end of a leg.
String? _legPlace(Map<String, Object?> leg, String cityKey, String iataKey) {
  for (final key in [cityKey, iataKey]) {
    final value = leg[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

class FlyerOnFlight {
  const FlyerOnFlight(
      {required this.name, required this.bdPhone, required this.initial});

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

/// The flight-cost categories the server takes; labour and anything else
/// go in as `others` with a label.
const flightCostCategories = [
  'transport',
  'courier',
  'packaging',
  'customs',
  'others'
];

/// One cost for the whole flight: our cost only, never on a customer's bill.
class FlightCost {
  const FlightCost({
    required this.id,
    required this.category,
    required this.label,
    required this.amount,
    required this.date,
    required this.paid,
    required this.accountName,
  });

  final String id;
  final String category;

  /// What it was for, as saved; may repeat the category name.
  final String label;
  final double amount;
  final String date;
  final bool paid;
  final String? accountName;

  factory FlightCost.fromJson(Map<String, Object?> json) => FlightCost(
        id: requiredString(json, 'id'),
        category: requiredString(json, 'category'),
        label: optionalString(json, 'label') ?? '',
        amount: requiredDouble(json, 'amount'),
        date: optionalString(json, 'date') ?? '',
        paid: json['paid'] == true,
        accountName: optionalString(json, 'accountName'),
      );
}

/// How the flight's profit adds up, BDT. Costs on customers' bills are paid
/// back by them and stay out.
class FlightProfitBreakdown {
  const FlightProfitBreakdown({
    required this.shipmentCharges,
    required this.flyerIncome,
    required this.ticket,
    required this.flightCosts,
    required this.profit,
    this.otherCosts = 0,
  });

  final double shipmentCharges;
  final double flyerIncome;
  final double ticket;
  final double flightCosts;
  final double profit;

  /// Older shipment costs that are not on any bill; 0 when not sent.
  final double otherCosts;

  factory FlightProfitBreakdown.fromJson(Map<String, Object?> json) =>
      FlightProfitBreakdown(
        shipmentCharges: requiredDouble(json, 'shipmentCharges'),
        flyerIncome: requiredDouble(json, 'flyerIncome'),
        ticket: requiredDouble(json, 'ticket'),
        flightCosts: requiredDouble(json, 'flightCosts'),
        profit: requiredDouble(json, 'profit'),
        otherCosts: optionalDouble(json, 'otherCosts') ?? 0,
      );
}

class FlightDetail {
  const FlightDetail(
      {required this.summary,
      required this.flyerDetails,
      required this.bookings,
      this.flightCosts,
      this.flightCostTotal,
      this.profitBreakdown});

  final FlightSummary summary;
  final List<FlyerOnFlight> flyerDetails;
  final List<AdminShipment> bookings;

  /// Costs for the whole flight, newest first; null on an older server.
  final List<FlightCost>? flightCosts;
  final double? flightCostTotal;
  final FlightProfitBreakdown? profitBreakdown;

  /// The flight's kg the costs are shared by: each shipment's weighed kg,
  /// else its booked kg.
  double get shipmentKg =>
      bookings.fold(0.0, (sum, row) => sum + row.effectiveKg);

  factory FlightDetail.fromJson(Map<String, Object?> json) {
    final costs = json['flightCosts'];
    final breakdown = optionalMap(json, 'profitBreakdown');
    return FlightDetail(
      flightCosts: costs is List
          ? [
              for (final row in asMapList(costs, 'flightCosts'))
                FlightCost.fromJson(row)
            ]
          : null,
      flightCostTotal: optionalDouble(json, 'flightCostTotal'),
      profitBreakdown:
          breakdown == null ? null : FlightProfitBreakdown.fromJson(breakdown),
      summary: FlightSummary.fromJson(json),
      flyerDetails: [
        for (final row in requiredMapList(json, 'flyerDetails'))
          FlyerOnFlight.fromJson(row)
      ],
      bookings: [
        for (final row in requiredMapList(json, 'bookings'))
          AdminShipment.fromJson(row)
      ],
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
    this.accountName,
  });

  final String airlineCode;
  final String date;
  final List<String> flyerNames;
  final int spaceKg;
  final int mobiles;
  final int laptops;
  final double actualCost;
  final double agencyShare;

  /// When set, ticket cash leaves this ledger account. Omitted means no cash movement.
  final String? accountName;

  Map<String, Object?> toJson() => {
        'code': airlineCode,
        'date': date,
        'flyerNames': flyerNames,
        'spaceKg': spaceKg,
        'mobiles': mobiles,
        'laptops': laptops,
        'actualCost': actualCost,
        'agencyShare': agencyShare,
        if (accountName != null && accountName!.trim().isNotEmpty)
          'accountName': accountName!.trim(),
      };
}
