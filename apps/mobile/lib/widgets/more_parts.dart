import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';
import 'ui.dart';

/// Icon colours of the More list, one per kind of tool.
abstract final class MoreTone {
  static const blue = ToneColors(Color(0xFFE8EEF9), AppColors.primary);
  static const teal = ToneColors(Color(0xFFEAF5F7), Color(0xFF175C70));
  static const purple = ToneColors(Color(0xFFF1ECFB), Color(0xFF5B3BA8));
  static const orange = ToneColors(AppColors.accentSoft, Color(0xFFC25A16));
  static const green = ToneColors(AppColors.okSoft, AppColors.ok);
  static const grey = ToneColors(AppColors.neutralSoft, AppColors.inkSoft);
  static const primary = ToneColors(AppColors.primarySoft, AppColors.primary);
}

/// Small grey heading over a group of tiles, e.g. "PEOPLE".
class MoreGroupLabel extends StatelessWidget {
  const MoreGroupLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      child: Semantics(
          header: true,
          child: Text(text.toUpperCase(),
              style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  letterSpacing: 0.26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted))));
}

/// A white card of [MoreTile]s with full-width lines between them.
class MoreCard extends StatelessWidget {
  const MoreCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => PaperCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.lineSoft),
          children[i],
        ]
      ]));
}

/// One row of the More list: icon, title, a line under it and whatever
/// sits at the end (a chevron when nothing else does and it opens).
class MoreTile extends StatelessWidget {
  const MoreTile(
      {super.key,
      required this.icon,
      required this.tone,
      required this.title,
      this.subtitle,
      this.trailing,
      this.onTap});
  final IconData icon;
  final ToneColors tone;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              child: Row(children: [
                Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: tone.background,
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, size: 19, color: tone.foreground)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              fontWeight: FontWeight.w600)),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(subtitle!,
                            style: const TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: AppColors.muted)),
                    ])),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ] else if (onTap != null) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.faint),
                ],
              ]))));
}

/// Blue text at the end of a tile, e.g. "Change" or "0.5 kg".
class TileAction extends StatelessWidget {
  const TileAction(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              fontFeatures: [FontFeature.tabularFigures()])));
}

/// EN | বাংলা. Each option is written in its own language so anyone can find
/// theirs.
class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch(
      {super.key, required this.bangla, required this.onChanged});
  final bool bangla;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, bool forBangla) {
      final on = forBangla == bangla;
      return Semantics(
          button: true,
          selected: on,
          inMutuallyExclusiveGroup: true,
          child: InkWell(
              onTap: on ? null : () => onChanged(forBangla),
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                  height: minTouchTarget,
                  child: Center(
                      widthFactor: 1,
                      child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                              color: on ? AppColors.card : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: on
                                  ? const [
                                      BoxShadow(
                                          color: Color(0x14101828),
                                          blurRadius: 2,
                                          offset: Offset(0, 1))
                                    ]
                                  : null),
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                  color: on
                                      ? AppColors.ink
                                      : AppColors.muted)))))));
    }

    return Semantics(
        label: tr('Language'),
        container: true,
        child: Stack(alignment: Alignment.center, children: [
          Positioned.fill(
              top: 8,
              bottom: 8,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: const Color(0xFFE9EDF2),
                      borderRadius: BorderRadius.circular(999)))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                option('EN', false),
                option('বাংলা', true),
              ])),
        ]));
  }
}

/// "৳17.50" for the exchange rate.
String takaRate(double rate) => '৳${rate.toStringAsFixed(2)}';
