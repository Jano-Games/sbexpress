import 'package:flutter/material.dart';

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
      setState(() => _error = 'পাসওয়ার্ড দিন।');
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            const _Mark(),
            const SizedBox(height: 18),
            const Text('Sichuan Bangla Express', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.15, color: AppColors.teal)),
            const SizedBox(height: 8),
            const Text('Chengdu → Dhaka', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'স্টাফ লগইন ইমেইল ও পাসওয়ার্ডে। ভূমিকা অ্যাকাউন্ট থেকে আসে।',
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 28),
            TextField(
              key: const Key('login-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'ইমেইল'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('login-password'),
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _busy ? null : _submit(),
              decoration: InputDecoration(
                labelText: 'পাসওয়ার্ড',
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'পাসওয়ার্ড দেখুন' : 'পাসওয়ার্ড লুকান',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  constraints: const BoxConstraints(minWidth: minTouchTarget, minHeight: minTouchTarget),
                  icon: Text(_obscure ? 'দেখুন' : 'লুকান', style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger, height: 1.35)),
            ],
            const SizedBox(height: 20),
            AppButton(
              key: const Key('login-submit'),
              label: 'Login করুন',
              kind: AppButtonKind.current,
              busy: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(18)),
      child: const Text('SB', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
    );
  }
}
