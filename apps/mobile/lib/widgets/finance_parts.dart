import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models/finance_snapshot.dart';
import '../features/admin/money_format.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import 'ui.dart';

/// Shared pieces of the customer and finance screens: the navy money card,
/// account pickers, money fields, filters, pagers and date labels.

// ---------------------------------------------------------------------------
// Money formatting and dates.

/// "+৳3,200.00" for money in, "−৳800.00" for money out.
String signedMoney(double value, String currency) {
  final text = formatMoney(value.abs(), currency);
  if (value > 0) return '+$text';
  if (value < 0) return '−$text';
  return text;
}

String currencySymbol(String? currency) => currency == 'CNY' ? '¥' : '৳';

/// An API timestamp in the phone's time zone.
DateTime? localTime(String iso) => DateTime.tryParse(iso)?.toLocal();

const _shortMonths = [
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

/// Short English month, kept in both languages like flight dates ("Oct").
String shortMonth(int month) => _shortMonths[month - 1];

String monthName(int month) => switch (month) {
      1 => tr('January'),
      2 => tr('February'),
      3 => tr('March'),
      4 => tr('April'),
      5 => tr('May'),
      6 => tr('June'),
      7 => tr('July'),
      8 => tr('August'),
      9 => tr('September'),
      10 => tr('October'),
      11 => tr('November'),
      _ => tr('December'),
    };

String weekdayName(DateTime date) => switch (date.weekday) {
      DateTime.monday => tr('Monday'),
      DateTime.tuesday => tr('Tuesday'),
      DateTime.wednesday => tr('Wednesday'),
      DateTime.thursday => tr('Thursday'),
      DateTime.friday => tr('Friday'),
      DateTime.saturday => tr('Saturday'),
      _ => tr('Sunday'),
    };

/// "Saturday · 24 Oct".
String dayHeading(DateTime date) =>
    '${weekdayName(date)} · ${date.day} ${shortMonth(date.month)}';

/// "24 Oct".
String shortDate(DateTime date) => '${date.day} ${shortMonth(date.month)}';

/// "2:05 PM".
String clockTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}

/// `YYYY-MM` for a calendar month.
String monthKey(int year, int month) =>
    '$year-${month.toString().padLeft(2, '0')}';

/// "October 2026" for `2026-10`; the text itself when it is not a month.
String monthTitle(String key) {
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(key);
  if (match == null) return key;
  final month = int.parse(match.group(2)!);
  if (month < 1 || month > 12) return key;
  return '${monthName(month)} ${match.group(1)}';
}

/// "October" for `2026-10`.
String monthOnly(String key) {
  final match = RegExp(r'^\d{4}-(\d{2})$').firstMatch(key);
  final month = match == null ? 0 : int.parse(match.group(1)!);
  return month < 1 || month > 12 ? key : monthName(month);
}

/// The month [delta] months away from [key].
String shiftMonth(String key, int delta) {
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(key);
  if (match == null) return key;
  final index =
      int.parse(match.group(1)!) * 12 + int.parse(match.group(2)!) - 1 + delta;
  return monthKey(index ~/ 12, index % 12 + 1);
}

String currentMonthKey([DateTime? now]) {
  final today = now ?? DateTime.now();
  return monthKey(today.year, today.month);
}

IconData accountIcon(String kind) => switch (kind) {
      'bank' => Icons.account_balance_outlined,
      'mobile' || 'wallet' => Icons.smartphone_outlined,
      'fund' => Icons.savings_outlined,
      _ => Icons.payments_outlined,
    };

// ---------------------------------------------------------------------------
// Navy money card.

abstract final class HeroColors {
  static const soft = Color(0xB8FFFFFF);
  static const label = Color(0xBFFFFFFF);
  static const line = Color(0x24FFFFFF);
  static const track = Color(0x29FFFFFF);
  static const button = Color(0x1AFFFFFF);

  /// Money still owed, on navy.
  static const due = Color(0xFFFFB3B0);
}

class MoneyHero extends StatelessWidget {
  const MoneyHero(
      {super.key,
      required this.children,
      this.padding = const EdgeInsets.all(18)});
  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(heroRadius)),
      child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children)));
}

/// Large amount with its label, e.g. "Amount due".
class HeroAmount extends StatelessWidget {
  const HeroAmount(
      {super.key,
      required this.label,
      required this.value,
      this.color = Colors.white});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: HeroColors.label)),
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value,
                maxLines: 1,
                style: TextStyle(
                    fontSize: 32,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()]))),
      ]);
}

