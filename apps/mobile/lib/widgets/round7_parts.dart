import 'package:flutter/material.dart';

import '../data/models/finance_snapshot.dart';
import '../data/models/flight.dart';
import '../data/models/ledger_actions.dart' show costCategories;
import '../features/admin/money_format.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import 'finance_parts.dart' show RadioRow, accountCaption, accountIcon;
import 'flow_parts.dart' show usualCostIcon;
import 'team_parts.dart' show DashedOutline;
import 'ui.dart';

/// Pieces of the one-page shipment, the costs on a bill, flight costs and
/// the saved customer link.

// ---------------------------------------------------------------------------
// Money lines and figures.

/// One line of a money breakdown: a label (with an optional line under it)
/// and its amount.
class MoneyRow extends StatelessWidget {
  const MoneyRow(
      {super.key,
      required this.label,
      required this.value,
      this.note,
      this.strong = false,
      this.color,
      this.valueWeight = FontWeight.w600});
  final String label, value;
  final String? note;
  final bool strong;

  /// Paints both sides, e.g. green for what was paid.
  final Color? color;
  final FontWeight valueWeight;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? AppColors.ink;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: LayoutBuilder(
            builder: (context, box) =>
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(label,
                            style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                fontWeight:
                                    strong ? FontWeight.w700 : FontWeight.w400,
                                color: ink)),
                        if (note != null)
                          Text(note!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: AppColors.muted)),
                      ])),
                  const SizedBox(width: 12),
                  // The amount keeps its own width, up to 60% of the row.
                  ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: box.maxWidth * 0.6),
                      child: Text(value,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              fontWeight:
                                  strong ? FontWeight.w700 : valueWeight,
                              color: ink,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ]))),
                ])));
  }
}

/// Tinted tile with a small label and a bold amount, e.g. Paid or Still due.
class SoftFigure extends StatelessWidget {
  const SoftFigure(
      {super.key,
      required this.label,
      required this.value,
      this.tone = ChipTone.neutral});
  final String label, value;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = toneColors(tone);
    return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
            color: colors.background, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, height: 1.35, color: colors.foreground)),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(value,
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 18,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: colors.foreground,
                      fontFeatures: const [FontFeature.tabularFigures()]))),
        ]));
  }
}

/// Card heading with a line under it and an optional action at the end.
class CardHead extends StatelessWidget {
  const CardHead(
      {super.key, required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15, height: 1.3, fontWeight: FontWeight.w700)),
          if (subtitle != null)
            Text(subtitle!,
                style: const TextStyle(
                    fontSize: 12, height: 1.4, color: AppColors.muted)),
        ])),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ]);
}

/// Outlined "+ Add" button at the end of a card heading.
class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.onPressed, this.label});
  final VoidCallback? onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
          side: const BorderSide(color: AppColors.field),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(controlRadius)),
          textStyle: const TextStyle(
              fontFamily: 'HindSiliguri',
              fontSize: 14,
              fontWeight: FontWeight.w600)),
      icon: const Icon(Icons.add_rounded, size: 18),
      label: Text(label ?? tr('Add')));
}

/// Square-ish quiet button with an icon over or beside its label, for rows
/// of two or three actions such as PDF · Share · Edit.
class QuietAction extends StatelessWidget {
  const QuietAction(
      {super.key,
      required this.icon,
      required this.label,
      required this.onPressed,
      this.tinted = false});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Soft blue, for the action most people want.
  final bool tinted;

  @override
  Widget build(BuildContext context) => OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
          foregroundColor: tinted ? AppColors.primaryInk : AppColors.ink,
          backgroundColor: tinted ? AppColors.primarySoft : AppColors.card,
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          side:
              BorderSide(color: tinted ? Colors.transparent : AppColors.field),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(controlRadius)),
          textStyle: const TextStyle(
              fontFamily: 'HindSiliguri',
              fontSize: 14,
              fontWeight: FontWeight.w600)),
      child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17),
            const SizedBox(width: 6),
            Flexible(
                child: Text(label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis)),
          ]));
}

/// Equal-width actions side by side.
class ActionRow extends StatelessWidget {
  const ActionRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: children[i]),
        ]
      ]));
}

