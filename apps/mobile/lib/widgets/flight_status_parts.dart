import 'package:flutter/material.dart';

import '../data/models/flight.dart';
import '../data/models/hub_flight.dart';
import '../l10n/places.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import 'flight_parts.dart' show adminFlightBadge;
import 'ui.dart';

/// Flight status from the airline: the pill and note each flight shows, the
/// banners that ask a person to confirm, the Flight tracking card and the
/// note about orders that moved when the flight left.

/// More than a few minutes off the plan.
bool isOffPlan(int? minutes) => minutes != null && minutes.abs() >= 5;

/// "23 min late", "27 min early", "1 h 35 min late" or "on time".
String lateText(int minutes) {
  if (!isOffPlan(minutes)) return tr('on time');
  final total = minutes.abs();
  final h = total ~/ 60, m = total % 60;
  if (minutes > 0) {
    if (h == 0) return tr('{n} min late', {'n': m});
    if (m == 0) return tr('{h} h late', {'h': h});
    return tr('{h} h {m} min late', {'h': h, 'm': m});
  }
  if (h == 0) return tr('{n} min early', {'n': m});
  if (m == 0) return tr('{h} h early', {'h': h});
  return tr('{h} h {m} min early', {'h': h, 'm': m});
}

/// The same with a capital first letter, for a pill.
String lateLabel(int minutes) {
  final text = lateText(minutes);
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

String _two(int n) => n.toString().padLeft(2, '0');

/// When the airline was asked, on this phone's clock: "14:10", or
/// "13 Nov 14:10" on another day.
String checkedLabel(DateTime at, {DateTime? now}) {
  final local = at.toLocal();
  final clock = '${_two(local.hour)}:${_two(local.minute)}';
  final today = (now ?? DateTime.now()).toLocal();
  if (local.year == today.year &&
      local.month == today.month &&
      local.day == today.day) {
    return clock;
  }
  final day = FlightDay.parse(
      '${local.year}-${_two(local.month)}-${_two(local.day)}',
      today: today);
  return day == null ? clock : '${day.day} ${day.month} $clock';
}

/// What a flight shows for its status: the pill, a line under it and
/// whether it asks a person to confirm what happened.
class FlightLook {
  const FlightLook(this.label, this.tone,
      {this.icon,
      this.note,
      this.noteTone = ChipTone.neutral,
      this.confirm = false});
  final String label;
  final ChipTone tone;
  final IconData? icon;
  final String? note;
  final ChipTone noteTone;

  /// The date is over with no word from the airline: Confirm status.
  final bool confirm;

  bool get cancelled => tone == ChipTone.red;
}

/// A cancelled flight still waiting for a person.
bool flightCancelled(String status, FlightTracking? tracking) =>
    status == 'upcoming' && (tracking?.cancelled ?? false);

/// Pill and note for a flight, from its status and what the airline said.
/// [plain] gives the usual pill for an upcoming flight.
FlightLook flightLook(
    {required String status,
    required bool dateOver,
    required FlightTracking? tracking,
    required (String, ChipTone) plain}) {
  final t = tracking;
  if (status == 'completed') {
    final at = t?.landed == true ? t!.landsAt : null;
    final late = t?.landed == true ? t!.landsLateMin : null;
    return FlightLook(
        at == null ? tr('Landed') : tr('Landed {time}', {'time': at}),
        ChipTone.green,
        icon: Icons.flight_land_rounded,
        noteTone: ChipTone.green,
        note: at == null
            ? null
            : [
                late == null
                    ? tr('Landed')
                    : tr('Landed {late}', {'late': lateText(late)}),
                tr('from the airline'),
              ].join(' · '));
  }
  if (status == 'departed') {
    String? note;
    if (t != null && t.left) {
      final lands = t.landsAt;
      final late = t.landsLateMin;
      note = [
        if (t.leftAt != null) tr('Left {time}', {'time': t.leftAt}),
        if (lands != null)
          isOffPlan(late)
              ? tr('lands {time}, {late}',
                  {'time': lands, 'late': lateText(late!)})
              : tr('lands {time}', {'time': lands}),
        tr('from the airline'),
      ].join(' · ');
    }
    return FlightLook(tr('On the way'), ChipTone.amber,
        icon: Icons.flight_takeoff_rounded,
        note: note,
        noteTone: ChipTone.amber);
  }
  if (t?.cancelled ?? false) {
    return FlightLook(tr('Cancelled by airline'), ChipTone.red,
        icon: Icons.error_outline_rounded,
        note: tr('Nothing changed here. Move it to the new date.'),
        noteTone: ChipTone.red);
  }
  if (dateOver) {
    return FlightLook(tr('Date has passed'), ChipTone.amber,
        icon: Icons.error_outline_rounded,
        note: tr('No update from the airline. Confirm what happened.'),
        noteTone: ChipTone.amber,
        confirm: true);
  }
  final waiting = t?.waitingLate;
  return FlightLook(plain.$1, plain.$2,
      note: waiting == null
          ? null
          : [
              tr('Leaves {time}, {late}', {
                'time': waiting.depLocal ?? waiting.plannedDep,
                'late': lateText(waiting.depLateMin!)
              }),
              tr('from the airline'),
            ].join(' · '),
      noteTone: ChipTone.amber);
}

/// The look of an admin flight row or page.
FlightLook adminFlightLook(FlightSummary row, FlightDay? day,
        {bool next = false, bool detail = false}) =>
    flightLook(
        status: row.status,
        dateOver: row.scheduleNeedsConfirmation,
        tracking: row.tracking,
        plain: adminFlightBadge(row, day, next: next, detail: detail));

/// A pill with an optional icon in front.
class LookPill extends StatelessWidget {
  const LookPill({super.key, required this.look});
  final FlightLook look;

  @override
  Widget build(BuildContext context) {
    final colors = toneColors(look.tone);
    return Container(
        padding: EdgeInsets.fromLTRB(look.icon == null ? 10 : 8, 2, 10, 2),
        decoration: BoxDecoration(
            color: colors.background, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (look.icon != null) ...[
            Icon(look.icon, size: 14, color: colors.foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
              child: Text(look.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colors.foreground,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.5))),
        ]));
  }
}

