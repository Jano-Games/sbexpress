import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models/flight.dart';
import '../data/models/hub_flight.dart';
import '../features/flights/hub_flights_screen.dart' show banglaPlace;
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import 'ui.dart';

/// Parts shared by the admin flight, shipment bill and booking screens.

/// Status label and tone for an admin flight. With [detail] an upcoming
/// flight reads "Upcoming · In 3 days".
(String, ChipTone) adminFlightBadge(FlightSummary row, FlightDay? day,
    {bool next = false, bool detail = false}) {
  switch (row.status) {
    case 'departed':
      return (tr('Departed'), ChipTone.amber);
    case 'completed':
      return (tr('Completed'), ChipTone.green);
  }
  if (row.scheduleNeedsConfirmation || (day != null && day.daysAway < 0)) {
    return (tr('Date not updated'), ChipTone.amber);
  }
  final when = day?.relativeLabel;
  if (detail) {
    return (
      [tr('Upcoming'), if (when != null) when].join(' · '),
      ChipTone.blue
    );
  }
  if (next) {
    return (
      when == null
          ? tr('Up next')
          : tr('Next · {when}', {'when': isBangla ? when : _lowerFirst(when)}),
      ChipTone.blue
    );
  }
  return (when ?? tr('Upcoming'), ChipTone.neutral);
}

String _lowerFirst(String text) =>
    text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);

/// Secondary white type on the navy money surface.
const heroSoft = Color(0xBFFFFFFF);

/// Amounts still owed, on the navy money surface.
const heroAlert = Color(0xFFFFB3B0);

const _heroRule = Color(0x24FFFFFF);

/// Navy money summary: a label, a large amount and optional details below.
class MoneyHero extends StatelessWidget {
  const MoneyHero(
      {super.key,
      required this.label,
      required this.amount,
      this.trailing,
      this.children = const [],
      this.amountSize = 30});
  final String label, amount;
  final Widget? trailing;
  final List<Widget> children;
  final double amountSize;

  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(heroRadius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, color: heroSoft, height: 1.4)),
                FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(amount,
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: amountSize,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ]))),
              ])),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ]),
        for (final child in children) ...[const SizedBox(height: 14), child],
      ]));
}

/// One figure on the navy surface.
class HeroFigure {
  const HeroFigure(this.label, this.value, {this.alert = false});
  final String label, value;

  /// Pink when money is still owed.
  final bool alert;
}

/// A ruled row of figures under the hero amount.
class HeroFigures extends StatelessWidget {
  const HeroFigures({super.key, required this.figures, this.size = 15});
  final List<HeroFigure> figures;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _heroRule))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < figures.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                WordFitText(figures[i].label,
                    style: const TextStyle(
                        fontSize: 12, color: heroSoft, height: 1.35)),
                FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(figures[i].value,
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: size,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: figures[i].alert ? heroAlert : Colors.white,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ]))),
              ])),
        ]
      ]));
}

/// Ruled label–amount lines under the hero amount.
class HeroLines extends StatelessWidget {
  const HeroLines({super.key, required this.lines});
  final List<(String, String)> lines;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: _heroRule))),
      child: Column(children: [
        for (var i = 0; i < lines.length; i++)
          Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Text(lines[i].$1,
                        style: const TextStyle(
                            fontSize: 13, color: heroSoft, height: 1.4))),
                const SizedBox(width: 8),
                Text(lines[i].$2,
                    style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ])),
      ]));
}

/// Translucent pill button on the navy surface, e.g. "Ticket money ›".
class HeroButton extends StatelessWidget {
  const HeroButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
      color: const Color(0x1FFFFFFF),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
              constraints: const BoxConstraints(
                  minHeight: minTouchTarget, maxWidth: 160),
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                        child: Text(label,
                            maxLines: 2,
                            style: const TextStyle(
                                fontSize: 13,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                                color: Colors.white))),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: Colors.white),
                  ])))));
}

