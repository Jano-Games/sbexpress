import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'data/api/api_client.dart';
import 'data/session/session_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/main_shell.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class SbExpressApp extends StatelessWidget {
  const SbExpressApp({super.key, required this.session, required this.api});

  final SessionController session;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    return AppScope.wired(
      session: session,
      api: api,
      child: MaterialApp(
        title: 'SBExpress',
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        home: AuthGate(session: session),
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
