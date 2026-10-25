import 'package:flutter/widgets.dart';

import 'app.dart';
import 'config.dart';
import 'data/api/api_client.dart';
import 'data/repositories/auth_repository.dart';
import 'data/session/secure_session_store.dart';
import 'data/session/session_controller.dart';
import 'l10n/l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final language = LanguageStore();
  await language.load();
  final store = SecureSessionStore();
  late final SessionController session;
  final api = ApiClient(
    baseUrl: apiBaseUrl,
    session: store,
    onUnauthorized: () => session.handleUnauthorized(),
  );
  session = SessionController(store: store, auth: AuthRepository(api));
  runApp(SbExpressApp(session: session, api: api, language: language));
}
