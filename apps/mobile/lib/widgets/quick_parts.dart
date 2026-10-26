import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../data/uploads/photo_upload.dart';
import '../data/uploads/quick_uploads.dart';
import '../data/uploads/upload_queue.dart';
import '../features/admin/money_format.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import 'flight_parts.dart' show MeterBar;
import 'flow_parts.dart' show SheetHeader, showFlowSheet;
import 'team_parts.dart' show DashedOutline;
import 'ui.dart';

/// Pieces of the quick-add screens: the overview, the Add menu, the one-page
/// booking, the customer and flyer forms.

// ---------------------------------------------------------------------------
// Money.

/// "৳8,400" for whole amounts and "৳8,400.50" otherwise; "¥1,200" in CNY.
String wholeMoney(double value, String currency) {
  if (currency == 'CNY') {
    final negative = value < 0;
    final text = formatBdt(value.abs()).replaceFirst('৳', '¥');
    final trimmed =
        text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
    return negative ? '-$trimmed' : trimmed;
  }
  final text = formatBdt(value);
  return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
}

String wholeBdt(double value) => wholeMoney(value, 'BDT');

/// "6", "6.5" or "6.25" kg without trailing zeros.
String plainKg(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  final fixed = value.toStringAsFixed(2);
  return fixed.endsWith('0') ? fixed.substring(0, fixed.length - 1) : fixed;
}

// ---------------------------------------------------------------------------
// Overview.

/// White tile with a tinted icon, a large count and a label. [hot] outlines
/// it in orange for work that waits on the admin.
class WorkTile extends StatelessWidget {
  const WorkTile(
      {super.key,
      required this.icon,
      required this.value,
      required this.label,
      required this.onTap,
      this.tone = ChipTone.blue,
      this.hot = false});
  final IconData icon;
  final String value, label;
  final VoidCallback onTap;
  final ChipTone tone;
  final bool hot;

  @override
  Widget build(BuildContext context) => PaperCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      border: hot
          ? const BorderSide(color: AppColors.accentLine, width: 1.5)
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(icon, tone: hot ? ChipTone.amber : tone, size: 34),
        const SizedBox(height: 6),
        Text(value,
            maxLines: 1,
            style: const TextStyle(
                fontSize: 24,
                height: 1.15,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(height: 4),
        WordFitText(label,
            style: TextStyle(
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: hot ? AppColors.accentInk : AppColors.inkSoft)),
      ]));
}

/// Small white tile with who owes what, e.g. "Customers owe us ৳15,400".
class OweTile extends StatelessWidget {
  const OweTile(
      {super.key,
      required this.label,
      required this.amount,
      required this.caption,
      required this.onTap,
      this.color = AppColors.ink,
      this.link = false});
  final String label, amount, caption;
  final VoidCallback onTap;
  final Color color;

  /// Draws the caption as a blue link.
  final bool link;

  @override
  Widget build(BuildContext context) => PaperCard(
      onTap: onTap,
      radius: 14,
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WordFitText(label,
            style: const TextStyle(
                fontSize: 12, height: 1.3, color: AppColors.muted)),
        const SizedBox(height: 2),
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(amount,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 17,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()]))),
        const SizedBox(height: 2),
        WordFitText(caption,
            style: TextStyle(
                fontSize: 12,
                height: 1.3,
                fontWeight: link ? FontWeight.w600 : FontWeight.w400,
                color: link ? AppColors.primary : AppColors.muted)),
      ]));
}

/// Tiles of equal width side by side, all as tall as the tallest. Unlike
/// an [IntrinsicHeight] row it lays the tiles out for real, so tiles may hold
/// [WordFitText] and other layout builders.
class TileRow extends MultiChildRenderObjectWidget {
  const TileRow({super.key, required super.children, this.gap = 10});
  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTileRow(gap: gap, textDirection: Directionality.of(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderTileRow)
      ..gap = gap
      ..textDirection = Directionality.of(context);
  }
}

