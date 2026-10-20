import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.15)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: const TextStyle(color: AppColors.muted, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.subtitle});

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(12)),
          child: const Text('SB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sichuan Bangla Express', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.2)),
              Text(subtitle ?? 'Chengdu → Dhaka', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.value, this.hint, this.tone = ChipTone.teal});

  final String label;
  final String value;
  final String? hint;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = toneColors(tone);
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.foreground, height: 1.15)),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(hint!, style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.3)),
          ],
        ],
      ),
    );
  }
}

class CapacityBar extends StatelessWidget {
  const CapacityBar({super.key, required this.booked, required this.space});

  final double booked;
  final double space;

  @override
  Widget build(BuildContext context) {
    final ratio = space <= 0 ? 0.0 : (booked / space).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Container(decoration: BoxDecoration(color: AppColors.neutralSoft, borderRadius: BorderRadius.circular(99))),
                  Container(
                    width: constraints.maxWidth * ratio,
                    decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(99)),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          '${booked.toStringAsFixed(1)} / ${space.toStringAsFixed(space == space.roundToDouble() ? 0 : 1)} kg',
          style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class KvRow extends StatelessWidget {
  const KvRow({super.key, required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted))),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w600, color: valueColor ?? AppColors.ink))),
        ],
      ),
    );
  }
}

class DirectoryTile extends StatelessWidget {
  const DirectoryTile({super.key, required this.title, required this.subtitle, required this.onTap, this.badge});

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        child: Container(
          constraints: const BoxConstraints(minHeight: minTouchTarget),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(cardRadius), border: Border.all(color: AppColors.line)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(color: AppColors.muted, height: 1.35)),
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                StatusPill(label: badge!),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class ChoiceChips extends StatelessWidget {
  const ChoiceChips({super.key, required this.options, required this.selected, required this.onSelected});

  final List<({String value, String label})> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          Material(
            color: option.value == selected ? AppColors.teal : AppColors.card,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => onSelected(option.value),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                constraints: const BoxConstraints(minHeight: minTouchTarget, minWidth: minTouchTarget),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: option.value == selected ? AppColors.teal : AppColors.line),
                ),
                child: Text(
                  option.label,
                  style: TextStyle(color: option.value == selected ? Colors.white : AppColors.ink, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

enum AppButtonKind { current, teal, quiet, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AppButtonKind.teal,
    this.busy = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final background = switch (kind) {
      AppButtonKind.current => AppColors.amber,
      AppButtonKind.teal => AppColors.teal,
      AppButtonKind.quiet => AppColors.card,
      AppButtonKind.danger => AppColors.card,
    };
    final foreground = switch (kind) {
      AppButtonKind.current => AppColors.amberInk,
      AppButtonKind.teal => Colors.white,
      AppButtonKind.quiet => AppColors.teal,
      AppButtonKind.danger => AppColors.danger,
    };
    final border = switch (kind) {
      AppButtonKind.quiet => const BorderSide(color: AppColors.teal),
      AppButtonKind.danger => const BorderSide(color: AppColors.danger),
      _ => BorderSide.none,
    };
    final child = SizedBox(
      height: minTouchTarget,
      width: expand ? double.infinity : null,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.45),
          disabledForegroundColor: foreground.withValues(alpha: 0.7),
          elevation: 0,
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: border),
          textStyle: const TextStyle(fontFamily: 'HindSiliguri', fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: busy
            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: foreground))
            : Text(label),
      ),
    );
    return child;
  }
}

class PaperCard extends StatelessWidget {
  const PaperCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: colors.background, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: colors.foreground, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

class ErrorNote extends StatelessWidget {
  const ErrorNote({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: AppColors.danger, height: 1.4)),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            AppButton(label: 'আবার চেষ্টা', onPressed: onRetry, kind: AppButtonKind.teal, expand: false),
          ],
        ],
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  const EmptyNote({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: AppColors.muted, height: 1.4)),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(color: AppColors.muted, height: 1.35)),
          ],
        ],
      ),
    );
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const labels = ['হোম', 'Shipment', 'কাজ', 'আরও'];
  static const kinds = [SbxIconKind.home, SbxIconKind.shipment, SbxIconKind.tasks, SbxIconKind.more];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      child: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: index == i,
                      label: labels[i],
                      child: InkWell(
                        key: Key('nav-$i'),
                        onTap: () => onChanged(i),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: minTouchTarget, minWidth: minTouchTarget),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedContainer(
                                key: index == i ? const Key('nav-pill') : null,
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: index == i ? AppColors.tealSoft : Colors.transparent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: SbxIcon(kinds[i], color: index == i ? AppColors.teal : AppColors.muted),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                labels[i],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: index == i ? FontWeight.w600 : FontWeight.w500,
                                  color: index == i ? AppColors.teal : AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BackTitle extends StatelessWidget implements PreferredSizeWidget {
  const BackTitle({super.key, required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const SbxIcon(SbxIconKind.back),
        constraints: const BoxConstraints(minWidth: minTouchTarget, minHeight: minTouchTarget),
        tooltip: 'পিছনে',
      ),
    );
  }
}
