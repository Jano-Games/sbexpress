import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'data/api/api_client.dart';
import 'data/session/session_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/main_shell.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class SbExpressApp extends StatefulWidget {
  const SbExpressApp({super.key, required this.session, required this.api});

  final SessionController session;
  final ApiClient api;

  @override
  State<SbExpressApp> createState() => _SbExpressAppState();
}

class _SbExpressAppState extends State<SbExpressApp> {
  var _navigatorGeneration = 0;
  var _hadUser = false;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
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
      child: MaterialApp(
        key: ValueKey(_navigatorGeneration),
        title: 'SBExpress',
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        home: AuthGate(session: widget.session),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.session});

  final SessionController session;

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
        if (!widget.session.ready) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.teal)));
        }
        final banner = widget.session.banner;
        if (widget.session.user == null) {
          return LoginScreen(onSubmit: widget.session.login);
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
                    child: Text(banner, style: const TextStyle(color: AppColors.amberInk)),
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