/// A cost line: grey icon, what it was for, how it was paid and the amount.
class CostLine extends StatelessWidget {
  const CostLine(
      {super.key,
      required this.icon,
      required this.title,
      required this.detail,
      required this.amount,
      this.divider = false,
      this.onTap,
      this.trailing,
      this.detailColor,
      this.extra});
  final IconData icon;
  final String title, detail, amount;
  final bool divider;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? detailColor;

  /// Under the detail, e.g. a "Mark paid" action.
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final body = Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: divider
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.lineSoft)))
            : null,
        child: Row(children: [
          IconBadge(icon, tone: ChipTone.neutral, size: 38),
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
                Text(detail,
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: detailColor ?? AppColors.muted)),
                if (extra != null) extra!,
              ])),
          const SizedBox(width: 8),
          Text(amount,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()])),
          if (trailing != null) trailing!,
        ]));
    return onTap == null ? body : InkWell(onTap: onTap, child: body);
  }
}

/// Neutral note with an icon, a short title and a line under it.
class NoteBox extends StatelessWidget {
  const NoteBox(
      {super.key,
      required this.icon,
      required this.title,
      required this.body,
      this.tone = ChipTone.neutral,
      this.extra});
  final IconData icon;
  final String title, body;
  final ChipTone tone;

  /// Under the body, e.g. a [ChangeLine].
  final Widget? extra;

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
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 18, color: colors.foreground)),
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
                    Text(body,
                        style: const TextStyle(
                            fontSize: 12, height: 1.4, color: AppColors.muted)),
                    if (extra != null) extra!,
                  ])),
            ])));
  }
}

/// "Bill ৳5,100 → ৳5,400" with the arrow drawn as an icon, so it shows in
/// every font.
class ChangeLine extends StatelessWidget {
  const ChangeLine(
      {super.key,
      required this.label,
      required this.from,
      required this.to,
      this.style =
          const TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted)});
  final String label, from, to;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Semantics(
      label: '$label $from, $to',
      excludeSemantics: true,
      child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '$label $from '),
            WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(Icons.arrow_forward_rounded,
                    size: (style.fontSize ?? 14) + 1, color: style.color)),
            TextSpan(text: ' $to'),
          ]),
          style: style
              .copyWith(fontFeatures: const [FontFeature.tabularFigures()])));
}

// ---------------------------------------------------------------------------
// Sheet fields.

/// Small bold field label, with an optional muted part after it.
class SheetLabel extends StatelessWidget {
  const SheetLabel(this.text, {super.key, this.extra});
  final String text;
  final String? extra;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text.rich(
          TextSpan(children: [
            TextSpan(text: text),
            if (extra != null)
              TextSpan(
                  text: ' $extra',
                  style: const TextStyle(
                      fontWeight: FontWeight.w400, color: AppColors.muted)),
          ]),
          style: const TextStyle(
              fontSize: 13, height: 1.35, fontWeight: FontWeight.w600)));
}

/// "+ New" chip with a dashed outline.
class NewChip extends StatelessWidget {
  const NewChip(
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
      child: DashedOutline(
          radius: 999,
          strokeWidth: selected ? 1.5 : 1,
          color: selected ? AppColors.primary : const Color(0xFFC3CAD5),
          background: selected ? AppColors.primarySoft : AppColors.card,
          child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: 44, minWidth: 48),
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(selected ? Icons.check_rounded : Icons.add_rounded,
                            size: 17, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Flexible(
                            child: Text(label,
                                style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.3,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary))),
                      ]))))));
}

/// Where the money came from: an account, or "Pay later" (saved unpaid).
typedef PayFrom = ({String? account, bool later});

/// Field showing the chosen account or "Pay later"; tapping it opens both
/// in a sheet. [showBalance] puts the account's balance at the end,
/// otherwise "or pay later".
class PayFromField extends StatelessWidget {
  const PayFromField(
      {super.key,
      required this.accounts,
      required this.value,
      required this.onChanged,
      required this.sheetTitle,
      this.showBalance = false});
  final List<FinanceAccount> accounts;
  final PayFrom value;
  final ValueChanged<PayFrom> onChanged;
  final String sheetTitle;
  final bool showBalance;