class _TileParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderTileRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TileParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TileParentData> {
  _RenderTileRow({required double gap, required TextDirection textDirection})
      : _gap = gap,
        _textDirection = textDirection;

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TileParentData) {
      child.parentData = _TileParentData();
    }
  }

  double _tileWidth(double width) =>
      childCount == 0 ? 0 : (width - _gap * (childCount - 1)) / childCount;

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final each = _tileWidth(width).clamp(0.0, double.infinity);
    var height = 0.0;
    var child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints.tightFor(width: each), parentUsesSize: true);
      if (child.size.height > height) height = child.size.height;
      child = childAfter(child);
    }
    height = constraints.constrainHeight(height);
    var x = 0.0;
    child = firstChild;
    while (child != null) {
      // Not tight and parentUsesSize: a tile stays part of the row's layout,
      // so when its content changes the whole row measures again.
      child.layout(
          BoxConstraints(minWidth: each, maxWidth: each, minHeight: height),
          parentUsesSize: true);
      final data = child.parentData! as _TileParentData;
      data.offset =
          Offset(_textDirection == TextDirection.rtl ? width - x - each : x, 0);
      x += each + _gap;
      child = childAfter(child);
    }
    size = constraints.constrain(Size(width, height));
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    var height = 0.0;
    var child = firstChild;
    while (child != null) {
      final value = child.getMinIntrinsicHeight(_tileWidth(width));
      if (value > height) height = value;
      child = childAfter(child);
    }
    return height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// Rounded bar split into coloured parts by their share of the total.
class SegmentBar extends StatelessWidget {
  const SegmentBar(
      {super.key,
      required this.parts,
      this.height = 8,
      this.track = AppColors.lineSoft,
      this.label});
  final List<(double, Color)> parts;
  final double height;
  final Color track;

  /// Read out instead of the bar.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final part in parts)
        if (part.$1 > 0) part
    ];
    final total = shown.fold<double>(0, (sum, part) => sum + part.$1);
    final radius = BorderRadius.circular(height / 2);
    final bar = SizedBox(
        height: height,
        width: double.infinity,
        child: total <= 0
            ? DecoratedBox(
                decoration: BoxDecoration(color: track, borderRadius: radius))
            : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                      flex: (shown[i].$1 / total * 1000).round().clamp(1, 1000),
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: shown[i].$2, borderRadius: radius))),
                ]
              ]));
    return Semantics(label: label, excludeSemantics: true, child: bar);
  }
}

/// A row of a "Needs attention" list: tinted icon, a title, a detail line and
/// a badge or chevron.
class AttentionRow extends StatelessWidget {
  const AttentionRow(
      {super.key,
      required this.icon,
      required this.title,
      this.detail,
      this.tone = ChipTone.amber,
      this.badge,
      this.onTap});
  final IconData icon;
  final String title;
  final String? detail;
  final ChipTone tone;
  final Widget? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = toneColors(tone);
    return InkWell(
        onTap: onTap,
        child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: minTouchTarget),
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, size: 19, color: colors.foreground)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w600)),
                        if (detail != null && detail!.isNotEmpty)
                          Text(detail!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: AppColors.muted)),
                      ])),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    badge!,
                  ] else if (onTap != null) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppColors.faint),
                  ],
                ]))));
  }
}

/// One figure of a [FigureRow]: a large number over a small label.
class SmallFigure {
  const SmallFigure(this.value, this.label);
  final String value, label;
}

/// Equal columns of a bold figure over a muted label.
class FigureRow extends StatelessWidget {
  const FigureRow({super.key, required this.figures});
  final List<SmallFigure> figures;

  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < figures.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(figures[i].value,
                    maxLines: 1,
                    style: const TextStyle(
                        fontSize: 17,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()])),
                WordFitText(figures[i].label,
                    style: const TextStyle(
                        fontSize: 12, height: 1.3, color: AppColors.muted)),
              ])),
        ]
      ]);
}

// ---------------------------------------------------------------------------
// Add menu.

enum AddChoice { shipment, flight, customer, flyer, ticket }

