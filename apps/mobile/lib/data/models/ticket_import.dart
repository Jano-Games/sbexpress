import '../json_read.dart';

/// What the server read from an e-ticket PDF. Nothing is stored until the
/// admin creates the reviewed flights.
class TicketImport {
  const TicketImport({
    required this.agency,
    required this.passenger,
    required this.pnr,
    required this.ticketNumber,
    required this.issuedOn,
    required this.flyerMatches,
    required this.journeys,
  });

  final String? agency;
  final String? passenger;
  final String? pnr;
  final String? ticketNumber;
  final String? issuedOn;

  /// Existing flyers that look like the passenger, best first.
  final List<String> flyerMatches;
  final List<TicketJourney> journeys;

  factory TicketImport.fromJson(Map<String, Object?> json) {
    final ticket = asJsonMap(json['ticket'], 'ticket');
    return TicketImport(
      agency: requiredNullableString(ticket, 'agency'),
      passenger: requiredNullableString(ticket, 'passenger'),
      pnr: requiredNullableString(ticket, 'pnr'),
      ticketNumber: requiredNullableString(ticket, 'ticketNumber'),
      issuedOn: requiredNullableString(ticket, 'issuedOn'),
      flyerMatches: [
        for (final row in requiredMapList(json, 'flyerMatches'))
          requiredString(row, 'name')
      ],
      journeys: [
        for (final row in requiredMapList(json, 'journeys'))
          TicketJourney.fromJson(row)
      ],
    );
  }
}

/// `to_bangladesh`, `from_bangladesh` or `other`.
class TicketJourney {
  const TicketJourney(
      {required this.direction, required this.date, required this.legs});

  final String direction;
  final String date;
  final List<TicketLeg> legs;

  factory TicketJourney.fromJson(Map<String, Object?> json) => TicketJourney(
        direction: requiredString(json, 'direction'),
        date: requiredString(json, 'date'),
        legs: [
          for (final row in requiredMapList(json, 'legs'))
            TicketLeg.fromJson(row)
        ],
      );
}

/// One segment; editable in the review screen.
class TicketLeg {
  TicketLeg({
    required this.code,
    required this.date,
    required this.fromIata,
    required this.fromCity,
    required this.toIata,
    required this.toCity,
    required this.depTime,
    required this.arrTime,
  });

  String code;
  String date;
  String fromIata;
  String fromCity;
  String toIata;
  String toCity;
  String depTime;
  String arrTime;

  factory TicketLeg.fromJson(Map<String, Object?> json) => TicketLeg(
        code: requiredString(json, 'code'),
        date: requiredString(json, 'date'),
        fromIata: requiredString(json, 'fromIata'),
        fromCity: requiredString(json, 'fromCity'),
        toIata: requiredString(json, 'toIata'),
        toCity: requiredString(json, 'toCity'),
        depTime: requiredString(json, 'depTime'),
        arrTime: requiredString(json, 'arrTime'),
      );

  Map<String, Object?> toJson() => {
        'source': 'ticket',
        'code': code,
        'date': date,
        'fromIata': fromIata,
        'fromCity': fromCity,
        'toIata': toIata,
        'toCity': toCity,
        'depTime': depTime,
        'arrTime': arrTime,
      };
}

/// One journey under review, with the flight's own settings.
class TicketFlightDraft {
  TicketFlightDraft({required this.direction, required this.legs});

  final String direction;
  final List<TicketLeg> legs;
  int spaceKg = 44;
  int mobiles = 2;
  int laptops = 1;
  double actualCost = 0;
  double agencyShare = 0;
  bool saved = false;
  String? error;

  String get route => legs.isEmpty
      ? '—'
      : [
          legs.first.fromIata.isEmpty
              ? legs.first.fromCity
              : legs.first.fromIata,
          for (final leg in legs) leg.toIata.isEmpty ? leg.toCity : leg.toIata
        ].join(' → ');

  /// English text of the first thing to fix, or null when the draft can be saved.
  String? get problem {
    if (legs.isEmpty) return 'Keep at least one segment.';
    for (final leg in legs) {
      if (!RegExp(r'^[A-Z0-9]{2}\d{1,4}$').hasMatch(leg.code)) {
        return 'Check the flight number.';
      }
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(leg.date)) {
        return 'Check the segment date.';
      }
      if (!RegExp(r'^[A-Z]{3}$').hasMatch(leg.fromIata) ||
          !RegExp(r'^[A-Z]{3}$').hasMatch(leg.toIata)) {
        return 'Use three-letter airport codes.';
      }
      if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(leg.depTime) ||
          !RegExp(r'^\d{2}:\d{2}$').hasMatch(leg.arrTime)) {
        return 'Check departure and arrival times.';
      }
    }
    if (actualCost < 0 || agencyShare < 0) {
      return 'Ticket amounts must be zero or more.';
    }
    if (agencyShare > actualCost) {
      return 'Agency share cannot exceed the ticket cost.';
    }
    return null;
  }

  /// POST /flights body. Amounts are BDT; no money moves on create.
  Map<String, Object?> toJson(String flyer) => {
        'code': [for (final leg in legs) leg.code].join('+'),
        'date': legs.first.date,
        'depTime': legs.first.depTime,
        'arrTime': legs.last.arrTime,
        'flyerNames': [flyer],
        'spaceKg': spaceKg,
        'mobiles': mobiles,
        'laptops': laptops,
        'actualCost': actualCost,
        'agencyShare': agencyShare,
        'legs': [for (final leg in legs) leg.toJson()],
      };

  static List<TicketFlightDraft> fromImport(TicketImport ticket) => [
        for (final journey in ticket.journeys)
          TicketFlightDraft(direction: journey.direction, legs: journey.legs),
      ];
}