  FinanceAccount? get _account {
    for (final account in accounts) {
      if (account.name == value.account) return account;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final account = value.later ? null : _account;
    final title = value.later
        ? tr('Pay later')
        : account?.name ?? tr('Choose an account');
    final end = value.later
        ? tr('Saved unpaid')
        : showBalance && account != null
            ? formatMoney(account.balance, account.currency)
            : tr('or pay later');
    return Semantics(
        button: true,
        label: '$sheetTitle: $title',
        excludeSemantics: true,
        child: Material(
            color: AppColors.card,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(controlRadius),
                side: const BorderSide(color: AppColors.field)),
            child: InkWell(
                borderRadius: BorderRadius.circular(controlRadius),
                onTap: () async {
                  final picked = await showPayFromSheet(context,
                      title: sheetTitle, accounts: accounts, value: value);
                  if (picked != null) onChanged(picked);
                },
                child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                        child: Row(children: [
                          Expanded(
                              child: Text(title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 15,
                                      height: 1.35,
                                      fontWeight:
                                          account == null && !value.later
                                              ? FontWeight.w400
                                              : FontWeight.w600,
                                      color: account == null && !value.later
                                          ? AppColors.muted
                                          : AppColors.ink))),
                          const SizedBox(width: 8),
                          Flexible(
                              child: Text(end,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.muted))),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              color: AppColors.muted),
                        ]))))));
  }
}

/// Every account, then "Pay later".
Future<PayFrom?> showPayFromSheet(BuildContext context,
        {required String title,
        required List<FinanceAccount> accounts,
        required PayFrom value}) =>
    showModalBottomSheet<PayFrom>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
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
                              children: [
                            if (accounts.isEmpty)
                              Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                      tr(
                                          'No accounts yet. Add a fund in Finance first.'),
                                      style: const TextStyle(
                                          color: AppColors.muted))),
                            for (final account in accounts)
                              RadioRow(
                                  key: ValueKey('pay-from-${account.name}'),
                                  title: account.name,
                                  subtitle: accountCaption(account),
                                  icon: accountIcon(account.kind),
                                  selected: !value.later &&
                                      account.name == value.account,
                                  onTap: () => Navigator.of(context).pop(
                                      (account: account.name, later: false))),
                            RadioRow(
                                key: const Key('pay-from-later'),
                                title: tr('Pay later'),
                                subtitle: tr(
                                    'Save it as unpaid. Nothing leaves an account.'),
                                icon: Icons.schedule_rounded,
                                selected: value.later,
                                onTap: () => Navigator.of(context)
                                    .pop((account: null, later: true))),
                          ])),
                    ]))));

// ---------------------------------------------------------------------------
// Customer link.

/// The link itself in a dashed box, selectable.
class UrlBox extends StatelessWidget {
  const UrlBox({super.key, required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => DashedOutline(
      radius: controlRadius,
      strokeWidth: 1,
      color: const Color(0xFFC3CAD5),
      background: AppColors.paper,
      child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: SelectableText(url,
              style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink))));
}

// ---------------------------------------------------------------------------
// Cost names and icons.

/// "Courier", "Customs", … for a cost category in the app language.
String costCategoryLabel(String category) =>
    costCategories[category] ?? tr('Other');

/// The labour chip's saved label.
const labourLabel = 'Labour';

/// What a flight cost was for: its category, or the label of an "others"
/// cost (labour or a new name).
String flightCostTitle(FlightCost cost) {
  if (cost.category != 'others') return costCategoryLabel(cost.category);
  final label = cost.label.trim();
  if (label.isEmpty) return tr('Other');
  if (label.toLowerCase() == labourLabel.toLowerCase()) return tr('Labour');
  return label;
}

/// "Airport to Dhaka hub · Dhaka cash" or "Pay later · unpaid".
String flightCostDetail(FlightCost cost) {
  final label = cost.label.trim();
  final named = cost.category != 'others' &&
      label.isNotEmpty &&
      label.toLowerCase() != cost.category.toLowerCase() &&
      label != costCategoryLabel(cost.category);
  final paid = cost.paid
      ? (cost.accountName == null || cost.accountName!.isEmpty
          ? tr('Paid')
          : cost.accountName!)
      : tr('Pay later · unpaid');
  return [if (named) label, paid].join(' · ');
}

IconData flightCostIcon(FlightCost cost) {
  if (cost.category == 'transport') return Icons.airport_shuttle_outlined;
  if (cost.category != 'others') return usualCostIcon(cost.category);
  return cost.label.trim().toLowerCase() == labourLabel.toLowerCase()
      ? Icons.engineering_outlined
      : Icons.receipt_long_outlined;
}
