import 'package:flutter/material.dart';

/// SBExpress palette: the web panel's blue for actions, orange only for
/// "do this now", green for done and red for problems. Older token names
/// (teal, amber, blue) stay as aliases so every screen follows the palette.
abstract final class AppColors {
  static const primary = Color(0xFF2459B8);
  static const primarySoft = Color(0xFFE5EBF6);
  static const primaryInk = Color(0xFF1B438A);

  /// The current step or the next thing to do.
  static const accent = Color(0xFFE8742A);
  static const accentSoft = Color(0xFFFDF0E6);
  static const accentInk = Color(0xFF9A4A12);
  static const accentStrong = Color(0xFFA9490F);
  static const accentLine = Color(0xFFF3B98C);

  /// Money summary surface.
  static const navy = Color(0xFF15213A);

  static const paper = Color(0xFFF4F6F9);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE3E7EE);
  static const lineSoft = Color(0xFFEEF1F5);
  static const field = Color(0xFFD5DBE4);
  static const ink = Color(0xFF18212F);
  static const inkSoft = Color(0xFF3A4658);
  static const muted = Color(0xFF5B677A);
  static const faint = Color(0xFF8A95A6);
  static const danger = Color(0xFFB3343B);
  static const dangerSoft = Color(0xFFFCEEEF);
  static const dangerLine = Color(0xFFE3B4B7);
  static const alert = Color(0xFFD23F45);
  static const ok = Color(0xFF1F7A4A);
  static const okSoft = Color(0xFFE8F5EE);
  static const neutralSoft = Color(0xFFEEF1F5);

  static const teal = primary;
  static const tealSoft = primarySoft;
  static const tealInk = primaryInk;
  static const blue = primary;
  static const blueSoft = primarySoft;
  static const amber = accent;
  static const amberInk = accentInk;
  static const warnSoft = accentSoft;
}

const double minTouchTarget = 48;
const double cardRadius = 16;
const double heroRadius = 20;
const double controlRadius = 12;
const double pageGutter = 16;

/// Soft elevation for white cards on the grey page.
const List<BoxShadow> cardShadow = [
  BoxShadow(color: Color(0x0D101828), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0A101828), blurRadius: 14, offset: Offset(0, 4)),
];

enum ChipTone { teal, neutral, blue, amber, green, red }

class ToneColors {
  const ToneColors(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

ToneColors toneColors(ChipTone tone) {
  switch (tone) {
    case ChipTone.teal:
      return const ToneColors(AppColors.primarySoft, AppColors.primaryInk);
    case ChipTone.neutral:
      return const ToneColors(AppColors.neutralSoft, AppColors.inkSoft);
    case ChipTone.blue:
      return const ToneColors(AppColors.primarySoft, AppColors.primaryInk);
    case ChipTone.amber:
      return const ToneColors(AppColors.accentSoft, AppColors.accentInk);
    case ChipTone.green:
      return const ToneColors(AppColors.okSoft, AppColors.ok);
    case ChipTone.red:
      return const ToneColors(AppColors.dangerSoft, AppColors.danger);
  }
}

/// Pipeline index 0 is waiting, 1–5 are in motion, 6–7 are hub handling, 8 is done.
ChipTone shipmentStatusTone(int index) {
  if (index <= 0) return ChipTone.neutral;
  if (index >= 8) return ChipTone.green;
  if (index >= 6) return ChipTone.amber;
  return ChipTone.blue;
}

ChipTone payTone(String status) {
  switch (status) {
    case 'paid':
      return ChipTone.green;
    case 'unpaid':
      return ChipTone.red;
    case 'partial':
    case 'cod':
      return ChipTone.amber;
    case 'monthly':
      return ChipTone.blue;
    default:
      return ChipTone.neutral;
  }
}

ChipTone flightStatusTone(String status) {
  switch (status) {
    case 'upcoming':
      return ChipTone.blue;
    case 'departed':
      return ChipTone.amber;
    default:
      return ChipTone.neutral;
  }
}

ChipTone noticeTone(String tag) {
  switch (tag) {
    case 'WEIGHT':
      return ChipTone.red;
    case 'FLIGHT':
      return ChipTone.blue;
    case 'DUE':
      return ChipTone.amber;
    default:
      return ChipTone.neutral;
  }
}