/// The "+ Add" sheet; returns what to create, or null when closed.
Future<AddChoice?> showAddMenu(BuildContext context) =>
    showFlowSheet<AddChoice>(context, (context) => const _AddMenu());

class _AddMenu extends StatelessWidget {
  const _AddMenu();

  @override
  Widget build(BuildContext context) {
    Widget tile(AddChoice choice, IconData icon, String title, String line,
        {bool main = false}) {
      return Semantics(
          button: true,
          child: Material(
              color: main ? AppColors.primarySoft : AppColors.paper,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                  key: Key('add-${choice.name}'),
                  onTap: () => Navigator.of(context).pop(choice),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 118),
                      child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                        color: main
                                            ? AppColors.primary
                                            : AppColors.card,
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Icon(icon,
                                        size: 20,
                                        color: main
                                            ? Colors.white
                                            : AppColors.primary)),
                                const SizedBox(height: 8),
                                WordFitText(title,
                                    style: TextStyle(
                                        fontSize: 15,
                                        height: 1.3,
                                        fontWeight: FontWeight.w700,
                                        color: main
                                            ? AppColors.primaryInk
                                            : AppColors.ink)),
                                const SizedBox(height: 2),
                                Text(line,
                                    style: TextStyle(
                                        fontSize: 12,
                                        height: 1.35,
                                        color: main
                                            ? AppColors.inkSoft
                                            : AppColors.muted)),
                              ]))))));
    }

    return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetHeader(title: tr('Add new')),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TileRow(children: [
                      tile(AddChoice.shipment, Icons.inventory_2_outlined,
                          tr('Shipment'), tr('Book cargo for a customer'),
                          main: true),
                      tile(AddChoice.flight, Icons.flight_rounded, tr('Flight'),
                          tr('Enter it or import the e-ticket')),
                    ]),
                    const SizedBox(height: 10),
                    TileRow(children: [
                      tile(AddChoice.customer, Icons.person_add_alt_outlined,
                          tr('Customer'), tr('Code fills in by itself')),
                      tile(AddChoice.flyer, Icons.badge_outlined, tr('Flyer'),
                          tr('Profile with ID, visa and admission')),
                    ]),
                    const SizedBox(height: 14),
                    Material(
                        color: AppColors.card,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: AppColors.field)),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                            key: const Key('add-ticket'),
                            onTap: () =>
                                Navigator.of(context).pop(AddChoice.ticket),
                            child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(minHeight: 52),
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    child: Row(children: [
                                      const Icon(Icons.upload_file_outlined,
                                          size: 20, color: AppColors.primary),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: Text(
                                              tr(
                                                  'Import flight from e-ticket PDF'),
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  height: 1.35,
                                                  fontWeight:
                                                      FontWeight.w600))),
                                      const Icon(Icons.chevron_right_rounded,
                                          size: 18, color: AppColors.faint),
                                    ])))))
                  ])),
        ]));
  }
}

// ---------------------------------------------------------------------------
// One-page forms.

enum StepMark { done, current, waiting }

/// Round step number: a green tick when done, orange for the step to do now.
class StepBadge extends StatelessWidget {
  const StepBadge({super.key, required this.number, required this.mark});
  final int number;
  final StepMark mark;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border) = switch (mark) {
      StepMark.done => (AppColors.ok, Colors.white, null),
      StepMark.current => (
          AppColors.accentSoft,
          AppColors.accentInk,
          AppColors.accent
        ),
      StepMark.waiting => (AppColors.lineSoft, AppColors.muted, null),
    };
    return Semantics(
        label: mark == StepMark.done
            ? tr('Step {n} done', {'n': number})
            : tr('Step {n}', {'n': number}),
        excludeSemantics: true,
        child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
                border: border == null
                    ? null
                    : Border.all(color: border, width: 2)),
            child: mark == StepMark.done
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : Text('$number',
                    style: TextStyle(
                        fontSize: 13,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: foreground))));
  }
}