/// Card heading: tinted icon, title and a short line under it.
class CardHeading extends StatelessWidget {
  const CardHeading(
      {super.key,
      required this.icon,
      required this.title,
      this.subtitle,
      this.tone = ChipTone.blue,
      this.trailing});
  final IconData icon;
  final String title;
  final String? subtitle;
  final ChipTone tone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        IconBadge(icon, tone: tone),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, height: 1.3)),
          if (subtitle != null)
            Text(subtitle!,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.muted, height: 1.4)),
        ])),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ]);
}

/// Card title without an icon.
class CardTitle extends StatelessWidget {
  const CardTitle(
      {super.key, required this.title, this.subtitle, this.size = 17});
  final String title;
  final String? subtitle;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                fontSize: size, fontWeight: FontWeight.w700, height: 1.3)),
        if (subtitle != null)
          Text(subtitle!,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.muted, height: 1.45)),
      ]);
}

/// First letter of a name, for avatars.
String initialOf(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
}

/// Initial in a circle (people) or a rounded square (customers).
class LetterAvatar extends StatelessWidget {
  const LetterAvatar(this.name,
      {super.key,
      this.size = 38,
      this.square = false,
      this.color = AppColors.primary,
      this.foreground = Colors.white});
  final String name;
  final double size;
  final bool square;
  final Color color, foreground;

  /// Customer style: soft blue square with a blue letter.
  const LetterAvatar.customer(this.name, {super.key, this.size = 44})
      : square = true,
        color = AppColors.primarySoft,
        foreground = AppColors.primary;

  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: color,
          shape: square ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: square ? BorderRadius.circular(size * 0.28) : null),
      child: Text(initialOf(name),
          style: TextStyle(
              fontSize: size * 0.4,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: foreground)));
}

/// Rounded progress bar on a pale track.
class MeterBar extends StatelessWidget {
  const MeterBar(
      {super.key,
      required this.value,
      this.height = 8,
      this.color = AppColors.primary});
  final double value, height;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
          value: value.isNaN ? 0 : value.clamp(0.0, 1.0),
          minHeight: height,
          color: color,
          backgroundColor: AppColors.lineSoft));
}

String _kg(double value) =>
    value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);

/// "31.5 / 44 kg booked" with the free or over weight beside it.
class CapacityText extends StatelessWidget {
  const CapacityText(
      {super.key,
      required this.booked,
      required this.space,
      this.extra,
      this.size = 13});
  final double booked, space;

  /// Muted text after the booked figure, e.g. "· 4 shipments".
  final String? extra;
  final double size;

  @override
  Widget build(BuildContext context) {
    final left = space - booked;
    final over = left < 0;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
          child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: tr('{booked} / {space} kg booked', {
                      'booked': booked.toStringAsFixed(1),
                      'space': _kg(space)
                    }),
                    style: TextStyle(
                        fontWeight:
                            size > 13 ? FontWeight.w700 : FontWeight.w600)),
                if (extra != null)
                  TextSpan(
                      text: ' $extra',
                      style: const TextStyle(color: AppColors.muted)),
              ]),
              style: TextStyle(fontSize: size, height: 1.4))),
      const SizedBox(width: 8),
      Text(
          over
              ? tr('{kg} kg over', {'kg': _kg(-left)})
              : tr('{kg} kg free', {'kg': _kg(left)}),
          style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: over ? AppColors.danger : AppColors.muted)),
    ]);
  }
}