Color _noteColor(ChipTone tone) => switch (tone) {
      ChipTone.red => AppColors.danger,
      ChipTone.amber => AppColors.accentInk,
      ChipTone.green => AppColors.ok,
      _ => AppColors.muted,
    };

/// One line under a flight: what the airline said, or what to do.
class StatusNote extends StatelessWidget {
  const StatusNote({super.key, required this.text, this.tone});
  final String text;
  final ChipTone? tone;

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontSize: 13,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: _noteColor(tone ?? ChipTone.neutral)));
}

/// The orange "Confirm status" button.
class ConfirmStatusButton extends StatelessWidget {
  const ConfirmStatusButton({super.key, required this.onPressed, this.label});
  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontFamily: 'HindSiliguri',
              fontSize: 14,
              fontWeight: FontWeight.w700)),
      icon: const Icon(Icons.check_rounded, size: 18),
      label: Text(label ?? tr('Confirm status')));
}

/// A tinted box with an icon, a title, a line and optional buttons.
class FlightBanner extends StatelessWidget {
  const FlightBanner(
      {super.key,
      required this.tone,
      required this.icon,
      required this.title,
      required this.body,
      this.actions = const []});
  final ChipTone tone;
  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, line) = switch (tone) {
      ChipTone.red => (
          AppColors.dangerSoft,
          AppColors.danger,
          AppColors.dangerLine
        ),
      ChipTone.green => (
          AppColors.okSoft,
          AppColors.ok,
          const Color(0xFFB9DEC8)
        ),
      _ => (AppColors.accentSoft, AppColors.accentInk, AppColors.accentLine),
    };
    return Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
            color: background,
            border: Border.all(color: line),
            borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 20, color: foreground)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: foreground)),
                const SizedBox(height: 2),
                Text(body,
                    style: const TextStyle(
                        fontSize: 13, height: 1.45, color: AppColors.inkSoft)),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: actions),
                ],
              ])),
        ]));
  }
}