/// White card for one numbered part of a one-page form. The part to do now
/// gets an orange outline.
class StepCard extends StatelessWidget {
  const StepCard(
      {super.key,
      required this.number,
      required this.mark,
      required this.title,
      required this.children,
      this.trailing,
      this.gap = 12});
  final int number;
  final StepMark mark;
  final String title;
  final Widget? trailing;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => PaperCard(
      padding: const EdgeInsets.all(14),
      border: mark == StepMark.current
          ? const BorderSide(color: AppColors.accentLine, width: 1.5)
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          StepBadge(number: number, mark: mark),
          const SizedBox(width: 10),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w700))),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ]),
        for (final child in children) ...[SizedBox(height: gap), child],
      ]));
}

/// A choice drawn as a bordered tile: blue and thicker when chosen.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile(
      {super.key,
      required this.title,
      required this.selected,
      required this.onTap,
      this.subtitle,
      this.tick = false});
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  /// Puts a tick before the title when chosen.
  final bool tick;

  @override
  Widget build(BuildContext context) => Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Material(
          color: selected ? AppColors.primarySoft : AppColors.card,
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(subtitle == null ? controlRadius : 16),
              side: BorderSide(
                  color: selected ? AppColors.primary : AppColors.field,
                  width: selected ? 2 : 1)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: subtitle == null ? 10 : 14,
                          vertical: subtitle == null ? 8 : 14),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: subtitle == null
                              ? CrossAxisAlignment.center
                              : CrossAxisAlignment.start,
                          children: [
                            Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (tick && selected) ...[
                                    const Icon(Icons.check_rounded,
                                        size: 17, color: AppColors.primaryInk),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(
                                      child: WordFitText(title,
                                          textAlign: subtitle == null
                                              ? TextAlign.center
                                              : TextAlign.start,
                                          style: TextStyle(
                                              fontSize:
                                                  subtitle == null ? 14 : 15,
                                              height: 1.3,
                                              fontWeight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                              color: selected
                                                  ? AppColors.primaryInk
                                                  : AppColors.ink))),
                                ]),
                            if (subtitle != null) ...[
                              const SizedBox(height: 6),
                              Text(subtitle!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: selected
                                          ? AppColors.inkSoft
                                          : AppColors.muted)),
                            ],
                          ]))))));
}

/// A row of a radio list drawn as separate cards, e.g. the flights to book on.
class OptionRow extends StatelessWidget {
  const OptionRow(
      {super.key,
      required this.title,
      required this.selected,
      required this.onTap,
      this.subtitle,
      this.trailing});
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Material(
          color: selected ? AppColors.primarySoft : AppColors.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(controlRadius),
              side: BorderSide(
                  color: selected ? AppColors.primary : AppColors.field,
                  width: selected ? 2 : 1)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: selected ? 11 : 12,
                          vertical: selected ? 9 : 10),
                      child: Row(children: [
                        Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                                color: AppColors.card,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: selected
                                        ? AppColors.primary
                                        : const Color(0xFFB8C1CF),
                                    width: selected ? 6 : 2))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(title,
                                  style: TextStyle(
                                      fontSize: 14,
                                      height: 1.35,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: selected
                                          ? AppColors.primaryInk
                                          : AppColors.ink)),
                              if (subtitle != null)
                                Text(subtitle!,
                                    style: TextStyle(
                                        fontSize: 12,
                                        height: 1.4,
                                        color: selected
                                            ? AppColors.inkSoft
                                            : AppColors.muted)),
                            ])),
                        if (trailing != null) ...[
                          const SizedBox(width: 8),
                          trailing!
                        ],
                      ]))))));
}

/// White dashed button, e.g. "Decide later" or "+ New".
class DashedButton extends StatelessWidget {
  const DashedButton(
      {super.key,
      required this.label,
      required this.onTap,
      this.selected = false,
      this.icon,
      this.radius = controlRadius,
      this.height = 40,
      this.color = AppColors.inkSoft});
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final IconData? icon;
  final double radius, height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final body = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height, minWidth: 48),
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon,
                            size: 17,
                            color: selected ? AppColors.primaryInk : color),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                          child: Text(label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  height: 1.3,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? AppColors.primaryInk
                                      : color))),
                    ]))));
    return Semantics(
        button: true,
        selected: selected,
        child: selected
            ? Material(
                color: AppColors.primarySoft,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radius),
                    side: const BorderSide(color: AppColors.primary, width: 2)),
                child: body)
            : DashedOutline(
                radius: radius,
                strokeWidth: 1,
                color: const Color(0xFFB8C1CF),
                background: AppColors.card,
                child: body));
  }
}