/// Small label and amount on the navy card, e.g. "Billed".
class HeroFigure extends StatelessWidget {
  const HeroFigure(
      {super.key,
      required this.label,
      required this.value,
      this.size = 16,
      this.color = Colors.white,
      this.icon,
      this.note});
  final String label, value;
  final double size;
  final Color color;
  final IconData? icon;

  /// A second, smaller amount under the main one.
  final String? note;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: HeroColors.soft),
            const SizedBox(width: 4),
          ],
          Flexible(
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 12, color: HeroColors.soft))),
        ]),
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value,
                maxLines: 1,
                style: TextStyle(
                    fontSize: size,
                    height: 1.3,
                    fontWeight: size > 18 ? FontWeight.w700 : FontWeight.w600,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()]))),
        if (note != null)
          Text(note!,
              style: const TextStyle(fontSize: 13, color: Color(0xCCFFFFFF))),
      ]);
}

class HeroDivider extends StatelessWidget {
  const HeroDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: HeroColors.line);
}

/// White progress bar on the navy card.
class HeroBar extends StatelessWidget {
  const HeroBar({super.key, required this.value, this.label});
  final double value;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
      label: label,
      child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
              height: 8,
              color: HeroColors.track,
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4)))))));
}

/// Round 44px button on the navy card.
class HeroStepButton extends StatelessWidget {
  const HeroStepButton(
      {super.key,
      required this.icon,
      required this.tooltip,
      required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
          backgroundColor: HeroColors.button,
          disabledBackgroundColor: const Color(0x0DFFFFFF),
          foregroundColor: Colors.white,
          disabledForegroundColor: const Color(0x52FFFFFF),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(controlRadius))),
      icon: Icon(icon, size: 22));
}

// ---------------------------------------------------------------------------
// Cards, rows and headers.

/// White card whose rows are split by full-width lines.
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.children, this.border});
  final List<Widget> children;
  final BorderSide? border;

  @override
  Widget build(BuildContext context) => PaperCard(
      padding: EdgeInsets.zero,
      border: border,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.lineSoft),
          children[i],
        ]
      ]));
}

/// [start] takes the row; [end] keeps its natural width up to [maxFraction]
/// of the row and must shrink itself (e.g. with a FittedBox) beyond that.
class SplitRow extends StatelessWidget {
  const SplitRow(
      {super.key,
      required this.start,
      required this.end,
      this.maxFraction = 0.5,
      this.gap = 8,
      this.crossAxisAlignment = CrossAxisAlignment.center});
  final Widget start, end;
  final double maxFraction, gap;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final cap =
            box.hasBoundedWidth ? box.maxWidth * maxFraction : double.infinity;
        return Row(crossAxisAlignment: crossAxisAlignment, children: [
          Expanded(child: start),
          SizedBox(width: gap),
          ConstrainedBox(
              constraints: BoxConstraints(maxWidth: cap), child: end),
        ]);
      });
}

/// One-line amount that shrinks instead of overflowing.
class FitAmount extends StatelessWidget {
  const FitAmount(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerEnd,
      child: Text(text,
          maxLines: 1,
          style: style
              .copyWith(fontFeatures: const [FontFeature.tabularFigures()])));
}

/// Small white tile with a label and a number.
class StatTile extends StatelessWidget {
  const StatTile(
      {super.key,
      required this.label,
      required this.value,
      this.highlight = false});
  final String label, value;

  /// Orange outline for something that needs doing.
  final bool highlight;

  @override
  Widget build(BuildContext context) => PaperCard(
      radius: 14,
      padding: const EdgeInsets.all(12),
      border: highlight
          ? const BorderSide(color: AppColors.accentLine, width: 1.5)
          : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        WordFitText(label,
            maxLines: 2,
            style: TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                color: highlight ? AppColors.accentInk : AppColors.muted)),
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value,
                maxLines: 1,
                style: const TextStyle(
                    fontSize: 19,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()]))),
      ]));
}

/// Round initial for a person or business.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar(
      {super.key,
      required this.name,
      this.tone = ChipTone.neutral,
      this.size = 42});
  final String name;
  final ChipTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = toneColors(tone);
    final trimmed = name.trim();
    final initial =
        trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
    return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration:
            BoxDecoration(color: colors.background, shape: BoxShape.circle),
        child: Text(initial,
            style: TextStyle(
                fontSize: size * 0.38,
                fontWeight: FontWeight.w700,
                color: colors.foreground)));
  }
}

/// Muted date line above a group of rows.
class DayHeader extends StatelessWidget {
  const DayHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: AppColors.muted)));
}

