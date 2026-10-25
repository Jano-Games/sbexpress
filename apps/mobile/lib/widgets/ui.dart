import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import 'brand_mark.dart';

class PageHeader extends StatelessWidget {
  const PageHeader(
      {super.key,
      required this.title,
      this.subtitle,
      this.action,
      this.eyebrow});
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!,
                      style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 0.6,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4)
                ],
                Text(title,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.3)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 14, height: 1.5))
                ],
              ])),
          if (action != null) ...[const SizedBox(width: 12), action!],
        ]),
      );
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.subtitle, this.onDark = false});
  final String? subtitle;

  /// White type for the blue login panel.
  final bool onDark;
  @override
  Widget build(BuildContext context) => Row(children: [
        BrandMark(onDark: onDark),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SBExpress',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: onDark ? Colors.white : AppColors.ink)),
          Text(subtitle ?? 'Sichuan Bangla Express',
              style: TextStyle(
                  fontSize: 12,
                  color: onDark ? const Color(0xD1FFFFFF) : AppColors.muted,
                  height: 1.4)),
        ])),
      ]);
}

class MetricTile extends StatelessWidget {
  const MetricTile(
      {super.key,
      required this.label,
      required this.value,
      this.hint,
      this.tone = ChipTone.teal});
  final String label, value;
  final String? hint;
  final ChipTone tone;
  @override
  Widget build(BuildContext context) => PaperCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color:
                      tone == ChipTone.red ? AppColors.danger : AppColors.ink)),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!,
                style: const TextStyle(
                    color: AppColors.muted, fontSize: 12, height: 1.45))
          ],
        ],
      ));
}

class CapacityBar extends StatelessWidget {
  const CapacityBar({super.key, required this.booked, required this.space});
  final double booked, space;
  @override
  Widget build(BuildContext context) {
    final over = booked > space;
    final left = space - booked;
    String kg(double value) =>
        value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
              value: space <= 0 ? 0 : (booked / space).clamp(0.0, 1.0),
              minHeight: 8,
              color: over ? AppColors.danger : AppColors.primary,
              backgroundColor: AppColors.lineSoft)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
            child: Text('${booked.toStringAsFixed(1)} / ${kg(space)} kg',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, height: 1.3))),
        Text(
            over
                ? tr('{kg} kg over', {'kg': kg(-left)})
                : tr('{kg} kg free', {'kg': kg(left)}),
            style: TextStyle(
                fontSize: 13,
                height: 1.3,
                color: over ? AppColors.danger : AppColors.muted)),
      ]),
    ]);
  }
}

class KvRow extends StatelessWidget {
  const KvRow(
      {super.key, required this.label, required this.value, this.valueColor});
  final String label, value;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 14))),
        const SizedBox(width: 16),
        Flexible(
            flex: 2,
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.ink,
                    fontFeatures: const [FontFeature.tabularFigures()]))),
      ]));
}

class IconBadge extends StatelessWidget {
  const IconBadge(this.icon,
      {super.key,
      this.tone = ChipTone.blue,
      this.size = 40,
      this.round = false});
  final IconData icon;
  final ChipTone tone;
  final double size;
  final bool round;
  @override
  Widget build(BuildContext context) {
    final colors = toneColors(tone);
    return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: colors.background,
            shape: round ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: round ? null : BorderRadius.circular(size * 0.3)),
        child: Icon(icon, color: colors.foreground, size: size * 0.5));
  }
}

class DirectoryTile extends StatelessWidget {
  const DirectoryTile(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.onTap,
      this.badge,
      this.icon});
  final String title, subtitle;
  final VoidCallback onTap;
  final String? badge;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => PaperCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        if (icon != null) ...[IconBadge(icon!), const SizedBox(width: 12)],
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    color: AppColors.muted, fontSize: 13, height: 1.45))
          ],
        ])),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Flexible(child: StatusPill(label: badge!))
        ],
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right_rounded,
            size: 20, color: AppColors.faint),
      ]));
}

