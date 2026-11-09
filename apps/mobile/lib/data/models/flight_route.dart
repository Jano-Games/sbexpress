import '../json_read.dart';
import 'flight.dart';

/// One flight of an itinerary as the airline schedule has it.
class RouteLookupLeg {
  const RouteLookupLeg({
    required this.code,
    required this.date,
    required this.found,
    this.airline,
    this.fromIata = '',
    this.fromCity = '',
    this.toIata = '',
    this.toCity = '',
    this.depTime,
    this.arrTime,
  });

  final String code;

  /// The day it was found on; a connection may leave the next day.
  final String date;
  final bool found;
  final String? airline;
  final String fromIata;
  final String fromCity;
  final String toIata;
  final String toCity;
  final String? depTime;
  final String? arrTime;

  factory RouteLookupLeg.fromJson(Map<String, Object?> json) => RouteLookupLeg(
        code: requiredString(json, 'code'),
        date: requiredString(json, 'date'),
        found: requiredBool(json, 'found'),
        airline: optionalString(json, 'airline'),
        fromIata: optionalString(json, 'fromIata') ?? '',
        fromCity: optionalString(json, 'fromCity') ?? '',
        toIata: optionalString(json, 'toIata') ?? '',
        toCity: optionalString(json, 'toCity') ?? '',
        depTime: optionalString(json, 'depTime'),
        arrTime: optionalString(json, 'arrTime'),
      );

  FlightLeg toLeg() => FlightLeg(
        source: 'schedule',
        code: code,
        date: date,
        fromIata: fromIata,
        fromCity: fromCity,
        toIata: toIata,
        toCity: toCity,
        depTime: depTime ?? '—',
        arrTime: arrTime ?? '—',
      );
}

/// What the airline schedule says about a flight number on a day.
class RouteLookup {
  const RouteLookup({
    required this.configured,
    required this.found,
    required this.legs,
    required this.missing,
    this.depTime,
    this.arrTime,
    this.via,
  });

  /// False when the server has no flight data key; nothing was looked up.
  final bool configured;

  /// Every flight was found.
  final bool found;
  final List<RouteLookupLeg> legs;

  /// Numbers the schedule does not have that day.
  final List<String> missing;
  final String? depTime;
  final String? arrTime;

  /// "Via PVG Shanghai", "Direct", or null when a stop is unknown.
  final String? via;

  factory RouteLookup.fromJson(Map<String, Object?> json) => RouteLookup(
        configured: requiredBool(json, 'configured'),
        found: requiredBool(json, 'found'),
        legs: [
          for (final row in requiredMapList(json, 'legs'))
            RouteLookupLeg.fromJson(row)
        ],
        missing: requiredStringList(json, 'missing'),
        depTime: optionalString(json, 'depTime'),
        arrTime: optionalString(json, 'arrTime'),
        via: optionalString(json, 'via'),
      );
}

/// The parts of a flight its Edit page changes. The legs carry the number,
/// the times and the stops.
class FlightEdit {
  const FlightEdit({
    required this.date,
    required this.depTime,
    required this.arrTime,
    required this.legs,
    required this.spaceKg,
    required this.mobiles,
    required this.laptops,
  });

  final String date;
  final String depTime;
  final String arrTime;
  final List<FlightLeg> legs;
  final int spaceKg;
  final int mobiles;
  final int laptops;

  Map<String, Object?> toJson() => {
        'date': date,
        'depTime': depTime,
        'arrTime': arrTime,
        'legs': [for (final leg in legs) leg.toJson()],
        'spaceKg': spaceKg,
        'mobiles': mobiles,
        'laptops': laptops,
      };
}
