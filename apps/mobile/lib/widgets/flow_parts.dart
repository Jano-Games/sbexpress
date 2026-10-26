import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models/flow.dart';
import '../features/admin/money_format.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import 'team_parts.dart' show DashedOutline;
import 'ui.dart';

/// Pieces of the core business flow: who pays the ticket, how the customer
/// pays, the usual shipment costs and getting paid.

// ---------------------------------------------------------------------------
// Usual costs.

String usualCostLabel(String category) => switch (category) {
      'packaging' => tr('Packaging'),
      'courier' => tr('Courier'),
      'customs' => tr('Customs'),
      'transport' => tr('Local transport'),
      _ => tr('Other'),
    };

/// English name sent as the reason when the operator leaves the note empty.
String usualCostReason(String category) => switch (category) {
      'packaging' => 'Packaging',
      'courier' => 'Courier',
      'customs' => 'Customs',
      'transport' => 'Local transport',
      _ => 'Other cost',
    };

IconData usualCostIcon(String category) => switch (category) {
      'packaging' => Icons.inventory_2_outlined,
      'courier' => Icons.local_shipping_outlined,
      'customs' => Icons.shield_outlined,
      'transport' => Icons.directions_car_outlined,
      _ => Icons.more_horiz_rounded,
    };

/// The Dhaka hub is step 6 of 9; the usual costs are due from there on.
const dhakaHubIndex = 5;

// ---------------------------------------------------------------------------
// Chips.

/// Small rounded chip with an icon, e.g. "Monthly" or "3 of 4 costs".
class FlowChip extends StatelessWidget {
  const FlowChip(
      {super.key,
      required this.label,
      this.icon,
      this.tone = ChipTone.neutral,
      this.dashed = false,
      this.outlined = false});
  final String label;
  final IconData? icon;
  final ChipTone tone;

  /// White with a dashed outline, for something not due yet.
  final bool dashed;

  /// Adds a thin border in the tone's colour.
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final colors = toneColors(tone);
    final foreground = dashed ? AppColors.inkSoft : colors.foreground;
    final body = Padding(
        padding: EdgeInsets.fromLTRB(icon == null ? 8 : 6, 1, 8, 1),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: foreground))),
        ]));
    if (dashed) {
      return DashedOutline(
          radius: 999,
          strokeWidth: 1,
          color: const Color(0xFFC3CAD5),
          background: AppColors.card,
          child: body);
    }
    return Container(
        decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(999),
            border: outlined ? Border.all(color: AppColors.accentLine) : null),
        child: body);
  }
}

/// "After delivery" or "Monthly" for a shipment.
class PayWayChip extends StatelessWidget {
  const PayWayChip({super.key, required this.monthly});
  final bool monthly;

  @override
  Widget build(BuildContext context) => FlowChip(
      label: monthly ? tr('Monthly') : tr('After delivery'),
      icon: monthly
          ? Icons.calendar_month_outlined
          : Icons.local_shipping_outlined);
}

/// How far the usual costs are: done, missing (orange) or not due yet.
class CostStatusChip extends StatelessWidget {
  const CostStatusChip(
      {super.key, required this.costs, required this.statusIndex});
  final List<UsualCost> costs;
  final int statusIndex;

  @override
  Widget build(BuildContext context) {
    final done = usualCostsAdded(costs);
    final total = costs.length;
    if (done >= total) {
      return FlowChip(
          label: tr('Costs done'),
          icon: Icons.check_rounded,
          tone: ChipTone.green);
    }
    if (statusIndex < dhakaHubIndex) {
      return done == 0
          ? FlowChip(
              label: tr('Costs not due yet'),
              icon: Icons.schedule_rounded,
              dashed: true)
          : FlowChip(
              label:
                  tr('{done} of {total} costs', {'done': done, 'total': total}),
              icon: Icons.schedule_rounded);
    }
    return FlowChip(
        label: tr('{done} of {total} costs', {'done': done, 'total': total}),
        icon: Icons.error_outline_rounded,
        tone: ChipTone.amber);
  }
}

// ---------------------------------------------------------------------------
// Choices.

enum ChoiceMark { check, radio }