class ChoiceChips extends StatelessWidget {
  const ChoiceChips(
      {super.key,
      required this.options,
      required this.selected,
      required this.onSelected});
  final List<({String value, String label})> options;
  final String selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 0, children: [
        for (final option in options)
          Semantics(
              selected: option.value == selected,
              button: true,
              child: InkWell(
                  onTap: () => onSelected(option.value),
                  borderRadius: BorderRadius.circular(999),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(
                          minHeight: minTouchTarget, minWidth: minTouchTarget),
                      child: Center(
                          widthFactor: 1,
                          child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                  color: option.value == selected
                                      ? AppColors.primary
                                      : AppColors.card,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: option.value == selected
                                          ? AppColors.primary
                                          : AppColors.field)),
                              child: Text(option.label,
                                  style: TextStyle(
                                      fontSize: 14,
                                      height: 1.35,
                                      fontWeight: option.value == selected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: option.value == selected
                                          ? Colors.white
                                          : AppColors.inkSoft)))))))
      ]);
}

enum AppButtonKind { current, teal, quiet, danger, tonal }

class AppButton extends StatelessWidget {
  const AppButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.kind = AppButtonKind.teal,
      this.busy = false,
      this.expand = true,
      this.icon});
  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final bool busy, expand;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final (background, foreground, side) = switch (kind) {
      AppButtonKind.current || AppButtonKind.teal => (
          AppColors.primary,
          Colors.white,
          BorderSide.none
        ),
      AppButtonKind.tonal => (
          AppColors.primarySoft,
          AppColors.primaryInk,
          BorderSide.none
        ),
      AppButtonKind.quiet => (
          AppColors.card,
          AppColors.ink,
          const BorderSide(color: AppColors.field)
        ),
      AppButtonKind.danger => (
          AppColors.card,
          AppColors.danger,
          const BorderSide(color: AppColors.dangerLine, width: 1.5)
        ),
    };
    final labelWidget = Text(label, textAlign: TextAlign.center);
    return SizedBox(
        width: expand ? double.infinity : null,
        child: FilledButton(
          onPressed: onPressed != null && !busy ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            disabledBackgroundColor: AppColors.neutralSoft,
            disabledForegroundColor: AppColors.faint,
            elevation: 0,
            minimumSize: const Size(48, 50),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(controlRadius),
                side: onPressed == null ? BorderSide.none : side),
            textStyle: const TextStyle(
                fontFamily: 'HindSiliguri',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4),
          ),
          child: busy
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: background == AppColors.primary
                          ? Colors.white
                          : AppColors.primary))
              : icon == null
                  ? labelWidget
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          Icon(icon, size: 19),
                          const SizedBox(width: 8),
                          Flexible(child: labelWidget)
                        ]),
        ));
  }
}

class PaperCard extends StatelessWidget {
  const PaperCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.onTap,
      this.color = AppColors.card,
      this.border,
      this.radius = cardRadius,
      this.flat = false});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color color;

  /// Highlights the card, e.g. the next flight or the current step.
  final BorderSide? border;
  final double radius;

  /// Drops the shadow for cards that sit on another surface.
  final bool flat;
  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
          borderRadius: shape, boxShadow: flat ? null : cardShadow),
      child: Material(
        color: color,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
            borderRadius: shape, side: border ?? BorderSide.none),
        child: InkWell(
            onTap: onTap,
            child: Container(
                width: double.infinity, padding: padding, child: child)),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.tone = ChipTone.teal});
  final String label;
  final ChipTone tone;
  @override
  Widget build(BuildContext context) {
    final colors = toneColors(tone);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
            color: colors.background, borderRadius: BorderRadius.circular(999)),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: colors.foreground,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                height: 1.5)));
  }
}

/// Five-segment hub chain progress: green done, orange current, grey waiting.
class StepBars extends StatelessWidget {
  const StepBars(
      {super.key,
      required this.done,
      this.current = true,
      this.total = 5,
      this.segmentWidth,
      this.height = 4});
  final int done, total;

  /// Whether the segment after the done ones is the step to do now.
  final bool current;

  /// Fixed segment width; null stretches across the row.
  final double? segmentWidth;
  final double height;
  @override
  Widget build(BuildContext context) {
    Widget segment(int i) {
      final color = i < done
          ? AppColors.ok
          : i == done && current
              ? AppColors.accent
              : AppColors.line;
      final bar = Container(
          width: segmentWidth,
          height: height,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(height / 2)));
      return segmentWidth == null ? Expanded(child: bar) : bar;
    }

