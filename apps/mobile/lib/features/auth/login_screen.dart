import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../widgets/ui.dart';

/// Fingerprint sign-in offered on the sign-in screen.
class FingerprintLogin {
  const FingerprintLogin(
      {required this.firstName, required this.email, required this.signIn});

  /// "Sadia", for "Welcome back, Sadia".
  final String firstName;

  /// Filled into the email field for the password way in.
  final String email;

  /// Shows the prompt and signs in. False when the prompt was cancelled.
  final Future<bool> Function() signIn;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSubmit, this.fingerprint});

  /// [remember] keeps the phone signed in for 30 days.
  final Future<void> Function(String email, String password, bool remember)
      onSubmit;

  /// Shown above the password form when this phone has a fingerprint key.
  final FingerprintLogin? fingerprint;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  var _fingerprintBusy = false;
  var _obscure = true;
  var _remember = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email.text = widget.fingerprint?.email ?? '';
  }

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
      setState(() => _error = tr('Enter a valid email.'));
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = tr('Enter your password.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(email, password, _remember);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fingerprint() async {
    final fingerprint = widget.fingerprint;
    if (fingerprint == null) return;
    setState(() {
      _fingerprintBusy = true;
      _error = null;
    });
    try {
      await fingerprint.signIn();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _fingerprintBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fingerprint = widget.fingerprint;
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light
            .copyWith(statusBarColor: Colors.transparent),
        child: Scaffold(
          backgroundColor: AppColors.card,
          body: Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(padding: EdgeInsets.zero, children: [
              const _Hero(),
              Transform.translate(
                  offset: const Offset(0, -24),
                  child: DecoratedBox(
                      decoration: const BoxDecoration(
                          color: AppColors.card,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(24))),
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
                          child: AutofillGroup(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                if (fingerprint != null)
                                  ..._fingerprintPart(fingerprint)
                                else ...[
                                  Text(tr('Sign in'),
                                      style: const TextStyle(
                                          fontSize: 24,
                                          height: 1.3,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(tr('Enter your staff email and password. Your account decides whether you get hub or admin.'),
                                      style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 14,
                                          height: 1.55)),
                                  const SizedBox(height: 20),
                                ],
                                ..._passwordPart(quiet: fingerprint != null),
                              ]))))),
            ]),
          )),
        ));
  }

  List<Widget> _fingerprintPart(FingerprintLogin fingerprint) => [
        Text(tr('Welcome back, {name}', {'name': fingerprint.firstName}),
            style: const TextStyle(
                fontSize: 22, height: 1.3, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(tr('Use your fingerprint, or your email and password.'),
            style: const TextStyle(
                color: AppColors.muted, fontSize: 13, height: 1.4)),
        const SizedBox(height: 16),
        FilledButton(
            key: const Key('login-fingerprint'),
            onPressed: _fingerprintBusy || _busy ? null : _fingerprint,
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary,
                disabledForegroundColor: Colors.white,
                minimumSize: const Size(48, 56),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(
                    fontFamily: 'HindSiliguri',
                    fontSize: 16,
                    height: 1.4,
                    fontWeight: FontWeight.w600)),
            child: _fingerprintBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        const Icon(Icons.fingerprint_rounded, size: 24),
                        const SizedBox(width: 10),
                        Flexible(
                            child: Text(tr('Sign in with fingerprint'),
                                textAlign: TextAlign.center)),
                      ])),
        const SizedBox(height: 16),
        Row(children: [
          const Expanded(child: Divider(height: 1, color: AppColors.line)),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(tr('or with password'),
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.faint))),
          const Expanded(child: Divider(height: 1, color: AppColors.line)),
        ]),
        const SizedBox(height: 14),
      ];

  List<Widget> _passwordPart({required bool quiet}) => [
        _FieldLabel(tr('Email')),
        TextField(
            key: const Key('login-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(hintText: tr('Your email'))),
        const SizedBox(height: 14),
        _FieldLabel(tr('Password')),
        TextField(
            key: const Key('login-password'),
            controller: _password,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _submit(),
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
                hintText: tr('Your password'),
                suffixIcon: IconButton(
                    tooltip:
                        _obscure ? tr('Show password') : tr('Hide password'),
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20)))),
        const SizedBox(height: 6),
        _RememberRow(
            value: _remember,
            onChanged: (value) => setState(() => _remember = value)),
        if (_error != null) ...[
          const SizedBox(height: 8),
          ErrorNote(message: _error!)
        ],
        const SizedBox(height: 8),
        AppButton(
            key: const Key('login-submit'),
            label: tr('Sign in'),
            icon: quiet ? null : Icons.arrow_forward_rounded,
            kind: quiet ? AppButtonKind.quiet : AppButtonKind.teal,
            busy: _busy,
            onPressed: _fingerprintBusy ? null : _submit),
        const SizedBox(height: 18),
        Text(tr('Forgot your password? Tell an admin.'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ];
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)));
}

/// "Remember me" with its 30-day line; the whole row toggles it.
class _RememberRow extends StatelessWidget {
  const _RememberRow({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
      checked: value,
      label: tr('Remember me'),
      excludeSemantics: true,
      child: InkWell(
          key: const Key('login-remember'),
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(controlRadius),
          child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: minTouchTarget),
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                            color: value ? AppColors.primary : AppColors.card,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                                color:
                                    value ? AppColors.primary : AppColors.field,
                                width: 1.5)),
                        child: value
                            ? const Icon(Icons.check_rounded,
                                size: 17, color: Colors.white)
                            : null),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(tr('Remember me'),
                              style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600)),
                          Text(tr('Stay signed in on this phone for 30 days'),
                              style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: AppColors.muted)),
                        ])),
                  ])))));
}

/// Blue panel: the brand, the promise and the route.
class _Hero extends StatelessWidget {
  const _Hero();

  static const _routeColor = Color(0xD9FFFFFF);
  static const _routeStyle =
      TextStyle(fontSize: 13, height: 1.4, color: _routeColor);

  @override
  Widget build(BuildContext context) => Container(
      decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment(-0.5, -1),
              end: Alignment(0.5, 1),
              colors: [AppColors.primary, AppColors.primaryInk])),
      child: SafeArea(
          bottom: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandLockup(onDark: true),
                    const SizedBox(height: 22),
                    Text(tr('All your air cargo work,\nin one app.'),
                        style: const TextStyle(
                            fontSize: 24,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 8),
                    Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          const Icon(Icons.flight_takeoff_rounded,
                              size: 16, color: _routeColor),
                          Text(tr('China'), style: _routeStyle),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 14, color: _routeColor),
                          Text(tr('Bangladesh'), style: _routeStyle),
                        ]),
                  ]))));
}
