import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

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
  const StatusPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: AppColors.tealSoft, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: const TextStyle(color: AppColors.tealInk, fontWeight: FontWeight.w600, fontSize: 13)),
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