    return Semantics(
        label: tr('Step {step}/{total}', {
          'step': (done + (current ? 1 : 0)).clamp(0, total),
          'total': total
        }),
        excludeSemantics: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            segment(i),
          ]
        ]));
  }
}

/// Small grey chip with an icon, e.g. "2 shipments".
class InfoChip extends StatelessWidget {
  const InfoChip(
      {super.key,
      required this.icon,
      required this.label,
      this.tone,
      this.muted = false});
  final IconData icon;
  final String label;
  final ChipTone? tone;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = tone == null ? null : toneColors(tone!);
    final foreground =
        colors?.foreground ?? (muted ? AppColors.muted : AppColors.inkSoft);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: colors?.background ?? AppColors.paper,
            borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 6),
          Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: foreground))),
        ]));
  }
}

/// Blue tip box.
class HintNote extends StatelessWidget {
  const HintNote({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline_rounded,
                size: 18, color: AppColors.primaryInk)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryInk))),
      ]));
}

class ErrorNote extends StatelessWidget {
  const ErrorNote({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        decoration: BoxDecoration(
            color: AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.error_outline_rounded,
                size: 20, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(
                child: Text(message,
                    style: const TextStyle(
                        color: AppColors.danger,
                        height: 1.5,
                        fontWeight: FontWeight.w500))),
          ]),
          if (onRetry != null)
            Padding(
                padding: const EdgeInsets.only(left: 22),
                child: TextButton(
                    onPressed: onRetry,
                    style:
                        TextButton.styleFrom(foregroundColor: AppColors.danger),
                    child: Text(tr('Try again'))))
          else
            const SizedBox(height: 8),
        ]),
      );
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(
      {super.key,
      required this.title,
      required this.body,
      this.icon = Icons.inbox_outlined});
  final String title, body;
  final IconData icon;
  @override
  Widget build(BuildContext context) => PaperCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(children: [
        IconBadge(icon, tone: ChipTone.neutral, size: 52, round: true),
        const SizedBox(height: 14),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 4),
        Text(body,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.muted, fontSize: 14, height: 1.5)),
      ]));
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(
      {super.key, required this.title, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, height: 1.35)),
          if (subtitle != null) ...[
            const SizedBox(height: 1),
            Text(subtitle!,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.muted, height: 1.45))
          ],
        ])),
        if (action != null) ...[const SizedBox(width: 8), action!],
      ]));
}

/// Text for narrow tiles and tabs. It wraps between words, never inside one:
/// when the longest word is wider than the space, the text shrinks until it
/// fits. English labels such as "Transactions" need this at large font sizes.
class WordFitText extends StatelessWidget {
  const WordFitText(this.text,
      {super.key, this.style, this.textAlign, this.maxLines});
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final resolved = DefaultTextStyle.of(context).style.merge(style);
        var shrink = 1.0;
        if (constraints.hasBoundedWidth) {
          for (final word in text.split(RegExp(r'\s+'))) {
            if (word.isEmpty) continue;
            final painter = TextPainter(
                text: TextSpan(text: word, style: resolved),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                maxLines: 1)
              ..layout();
            if (painter.width > constraints.maxWidth) {
              final fit = constraints.maxWidth / painter.width * 0.97;
              if (fit < shrink) shrink = fit;
            }
            painter.dispose();
          }
        }
        return Text(text,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
            style: shrink < 1
                ? resolved.copyWith(
                    fontSize: (resolved.fontSize ?? 14) * shrink)
                : style);
      });
}