/// Grey pill with two or three options, e.g. BDT / CNY.
class PillToggle extends StatelessWidget {
  const PillToggle(
      {super.key,
      required this.options,
      required this.selected,
      required this.onChanged});
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: AppColors.lineSoft, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final option in options)
          Semantics(
              button: true,
              selected: option == selected,
              inMutuallyExclusiveGroup: true,
              child: Material(
                  color:
                      option == selected ? AppColors.card : Colors.transparent,
                  shape: const StadiumBorder(),
                  elevation: option == selected ? 1 : 0,
                  shadowColor: const Color(0x33101828),
                  child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => onChanged(option),
                      child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(minHeight: 34, minWidth: 48),
                          child: Center(
                              widthFactor: 1,
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Text(option,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: option == selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: option == selected
                                              ? AppColors.ink
                                              : AppColors.muted)))))))),
      ]));
}

/// − count + in a small bordered box.
class MiniStepper extends StatelessWidget {
  const MiniStepper(
      {super.key,
      required this.value,
      required this.onLess,
      required this.onMore,
      this.lessLabel,
      this.moreLabel});
  final int value;

  /// Null disables the button.
  final VoidCallback? onLess, onMore;
  final String? lessLabel, moreLabel;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String tip, VoidCallback? onTap, bool more) =>
        Tooltip(
            message: tip,
            child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                    width: 40,
                    height: 44,
                    child: Icon(icon,
                        size: 19,
                        color: onTap == null
                            ? AppColors.faint
                            : more
                                ? AppColors.primary
                                : AppColors.ink))));
    return Container(
        decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.field),
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          button(Icons.remove_rounded, lessLabel ?? tr('One fewer'), onLess,
              false),
          SizedBox(
              width: 24,
              child: Text('$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700))),
          button(Icons.add_rounded, moreLabel ?? tr('One more'), onMore, true),
        ]));
  }
}

/// Picked photos as small squares, five to a row, with an add square.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid(
      {super.key,
      required this.photos,
      required this.onAdd,
      required this.onRemove,
      required this.addLabel,
      this.background = AppColors.card});
  final List<PickedPhoto> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final String addLabel;
  final Color background;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        const gap = 6.0;
        final size = (box.maxWidth - gap * 4) / 5;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (var i = 0; i < photos.length; i++)
            SizedBox(
                width: size,
                height: size,
                child: Stack(fit: StackFit.expand, children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _Thumb(bytes: photos[i].bytes)),
                  PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: Tooltip(
                          message: tr('Remove photo'),
                          child: InkResponse(
                              onTap: () => onRemove(i),
                              radius: 18,
                              child: SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: Center(
                                      child: Container(
                                          width: 22,
                                          height: 22,
                                          decoration: const BoxDecoration(
                                              color: Color(0xB318212F),
                                              shape: BoxShape.circle),
                                          child: const Icon(Icons.close_rounded,
                                              size: 14,
                                              color: Colors.white))))))),
                ])),
          SizedBox(
              width: size,
              height: size,
              child: Tooltip(
                  message: addLabel,
                  child: DashedOutline(
                      radius: 8,
                      color: const Color(0xFFB8C1CF),
                      background: background,
                      child: InkWell(
                          onTap: onAdd,
                          child: const Center(
                              child: Icon(Icons.add_a_photo_outlined,
                                  size: 20, color: AppColors.primary)))))),
        ]);
      });
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.bytes});
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) => Image.memory(bytes,
      fit: BoxFit.cover,
      cacheWidth: 200,
      gaplessPlayback: true,
      errorBuilder: (context, error, stack) => Container(
          color: const Color(0xFFDDE5F2),
          child: const Icon(Icons.image_outlined,
              size: 20, color: Color(0xFF6E7F99))));
}

