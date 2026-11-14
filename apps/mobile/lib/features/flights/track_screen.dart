import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app_scope.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/flight_position.dart';
import '../../l10n/l10n.dart';
import '../../l10n/places.dart';
import '../../theme/app_colors.dart';
import '../../widgets/flight_status_parts.dart';
import '../../widgets/ui.dart';

/// Where a flight in the air is now, on an OpenStreetMap map. The server keeps
/// one answer for 15 minutes and allows 6 refreshes a day per flight.
class TrackScreen extends StatefulWidget {
  const TrackScreen(
      {super.key, required this.code, required this.title, this.tiles = true});

  final String code;

  /// The flight number people know, e.g. MU2039.
  final String title;

  /// Map tiles from openstreetmap.org; tests and captures draw without them.
  final bool tiles;

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  PositionAnswer? _answer;
  String? _error;
  var _loading = true;
  var _refreshing = false;
  Timer? _wake;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _wake?.cancel();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _error = null;
      if (refresh) {
        _refreshing = true;
      } else {
        _loading = true;
      }
    });
    try {
      final answer = await AppScope.of(context)
          .flights
          .position(widget.code, refresh: refresh);
      if (!mounted) return;
      setState(() => _answer = answer);
      _scheduleWake(answer);
    } on ApiException catch (error) {
      if (mounted && error.status != 401) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  /// Turns the refresh button on when the 15 minutes have passed.
  void _scheduleWake(PositionAnswer answer) {
    _wake?.cancel();
    final at = answer.nextRefreshAt;
    if (at == null || answer.refreshesLeft == 0) return;
    final wait = at.difference(DateTime.now());
    if (wait.isNegative) return;
    _wake = Timer(wait + const Duration(seconds: 1), () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final answer = _answer;
    final track = answer?.track;
    return Scaffold(
      appBar: BackTitle(
          title: tr('Where is {flight} now', {'flight': widget.title}),
          subtitle: track == null ? null : _routeLine(track)),
      body: Column(children: [
        if (track != null)
          SizedBox(
              height: math.min(380, MediaQuery.sizeOf(context).height * 0.42),
              child: _FlightMap(track: track, tiles: widget.tiles)),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.fromLTRB(pageGutter, 16, pageGutter, 28),
              children: [
                if (_loading && answer == null) const LinearProgressIndicator(),
                if (_error != null)
                  ErrorNote(message: _error!, onRetry: () => _load()),
                if (answer != null && !answer.inAir)
                  EmptyNote(
                      icon: Icons.flight_rounded,
                      title: tr('This flight is not in the air'),
                      body: tr(
                          'The map shows the plane while it is flying. Check the flight page for times.')),
                if (answer != null && track != null) ...[
                  _PositionCard(track: track, title: widget.title),
                  const SizedBox(height: 12),
                  if (answer.note == 'unavailable') ...[
                    HintNote(
                        text: tr(
                            'The airline has no position for this flight right now. Try again later.')),
                    const SizedBox(height: 12),
                  ],
                  if (track.sample) ...[
                    HintNote(
                        text: tr(
                            'Sample position. Add the flight data key on the server for live positions.')),
                    const SizedBox(height: 12),
                  ],
                  _RefreshButton(
                      answer: answer,
                      busy: _refreshing,
                      onRefresh: () => _load(refresh: true)),
                ],
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

String _place(TrackPlace p) =>
    banglaPlace(p.city.isNotEmpty ? p.city : p.iata, fallback: p.iata);

/// "Chengdu to Dhaka, via Kunming".
String _routeLine(FlightTrack track) {
  final route = track.route;
  if (route.length < 2) {
    return tr(
        '{from} to {to}', {'from': _place(track.from), 'to': _place(track.to)});
  }
  final line = tr('{from} to {to}',
      {'from': _place(route.first), 'to': _place(route.last)});
  if (route.length == 2) return line;
  final stops = route.sublist(1, route.length - 1).map(_place).join(', ');
  return tr('{route}, via {stops}', {'route': line, 'stops': stops});
}

String _thousands(int n) {
  final s = n.abs().toString();
  final out = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _FlightMap extends StatelessWidget {
  const _FlightMap({required this.track, required this.tiles});

  final FlightTrack track;
  final bool tiles;

  @override
  Widget build(BuildContext context) {
    final located = [
      for (final p in track.route)
        if (p.located) p
    ];
    final plane = track.position;
    final planePoint = plane == null ? null : LatLng(plane.lat, plane.lon);
    final from = located.indexWhere((p) => p.iata == track.from.iata);
    final split = from < 0 ? 0 : from;
    LatLng at(TrackPlace p) => LatLng(p.lat!, p.lon!);
    final done = [
      for (final p in located.take(split + 1)) at(p),
      if (planePoint != null) planePoint,
    ];
    final ahead = [
      if (planePoint != null) planePoint else if (done.isNotEmpty) done.last,
      for (final p in located.skip(split + 1)) at(p),
    ];
    final points = [
      for (final p in located) at(p),
      if (planePoint != null) planePoint,
    ];
    if (points.isEmpty) {
      return const ColoredBox(color: Color(0xFFE8EDE6));
    }
    // Labels sit beside the pin; on the eastern side they go to its left so
    // the map edge does not cut them.
    final lons = [for (final p in points) p.longitude];
    final west = lons.reduce((a, b) => a < b ? a : b);
    final east = lons.reduce((a, b) => a > b ? a : b);
    bool labelLeft(TrackPlace p) =>
        east - west > 0.5 && p.lon! > west + (east - west) * 0.6;
    return FlutterMap(
      key: const Key('track-map'),
      options: MapOptions(
        backgroundColor: const Color(0xFFE8EDE6),
        initialCenter: points.first,
        initialZoom: 4,
        initialCameraFit: points.length < 2
            ? null
            : CameraFit.coordinates(
                coordinates: points,
                padding: const EdgeInsets.fromLTRB(56, 48, 56, 40),
                maxZoom: 7),
        interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        if (tiles)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.sbexpress.sbexpress',
          ),
        PolylineLayer(polylines: [
          if (done.length > 1)
            Polyline(points: done, color: AppColors.primary, strokeWidth: 3.5),
          if (ahead.length > 1)
            Polyline(
                points: ahead,
                color: AppColors.primary.withValues(alpha: 0.75),
                strokeWidth: 3,
                pattern: StrokePattern.dashed(segments: const [8, 7])),
        ]),
        MarkerLayer(markers: [
          for (var i = 0; i < located.length; i++)
            Marker(
              point: at(located[i]),
              width: 150,
              height: 44,
              child: _AirportPin(
                  place: located[i],
                  passed: i <= split,
                  end: i == located.length - 1,
                  labelLeft: labelLeft(located[i])),
            ),
          if (planePoint != null)
            Marker(
              point: planePoint,
              width: 42,
              height: 42,
              child: _Plane(headingDeg: plane!.headingDeg ?? 0),
            ),
        ]),
        if (tiles)
          const SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
              alignment: Alignment.bottomRight),
      ],
    );
  }
}

class _AirportPin extends StatelessWidget {
  const _AirportPin(
      {required this.place,
      required this.passed,
      required this.end,
      this.labelLeft = false});

  final TrackPlace place;
  final bool passed, end;

  /// The label goes left of the pin, for pins near the map's right edge.
  final bool labelLeft;

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: end ? 16 : 13,
      height: end ? 16 : 13,
      decoration: BoxDecoration(
          color: passed ? AppColors.primary : AppColors.card,
          shape: BoxShape.circle,
          border: Border.all(
              color: end ? AppColors.ink : AppColors.primary, width: 2.5)),
    );
    return Stack(clipBehavior: Clip.none, children: [
      Center(child: dot),
      Positioned(
        left: labelLeft ? null : 75 + 12,
        right: labelLeft ? 75 + 12 : null,
        top: 13,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
              color: AppColors.card.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(5)),
          child: Text('${place.iata} ${_place(place)}',
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
        ),
      ),
    ]);
  }
}

class _Plane extends StatelessWidget {
  const _Plane({required this.headingDeg});

  final int headingDeg;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.16),
            shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 4,
                    offset: Offset(0, 1))
              ]),
          child: Transform.rotate(
            angle: headingDeg * math.pi / 180,
            child: Icon(Icons.flight_rounded,
                size: 20, color: AppColors.primary, semanticLabel: tr('Plane')),
          ),
        ),
      );
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.track, required this.title});

  final FlightTrack track;
  final String title;

  @override
  Widget build(BuildContext context) {
    final p = track.position;
    final late = track.arrLateMin;
    final leg = track.legCode.isEmpty ? title : track.legCode;
    return PaperCard(
      key: const Key('track-card'),
      radius: heroRadius,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(
                '$leg · ${tr('{from} to {to}', {
                      'from': _place(track.from),
                      'to': _place(track.to)
                    })}',
                style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft)),
          ),
          const SizedBox(width: 8),
          LookPill(
              look: FlightLook(tr('In the air'), ChipTone.amber,
                  icon: Icons.flight_rounded)),
        ]),
        const SizedBox(height: 10),
        Text(tr('Lands in {place}', {'place': _place(track.to)}),
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Text(track.landsAt ?? '--:--',
                style: const TextStyle(
                    fontSize: 32,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ),
          if (late != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: LookPill(
                  look: FlightLook(lateLabel(late),
                      late >= 5 ? ChipTone.amber : ChipTone.green,
                      icon: Icons.schedule_rounded)),
            ),
        ]),
        if (p != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _Fact(
                    label: tr('Height'),
                    value: p.altitudeM == null
                        ? '—'
                        : tr('{n} m', {'n': _thousands(p.altitudeM!)}))),
            const SizedBox(width: 8),
            Expanded(
                child: _Fact(
                    label: tr('Speed'),
                    value: p.speedKmh == null
                        ? '—'
                        : tr('{n} km/h', {'n': _thousands(p.speedKmh!)}))),
            const SizedBox(width: 8),
            Expanded(
                child: _Fact(
                    label: tr('Done'),
                    value:
                        track.progress == null ? '—' : '${track.progress}%')),
          ]),
        ],
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.sync_rounded, size: 14, color: AppColors.muted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
                tr('Position from the airline feed · {time}',
                    {'time': _clock(p?.reportedAt ?? track.checkedAt)}),
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
        ]),
      ]),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
        decoration: BoxDecoration(
            color: AppColors.paper, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                maxLines: 1,
                style: const TextStyle(
                    fontSize: 16.5, fontWeight: FontWeight.w700)),
          ),
        ]),
      );
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton(
      {required this.answer, required this.busy, required this.onRefresh});

  final PositionAnswer answer;
  final bool busy;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final can = answer.canRefresh(now);
    final next = answer.nextRefreshAt;
    final label = answer.refreshesLeft == 0
        ? tr('No refreshes left today')
        : can || next == null
            ? tr('Refresh now')
            : tr('Refresh again at {time}', {'time': _clock(next)});
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AppButton(
          key: const Key('track-refresh'),
          label: label,
          icon: Icons.sync_rounded,
          kind: AppButtonKind.quiet,
          busy: busy,
          onPressed: can ? onRefresh : null),
      const SizedBox(height: 8),
      Text(
          tr('Live refresh once every 15 min · {left} of {total} left today',
              {'left': answer.refreshesLeft, 'total': 6}),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    ]);
  }
}