/// Bold label above a field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13, height: 1.4, fontWeight: FontWeight.w600)));
}

/// Muted help line under a field.
class FieldHint extends StatelessWidget {
  const FieldHint(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(left: 2, top: 6),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12, height: 1.45, color: AppColors.muted)));
}

/// Red text action such as "Reverse".
class DangerLink extends StatelessWidget {
  const DangerLink(
      {super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
        foregroundColor: AppColors.danger,
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
            fontFamily: 'HindSiliguri',
            fontSize: 14,
            fontWeight: FontWeight.w600));
    return icon == null
        ? TextButton(onPressed: onPressed, style: style, child: Text(label))
        : TextButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 17),
            label: Text(label));
  }
}

/// Grey pill that opens a shipment.
class ShipmentChip extends StatelessWidget {
  const ShipmentChip({super.key, required this.code, required this.onTap});
  final String code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: tr('Open shipment {code}', {'code': code}),
      excludeSemantics: true,
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Align(
                  widthFactor: 1,
                  child: Container(
                      height: 30,
                      padding: const EdgeInsets.fromLTRB(10, 0, 6, 0),
                      decoration: BoxDecoration(
                          color: AppColors.paper,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.line)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 15, color: AppColors.inkSoft),
                        const SizedBox(width: 5),
                        Flexible(
                            child: Text(code,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600))),
                        const Icon(Icons.chevron_right_rounded,
                            size: 16, color: AppColors.faint),
                      ]))))));
}

/// "18 lines · page 1 of 2" with previous and next buttons.
class PagerBar extends StatelessWidget {
  const PagerBar(
      {super.key, required this.summary, this.onPrevious, this.onNext});
  final String summary;
  final VoidCallback? onPrevious, onNext;

  @override
  Widget build(BuildContext context) {
    Widget button(Key key, String label, IconData icon, VoidCallback? onTap,
            {bool trailing = false}) =>
        Expanded(
            child: OutlinedButton(
                key: key,
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: AppColors.card,
                    disabledBackgroundColor: AppColors.paper,
                    foregroundColor: AppColors.ink,
                    disabledForegroundColor: AppColors.muted,
                    side: BorderSide(
                        color:
                            onTap == null ? AppColors.line : AppColors.field)),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: trailing
                        ? [
                            Flexible(child: Text(label)),
                            const SizedBox(width: 4),
                            Icon(icon, size: 18),
                          ]
                        : [
                            Icon(icon, size: 18),
                            const SizedBox(width: 4),
                            Flexible(child: Text(label)),
                          ])));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(summary,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 13, height: 1.45, color: AppColors.muted)),
      const SizedBox(height: 10),
      Row(children: [
        button(const Key('page-previous'), tr('Previous page'),
            Icons.chevron_left_rounded, onPrevious),
        const SizedBox(width: 10),
        button(const Key('page-next'), tr('Next page'),
            Icons.chevron_right_rounded, onNext,
            trailing: true),
      ]),
    ]);
  }
}

/// Coloured square key, e.g. "● Money in".
class LegendDot extends StatelessWidget {
  const LegendDot(
      {super.key,
      required this.color,
      required this.label,
      this.round = true,
      this.small = false});
  final Color color;
  final String label;
  final bool round;

  /// Muted 12 px label, for keys inside a card.
  final bool small;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: color,
                shape: round ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: round ? null : BorderRadius.circular(2))),
        SizedBox(width: small ? 4 : 6),
        Flexible(
            child: WordFitText(label,
                style: TextStyle(
                    fontSize: small ? 12 : 13,
                    height: 1.4,
                    color: small ? AppColors.muted : AppColors.inkSoft))),
      ]);
}

// ---------------------------------------------------------------------------
// Inputs.

/// Amount input with the currency sign in front.
class MoneyField extends StatelessWidget {
  const MoneyField(
      {super.key,
      required this.controller,
      this.currency,
      this.hint,
      this.onChanged});
  final TextEditingController controller;
  final String? currency;
  final String? hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()]),
      decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: AppColors.faint),
          prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: Text(currencySymbol(currency),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted))),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          contentPadding: const EdgeInsets.fromLTRB(4, 14, 14, 14)));
}

/// Grey search field used above lists.
class SearchBox extends StatelessWidget {
  const SearchBox(
      {super.key,
      required this.controller,
      required this.hint,
      required this.onChanged,
      this.maxLength});
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line));
    return TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        inputFormatters: [
          if (maxLength != null) LengthLimitingTextInputFormatter(maxLength)
        ],
        decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.paper,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            prefixIcon: const Icon(Icons.search_rounded, size: 21),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: tr('Clear search'),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    }),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5))));
  }
}