class QuickAction extends StatelessWidget {
  const QuickAction(
      {super.key,
      required this.label,
      required this.icon,
      required this.onTap,
      this.tone = ChipTone.blue});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final ChipTone tone;
  @override
  Widget build(BuildContext context) {
    final colors = toneColors(tone);
    return Material(
        color: Colors.transparent,
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Column(children: [
                  Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: BorderRadius.circular(15)),
                      child: Icon(icon, color: colors.foreground, size: 23)),
                  const SizedBox(height: 7),
                  WordFitText(label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w600)),
                ]))));
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav(
      {super.key,
      required this.index,
      required this.onChanged,
      this.admin = false});
  final int index;
  final ValueChanged<int> onChanged;
  final bool admin;

  /// Hub tabs. Flights sit beside shipments so the hub sees what is landing.
  static List<String> get labels =>
      [tr('Home'), tr('Shipments'), tr('Flights'), tr('Tasks'), tr('More')];
  static List<String> get adminLabels =>
      [tr('Home'), tr('Shipments'), tr('Flights'), tr('Finance'), tr('More')];
  @override
  Widget build(BuildContext context) {
    final names = admin ? adminLabels : labels;
    final icons = [
      (Icons.home_outlined, Icons.home_rounded),
      (Icons.inventory_2_outlined, Icons.inventory_2_rounded),
      (Icons.flight_outlined, Icons.flight_rounded),
      admin
          ? (
              Icons.account_balance_wallet_outlined,
              Icons.account_balance_wallet_rounded
            )
          : (Icons.checklist_rounded, Icons.checklist_rounded),
      (Icons.grid_view_outlined, Icons.grid_view_rounded),
    ];
    return Material(
        color: AppColors.card,
        child: DecoratedBox(
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line))),
            child: SafeArea(
                top: false,
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(children: [
                      for (var i = 0; i < names.length; i++)
                        Expanded(
                            child: Semantics(
                                button: true,
                                selected: index == i,
                                label: names[i],
                                excludeSemantics: true,
                                child: InkWell(
                                  key: Key('nav-$i'),
                                  onTap: () => onChanged(i),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4, horizontal: 2),
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            AnimatedContainer(
                                                key: index == i
                                                    ? const Key('nav-pill')
                                                    : null,
                                                duration: const Duration(
                                                    milliseconds: 180),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 4),
                                                decoration: BoxDecoration(
                                                    color: index == i
                                                        ? AppColors.primarySoft
                                                        : Colors.transparent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999)),
                                                child: Icon(
                                                    index == i
                                                        ? icons[i].$2
                                                        : icons[i].$1,
                                                    size: 22,
                                                    color: index == i
                                                        ? AppColors.primary
                                                        : AppColors.muted)),
                                            const SizedBox(height: 4),
                                            FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(names[i],
                                                    maxLines: 1,
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        height: 1.3,
                                                        fontWeight: index == i
                                                            ? FontWeight.w700
                                                            : FontWeight.w500,
                                                        color: index == i
                                                            ? AppColors
                                                                .primaryInk
                                                            : AppColors
                                                                .muted))),
                                          ])),
                                )))
                    ])))));
  }
}

class BackTitle extends StatelessWidget implements PreferredSizeWidget {
  const BackTitle(
      {super.key,
      required this.title,
      this.actions,
      this.onBack,
      this.subtitle});
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) => AppBar(
      title: _AppBarTitle(title: title, subtitle: subtitle),
      actions: actions,
      shape: const Border(bottom: BorderSide(color: AppColors.line)),
      leading: IconButton(
          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          icon: const SbxIcon(SbxIconKind.back, color: AppColors.ink),
          tooltip: tr('Back')));
}

class _AppBarTitle extends StatelessWidget {
  const _AppBarTitle({required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, height: 1.3)),
        if (subtitle != null)
          Text(subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.muted, height: 1.35)),
      ]);
}

class SurfaceGroup extends StatelessWidget {
  const SurfaceGroup({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => PaperCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AppColors.lineSoft),
          children[i],
        ]
      ]));
}

class MenuRow extends StatelessWidget {
  const MenuRow(
      {super.key,
      required this.title,
      required this.icon,
      required this.onTap,
      this.subtitle,
      this.trailing,
      this.tone = ChipTone.blue});
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;
  final ChipTone tone;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            IconBadge(icon, tone: tone),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(subtitle!,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 13, height: 1.4)),
                  ],
                ])),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.faint, size: 20),
          ])));
}

class AmountLabel extends StatelessWidget {
  const AmountLabel(
      {super.key,
      required this.label,
      required this.value,
      this.color,
      this.size = 20});
  final String label, value;
  final Color? color;
  final double size;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 3),
        // An amount stays on one line and shrinks rather than splitting.
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value,
                maxLines: 1,
                style: TextStyle(
                    fontSize: size,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: color ?? AppColors.ink,
                    fontFeatures: const [FontFeature.tabularFigures()]))),
      ]);
}