/// Large selectable card with an icon, a title and a short line, used for
/// "Who pays the ticket?" and "How will the customer pay?".
class BigChoice extends StatelessWidget {
  const BigChoice(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.selected,
      required this.onTap,
      this.mark = ChoiceMark.check});
  final IconData icon;
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;
  final ChoiceMark mark;

  @override
  Widget build(BuildContext context) {
    final filledIcon = mark == ChoiceMark.radio && selected;
    final Widget markWidget = switch ((mark, selected)) {
      (ChoiceMark.check, true) => Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
              color: AppColors.primary, shape: BoxShape.circle),
          child:
              const Icon(Icons.check_rounded, size: 15, color: Colors.white)),
      (ChoiceMark.radio, true) => Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2)),
          child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle))),
      _ => Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFC3CAD5), width: 2))),
    };
    return Semantics(
        selected: selected,
        button: true,
        inMutuallyExclusiveGroup: true,
        child: Material(
            color: selected ? AppColors.primarySoft : AppColors.card,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: selected ? AppColors.primary : AppColors.field,
                    width: selected ? 2 : 1)),
            child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 116),
                    child: Padding(
                        padding: EdgeInsets.all(selected ? 12 : 13),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                            color: filledIcon
                                                ? AppColors.primary
                                                : selected
                                                    ? AppColors.card
                                                    : AppColors.paper,
                                            borderRadius:
                                                BorderRadius.circular(11)),
                                        child: Icon(icon,
                                            size: 20,
                                            color: filledIcon
                                                ? Colors.white
                                                : selected
                                                    ? AppColors.primary
                                                    : AppColors.inkSoft)),
                                    const Spacer(),
                                    markWidget,
                                  ]),
                              const SizedBox(height: 8),
                              Text(title,
                                  style: TextStyle(
                                      fontSize: 16,
                                      height: 1.3,
                                      fontWeight: FontWeight.w700,
                                      color: selected
                                          ? AppColors.primaryInk
                                          : AppColors.ink)),
                              const SizedBox(height: 2),
                              Text(subtitle,
                                  style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: selected
                                          ? AppColors.inkSoft
                                          : AppColors.muted)),
                            ]))))));
  }
}

/// Two [BigChoice] cards side by side, the same height.
class ChoicePair extends StatelessWidget {
  const ChoicePair({super.key, required this.first, required this.second});
  final Widget first, second;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: first),
        const SizedBox(width: 10),
        Expanded(child: second),
      ]));
}

// ---------------------------------------------------------------------------
// Money figures.

/// Two-part bar: what we pay against what the flyers pay.
class SplitSummary extends StatelessWidget {
  const SplitSummary(
      {super.key,
      required this.ours,
      required this.flyers,
      required this.ticket,
      this.problem});
  final double ours, flyers, ticket;

  /// Shown in red instead of the "adds up" line.
  final String? problem;

  @override
  Widget build(BuildContext context) {
    final total = ours + flyers;
    final share = total <= 0 ? 0.0 : (ours / total).clamp(0.0, 1.0);
    Widget legend(Color dot, String label, double value) => Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Flexible(
                  child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: '$label ',
                            style: const TextStyle(color: AppColors.inkSoft)),
                        TextSpan(
                            text: formatBdt(value),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                      style: const TextStyle(fontSize: 15, height: 1.4))),
            ]);
    return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
            color: AppColors.paper, borderRadius: BorderRadius.circular(14)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 4,
              children: [
                legend(AppColors.primary, tr('We pay'), ours),
                legend(const Color(0xFFB7C0CD), tr('Flyers'), flyers),
              ]),
          const SizedBox(height: 8),
          Semantics(
              label: tr('We pay {ours}, flyers pay {flyers}',
                  {'ours': formatBdt(ours), 'flyers': formatBdt(flyers)}),
              excludeSemantics: true,
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: SizedBox(
                      height: 10,
                      child: Row(children: [
                        if (share > 0)
                          Expanded(
                              flex: (share * 1000).round().clamp(1, 1000),
                              child: Container(color: AppColors.primary)),
                        if (share > 0 && share < 1) const SizedBox(width: 3),
                        if (share < 1)
                          Expanded(
                              flex: ((1 - share) * 1000).round().clamp(1, 1000),
                              child: Container(color: const Color(0xFFB7C0CD))),
                      ])))),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(problem == null ? Icons.check_rounded : Icons.error_outline,
                size: 16,
                color: problem == null ? AppColors.ok : AppColors.danger),
            const SizedBox(width: 6),
            Expanded(
                child: Text(
                    problem ??
                        tr('Adds up to the {amount} ticket',
                            {'amount': formatBdt(ticket)}),
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: problem == null
                            ? AppColors.ok
                            : AppColors.danger))),
          ]),
        ]));
  }
}

/// "৳21,000 of ৳30,000 · ৳9,000 left" over a progress bar.
class MoneyProgress extends StatelessWidget {
  const MoneyProgress(
      {super.key,
      required this.done,
      required this.total,
      required this.left,
      this.color = AppColors.primary});
  final double done, total;
  final String left;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            runSpacing: 2,
            children: [
              Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: formatBdt(done),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    TextSpan(
                        text: ' ${tr('of {amount}', {
                              'amount': formatBdt(total)
                            })}',
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.muted)),
                  ]),
                  style: const TextStyle(height: 1.35)),
              Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(left,
                      style: const TextStyle(
                          fontSize: 13, height: 1.5, color: AppColors.muted))),
            ]),
        const SizedBox(height: 8),
        ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: total <= 0 ? 0 : (done / total).clamp(0.0, 1.0),
                minHeight: 8,
                color: color,
                backgroundColor: AppColors.lineSoft)),
      ]);
}