/// Pill-shaped option list; the chosen one is blue with a tick.
class CheckChips extends StatelessWidget {
  const CheckChips(
      {super.key,
      required this.options,
      required this.selected,
      required this.onSelected});
  final List<({String value, String label})> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final option in options)
          _CheckChip(
              label: option.label,
              selected: option.value == selected,
              onTap: () => onSelected(option.value)),
      ]);
}

class _CheckChip extends StatelessWidget {
  const _CheckChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
      selected: selected,
      button: true,
      child: Material(
          color: selected ? AppColors.primary : AppColors.card,
          shape: StadiumBorder(
              side: BorderSide(
                  color: selected ? AppColors.primary : AppColors.field)),
          child: InkWell(
              onTap: onTap,
              customBorder: const StadiumBorder(),
              child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: 44, minWidth: 48),
                  child: Padding(
                      padding:
                          EdgeInsets.fromLTRB(selected ? 12 : 16, 0, 16, 0),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (selected) ...[
                          const Icon(Icons.check_rounded,
                              size: 17, color: Colors.white),
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
                                        ? Colors.white
                                        : AppColors.ink))),
                      ]))))));
}

/// Large selectable card with an icon, e.g. Income / Capital / Expense.
class OptionCard extends StatelessWidget {
  const OptionCard(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.selected,
      required this.onTap,
      this.tone = ChipTone.neutral});
  final IconData icon;
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = toneColors(tone);
    return Semantics(
        selected: selected,
        button: true,
        inMutuallyExclusiveGroup: true,
        child: Material(
            color: selected ? AppColors.primarySoft : AppColors.card,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                    color: selected ? AppColors.primary : AppColors.line,
                    width: selected ? 2 : 1.5)),
            child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 92),
                    child: Stack(children: [
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                        color: selected
                                            ? AppColors.card
                                            : colors.background,
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Icon(icon,
                                        size: 19,
                                        color: selected
                                            ? AppColors.primary
                                            : colors.foreground)),
                                const SizedBox(height: 8),
                                WordFitText(title,
                                    style: TextStyle(
                                        fontSize: 15,
                                        height: 1.3,
                                        fontWeight: FontWeight.w700,
                                        color: selected
                                            ? AppColors.primaryInk
                                            : AppColors.ink)),
                                WordFitText(subtitle,
                                    style: TextStyle(
                                        fontSize: 12,
                                        height: 1.35,
                                        color: selected
                                            ? AppColors.primaryInk
                                            : AppColors.muted)),
                              ])),
                      if (selected)
                        const PositionedDirectional(
                            top: 10,
                            end: 10,
                            child: CircleAvatar(
                                radius: 10,
                                backgroundColor: AppColors.primary,
                                child: Icon(Icons.check_rounded,
                                    size: 14, color: Colors.white))),
                    ])))));
  }
}

/// Round radio mark drawn to match the cards.
class RadioMark extends StatelessWidget {
  const RadioMark({super.key, required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFC3CAD5),
              width: 2)),
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle))
          : null);
}

/// Row with a radio mark on the right, for one-of-many lists in a card.
class RadioRow extends StatelessWidget {
  const RadioRow(
      {super.key,
      required this.title,
      required this.selected,
      required this.onTap,
      this.subtitle,
      this.icon});
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    if (icon != null) ...[
                      IconBadge(icon!,
                          tone: selected ? ChipTone.blue : ChipTone.neutral,
                          size: 38),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600)),
                          if (subtitle != null)
                            Text(subtitle!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.4,
                                    color: AppColors.muted)),
                        ])),
                    const SizedBox(width: 10),
                    RadioMark(selected: selected),
                  ])))));
}

/// "BDT · ৳84,250.00".
String accountCaption(FinanceAccount account) =>
    '${account.currency} · ${formatMoney(account.balance, account.currency)}';

/// Every account as a radio list.
class AccountChoiceList extends StatelessWidget {
  const AccountChoiceList(
      {super.key,
      required this.accounts,
      required this.selected,
      required this.onSelected});
  final List<FinanceAccount> accounts;
  final String? selected;
  final ValueChanged<FinanceAccount> onSelected;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return EmptyNote(
          icon: Icons.account_balance_outlined,
          title: tr('No accounts'),
          body: tr('No accounts yet. Add a fund in Finance first.'));
    }
    return ListCard(children: [
      for (final account in accounts)
        RadioRow(
            key: ValueKey('account-${account.name}'),
            title: account.name,
            subtitle: accountCaption(account),
            icon: accountIcon(account.kind),
            selected: account.name == selected,
            onTap: () => onSelected(account)),
    ]);
  }
}

