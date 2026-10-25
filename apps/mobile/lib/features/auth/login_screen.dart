import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSubmit});

  final Future<void> Function(String email, String password) onSubmit;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  var _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'সঠিক ইমেইল দিন।');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'পাসওয়ার্ড দিন।');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(email, password);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.card,
        body: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(padding: EdgeInsets.zero, children: [
            const _Hero(),
            Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                child: AutofillGroup(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      const Text('লগইন করুন',
                          style: TextStyle(
                              fontSize: 24,
                              height: 1.3,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text(
                          'স্টাফ ইমেইল ও পাসওয়ার্ড দিন। হাব না অ্যাডমিন — অ্যাকাউন্ট থেকেই ঠিক হবে।',
                          style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                              height: 1.55)),
                      const SizedBox(height: 22),
                      const _FieldLabel('ইমেইল'),
                      TextField(
                          key: const Key('login-email'),
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email
                          ],
                          decoration: const InputDecoration(
                              hintText: 'আপনার ইমেইল',
                              prefixIcon:
                                  Icon(Icons.mail_outline_rounded, size: 20))),
                      const SizedBox(height: 16),
                      const _FieldLabel('পাসওয়ার্ড'),
                      TextField(
                          key: const Key('login-password'),
                          controller: _password,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _busy ? null : _submit(),
                          decoration: InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: const Icon(Icons.lock_outline_rounded,
                                  size: 20),
                              suffixIcon: IconButton(
                                  tooltip: _obscure
                                      ? 'পাসওয়ার্ড দেখুন'
                                      : 'পাসওয়ার্ড লুকান',
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20)))),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        ErrorNote(message: _error!)
                      ],
                      const SizedBox(height: 22),
                      AppButton(
                          key: const Key('login-submit'),
                          label: 'লগইন করুন',
                          icon: Icons.arrow_forward_rounded,
                          busy: _busy,
                          onPressed: _submit),
                      const SizedBox(height: 28),
                      const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield_outlined,
                                color: AppColors.muted, size: 16),
                            SizedBox(width: 8),
                            Flexible(
                                child: Text(
                                    'পাসওয়ার্ড ভুলে গেলে অ্যাডমিনকে জানান',
                                    style: TextStyle(
                                        color: AppColors.muted, fontSize: 13))),
                          ]),
                    ]))),
          ]),
        )),
      ));
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)));
}

class _Hero extends StatelessWidget {
  const _Hero();

  static const _soft = Color(0xCCFFFFFF);

  @override
  Widget build(BuildContext context) {
    Widget place(String country, String city, {bool end = false}) => Column(
            crossAxisAlignment:
                end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(country, style: const TextStyle(fontSize: 12, color: _soft)),
              Text(city,
                  style: const TextStyle(
                      fontSize: 18,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ]);
    return Container(
        decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
        child: SafeArea(
            bottom: false,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const BrandLockup(onDark: true),
                      const SizedBox(height: 32),
                      Row(children: [
                        place('চীন', 'চেংদু'),
                        Expanded(
                            child: SizedBox(
                                height: 36,
                                child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Positioned.fill(
                                          child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12),
                                              child: CustomPaint(
                                                  painter: _Dashes()))),
                                      Container(
                                          width: 36,
                                          height: 36,
                                          decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle),
                                          child: const Icon(
                                              Icons.flight_rounded,
                                              size: 19,
                                              color: AppColors.primary)),
                                    ]))),
                        place('বাংলাদেশ', 'ঢাকা', end: true),
                      ]),
                      const SizedBox(height: 28),
                      const Text('এয়ার কার্গোর সব কাজ,\nএক অ্যাপে।',
                          style: TextStyle(
                              fontSize: 25,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ]))));
  }
}

class _Dashes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x80FFFFFF)
      ..strokeWidth = 2;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += 9) {
      canvas.drawLine(
          Offset(x, y), Offset((x + 5).clamp(0, size.width), y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
