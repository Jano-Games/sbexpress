import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'ui.dart';

/// Pieces shared by the flyer, team, settings, task and billing forms.

/// Bold label above a field. With [optional], the trailing "(optional)" part
/// of the text is drawn lighter.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.optional = false});
  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final cut = optional && text.endsWith(')') ? text.lastIndexOf(' (') : -1;
    return Text.rich(
        TextSpan(children: [
          TextSpan(text: cut < 0 ? text : text.substring(0, cut)),
          if (cut >= 0)
            TextSpan(
                text: text.substring(cut),
                style: const TextStyle(
                    fontWeight: FontWeight.w400, color: AppColors.muted)),
        ]),
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.35,
            color: AppColors.ink));
  }
}

/// A label, the field itself and an optional helper line under it.
class LabeledField extends StatelessWidget {
  const LabeledField(
      {super.key,
      required this.label,
      required this.child,
      this.helper,
      this.trailing,
      this.optional = false});
  final String label;
  final Widget child;
  final String? helper;
  final Widget? trailing;

  /// The label ends in "(optional)", drawn lighter.
  final bool optional;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: FieldLabel(label, optional: optional)),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 6),
        child,
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(helper!,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.muted, height: 1.4)),
        ],
      ]);
}

/// Currency or unit sign drawn inside the start of a field.
Widget fieldSign(String sign, {double size = 16}) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 14, end: 6),
    child: Text(sign,
        style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w600,
            color: AppColors.muted)));

const fieldSignConstraints = BoxConstraints(minWidth: 0, minHeight: 0);

/// White card that holds a group of fields.
class FormCard extends StatelessWidget {
  const FormCard(
      {super.key, required this.children, this.title, this.gap = 14});
  final List<Widget> children;
  final String? title;
  final double gap;

  @override
  Widget build(BuildContext context) => PaperCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) ...[
          Text(title!,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, height: 1.35)),
          SizedBox(height: gap - 2),
        ],
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          children[i],
        ],
      ]));
}

/// Two fields side by side, stacked when large text leaves too little room.
class PairRow extends StatelessWidget {
  const PairRow(
      {super.key,
      required this.first,
      required this.second,
      this.flex = const [1, 1]});
  final Widget first, second;
  final List<int> flex;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(100) / 100;
        if (box.maxWidth / scale < 280) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [first, const SizedBox(height: 14), second]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: flex[0], child: first),
          const SizedBox(width: 10),
          Expanded(flex: flex[1], child: second),
        ]);
      });
}

typedef SegmentOption<T> = ({T value, String label, IconData? icon});

/// Grey track with a white thumb, for two or three exclusive choices.
class SegmentPicker<T> extends StatelessWidget {
  const SegmentPicker(
      {super.key,
      required this.options,
      required this.selected,
      required this.onChanged,
      this.flex,
      this.oneLine = false});
  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Relative widths; null makes every option equal.
  final List<int>? flex;

  /// Shrinks a long label instead of wrapping it, for narrow pickers.
  final bool oneLine;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: const Color(0xFFE9EDF2),
          borderRadius: BorderRadius.circular(controlRadius)),
      child: Row(children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
              flex: flex == null ? 1 : flex![i],
              child: _Segment(
                  option: options[i],
                  selected: options[i].value == selected,
                  oneLine: oneLine,
                  onTap: () => onChanged(options[i].value))),
        ]
      ]));
}

class _Segment<T> extends StatelessWidget {
  const _Segment(
      {required this.option,
      required this.selected,
      required this.oneLine,
      required this.onTap});
  final SegmentOption<T> option;
  final bool selected, oneLine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.ink : AppColors.muted;
    final style = TextStyle(
        fontSize: 14,
        height: 1.3,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: color);
    final content = oneLine
        ? FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (option.icon != null) ...[
                Icon(option.icon, size: 15, color: color),
                const SizedBox(width: 5),
              ],
              Text(option.label, maxLines: 1, style: style),
            ]))
        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (option.icon != null) ...[
              Icon(option.icon, size: 16, color: color),
              const SizedBox(width: 6),
            ],
            Flexible(
                child: WordFitText(option.label,
                    textAlign: TextAlign.center, style: style)),
          ]);
    return Semantics(
        selected: selected,
        button: true,
        inMutuallyExclusiveGroup: true,
        child: Material(
            color: selected ? AppColors.card : Colors.transparent,
            elevation: selected ? 1 : 0,
            shadowColor: const Color(0x33101828),
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: onTap,
                child: Container(
                    alignment: Alignment.center,
                    constraints: const BoxConstraints(minHeight: 40),
                    padding: EdgeInsets.symmetric(
                        horizontal: oneLine ? 4 : 6, vertical: 8),
                    child: content))));
  }
}

/// Round chips where the chosen one is filled blue with a tick.
class TickChips extends StatelessWidget {
  const TickChips(
      {super.key,
      required this.options,
      required this.selected,
      required this.onSelected});
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final option in options)
          Semantics(
              selected: option == selected,
              button: true,
              child: Material(
                  color:
                      option == selected ? AppColors.primary : AppColors.card,
                  shape: StadiumBorder(
                      side: BorderSide(
                          color: option == selected
                              ? AppColors.primary
                              : AppColors.field)),
                  child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => onSelected(option),
                      child: Container(
                          constraints: const BoxConstraints(
                              minHeight: minTouchTarget - 4),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (option == selected) ...[
                              const Icon(Icons.check_rounded,
                                  size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                            ],
                            Text(option,
                                style: TextStyle(
                                    fontSize: 14,
                                    height: 1.3,
                                    fontWeight: option == selected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: option == selected
                                        ? Colors.white
                                        : AppColors.ink)),
                          ]))))),
      ]);
}