String _place(String iata, String city) => [
      iata,
      banglaPlace(city, fallback: '')
    ].where((part) => part.trim().isNotEmpty).join(' ');

/// Each leg as the airline saw it, when it was last asked and when the
/// next check comes.
class FlightTrackingCard extends StatelessWidget {
  const FlightTrackingCard({super.key, required this.tracking});
  final FlightTracking tracking;

  static (String, ChipTone) _chip(TrackingLeg leg) => switch (leg.state) {
        'landed' => (tr('Landed'), ChipTone.green),
        'in_air' => (tr('In the air'), ChipTone.amber),
        'cancelled' => (tr('Cancelled'), ChipTone.red),
        'waiting' => (tr('Not left yet'), ChipTone.neutral),
        _ => (tr('No data'), ChipTone.neutral),
      };

  static String _line(TrackingLeg leg) {
    final dep = leg.depLocal ?? leg.plannedDep;
    final arr = leg.arrLocal ?? leg.plannedArr;
    switch (leg.state) {
      case 'landed':
        return tr('Left {dep} · landed {arr}', {'dep': dep, 'arr': arr});
      case 'in_air':
        return [
          isOffPlan(leg.depLateMin)
              ? tr('Left {time}, planned {planned}',
                  {'time': dep, 'planned': leg.plannedDep})
              : tr('Left {time}', {'time': dep}),
          tr('lands {time}', {'time': arr}),
        ].join(' · ');
      case 'cancelled':
        return tr('Airline status: cancelled');
      case 'waiting':
        return isOffPlan(leg.depLateMin)
            ? tr('Leaves {time}, {late}',
                {'time': dep, 'late': lateText(leg.depLateMin!)})
            : tr('Leaves {time}', {'time': dep});
      default:
        return tr('No data from the airline for this day');
    }
  }

  @override
  Widget build(BuildContext context) {
    final footer = switch (tracking.nextCheck) {
      'after_landing' => tr(
          'Updated from the airline by itself. Next check soon after it lands. You can still change the status in Edit.'),
      'after_takeoff' => tr(
          'Updated from the airline by itself. Next check soon after it takes off. You can still change the status in Edit.'),
      _ => tr(
          'Updated from the airline by itself. You can still change the status in Edit.'),
    };
    return PaperCard(
        key: const Key('flight-tracking'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Text(tr('Flight tracking'),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.3))),
            const Icon(Icons.sync_rounded, size: 14, color: AppColors.muted),
            const SizedBox(width: 4),
            Text(
                tr('Checked {time}',
                    {'time': checkedLabel(tracking.checkedAt)}),
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
          const SizedBox(height: 12),
          for (final (i, leg) in tracking.legs.indexed)
            _LegRow(
                leg: leg,
                chip: _chip(leg),
                line: _line(leg),
                last: i == tracking.legs.length - 1),
          const Divider(height: 20, color: AppColors.lineSoft),
          Text(footer,
              style: const TextStyle(
                  fontSize: 13, height: 1.45, color: AppColors.muted)),
        ]));
  }
}

class _LegRow extends StatelessWidget {
  const _LegRow(
      {required this.leg,
      required this.chip,
      required this.line,
      required this.last});
  final TrackingLeg leg;
  final (String, ChipTone) chip;
  final String line;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final done = leg.state == 'landed';
    final dot = done ? AppColors.ok : AppColors.primary;
    final from = _place(leg.fromIata, leg.fromCity);
    final to = _place(leg.toIata, leg.toCity);
    return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
          width: 16,
          child: Column(children: [
            const SizedBox(height: 3),
            Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(color: dot, spreadRadius: 1.5)])),
            if (!last)
              Expanded(
                  child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      color: AppColors.line)),
          ])),
      const SizedBox(width: 12),
      Expanded(
          child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(leg.code,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35))),
                      StatusPill(label: chip.$1, tone: chip.$2),
                    ]),
                    if (from.isNotEmpty || to.isNotEmpty)
                      Text(
                          tr('{from} to {to}', {
                            'from': from.isEmpty ? '?' : from,
                            'to': to.isEmpty ? '?' : to
                          }),
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: AppColors.muted)),
                    Text(line,
                        style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AppColors.inkSoft)),
                  ]))),
    ]));
  }
}

