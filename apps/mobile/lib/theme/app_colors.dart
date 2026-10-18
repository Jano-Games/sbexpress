import 'package:flutter/material.dart';

/// Pixel's board: deep teal, amber only for the current action, warm paper.
abstract final class AppColors {
  static const teal = Color(0xFF0B5563);
  static const tealSoft = Color(0xFFD7E7EA);
  static const tealInk = Color(0xFF083F4A);
  static const amber = Color(0xFFFFB020);
  static const amberInk = Color(0xFF3D2A00);
  static const paper = Color(0xFFF7F5F0);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE4DFD6);
  static const ink = Color(0xFF1C1915);
  static const muted = Color(0xFF6E675F);
  static const danger = Color(0xFF9B3A2F);
  static const ok = Color(0xFF1F7A4D);
}

const double minTouchTarget = 48;
const double cardRadius = 18;