/// Plane on a dashed line between departure and arrival.
class DashedPlane extends StatelessWidget {
  const DashedPlane({super.key, this.size = 18, this.highlight = false});
  final double size;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final big = size > 24;
    return SizedBox(
        width: double.infinity,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          Positioned.fill(
              child: CustomPaint(painter: _DashPainter(width: big ? 2 : 1.5))),
          Container(
              width: big ? size : size + 10,
              height: size,
              decoration: big
                  ? const BoxDecoration(
                      color: AppColors.primarySoft, shape: BoxShape.circle)
                  : const BoxDecoration(color: AppColors.card),
              child: Icon(Icons.flight_rounded,
                  size: big ? size * 0.55 : size * 0.85,
                  color: big || highlight ? AppColors.primary : AppColors.muted,
                  semanticLabel: tr('Flight'))),
        ]));
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.width});
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC3CAD5)
      ..strokeWidth = width;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(
          Offset(x, y), Offset((x + 4).clamp(0, size.width), y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter oldDelegate) =>
      oldDelegate.width != width;
}

bool isClockTime(String value) =>
    RegExp(r'^\d{1,2}:\d{2}').hasMatch(value.trim());

/// "Direct" or "via Kunming" for the stops between two airports. A stop
/// such as "KMG Kunming" shows the city alone.
String stopText(String? stop) {
  if (stop == null) return tr('Direct');
  final cities = [
    for (final part in stop.split(','))
      if (part.trim().isNotEmpty)
        () {
          final place = part.trim().replaceFirst(RegExp(r'^[A-Z]{3}\s+'), '');
          return banglaPlace(place, fallback: place);
        }()
  ];
  return tr('via {stop}', {'stop': cities.join(', ')});
}

/// Departure, the stop and arrival on one line, as on the flight cards.
class RouteLine extends StatelessWidget {
  const RouteLine(
      {super.key,
      required this.depTime,
      required this.arrTime,
      required this.from,
      required this.to,
      required this.stop,
      this.highlight = false});
  final String depTime, arrTime, from, to;
  final String? stop;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    Widget end(String time, String city, {bool right = false}) {
      final known = isClockTime(time);
      return Column(
          crossAxisAlignment:
              right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(known ? time : '--:--',
                style: TextStyle(
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: known ? AppColors.ink : AppColors.faint,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            Text(city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]);
    }

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Flexible(flex: 2, child: end(depTime, from)),
      const SizedBox(width: 8),
      Expanded(
          flex: 3,
          child: Column(children: [
            DashedPlane(highlight: highlight),
            Text(stopText(stop),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, height: 1.3, color: AppColors.muted)),
          ])),
      const SizedBox(width: 8),
      Flexible(flex: 2, child: end(arrTime, to, right: true)),
    ]);
  }
}

/// Large departure and arrival ends for the flight detail card.
class RouteEnds extends StatelessWidget {
  const RouteEnds(
      {super.key,
      required this.depTime,
      required this.arrTime,
      required this.from,
      required this.to,
      required this.stop});
  final String depTime, arrTime, from, to;
  final String? stop;

  @override
  Widget build(BuildContext context) {
    Widget end(String city, String time, String note, {bool right = false}) {
      final known = isClockTime(time);
      return Column(
          crossAxisAlignment:
              right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(known ? time : '--:--',
                    style: TextStyle(
                        fontSize: 26,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: known ? AppColors.ink : AppColors.faint,
                        fontFeatures: const [FontFeature.tabularFigures()]))),
            Text(note,
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]);
    }

    return Row(children: [
      Flexible(flex: 3, child: end(from, depTime, tr('Departs'))),
      const SizedBox(width: 10),
      Expanded(
          flex: 4,
          child: Column(children: [
            const DashedPlane(size: 34),
            const SizedBox(height: 4),
            Text(stopText(stop),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ])),
      const SizedBox(width: 10),
      Flexible(flex: 3, child: end(to, arrTime, tr('Arrives'), right: true)),
    ]);
  }
}

/// Day number over "Oct · Wed"; blue for the next flight. The second line
/// shrinks to fit long weekday names such as "বৃহস্পতি".
class DateBlock extends StatelessWidget {
  const DateBlock({super.key, required this.day, this.highlight = false});
  final FlightDay? day;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final date = day;
    return Container(
        width: 56,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
            color: highlight ? AppColors.primary : AppColors.paper,
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(date == null ? '—' : '${date.day}',
              style: TextStyle(
                  fontSize: 21,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  color: highlight ? Colors.white : AppColors.ink)),
          FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(date == null ? '' : '${date.month} · ${date.weekday}',
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: highlight
                          ? const Color(0xE6FFFFFF)
                          : AppColors.muted))),
        ]));
  }
}