class WorkspaceScaffold extends StatelessWidget {
  const WorkspaceScaffold(
      {super.key,
      required this.title,
      required this.children,
      this.subtitle,
      this.actions,
      this.toolbar,
      this.onRefresh,
      this.root = false,
      this.footer});
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? toolbar, footer;
  final Future<void> Function()? onRefresh;
  final List<Widget> children;

  /// Tab roots get a large title on the grey page; pushed screens get a
  /// white bar with a back button.
  final bool root;
  @override
  Widget build(BuildContext context) {
    final list = ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
            pageGutter, root && toolbar == null ? 4 : 16, pageGutter, 28),
        children: children);
    return Scaffold(
      appBar: root
          ? AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: AppColors.paper,
              toolbarHeight: subtitle == null ? 64 : 76,
              titleSpacing: pageGutter + 4,
              title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                            height: 1.3)),
                    if (subtitle != null)
                      Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                              height: 1.4)),
                  ]),
              actions: [...?actions, const SizedBox(width: 8)])
          : AppBar(
              leading: IconButton(
                  tooltip: tr('Back'),
                  icon: const Icon(Icons.arrow_back_rounded, size: 22),
                  onPressed: () => Navigator.of(context).maybePop()),
              title: _AppBarTitle(title: title, subtitle: subtitle),
              actions: actions,
              shape: const Border(bottom: BorderSide(color: AppColors.line))),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(children: [
                if (toolbar != null)
                  Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                          pageGutter, root ? 2 : 12, pageGutter, 12),
                      decoration: BoxDecoration(
                          color: root ? AppColors.paper : AppColors.card,
                          border: root
                              ? null
                              : const Border(
                                  bottom: BorderSide(color: AppColors.line))),
                      child: toolbar),
                Expanded(
                    child: onRefresh == null
                        ? list
                        : RefreshIndicator(onRefresh: onRefresh!, child: list)),
              ]))),
      bottomNavigationBar: footer,
    );
  }
}

/// Segmented control. Later steps can be locked with [enabledThrough].
class ScreenTabs extends StatelessWidget {
  const ScreenTabs(
      {super.key,
      required this.labels,
      required this.index,
      required this.onChanged,
      this.enabledThrough});
  final List<String> labels;
  final int index;
  final int? enabledThrough;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: const Color(0xFFE9EDF2),
          borderRadius: BorderRadius.circular(controlRadius)),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
              child: Semantics(
                  selected: index == i,
                  button: true,
                  enabled: enabledThrough == null || i <= enabledThrough!,
                  child: Material(
                      color: index == i ? AppColors.card : Colors.transparent,
                      elevation: index == i ? 1 : 0,
                      shadowColor: const Color(0x33101828),
                      borderRadius: BorderRadius.circular(9),
                      child: InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: enabledThrough != null && i > enabledThrough!
                              ? null
                              : () => onChanged(i),
                          child: Container(
                            alignment: Alignment.center,
                            constraints: const BoxConstraints(minHeight: 40),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 8),
                            child: WordFitText(labels[i],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 14,
                                    height: 1.3,
                                    fontWeight: index == i
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: index == i
                                        ? AppColors.ink
                                        : enabledThrough != null &&
                                                i > enabledThrough!
                                            ? AppColors.faint
                                            : AppColors.muted)),
                          )))))
        ]
      ]));
}

class FormSection extends StatelessWidget {
  const FormSection(
      {super.key, required this.title, required this.children, this.caption});
  final String title;
  final String? caption;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PaperCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(caption!,
              style: const TextStyle(fontSize: 13, color: AppColors.muted))
        ],
        const Divider(height: 26),
        ...children,
      ])));
}

class ActionFooter extends StatelessWidget {
  const ActionFooter({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
      color: AppColors.card,
      child: SafeArea(
          top: false,
          child: Container(
              padding:
                  const EdgeInsets.fromLTRB(pageGutter, 12, pageGutter, 12),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.line))),
              child: child)));
}