/// One figure of a [FigureStrip].
class StripFigure {
  const StripFigure(this.label, this.value, {this.icon, this.color});
  final String label, value;
  final IconData? icon;
  final Color? color;
}

/// Grey strip of figures split by thin lines, e.g. Pays · Paid · Still due.
class FigureStrip extends StatelessWidget {
  const FigureStrip({super.key, required this.figures});
  final List<StripFigure> figures;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          color: AppColors.paper, borderRadius: BorderRadius.circular(14)),
      child: IntrinsicHeight(
          child: Row(children: [
        for (var i = 0; i < figures.length; i++) ...[
          if (i > 0) const VerticalDivider(width: 1, color: AppColors.line),
          Expanded(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(figures[i].label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: AppColors.muted)),
                        FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              if (figures[i].icon != null) ...[
                                Icon(figures[i].icon,
                                    size: 15, color: AppColors.primary),
                                const SizedBox(width: 5),
                              ],
                              Text(figures[i].value,
                                  maxLines: 1,
                                  style: TextStyle(
                                      fontSize: 15,
                                      height: 1.35,
                                      fontWeight: FontWeight.w700,
                                      color: figures[i].color ?? AppColors.ink,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ])),
                            ])),
                      ]))),
        ]
      ])));
}

/// Large amount field with the taka sign and an optional badge such as
/// "Usual amount".
class BigAmountField extends StatelessWidget {
  const BigAmountField(
      {super.key,
      required this.controller,
      this.onChanged,
      this.badge,
      this.hint = '0',
      this.suffix,
      this.fontSize = 20,
      this.textAlign = TextAlign.start});
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String? badge;
  final String hint;

  /// Muted text at the end, e.g. "BDT", when there is no badge.
  final String? suffix;
  final double fontSize;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final end = badge != null
        ? Padding(
            padding: const EdgeInsetsDirectional.only(end: 10),
            child: FlowChip(label: badge!, tone: ChipTone.green))
        : suffix != null
            ? Padding(
                padding: const EdgeInsetsDirectional.only(end: 14),
                child: Text(suffix!,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted)))
            : null;
    return TextField(
        controller: controller,
        onChanged: onChanged,
        textAlign: textAlign,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()]),
        decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: AppColors.faint),
            prefixIcon: const Padding(
                padding: EdgeInsetsDirectional.only(start: 14, end: 8),
                child: Text('৳',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted))),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            suffixIcon: end,
            suffixIconConstraints: const BoxConstraints(minWidth: 0),
            contentPadding: const EdgeInsets.fromLTRB(4, 14, 8, 14)));
  }
}

// ---------------------------------------------------------------------------
// Sheets.

/// Opens a white bottom sheet with a drag handle that grows with the
/// keyboard.
Future<T?> showFlowSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) => Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: builder(context)));

/// Sheet title, a line under it and a round close button.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w700, height: 1.3)),
          if (subtitle != null)
            Text(subtitle!,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.muted, height: 1.4)),
        ])),
        IconButton(
            tooltip: tr('Close'),
            style: IconButton.styleFrom(
                backgroundColor: AppColors.paper,
                foregroundColor: AppColors.inkSoft,
                minimumSize: const Size(44, 44)),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close_rounded, size: 20)),
      ]));
}

/// Tinted box that shows what saving will change.
class ResultPreview extends StatelessWidget {
  const ResultPreview(
      {super.key,
      required this.icon,
      required this.title,
      this.caption,
      this.body,
      this.trailing,
      this.tone = ChipTone.blue});
  final IconData icon;
  final String title;
  final String? caption, body;
  final List<String>? trailing;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = toneColors(tone);
    return Semantics(
        liveRegion: true,
        child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: tone == ChipTone.green
                          ? BoxShape.circle
                          : BoxShape.rectangle,
                      borderRadius: tone == ChipTone.green
                          ? null
                          : BorderRadius.circular(10)),
                  child: Icon(icon, size: 18, color: colors.foreground)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    if (caption != null)
                      Text(caption!,
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: AppColors.inkSoft)),
                    Text(title,
                        style: TextStyle(
                            fontSize: 16,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: colors.foreground)),
                    if (body != null)
                      Text(body!,
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: AppColors.inkSoft)),
                  ])),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final line in trailing!)
                    Text(line,
                        style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.inkSoft)),
                ]),
              ],
            ])));
  }
}

/// White card row: tinted icon, a title, lines under it and a chevron.
class LinkCard extends StatelessWidget {
  const LinkCard(
      {super.key,
      required this.icon,
      required this.title,
      required this.lines,
      required this.onTap,
      this.tone = ChipTone.blue,
      this.trailing});
  final IconData icon;
  final String title;
  final List<String> lines;
  final VoidCallback onTap;
  final ChipTone tone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => PaperCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        IconBadge(icon, tone: tone),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, height: 1.35)),
          for (final line in lines)
            Text(line,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.muted, height: 1.4)),
        ])),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right_rounded,
            size: 20, color: AppColors.faint),
      ]));
}