/// "Wed 21 Oct" in the app language; the raw text when it is not a date.
String shortDay(String iso) {
  final day = FlightDay.parse(iso);
  return day == null ? iso : '${day.weekday} ${day.day} ${day.month}';
}

/// "17 Oct"; the raw text when it is not a date.
String dayMonth(String iso) {
  final day = FlightDay.parse(iso);
  return day == null ? iso : '${day.day} ${day.month}';
}

/// One label and value in a two-column fact grid.
class Fact {
  const Fact(this.label, this.value, {this.onTap, this.color});
  final String label, value;

  /// Shows the value as a blue link with a chevron.
  final VoidCallback? onTap;
  final Color? color;
}

/// Two columns of small label and bold value.
class FactGrid extends StatelessWidget {
  const FactGrid({super.key, required this.facts});
  final List<Fact> facts;

  @override
  Widget build(BuildContext context) {
    Widget cell(Fact fact) {
      final link = fact.onTap != null;
      final value = Text(fact.value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: link ? AppColors.primary : fact.color ?? AppColors.ink));
      final body =
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(fact.label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.muted, height: 1.4)),
        if (link)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: value),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.primary),
          ])
        else
          value,
      ]);
      if (!link) return body;
      return InkWell(
          onTap: fact.onTap,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: minTouchTarget),
              child: Align(alignment: Alignment.topLeft, child: body)));
    }

    return Column(children: [
      for (var i = 0; i < facts.length; i += 2)
        Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: cell(facts[i])),
              const SizedBox(width: 16),
              Expanded(
                  child: i + 1 < facts.length
                      ? cell(facts[i + 1])
                      : const SizedBox.shrink()),
            ])),
    ]);
  }
}

/// Grey icon, label and value on one row, as in "Handling and delivery".
class IconValueRow extends StatelessWidget {
  const IconValueRow(
      {super.key,
      required this.icon,
      required this.label,
      required this.value,
      this.done = false});
  final IconData icon;
  final String label, value;

  /// Darker value once the step has happened.
  final bool done;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
          builder: (context, constraints) => Row(children: [
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: done ? AppColors.okSoft : AppColors.paper,
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon,
                        size: 19,
                        color: done ? AppColors.ok : AppColors.muted)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.inkSoft,
                            height: 1.4))),
                const SizedBox(width: 8),
                ConstrainedBox(
                    constraints:
                        BoxConstraints(maxWidth: constraints.maxWidth * 0.48),
                    child: Text(value,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            fontWeight:
                                done ? FontWeight.w600 : FontWeight.w400,
                            color: done ? AppColors.ink : AppColors.muted))),
              ])));
}

/// Grey strip of up to three figures with dividers between them.
class StatStrip extends StatelessWidget {
  const StatStrip({super.key, required this.items});
  final List<(String, String, Color?)> items;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: AppColors.paper, borderRadius: BorderRadius.circular(14)),
      child: IntrinsicHeight(
          child: Row(children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const VerticalDivider(width: 1, color: AppColors.line),
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].$1,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: AppColors.muted)),
                        FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(items[i].$2,
                                maxLines: 1,
                                style: TextStyle(
                                    fontSize: 16,
                                    height: 1.35,
                                    fontWeight: FontWeight.w700,
                                    color: items[i].$3 ?? AppColors.ink,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ]))),
                      ]))),
        ]
      ])));
}

/// Orange "do this now" note, optionally with an action under it.
class ActionNote extends StatelessWidget {
  const ActionNote({super.key, required this.text, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
          color: AppColors.accentSoft,
          border: Border.all(color: AppColors.accentLine),
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.warning_amber_rounded,
                  size: 18, color: AppColors.accentInk)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accentInk))),
        ]),
        if (action != null) ...[const SizedBox(height: 10), action!],
      ]));
}

