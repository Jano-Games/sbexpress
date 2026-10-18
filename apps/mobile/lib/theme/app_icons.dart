import 'package:flutter/material.dart';

import 'app_colors.dart';

enum SbxIconKind { home, shipment, tasks, more, back, camera, check, logout, image }

class SbxIcon extends StatelessWidget {
  const SbxIcon(this.kind, {super.key, this.size = 22, this.color = AppColors.teal});

  final SbxIconKind kind;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _IconPainter(kind, color),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.kind, this.color);

  final SbxIconKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    switch (kind) {
      case SbxIconKind.home:
        final roof = Path()
          ..moveTo(w * 0.16, h * 0.46)
          ..lineTo(w * 0.5, h * 0.16)
          ..lineTo(w * 0.84, h * 0.46);
        canvas.drawPath(roof, paint);
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.26, h * 0.44, w * 0.48, h * 0.4), Radius.circular(w * 0.06)),
          paint,
        );
      case SbxIconKind.shipment:
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.18, h * 0.28, w * 0.64, h * 0.5), Radius.circular(w * 0.08)),
          paint,
        );
        canvas.drawLine(Offset(w * 0.18, h * 0.46), Offset(w * 0.82, h * 0.46), paint);
        canvas.drawLine(Offset(w * 0.5, h * 0.28), Offset(w * 0.5, h * 0.46), paint);
      case SbxIconKind.tasks:
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.22, h * 0.16, w * 0.56, h * 0.68), Radius.circular(w * 0.08)),
          paint,
        );
        canvas.drawLine(Offset(w * 0.36, h * 0.38), Offset(w * 0.64, h * 0.38), paint);
        canvas.drawLine(Offset(w * 0.36, h * 0.52), Offset(w * 0.64, h * 0.52), paint);
        canvas.drawLine(Offset(w * 0.36, h * 0.66), Offset(w * 0.54, h * 0.66), paint);
      case SbxIconKind.more:
        for (final dx in [0.28, 0.5, 0.72]) {
          canvas.drawCircle(Offset(w * dx, h * 0.5), w * 0.07, fill);
        }
      case SbxIconKind.back:
        final path = Path()
          ..moveTo(w * 0.62, h * 0.22)
          ..lineTo(w * 0.32, h * 0.5)
          ..lineTo(w * 0.62, h * 0.78);
        canvas.drawPath(path, paint);
      case SbxIconKind.camera:
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.16, h * 0.32, w * 0.68, h * 0.46), Radius.circular(w * 0.08)),
          paint,
        );
        canvas.drawCircle(Offset(w * 0.5, h * 0.55), w * 0.12, paint);
        canvas.drawLine(Offset(w * 0.34, h * 0.32), Offset(w * 0.42, h * 0.22), paint);
        canvas.drawLine(Offset(w * 0.42, h * 0.22), Offset(w * 0.58, h * 0.22), paint);
      case SbxIconKind.check:
        final path = Path()
          ..moveTo(w * 0.22, h * 0.52)
          ..lineTo(w * 0.42, h * 0.72)
          ..lineTo(w * 0.78, h * 0.3);
        canvas.drawPath(path, paint);
      case SbxIconKind.logout:
        canvas.drawLine(Offset(w * 0.42, h * 0.5), Offset(w * 0.78, h * 0.5), paint);
        final arrow = Path()
          ..moveTo(w * 0.62, h * 0.34)
          ..lineTo(w * 0.8, h * 0.5)
          ..lineTo(w * 0.62, h * 0.66);
        canvas.drawPath(arrow, paint);
        final door = Path()
          ..moveTo(w * 0.46, h * 0.22)
          ..lineTo(w * 0.22, h * 0.22)
          ..lineTo(w * 0.22, h * 0.78)
          ..lineTo(w * 0.46, h * 0.78);
        canvas.drawPath(door, paint);
      case SbxIconKind.image:
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.16, h * 0.22, w * 0.68, h * 0.56), Radius.circular(w * 0.08)),
          paint,
        );
        canvas.drawCircle(Offset(w * 0.36, h * 0.4), w * 0.06, fill);
        final hill = Path()
          ..moveTo(w * 0.2, h * 0.68)
          ..lineTo(w * 0.4, h * 0.5)
          ..lineTo(w * 0.56, h * 0.64)
          ..lineTo(w * 0.78, h * 0.42);
        canvas.drawPath(hill, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _IconPainter oldDelegate) => oldDelegate.kind != kind || oldDelegate.color != color;
}
