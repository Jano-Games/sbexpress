import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/brand_mark.dart';

/// Shown while the saved sign-in is checked. The logo sits at the centre,
/// where the Android launch screen draws it, and grows in with the name.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _soft = Color(0xD1FFFFFF);
  static const _textBlock = 112.0;

  late final _intro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));
  late final _grow = Tween(begin: 0.55, end: 1.0)
      .animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutBack));
  late final _text = CurvedAnimation(
      parent: _intro, curve: const Interval(0.35, 1, curve: Curves.easeOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_intro.status != AnimationStatus.dismissed) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
          backgroundColor: AppColors.primary,
          body: Stack(children: [
            Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Balances the text below so the logo stays centred.
              const SizedBox(height: _textBlock),
              ScaleTransition(
                  scale: _grow,
                  child: const BrandMark(size: 150, onDark: true)),
              SizedBox(
                  height: _textBlock,
                  child: FadeTransition(
                      opacity: _text,
                      child: Column(children: [
                        const SizedBox(height: 22),
                        const Text('SBExpress',
                            style: TextStyle(
                                fontSize: 26,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        const SizedBox(height: 2),
                        const Text('Sichuan Bangla Express',
                            style: TextStyle(fontSize: 13, color: _soft)),
                        const SizedBox(height: 22),
                        SizedBox(
                            width: 64,
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: const LinearProgressIndicator(
                                    minHeight: 3,
                                    color: AppColors.accent,
                                    backgroundColor: Color(0xFF4A77C9)))),
                      ]))),
            ])),
            Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                    top: false,
                    child: Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: FadeTransition(
                            opacity: _text,
                            child: Text('${tr('China')} · ${tr('Bangladesh')}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13, color: _soft)))))),
          ])));
}