/// Above the orders of a flight that left: which moved to In transit by
/// themselves, and which did not and why.
class OrdersMovedNotes extends StatelessWidget {
  const OrdersMovedNotes(
      {super.key,
      required this.moved,
      required this.notMoved,
      required this.leftAt});
  final MovedOrders? moved;
  final List<NotMovedOrder> notMoved;

  /// The first take-off from the airline, local HH:mm.
  final String? leftAt;

  static String _why(NotMovedOrder order) => switch (order.reason) {
        'not_ready' => order.status == 'pending'
            ? tr(
                'It was not at the China hub yet. Check if it is on this flight.')
            : tr(
                'It was still at the China hub, not ready for shipment. Check if it is on this flight.'),
        'no_flyer' => tr(
            'It has no carrying flyer. Pick the flyer on the order to move it.'),
        'exception' =>
          tr('It has a problem to sort out first. Open the order.'),
        _ => tr(
            'It is ready for shipment but did not move. Open the order to move it.'),
      };

  @override
  Widget build(BuildContext context) {
    final codes = moved?.codes ?? const <String>[];
    final notes = <Widget>[
      if (codes.isNotEmpty)
        FlightBanner(
            key: const Key('orders-moved'),
            tone: ChipTone.green,
            icon: Icons.check_circle_outline_rounded,
            title: trn(codes.length, '{n} order moved to In transit',
                '{n} orders moved to In transit'),
            body: moved!.byAirline
                ? leftAt == null
                    ? tr('They moved when the airline said the flight left.')
                    : tr('They moved when the flight left at {time}.',
                        {'time': leftAt})
                : tr('They moved when {name} set the flight as left.',
                    {'name': moved!.by})),
      if (notMoved.length > 3)
        FlightBanner(
            key: const Key('orders-not-moved'),
            tone: ChipTone.amber,
            icon: Icons.warning_amber_rounded,
            title: trn(notMoved.length, '{n} order did not move',
                '{n} orders did not move'),
            body: tr('Open each one to check if it is on this flight: {codes}.',
                {'codes': notMoved.map((o) => o.code).join(', ')}))
      else
        for (final order in notMoved)
          FlightBanner(
              key: ValueKey('not-moved-${order.code}'),
              tone: ChipTone.amber,
              icon: Icons.warning_amber_rounded,
              title: tr('{code} did not move', {'code': order.code}),
              body: _why(order)),
    ];
    if (notes.isEmpty) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (i, note) in notes.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            note,
          ],
        ]));
  }
}

/// Hub: when the flight lands, from the airline, with a line from the
/// first airport to the last and the plane on it.
class HubLandingCard extends StatelessWidget {
  const HubLandingCard({super.key, required this.flight, this.onTrack});
  final HubFlight flight;

  /// Opens the map while the plane is in the air.
  final VoidCallback? onTrack;

