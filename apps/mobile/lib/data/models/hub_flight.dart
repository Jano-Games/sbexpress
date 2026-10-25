import '../json_read.dart';
import 'flight.dart';
import 'shipment.dart';

/// Hub view of a flight: schedule, flyers and weight on board. The server
/// leaves out fare, ticket cost, agency share and booking revenue for this
/// view, and the model reads none of them.
class HubFlight {
  const HubFlight({
    required this.code,
    required this.date,
    required this.depTime,
    required this.arrTime,
    required this.via,
    required this.from,
    required this.to,
    required this.status,
    required this.statusLabel,
    required this.scheduleNeedsConfirmation,
    required this.flyers,
    required this.shipmentCount,
    required this.kg,
    required this.receivedCount,
  });

  final String code;
  final String date;
  final String depTime;
  final String arrTime;
  final String via;
  final String? from;
  final String? to;
  final String status;
  final String statusLabel;
  final bool scheduleNeedsConfirmation;
  final List<String> flyers;
  final int shipmentCount;
  final double kg;

  /// Shipments from this flight already received at the Dhaka hub.
  final int receivedCount;

  String get displayCode => displayFlightCode(code);

  bool get timesKnown => _isTime(depTime) && _isTime(arrTime);

  /// "Via KMG Kunming" without the prefix; null for a direct flight.
  String? get stopLabel {
    final trimmed = via.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'direct') return null;
    return trimmed.replaceFirst(RegExp(r'^via\s+', caseSensitive: false), '');
  }

  factory HubFlight.fromJson(Map<String, Object?> json) {
    return HubFlight(
      code: requiredString(json, 'code'),
      date: requiredString(json, 'date'),
      depTime: requiredString(json, 'depTime'),
      arrTime: requiredString(json, 'arrTime'),
      via: requiredString(json, 'via'),
      from: requiredNullableString(json, 'from'),
      to: requiredNullableString(json, 'to'),
      status: requiredString(json, 'status'),
      statusLabel: requiredString(json, 'statusLabel'),
      scheduleNeedsConfirmation:
          requiredBool(json, 'scheduleNeedsConfirmation'),
      flyers: requiredStringList(json, 'flyers'),
      shipmentCount: requiredInt(json, 'shipmentCount'),
      kg: requiredDouble(json, 'kg'),
      receivedCount: requiredInt(json, 'receivedCount'),
    );
  }
}

bool _isTime(String value) => RegExp(r'^\d{1,2}:\d{2}').hasMatch(value.trim());

class HubFlightDetail extends HubFlight {
  const HubFlightDetail({
    required super.code,
    required super.date,
    required super.depTime,
    required super.arrTime,
    required super.via,
    required super.from,
    required super.to,
    required super.status,
    required super.statusLabel,
    required super.scheduleNeedsConfirmation,
    required super.flyers,
    required super.shipmentCount,
    required super.kg,
    required super.receivedCount,
    required this.flyerDetails,
    required this.shipments,
  });

  final List<FlyerOnFlight> flyerDetails;
  final List<OperationalShipment> shipments;

  factory HubFlightDetail.fromJson(Map<String, Object?> json) {
    final base = HubFlight.fromJson(json);
    return HubFlightDetail(
      code: base.code,
      date: base.date,
      depTime: base.depTime,
      arrTime: base.arrTime,
      via: base.via,
      from: base.from,
      to: base.to,
      status: base.status,
      statusLabel: base.statusLabel,
      scheduleNeedsConfirmation: base.scheduleNeedsConfirmation,
      flyers: base.flyers,
      shipmentCount: base.shipmentCount,
      kg: base.kg,
      receivedCount: base.receivedCount,
      flyerDetails: [
        for (final row in requiredMapList(json, 'flyerDetails'))
          FlyerOnFlight.fromJson(row)
      ],
      shipments: [
        for (final row in requiredMapList(json, 'shipments'))
          OperationalShipment.fromJson(row)
      ],
    );
  }
}

class HubFlightSchedule {
  const HubFlightSchedule({required this.upcoming, required this.arrived});

  /// Upcoming and in-the-air flights, soonest first.
  final List<HubFlight> upcoming;

  /// Recently completed flights, latest first.
  final List<HubFlight> arrived;

  int get shipmentCount =>
      upcoming.fold(0, (total, flight) => total + flight.shipmentCount);

  double get kg => upcoming.fold(0.0, (total, flight) => total + flight.kg);

  factory HubFlightSchedule.fromJson(Map<String, Object?> json) {
    return HubFlightSchedule(
      upcoming: [
        for (final row in requiredMapList(json, 'upcoming'))
          HubFlight.fromJson(row)
      ],
      arrived: [
        for (final row in requiredMapList(json, 'arrived'))
          HubFlight.fromJson(row)
      ],
    );
  }
}

const _weekdays = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহস্পতি', 'শুক্র', 'শনি', 'রবি'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

/// Calendar parts of a flight's `YYYY-MM-DD` date, relative to [today].
class FlightDay {
  const FlightDay(
      {required this.day,
      required this.month,
      required this.weekday,
      required this.daysAway});

  final int day;
  final String month;

  /// Short Bangla weekday, e.g. "মঙ্গল".
  final String weekday;

  /// Whole days from today; negative once the date has passed.
  final int daysAway;

  String get shortLabel => '$weekday, $day $month';

  /// "আজ", "আগামীকাল", "3 দিন পর", "গতকাল", "2 দিন আগে".
  String get relativeLabel {
    if (daysAway == 0) return 'আজ';
    if (daysAway == 1) return 'আগামীকাল';
    if (daysAway == -1) return 'গতকাল';
    if (daysAway > 1) return '$daysAway দিন পর';
    return '${-daysAway} দিন আগে';
  }

  static FlightDay? parse(String iso, {DateTime? today}) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return null;
    final date = DateTime(parsed.year, parsed.month, parsed.day);
    final now = today ?? DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    return FlightDay(
      day: date.day,
      month: _months[date.month - 1],
      weekday: _weekdays[date.weekday - 1],
      daysAway: date.difference(base).inDays,
    );
  }
}