/// Asks whether to take a photo or pick from the gallery.
Future<FileSource?> askPhotoSource(BuildContext context) =>
    showFlowSheet<FileSource>(
        context,
        (context) => SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SheetHeader(title: tr('Add photos')),
              const SizedBox(height: 8),
              ListTile(
                  minTileHeight: 56,
                  leading: const Icon(Icons.photo_camera_outlined,
                      color: AppColors.primary),
                  title: Text(tr('Take a photo')),
                  onTap: () => Navigator.of(context).pop(FileSource.camera)),
              ListTile(
                  minTileHeight: 56,
                  leading: const Icon(Icons.photo_library_outlined,
                      color: AppColors.primary),
                  title: Text(tr('Choose from gallery')),
                  onTap: () => Navigator.of(context).pop(FileSource.gallery)),
              const SizedBox(height: 12),
            ])));

// ---------------------------------------------------------------------------
// Documents and uploads.

/// One document of the flyer form: empty with Camera / Gallery / PDF, or the
/// chosen file with a remove button.
class DocumentSlot extends StatelessWidget {
  const DocumentSlot(
      {super.key,
      required this.title,
      required this.icon,
      required this.file,
      required this.onPick,
      required this.onRemove});
  final String title;
  final IconData icon;
  final PickedPhoto? file;
  final ValueChanged<FileSource> onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final picked = file;
    if (picked != null) {
      return Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          decoration: BoxDecoration(
              border: Border.all(color: AppColors.lineSoft),
              borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const IconBadge(Icons.check_rounded,
                tone: ChipTone.green, size: 44),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w600)),
                  Text(tr('{file} · ready to upload', {'file': picked.name}),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, height: 1.4, color: AppColors.ok)),
                ])),
            IconButton(
                tooltip: tr('Remove {document} file', {'document': title}),
                onPressed: onRemove,
                color: AppColors.muted,
                icon: const Icon(Icons.close_rounded, size: 20)),
          ]));
    }
    Widget button(FileSource source, String label, IconData glyph) => Expanded(
        child: Material(
            color: source == FileSource.camera
                ? AppColors.primarySoft
                : AppColors.card,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: source == FileSource.camera
                    ? BorderSide.none
                    : const BorderSide(color: Color(0xFFDCE1E8))),
            child: InkWell(
                onTap: () => onPick(source),
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(glyph,
                                  size: 16,
                                  color: source == FileSource.camera
                                      ? AppColors.primaryInk
                                      : AppColors.inkSoft),
                              const SizedBox(width: 4),
                              Flexible(
                                  child: WordFitText(label,
                                      maxLines: 1,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: source == FileSource.camera
                                              ? AppColors.primaryInk
                                              : AppColors.ink))),
                            ]))))));
    return DashedOutline(
        radius: 14,
        strokeWidth: 1,
        background: AppColors.card,
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    IconBadge(icon, tone: ChipTone.neutral, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600)),
                          Text(tr('Photo or PDF'),
                              style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: AppColors.muted)),
                        ])),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    button(FileSource.camera, tr('Camera'),
                        Icons.photo_camera_outlined),
                    const SizedBox(width: 8),
                    button(FileSource.gallery, tr('Gallery'),
                        Icons.image_outlined),
                    const SizedBox(width: 8),
                    button(
                        FileSource.pdf, 'PDF', Icons.picture_as_pdf_outlined),
                  ]),
                ])));
  }
}

/// What a queue of uploads sends, for its wording.
enum UploadWhat { photos, files }

/// Progress of an [UploadQueue]: a bar, "3 of 4" and a retry for failures.
class UploadProgressCard extends StatelessWidget {
  const UploadProgressCard(
      {super.key,
      required this.queue,
      this.what = UploadWhat.photos,
      this.note});
  final UploadQueue queue;
  final UploadWhat what;

