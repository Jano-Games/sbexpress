import 'dart:async';

import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'data/api/api_client.dart';
import 'data/session/session_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/shell/main_shell.dart';
import 'l10n/l10n.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class SbExpressApp extends StatefulWidget {
  const SbExpressApp(
      {super.key,
      required this.session,
      required this.api,
      this.language,
      this.splashMinimum = Duration.zero});

  final SessionController session;
  final ApiClient api;
  final LanguageStore? language;

  /// How long the splash stays up at launch even when sign-in is restored
  /// at once. Tests leave it at zero.
  final Duration splashMinimum;

  @override
  State<SbExpressApp> createState() => _SbExpressAppState();
}

class _SbExpressAppState extends State<SbExpressApp> {
  var _navigatorGeneration = 0;
  var _hadUser = false;
  var _holdSplash = false;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    if (widget.splashMinimum > Duration.zero) {
      _holdSplash = true;
      _splashTimer = Timer(widget.splashMinimum, () {
        if (mounted) setState(() => _holdSplash = false);
      });
    }
  }

  @override
  void didUpdateWidget(SbExpressApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      oldWidget.session.removeListener(_onSession);
      widget.session.addListener(_onSession);
    }
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    final hasUser = widget.session.user != null;
    if (_hadUser && !hasUser) {
      setState(() => _navigatorGeneration += 1);
    }
    _hadUser = hasUser;
  }

  @override
  Widget build(BuildContext context) {
    return AppScope.wired(
      session: widget.session,
      api: widget.api,
      language: widget.language,
      // A language change remounts the app so every screen re-reads its text.
      child: ValueListenableBuilder<AppLanguage>(
        valueListenable: appLanguage,
        builder: (context, language, _) => MaterialApp(
          key: ValueKey('$_navigatorGeneration-${language.name}'),
          title: 'SBExpress',
          theme: buildAppTheme(),
          debugShowCheckedModeBanner: false,
          home: AuthGate(session: widget.session, holdSplash: _holdSplash),
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.session, this.holdSplash = false});

  final SessionController session;

  /// Keeps the splash up while the launch minimum has not passed.
  final bool holdSplash;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.session.restore();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        if (!widget.session.ready || widget.holdSplash) {
          return const SplashScreen();
        }
        final banner = widget.session.banner;
        if (widget.session.user == null) {
          final owner = widget.session.fingerprint;
          return LoginScreen(
              onSubmit: widget.session.login,
              fingerprint: owner == null
                  ? null
                  : FingerprintLogin(
                      firstName: owner.firstName,
                      email: owner.email,
                      signIn: widget.session.loginWithFingerprint));
        }
        return Column(
          children: [
            if (banner != null)
              Material(
                color: AppColors.amber,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(banner,
                        style: const TextStyle(color: AppColors.amberInk)),
                  ),
                ),
              ),
            const Expanded(child: MainShell()),
          ],
        );
      },
    );
  }
}