/// Rounded box with a dashed outline, for drop zones and "add" rows.
class DashedOutline extends StatelessWidget {
  const DashedOutline(
      {super.key,
      required this.child,
      this.radius = controlRadius,
      this.color = AppColors.field,
      this.background,
      this.strokeWidth = 1.5});
  final Widget child;
  final double radius, strokeWidth;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) => CustomPaint(
      foregroundPainter:
          _DashPainter(color: color, radius: radius, strokeWidth: strokeWidth),
      child: Material(
          color: background ?? Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: child));
}

class _DashPainter extends CustomPainter {
  const _DashPainter(
      {required this.color, required this.radius, required this.strokeWidth});
  final Color color;
  final double radius, strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 5), paint);
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;
}

/// Blue tip box with its own icon and optional rich text.
class TipNote extends StatelessWidget {
  const TipNote(
      {super.key, this.text, this.rich, this.icon = Icons.info_outline_rounded})
      : assert(text != null || rich != null);
  final String? text;
  final InlineSpan? rich;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        fontSize: 13,
        height: 1.5,
        fontWeight: FontWeight.w500,
        color: AppColors.primaryInk);
    return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 18, color: AppColors.primaryInk)),
          const SizedBox(width: 10),
          Expanded(
              child: rich == null
                  ? Text(text!, style: style)
                  : Text.rich(rich!, style: style)),
        ]));
  }
}

/// Orange note for something that needs a decision.
class AttentionNote extends StatelessWidget {
  const AttentionNote({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
          color: AppColors.accentSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accentLine)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentInk))),
      ]));
}

enum AvatarTone { filled, soft, muted }

/// Round initials. [letters] is 1 for staff and 2 for flyers.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.name,
      {super.key,
      this.size = 44,
      this.tone = AvatarTone.soft,
      this.letters = 2});
  final String name;
  final double size;
  final AvatarTone tone;
  final int letters;

  static String initialsOf(String name, {int letters = 2}) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    final picked = letters == 1 ? words.take(1) : words.take(2);
    return [for (final word in picked) word.characters.first.toUpperCase()]
        .join();
  }

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      AvatarTone.filled => (AppColors.primary, Colors.white),
      AvatarTone.soft => (AppColors.primarySoft, AppColors.primaryInk),
      AvatarTone.muted => (AppColors.neutralSoft, AppColors.inkSoft),
    };
    return ExcludeSemantics(
        child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration:
                BoxDecoration(color: background, shape: BoxShape.circle),
            child: Text(initialsOf(name, letters: letters),
                style: TextStyle(
                    fontSize: size * (letters == 1 ? 0.38 : 0.34),
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: foreground))));
  }
}

/// Light blue pill button for the app bar, e.g. "+ New".
class BarPillButton extends StatelessWidget {
  const BarPillButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.icon = Icons.add_rounded,
      this.outlined = false});
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// White with a grey outline, for closing something.
  final bool outlined;

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
          backgroundColor: outlined ? AppColors.card : AppColors.primarySoft,
          foregroundColor: outlined ? AppColors.inkSoft : AppColors.primaryInk,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          side: outlined ? const BorderSide(color: AppColors.field) : null,
          shape: const StadiumBorder()),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label));
}

/// Muted count or caption on the right of a section title.
class SectionCount extends StatelessWidget {
  const SectionCount(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 13, color: AppColors.muted));
}

/// Error line shown above the footer button so it is seen after tapping.
class FooterActions extends StatelessWidget {
  const FooterActions({super.key, required this.child, this.error});
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) => ActionFooter(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (error != null)
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.error_outline_rounded,
                        size: 18, color: AppColors.danger)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(error!,
                        style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                            color: AppColors.danger))),
              ])),
        child,
      ]));
}

/// Compact outlined or tonal button that fits three in a row.
class SmallActionButton extends StatelessWidget {
  const SmallActionButton(
      {super.key,
      required this.label,
      required this.icon,
      required this.onPressed,
      this.tonal = false,
      this.busy = false});
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool tonal, busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final foreground = !enabled
        ? AppColors.faint
        : tonal
            ? AppColors.primaryInk
            : AppColors.ink;
    return Material(
        color: !enabled
            ? AppColors.neutralSoft
            : tonal
                ? AppColors.primarySoft
                : AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
            side: tonal || !enabled
                ? BorderSide.none
                : const BorderSide(color: AppColors.field)),
        child: InkWell(
            borderRadius: BorderRadius.circular(controlRadius),
            onTap: enabled ? onPressed : null,
            child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (busy)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    Icon(icon, size: 18, color: foreground),
                  const SizedBox(width: 6),
                  Flexible(
                      child: WordFitText(label,
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: 14,
                              height: 1.3,
                              fontWeight: FontWeight.w600,
                              color: foreground))),
                ]))));
  }
}

/// Status pill with a leading tick, e.g. "Verified by Rafiq".
class TickPill extends StatelessWidget {
  const TickPill({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
          color: AppColors.okSoft, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_rounded, size: 13, color: AppColors.ok),
        const SizedBox(width: 4),
        Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ok))),
      ]));
}

/// Plain number for counts, without decimals when whole.
String plainNumber(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();
