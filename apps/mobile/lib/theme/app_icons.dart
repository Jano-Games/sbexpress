import 'package:flutter/material.dart';
import 'app_colors.dart';

enum SbxIconKind {
  home,
  shipment,
  tasks,
  more,
  back,
  camera,
  check,
  logout,
  image
}

class SbxIcon extends StatelessWidget {
  const SbxIcon(this.kind,
      {super.key, this.size = 22, this.color = AppColors.teal});
  final SbxIconKind kind;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Icon(
      switch (kind) {
        SbxIconKind.home => Icons.space_dashboard_outlined,
        SbxIconKind.shipment => Icons.inventory_2_outlined,
        SbxIconKind.tasks => Icons.task_alt_rounded,
        SbxIconKind.more => Icons.grid_view_rounded,
        SbxIconKind.back => Icons.arrow_back_rounded,
        SbxIconKind.camera => Icons.photo_camera_outlined,
        SbxIconKind.check => Icons.check_rounded,
        SbxIconKind.logout => Icons.logout_rounded,
        SbxIconKind.image => Icons.image_outlined,
      },
      size: size,
      color: color);
}