/// White button with an orange outline, for the step to do now.
class AccentOutlineButton extends StatelessWidget {
  const AccentOutlineButton(
      {super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.card,
          foregroundColor: AppColors.accentInk,
          minimumSize: const Size(48, 46),
          side: const BorderSide(color: AppColors.accent, width: 1.5)),
      child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19),
              const SizedBox(width: 8)
            ],
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ]));
}

/// Compact outlined button for a row of card actions.
class SmallOutlineButton extends StatelessWidget {
  const SmallOutlineButton(
      {super.key, required this.icon, required this.label, this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          textStyle: const TextStyle(
              fontFamily: 'HindSiliguri',
              fontSize: 14,
              height: 1.25,
              fontWeight: FontWeight.w600)),
      child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17),
            const SizedBox(width: 5),
            Flexible(
                child: WordFitText(label,
                    textAlign: TextAlign.center, maxLines: 2)),
          ]));
}

/// Square outlined icon button, e.g. view or share a PDF.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton(
      {super.key,
      required this.icon,
      required this.tooltip,
      required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton.outlined(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
          minimumSize: const Size(46, 46),
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.field),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(controlRadius))),
      icon: Icon(icon, size: 20));
}

/// Currency sign kept visible inside an empty amount field.
Widget currencyPrefix(String currency) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 14, end: 6),
    child: Text(currency == 'CNY' ? '¥' : '৳',
        style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.muted)));

const currencyPrefixConstraints = BoxConstraints(minWidth: 0, minHeight: 0);

/// Bold small label above a form control.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13, height: 1.35, fontWeight: FontWeight.w600)));
}

/// Row with a radio dot, a title and a line under it.
class RadioRow extends StatelessWidget {
  const RadioRow(
      {super.key,
      required this.selected,
      required this.title,
      required this.onTap,
      this.subtitle,
      this.leading,
      this.trailing});
  final bool selected;
  final String title;
  final String? subtitle;
  final Widget? leading, trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
          color: selected ? AppColors.primarySoft : Colors.transparent,
          child: InkWell(
              onTap: onTap,
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : const Color(0xFFC3CAD5),
                                width: 2)),
                        child: selected
                            ? Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle))
                            : null),
                    const SizedBox(width: 12),
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 12)
                    ],
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(title,
                              style: TextStyle(
                                  fontSize: 15,
                                  height: 1.35,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w600)),
                          if (subtitle != null)
                            Text(subtitle!,
                                style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: selected
                                        ? AppColors.inkSoft
                                        : AppColors.muted)),
                        ])),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!
                    ],
                  ])))));
}

/// Rows separated by hairlines inside one white card.
class RowCard extends StatelessWidget {
  const RowCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => PaperCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.lineSoft),
          children[i],
        ]
      ]));
}

/// Pill-shaped toggle chip with a check when chosen.
class CategoryChip extends StatelessWidget {
  const CategoryChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      selected: selected,
      child: Material(
          color: selected ? AppColors.primarySoft : AppColors.card,
          shape: StadiumBorder(
              side: BorderSide(
                  color: selected ? AppColors.primary : AppColors.field,
                  width: selected ? 1.5 : 1)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: 44, minWidth: 48),
                  child: Padding(
                      padding:
                          EdgeInsets.fromLTRB(selected ? 10 : 14, 8, 14, 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (selected) ...[
                          const Icon(Icons.check_rounded,
                              size: 17, color: AppColors.primaryInk),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                            child: Text(label,
                                style: TextStyle(
                                    fontSize: 14,
                                    height: 1.3,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: selected
                                        ? AppColors.primaryInk
                                        : AppColors.ink))),
                      ]))))));
}

