import '../json_read.dart';

/// One leg as the airline last saw it.
class TrackingLeg {
  const TrackingLeg({
    required this.code,
    required this.state,
    this.fromIata = '',
    this.fromCity = '',
    this.toIata = '',
    this.toCity = '',
    this.plannedDep = '',
    this.plannedArr = '',
    this.depLocal,
    this.arrLocal,
    this.depLateMin,
    this.arrLateMin,
  });

  final String code;

  /// `waiting`, `in_air`, `landed`, `cancelled` or `unknown`.
  final String state;
  final String fromIata;
  final String fromCity;
  final String toIata;
  final String toCity;

  /// The planned local times, HH:mm.
  final String plannedDep;
  final String plannedArr;

  /// When it left and lands (actual once it happened), local HH:mm.
  final String? depLocal;
  final String? arrLocal;

  /// Minutes behind the plan; negative is early.
  final int? depLateMin;
  final int? arrLateMin;

  factory TrackingLeg.fromJson(Map<String, Object?> json) => TrackingLeg(
        code: optionalString(json, 'code') ?? '',
        state: optionalString(json, 'state') ?? 'unknown',
        fromIata: optionalString(json, 'fromIata') ?? '',
        fromCity: optionalString(json, 'fromCity') ?? '',
        toIata: optionalString(json, 'toIata') ?? '',
        toCity: optionalString(json, 'toCity') ?? '',
        plannedDep: optionalString(json, 'plannedDep') ?? '',
        plannedArr: optionalString(json, 'plannedArr') ?? '',
        depLocal: optionalString(json, 'depLocal'),
        arrLocal: optionalString(json, 'arrLocal'),
        depLateMin: optionalInt(json, 'depLateMin'),
        arrLateMin: optionalInt(json, 'arrLateMin'),
      );
}

/// The leg in the air, or the last one that left: "left Shanghai 13:34".
class TrackingLastLeft {
  const TrackingLastLeft(
      {required this.code, this.iata = '', this.city = '', this.at});
  final String code;
  final String iata;
  final String city;
  final String? at;
}

/// What the airline says about a flight. The server asks soon after each
/// take-off and after the landing; null until it first asked.
class FlightTracking {
  const FlightTracking({
    required this.state,
    required this.checkedAt,
    this.left = false,
    this.leftAt,
    this.leftLateMin,
    this.lastLeft,
    this.landed = false,
    this.landsAt,
    this.landsLateMin,
    this.plannedDep = '',
    this.plannedArr = '',
    this.nextCheck,
    this.legs = const [],
  });

  /// `scheduled`, `on_the_way`, `landed`, `cancelled` or `none` (no data for
  /// that day); null when the airline said nothing usable.
  final String? state;
  final DateTime checkedAt;
  final bool left;

  /// The first take-off, local HH:mm, once it left.
  final String? leftAt;
  final int? leftLateMin;
  final TrackingLastLeft? lastLeft;
  final bool landed;

  /// The last landing, expected or actual, local HH:mm.
  final String? landsAt;
  final int? landsLateMin;
  final String plannedDep;
  final String plannedArr;

  /// `after_takeoff`, `after_landing` or null when no more checks are due.
  final String? nextCheck;
  final List<TrackingLeg> legs;

  bool get cancelled => state == 'cancelled';
  bool get noData => state == 'none';

  /// The leg the airline gave a later take-off for, before it left.
  TrackingLeg? get waitingLate {
    for (final leg in legs) {
      if (leg.state == 'waiting' && (leg.depLateMin ?? 0) >= 5) return leg;
    }
    return null;
  }

  static FlightTracking? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, Object?>.from(value);
    final checked = DateTime.tryParse(optionalString(json, 'checkedAt') ?? '');
    if (checked == null) return null;
    final last = optionalMap(json, 'lastLeft');
    final legs = json['legs'];
    return FlightTracking(
      state: optionalString(json, 'state'),
      checkedAt: checked,
      left: json['left'] == true,
      leftAt: optionalString(json, 'leftAt'),
      leftLateMin: optionalInt(json, 'leftLateMin'),
      lastLeft: last == null
          ? null
          : TrackingLastLeft(
              code: optionalString(last, 'code') ?? '',
              iata: optionalString(last, 'iata') ?? '',
              city: optionalString(last, 'city') ?? '',
              at: optionalString(last, 'at')),
      landed: json['landed'] == true,
      landsAt: optionalString(json, 'landsAt'),
      landsLateMin: optionalInt(json, 'landsLateMin'),
      plannedDep: optionalString(json, 'plannedDep') ?? '',
      plannedArr: optionalString(json, 'plannedArr') ?? '',
      nextCheck: optionalString(json, 'nextCheck'),
      legs: legs is List
          ? [
              for (final row in asMapList(legs, 'tracking.legs'))
                TrackingLeg.fromJson(row)
            ]
          : const [],
    );
  }
}

/// The orders moved to In transit when the flight left.
class MovedOrders {
  const MovedOrders({required this.at, required this.by, required this.codes});
  final DateTime at;

  /// `airline`, or the staff member's name.
  final String by;
  final List<String> codes;

  bool get byAirline => by == 'airline';

  static MovedOrders? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, Object?>.from(value);
    final at = DateTime.tryParse(optionalString(json, 'at') ?? '');
    final codes = json['codes'];
    if (at == null || codes is! List) return null;
    return MovedOrders(
        at: at,
        by: optionalString(json, 'by') ?? '',
        codes: [for (final code in codes) '$code']);
  }
}

/// An order on a flight that left but is not on its way.
class NotMovedOrder {
  const NotMovedOrder(
      {required this.code,
      required this.customer,
      required this.status,
      required this.reason});
  final String code;
  final String customer;
  final String status;

  /// `not_ready`, `no_flyer`, `exception` or `ready`.
  final String reason;

  static List<NotMovedOrder> listOf(Map<String, Object?> json) {
    final rows = json['notMoved'];
    if (rows is! List) return const [];
    return [
      for (final row in asMapList(rows, 'notMoved'))
        NotMovedOrder(
            code: optionalString(row, 'code') ?? '',
            customer: optionalString(row, 'customer') ?? '',
            status: optionalString(row, 'status') ?? '',
            reason: optionalString(row, 'reason') ?? 'ready'),
    ];
  }
}