  @override
  Widget build(BuildContext context) {
    final t = flight.tracking!;
    final place = banglaPlace(flight.to, fallback: tr('Bangladesh'));
    final late = t.landsLateMin;
    final lastLeft = t.lastLeft;
    final details = [
      if (isClockText(t.plannedArr))
        tr('Planned {time}', {'time': t.plannedArr}),
      if (!t.landed && lastLeft != null && lastLeft.at != null)
        tr('left {place} {time}', {
          'place': banglaPlace(
              lastLeft.city.isNotEmpty ? lastLeft.city : lastLeft.iata,
              fallback: tr('China')),
          'time': lastLeft.at
        }),
    ].join(' · ');
    return PaperCard(
        key: const Key('hub-landing'),
        radius: heroRadius,
        border: const BorderSide(color: AppColors.primary, width: 1.5),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
              t.landed
                  ? tr('Landed in {place}', {'place': place})
                  : tr('Lands in {place}', {'place': place}),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted)),
          const SizedBox(height: 2),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: Text(t.landsAt ?? '--:--',
                    style: const TextStyle(
                        fontSize: 34,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()]))),
            if (late != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: LookPill(
                      look: FlightLook(lateLabel(late),
                          late >= 5 ? ChipTone.amber : ChipTone.green,
                          icon: Icons.schedule_rounded))),
          ]),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(details,
                style: const TextStyle(
                    fontSize: 13, height: 1.45, color: AppColors.muted)),
          ],
          const SizedBox(height: 10),
          _LegProgress(tracking: t),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.sync_rounded, size: 14, color: AppColors.muted),
            const SizedBox(width: 4),
            Expanded(
                child: Text(
                    tr('From the airline · checked {time}',
                        {'time': checkedLabel(t.checkedAt)}),
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted))),
          ]),
          if (onTrack != null && t.left && !t.landed) ...[
            const SizedBox(height: 12),
            AppButton(
                key: const Key('hub-track'),
                label: tr('Track this flight'),
                icon: Icons.map_outlined,
                kind: AppButtonKind.tonal,
                onPressed: onTrack),
          ],
        ]));
  }
}

bool isClockText(String value) =>
    RegExp(r'^\d{1,2}:\d{2}').hasMatch(value.trim());

/// Airports along the way with the plane where it is now.
class _LegProgress extends StatelessWidget {
  const _LegProgress({required this.tracking});
  final FlightTracking tracking;

  @override
  Widget build(BuildContext context) {
    final legs = tracking.legs;
    final stops = [
      if (legs.isNotEmpty) legs.first.fromIata,
      for (final leg in legs) leg.toIata,
    ].map((code) => code.isEmpty ? '·' : code).toList();
    // In the air on leg i of n: halfway along it. Landed: at the end.
    var at = 0.0;
    if (tracking.landed) {
      at = 1;
    } else {
      final inAir = legs.indexWhere((leg) => leg.state == 'in_air');
      final done = legs.where((leg) => leg.state == 'landed').length;
      at = legs.isEmpty
          ? 0
          : inAir >= 0
              ? (inAir + 0.5) / legs.length
              : done / legs.length;
    }
    return SizedBox(
        height: 40,
        child: LayoutBuilder(builder: (context, box) {
          final width = box.maxWidth;
          final step = stops.length > 1 ? width / (stops.length - 1) : width;
          return Stack(clipBehavior: Clip.none, children: [
            Positioned(
                left: 0,
                right: 0,
                top: 10,
                child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(2)))),
            Positioned(
                left: 0,
                top: 10,
                child: Container(
                    width: width * at,
                    height: 3,
                    decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2)))),
            for (final (i, code) in stops.indexed) ...[
              Positioned(
                  left: (i * step - 5).clamp(-5, width - 6),
                  top: 6,
                  child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                          color: i * step <= width * at + 0.5
                              ? AppColors.primary
                              : AppColors.card,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: i * step <= width * at + 0.5
                                  ? AppColors.primary
                                  : AppColors.faint,
                              width: 2)))),
              Positioned(
                  left: i == 0
                      ? 0
                      : i == stops.length - 1
                          ? null
                          : i * step - 14,
                  right: i == stops.length - 1 ? 0 : null,
                  top: 22,
                  child: Text(code,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted))),
            ],
            if (!tracking.landed)
              Positioned(
                  left: (width * at - 11).clamp(-4, width - 18),
                  top: 0,
                  child: const RotatedBox(
                      quarterTurns: 1,
                      child: Icon(Icons.flight_rounded,
                          size: 22, color: AppColors.primary))),
          ]);
        }));
  }
}