  /// Shown under the bar while sending.
  final String? note;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: queue,
      builder: (context, _) {
        final photos = what == UploadWhat.photos;
        final failed = queue.failedCount;
        final finished = queue.finished;
        final title = !finished
            ? photos
                ? tr('Uploading photos')
                : tr('Uploading files')
            : failed == 0
                ? photos
                    ? tr('Photos uploaded')
                    : tr('Files uploaded')
                : photos
                    ? trn(failed, '{n} photo did not upload',
                        '{n} photos did not upload')
                    : trn(failed, '{n} file did not upload',
                        '{n} files did not upload');
        return PaperCard(
            padding: const EdgeInsets.all(14),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: Text(title,
                            style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                                color: finished && failed > 0
                                    ? AppColors.danger
                                    : AppColors.ink))),
                    const SizedBox(width: 8),
                    Text(
                        tr('{done} of {total}',
                            {'done': queue.doneCount, 'total': queue.total}),
                        style: const TextStyle(
                            fontSize: 13, height: 1.4, color: AppColors.muted)),
                  ]),
                  const SizedBox(height: 8),
                  Semantics(
                      label: tr('{done} of {total} uploaded',
                          {'done': queue.doneCount, 'total': queue.total}),
                      excludeSemantics: true,
                      child: MeterBar(
                          value: queue.progress,
                          color: finished && failed == 0
                              ? AppColors.ok
                              : AppColors.primary)),
                  if (!finished && note != null) ...[
                    const SizedBox(height: 8),
                    Text(note!,
                        style: const TextStyle(
                            fontSize: 12, height: 1.4, color: AppColors.muted)),
                  ],
                  if (finished && failed > 0) ...[
                    for (final job in queue.jobs)
                      if (job.state == UploadState.failed &&
                          job.error != null) ...[
                        const SizedBox(height: 8),
                        Text('${job.label}: ${job.error}',
                            style: const TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: AppColors.danger)),
                      ],
                    const SizedBox(height: 10),
                    AppButton(
                        key: const Key('upload-retry'),
                        label: tr('Try again'),
                        icon: Icons.refresh_rounded,
                        kind: AppButtonKind.tonal,
                        onPressed: queue.retryFailed),
                  ],
                ]));
      });
}

/// Files of an [UploadQueue] that are not sent yet, each with a retry once
/// it failed. [titleOf] names a file's group, e.g. "Visa".
class QueuedFilesCard extends StatelessWidget {
  const QueuedFilesCard(
      {super.key, required this.queue, required this.titleOf});
  final UploadQueue queue;
  final String Function(String? group) titleOf;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: queue,
      builder: (context, _) {
        final open = [
          for (final job in queue.jobs)
            if (job.state != UploadState.done) job
        ];
        if (open.isEmpty) return const SizedBox.shrink();
        return PaperCard(
            padding: EdgeInsets.zero,
            border: queue.failedCount > 0
                ? const BorderSide(color: AppColors.dangerLine, width: 1.5)
                : null,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                      child: Text(tr('Files still to upload'),
                          style: const TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              fontWeight: FontWeight.w700))),
                  for (final job in open)
                    Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                        child: Row(children: [
                          SizedBox(
                              width: 36,
                              height: 36,
                              child: job.state == UploadState.failed
                                  ? const IconBadge(Icons.error_outline_rounded,
                                      tone: ChipTone.red, size: 36)
                                  : Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          value: job.state ==
                                                      UploadState.uploading &&
                                                  job.progress > 0
                                              ? job.progress
                                              : null))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(titleOf(job.group),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.35,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                    job.state == UploadState.failed &&
                                            job.error != null
                                        ? '${job.label} · ${job.error}'
                                        : job.label,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        height: 1.4,
                                        color: job.state == UploadState.failed
                                            ? AppColors.danger
                                            : AppColors.muted)),
                              ])),
                          if (job.state == UploadState.failed)
                            TextButton(
                                onPressed: () => queue.retry(job),
                                child: Text(tr('Try again'))),
                        ])),
                  const SizedBox(height: 6),
                ]));
      });
}
