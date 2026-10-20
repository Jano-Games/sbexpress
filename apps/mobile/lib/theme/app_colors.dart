import 'package:flutter/material.dart';

/// Design board from docs/design: teal brand, warm paper, amber only for the
/// action that should happen now. Chip tones follow the same status map as the
/// web workspace (neutral, blue, amber, green, red).
abstract final class AppColors {
  static const teal = Color(0xFF0F766E);
  static const tealSoft = Color(0xFFE3F0EE);
  static const tealInk = Color(0xFF134E4A);
  static const amber = Color(0xFFFFB020);
  static const amberInk = Color(0xFF3D2A00);
  static const paper = Color(0xFFFAFAF8);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE7E5E0);
  static const ink = Color(0xFF1A1C1E);
  static const muted = Color(0xFF5B5E63);
  static const danger = Color(0xFFC92A2A);
  static const dangerSoft = Color(0xFFFDECEC);
  static const ok = Color(0xFF1B7A3D);
  static const okSoft = Color(0xFFE7F6EC);
  static const blue = Color(0xFF0E4DA4);
  static const blueSoft = Color(0xFFE7F0FE);
  static const warnSoft = Color(0xFFFBF5E9);
  static const neutralSoft = Color(0xFFF3F2EE);
}

const double minTouchTarget = 48;
const double cardRadius = 18;
const double pageGutter = 16;

enum ChipTone { teal, neutral, blue, amber, green, red }

class ToneColors {
  const ToneColors(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

ToneColors toneColors(ChipTone tone) {
  switch (tone) {
    case ChipTone.teal:
      return const ToneColors(AppColors.tealSoft, AppColors.tealInk);
    case ChipTone.neutral:
      return const ToneColors(AppColors.neutralSoft, AppColors.muted);
    case ChipTone.blue:
      return const ToneColors(AppColors.blueSoft, AppColors.blue);
    case ChipTone.amber:
      return const ToneColors(AppColors.warnSoft, AppColors.amberInk);
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
