import '../json_read.dart';

class TrackPlace {
  const TrackPlace(
      {required this.iata, required this.city, this.lat, this.lon});

  final String iata, city;
  final double? lat, lon;

  bool get located => lat != null && lon != null;

  factory TrackPlace.fromJson(Map<String, Object?> json) => TrackPlace(
      iata: optionalString(json, 'iata') ?? '',
      city: optionalString(json, 'city') ?? '',
      lat: optionalDouble(json, 'lat'),
      lon: optionalDouble(json, 'lon'));
}

class PlanePosition {
  const PlanePosition(
      {required this.lat,
      required this.lon,
      this.altitudeM,
      this.speedKmh,
      this.headingDeg,
      this.reportedAt});

  final double lat, lon;
  final int? altitudeM, speedKmh, headingDeg;
  final DateTime? reportedAt;

  factory PlanePosition.fromJson(Map<String, Object?> json) => PlanePosition(
      lat: requiredDouble(json, 'lat'),
      lon: requiredDouble(json, 'lon'),
      altitudeM: optionalInt(json, 'altitudeM'),
      speedKmh: optionalInt(json, 'speedKmh'),
      headingDeg: optionalInt(json, 'headingDeg'),
      reportedAt: optionalString(json, 'reportedAt') == null
          ? null
          : DateTime.tryParse(optionalString(json, 'reportedAt')!)?.toLocal());
}

/// Where a flight in the air is, from the airline feed.
class FlightTrack {
  const FlightTrack({
    required this.legCode,
    required this.from,
    required this.to,
    required this.route,
    required this.checkedAt,
    required this.sample,
    this.position,
    this.landsAt,
    this.arrLateMin,
    this.progress,
  });

  final String legCode;
  final TrackPlace from, to;
  final List<TrackPlace> route;
  final PlanePosition? position;
  final String? landsAt;
  final int? arrLateMin;
  final int? progress;
  final DateTime checkedAt;

  /// Made up by a server without the flight data key, for trying the screen.
  final bool sample;

  factory FlightTrack.fromJson(Map<String, Object?> json) => FlightTrack(
        legCode: optionalString(json, 'legCode') ?? '',
        from: TrackPlace.fromJson(asJsonMap(json['from'], 'from')),
        to: TrackPlace.fromJson(asJsonMap(json['to'], 'to')),
        route: json['route'] is List
            ? [
                for (final row in asMapList(json['route'], 'route'))
                  TrackPlace.fromJson(row)
              ]
            : const [],
        position: optionalMap(json, 'position') == null
            ? null
            : PlanePosition.fromJson(optionalMap(json, 'position')!),
        landsAt: optionalString(json, 'landsAt'),
        arrLateMin: optionalInt(json, 'arrLateMin'),
        progress: optionalInt(json, 'progress'),
        checkedAt: DateTime.tryParse(requiredString(json, 'checkedAt'))
                ?.toLocal() ??
            DateTime.now(),
        sample: json['sample'] == true,
      );
}

class PositionAnswer {
  const PositionAnswer(
      {required this.inAir,
      required this.refreshesLeft,
      this.track,
      this.nextRefreshAt,
      this.note});

  final bool inAir;
  final FlightTrack? track;
  final DateTime? nextRefreshAt;
  final int refreshesLeft;

  /// 'limit' when today's refreshes are used up; 'unavailable' when the
  /// airline has no position.
  final String? note;

  factory PositionAnswer.fromJson(Map<String, Object?> json) => PositionAnswer(
        inAir: json['inAir'] == true,
        track: optionalMap(json, 'track') == null
            ? null
            : FlightTrack.fromJson(optionalMap(json, 'track')!),
        nextRefreshAt: optionalString(json, 'nextRefreshAt') == null
            ? null
            : DateTime.tryParse(optionalString(json, 'nextRefreshAt')!)
                ?.toLocal(),
        refreshesLeft: optionalInt(json, 'refreshesLeft') ?? 0,
        note: optionalString(json, 'note'),
      );

  bool canRefresh(DateTime now) =>
      inAir &&
      refreshesLeft > 0 &&
      (nextRefreshAt == null || !now.isBefore(nextRefreshAt!));
}
