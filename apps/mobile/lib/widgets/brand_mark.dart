import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The SBExpress mark: a dotted flight path from Chengdu to an orange Dhaka
/// dot, with a plane on the way.
///
/// The same painter draws the in-app logo and, through
/// `test/render_brand_test.dart`, the Android launcher and splash images.
class BrandMarkPainter extends CustomPainter {
  const BrandMarkPainter({
    this.tile,
    required this.art,
    this.accent = AppColors.accent,
    this.ring = Colors.white,
  });

  /// Rounded-square background; null draws the mark alone.
  final Color? tile;
  final Color art;
  final Color accent;

  /// Thin ring around the Dhaka dot.
  final Color ring;

  // The mark is designed on a 120-unit square.
  static const _start = Offset(28, 86);
  static const _control = Offset(50, 34);
  static const _end = Offset(92, 36);
  static const _planeAt = 0.5;

  static Offset _curve(double t) =>
      _start * ((1 - t) * (1 - t)) +
      _control * (2 * (1 - t) * t) +
      const Offset(90, 36) * (t * t);

  static Offset _tangent(double t) =>
      (_control - _start) * (2 * (1 - t)) +
      (const Offset(90, 36) - _control) * (2 * t);

  static final Path _plane = Path()
    ..moveTo(14, 0)
    ..cubicTo(14, -2, 12, -2.5, 10, -2.5)
    ..lineTo(3, -2.5)
    ..lineTo(-4, -11)
    ..lineTo(-8, -11)
    ..lineTo(-3, -2.5)
    ..lineTo(-10, -2.5)
    ..lineTo(-13, -6.5)
    ..lineTo(-16, -6.5)
    ..lineTo(-14, 0)
    ..lineTo(-16, 6.5)
    ..lineTo(-13, 6.5)
    ..lineTo(-10, 2.5)
    ..lineTo(-3, 2.5)
    ..lineTo(-8, 11)
    ..lineTo(-4, 11)
    ..lineTo(3, 2.5)
    ..lineTo(10, 2.5)
    ..cubicTo(12, 2.5, 14, 2, 14, 0)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 120;
    canvas.save();
    canvas.translate(
        (size.width - 120 * scale) / 2, (size.height - 120 * scale) / 2);
    canvas.scale(scale);
    if (tile != null) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(0, 0, 120, 120), const Radius.circular(28)),
          Paint()..color = tile!);
    }
    final fill = Paint()..color = art;
    final planeCenter = _curve(_planeAt);

    // A dot every 8 units along the path, leaving room around the plane.
    var length = 0.0;
    var nextDot = 8.0;
    var previous = _start;
    for (var i = 1; i <= 400; i++) {
      final point = _curve(i / 400);
      length += (point - previous).distance;
      previous = point;
      if (length >= nextDot) {
        nextDot += 8;
        if ((point - planeCenter).distance > 21 &&
            (point - _start).distance > 12 &&
            (point - _end).distance > 13) {
          canvas.drawCircle(point, 2.2, fill);
        }
      }
    }
    canvas.drawCircle(_start, 7, fill);
    canvas.drawCircle(_end, 10.5, Paint()..color = ring);
    canvas.drawCircle(_end, 7.5, Paint()..color = accent);

    final heading = _tangent(_planeAt);
    canvas.save();
    canvas.translate(planeCenter.dx, planeCenter.dy);
    canvas.rotate(math.atan2(heading.dy, heading.dx));
    canvas.scale(1.15);
    canvas.drawPath(_plane, fill);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(BrandMarkPainter oldDelegate) =>
      tile != oldDelegate.tile ||
      art != oldDelegate.art ||
      accent != oldDelegate.accent ||
      ring != oldDelegate.ring;
}

/// The logo as a rounded tile. [onDark] gives a white tile for blue panels.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44, this.onDark = false});
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Semantics(
      label: 'SBExpress',
      image: true,
      child: CustomPaint(
          size: Size.square(size),
          painter: BrandMarkPainter(
              tile: onDark ? Colors.white : AppColors.primary,
              art: onDark ? AppColors.primary : Colors.white)));
}