/// − count + control inside a field-shaped box.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper(
      {super.key,
      required this.value,
      required this.onChanged,
      this.min = 1,
      this.max = 20});
  final int value, min, max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, String tip, int next, bool primary) {
      final enabled = next >= min && next <= max;
      return Material(
          color: primary ? AppColors.primarySoft : AppColors.paper,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: enabled ? () => onChanged(next) : null,
              child: Tooltip(
                  message: tip,
                  child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(icon,
                          size: 20,
                          color: !enabled
                              ? AppColors.faint
                              : primary
                                  ? AppColors.primary
                                  : AppColors.ink)))));
    }

    return Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.field, width: 1.5),
            borderRadius: BorderRadius.circular(controlRadius)),
        child: Row(children: [
          step(Icons.remove_rounded, tr('One fewer'), value - 1, false),
          Expanded(
              child: Text('$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700))),
          step(Icons.add_rounded, tr('One more'), value + 1, true),
        ]));
  }
}

/// Numbered wizard steps with a bar above each; finished steps get a check
/// and can be tapped to go back.
class WizardSteps extends StatelessWidget {
  const WizardSteps(
      {super.key,
      required this.labels,
      required this.current,
      required this.onBack});
  final List<String> labels;
  final int current;
  final ValueChanged<int> onBack;

  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
              child: Semantics(
                  button: i < current,
                  selected: i == current,
                  label: tr('Step {step}/{total}',
                      {'step': i + 1, 'total': labels.length}),
                  child: InkWell(
                      onTap: i < current ? () => onBack(i) : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                        color: i <= current
                                            ? AppColors.primary
                                            : AppColors.line,
                                        borderRadius:
                                            BorderRadius.circular(2))),
                                const SizedBox(height: 6),
                                Row(children: [
                                  Container(
                                      width: 22,
                                      height: 22,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: i == current
                                              ? AppColors.primary
                                              : i < current
                                                  ? AppColors.primarySoft
                                                  : AppColors.lineSoft),
                                      child: i < current
                                          ? const Icon(Icons.check_rounded,
                                              size: 15,
                                              color: AppColors.primary)
                                          : Text('${i + 1}',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: i == current
                                                      ? Colors.white
                                                      : AppColors.muted))),
                                  const SizedBox(width: 6),
                                  Expanded(
                                      child: WordFitText(labels[i],
                                          maxLines: 1,
                                          style: TextStyle(
                                              fontSize: 13,
                                              height: 1.3,
                                              fontWeight: i == current
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: i == current
                                                  ? AppColors.primaryInk
                                                  : i < current
                                                      ? AppColors.ink
                                                      : AppColors.muted))),
                                ]),
                              ]))))),
        ]
      ]);
}

/// Blue text button with an optional chevron, e.g. "Change ›" or "Edit".
class LinkText extends StatelessWidget {
  const LinkText(
      {super.key,
      required this.label,
      required this.onTap,
      this.chevron = false});
  final String label;
  final VoidCallback onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
          constraints: const BoxConstraints(
              minHeight: minTouchTarget, minWidth: minTouchTarget),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                    if (chevron)
                      const Icon(Icons.chevron_right_rounded,
                          size: 18, color: AppColors.primary),
                  ]))));
}

/// A created customer link with a copy button.
class LinkBox extends StatelessWidget {
  const LinkBox({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
          color: AppColors.paper, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.link_rounded, size: 18, color: AppColors.muted),
        const SizedBox(width: 10),
        Expanded(
            child: SelectableText(url,
                style: const TextStyle(
                    fontSize: 13, height: 1.4, color: AppColors.inkSoft))),
        const SizedBox(width: 6),
        TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(tr('Link copied'))));
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 17),
            label: Text(tr('Copy link'))),
      ]));
}

/// Small uppercase-style section label inside a card, e.g. "CARGO".
class CapsLabel extends StatelessWidget {
  const CapsLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(isBangla ? text : text.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w700,
              color: AppColors.muted));
}