/// Tappable field showing the chosen account; opens a list of all accounts.
class AccountField extends StatelessWidget {
  const AccountField(
      {super.key,
      required this.accounts,
      required this.selected,
      required this.onSelected,
      required this.sheetTitle,
      this.tone = ChipTone.blue});
  final List<FinanceAccount> accounts;
  final FinanceAccount? selected;
  final ValueChanged<FinanceAccount> onSelected;
  final String sheetTitle;

  /// Icon colour once an account is chosen.
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final account = selected;
    return Semantics(
        button: true,
        label: account == null
            ? '$sheetTitle: ${tr('Choose an account')}'
            : '$sheetTitle: ${account.name}, ${account.currency}',
        excludeSemantics: true,
        child: Material(
            color: AppColors.card,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(controlRadius),
                side: const BorderSide(color: AppColors.field)),
            child: InkWell(
                borderRadius: BorderRadius.circular(controlRadius),
                onTap: () async {
                  final picked = await showAccountSheet(context,
                      title: sheetTitle,
                      accounts: accounts,
                      selected: account?.name);
                  if (picked != null) onSelected(picked);
                },
                child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 60),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(children: [
                          IconBadge(
                              account == null
                                  ? Icons.account_balance_wallet_outlined
                                  : accountIcon(account.kind),
                              tone: account == null ? ChipTone.neutral : tone,
                              size: 38),
                          const SizedBox(width: 12),
                          Expanded(
                              child: account == null
                                  ? Text(tr('Choose an account'),
                                      style: const TextStyle(
                                          fontSize: 15, color: AppColors.muted))
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                          Text(account.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 15,
                                                  height: 1.35,
                                                  fontWeight: FontWeight.w600)),
                                          Text(account.currency,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.muted)),
                                        ])),
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              color: AppColors.muted),
                        ]))))));
  }
}

Future<FinanceAccount?> showAccountSheet(BuildContext context,
    {required String title,
    required List<FinanceAccount> accounts,
    String? selected}) {
  return showModalBottomSheet<FinanceAccount>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SheetFrame(title: title, children: [
            if (accounts.isEmpty)
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                      tr('No accounts yet. Add a fund in Finance first.'),
                      style: const TextStyle(color: AppColors.muted))),
            for (final account in accounts)
              RadioRow(
                  title: account.name,
                  subtitle: accountCaption(account),
                  icon: accountIcon(account.kind),
                  selected: account.name == selected,
                  onTap: () => Navigator.of(context).pop(account)),
          ]));
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
      child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700))),
                Flexible(
                    child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 12),
                        children: children)),
              ])));
}

/// Pick one value from a short list in a bottom sheet.
Future<String?> showChoiceSheet(BuildContext context,
    {required String title,
    required List<({String value, String label})> options,
    required String selected}) {
  return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SheetFrame(title: title, children: [
            for (final option in options)
              RadioRow(
                  key: ValueKey('choice-${option.value}'),
                  title: option.label,
                  selected: option.value == selected,
                  onTap: () => Navigator.of(context).pop(option.value)),
          ]));
}

/// Rounded filter button that opens a menu; blue once a filter is set.
class FilterPill extends StatelessWidget {
  const FilterPill(
      {super.key,
      required this.label,
      required this.active,
      required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
      color: active ? AppColors.primarySoft : AppColors.card,
      shape: StadiumBorder(
          side:
              BorderSide(color: active ? AppColors.primary : AppColors.field)),
      child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 14,
                            height: 1.3,
                            fontWeight:
                                active ? FontWeight.w600 : FontWeight.w500,
                            color:
                                active ? AppColors.primaryInk : AppColors.ink)),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 19,
                        color: active ? AppColors.primaryInk : AppColors.muted),
                  ])))));
}

/// Fills `{amount}` in [template] as bold text and the rest as normal text.
/// The template comes from [tr] with every other placeholder filled.
class AmountSentence extends StatelessWidget {
  const AmountSentence(
      {super.key, required this.template, required this.amount});
  final String template, amount;

  @override
  Widget build(BuildContext context) {
    final parts = template.split('{amount}');
    return Text.rich(
        TextSpan(children: [
          for (var i = 0; i < parts.length; i++) ...[
            if (i > 0)
              TextSpan(
                  text: amount,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppColors.ink)),
            TextSpan(text: parts[i]),
          ]
        ]),
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 13, height: 1.4, color: AppColors.inkSoft));
  }
}
