import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sbexpress/theme/app_colors.dart';
import 'package:sbexpress/widgets/brand_mark.dart';

/// Writes the Android launcher and splash images from [BrandMarkPainter].
///
/// `RENDER_BRAND=1 flutter test test/render_brand_test.dart`
const _densities = {
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};
const _res = 'android/app/src/main/res';

Future<void> _png(String path, int pixels,
    {required BrandMarkPainter painter, double inset = 0}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final side = pixels - inset * 2;
  canvas.translate(inset, inset);
  painter.paint(canvas, Size.square(side));
  final image = await recorder.endRecording().toImage(pixels, pixels);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File(path)..parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('render brand images', (tester) async {
    if (Platform.environment['RENDER_BRAND'] != '1') return;
    await tester.runAsync(() async {
      const tile = BrandMarkPainter(tile: AppColors.primary, art: Colors.white);
      const mark = BrandMarkPainter(art: Colors.white);
      const mono = BrandMarkPainter(
          art: Colors.white, accent: Colors.white, ring: Color(0x00000000));
      const splash =
          BrandMarkPainter(tile: Colors.white, art: AppColors.primary);
      for (final MapEntry(key: name, value: d) in _densities.entries) {
        // Legacy icon: a 48dp tile with a 2dp margin.
        await _png('$_res/mipmap-$name/ic_launcher.png', (48 * d).round(),
            painter: tile, inset: 2 * d);
        // Adaptive layers are 108dp; the mark sits in the middle 72dp.
        await _png(
            '$_res/mipmap-$name/ic_launcher_foreground.png', (108 * d).round(),
            painter: mark, inset: 18 * d);
        await _png(
            '$_res/mipmap-$name/ic_launcher_monochrome.png', (108 * d).round(),
            painter: mono, inset: 18 * d);
        // Launch screen logo, 150dp.
        await _png('$_res/drawable-$name/splash_logo.png', (150 * d).round(),
            painter: splash);
      }
      await _png('docs/brand/sbexpress-icon-512.png', 512, painter: tile);
    });
  });
}
