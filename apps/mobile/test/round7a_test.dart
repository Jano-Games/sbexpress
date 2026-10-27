import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sbexpress/app.dart';
import 'package:sbexpress/app_scope.dart';
import 'package:sbexpress/data/models/session_user.dart';
import 'package:sbexpress/data/repositories/auth_repository.dart';
import 'package:sbexpress/data/session/biometrics.dart';
import 'package:sbexpress/data/session/session_controller.dart';
import 'package:sbexpress/data/session/session_store.dart';
import 'package:sbexpress/features/admin/admin_home_screen.dart';
import 'package:sbexpress/features/auth/login_screen.dart';
import 'package:sbexpress/features/customers/statement_screen.dart';
import 'package:sbexpress/features/finance/get_paid_screen.dart';
import 'package:sbexpress/features/more/more_screen.dart';
import 'package:sbexpress/features/shell/main_shell.dart';
import 'package:sbexpress/features/tasks/tasks_screen.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'package:sbexpress/theme/app_theme.dart';
import 'package:sbexpress/widgets/quick_parts.dart' show wholeBdt;

import 'support/screen_fixtures.dart';

typedef _Call = ({String call, Object? body});

/// Fingerprint check whose answers the test sets.
class _FakeBiometrics implements Biometrics {
  _FakeBiometrics({this.enrolled = true, this.pass = true});

  bool enrolled;
  bool pass;
  final reasons = <String>[];

  @override
  Future<bool> available() async => enrolled;

  @override
  Future<bool> prompt(String reason) async {
    reasons.add(reason);
    return pass;
  }
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

const _sadia = {
  'id': 'u7',
  'name': 'Sadia Karim',
  'email': 'sadia@sbexpress.com',
  'role': 'admin',
  'roleLabel': 'Admin',
};

const _owner = '{"id":"u7","name":"Sadia Karim","email":"sadia@sbexpress.com"}';

/// A session on the screen fixtures. Calls to `/api/auth/*` and every
/// write are recorded and answered by [auth] (or `{ok: true}`).
({SessionController session, MemorySessionStore store, List<_Call> calls})
    _setup(
        {_FakeBiometrics? biometrics,
        bool signedIn = true,
        Future<http.Response?> Function(http.Request request)? auth}) {
  final store = MemorySessionStore();
  if (signedIn) store.token = 'tok';
  final calls = <_Call>[];
  final api = screenFixtureApi(intercept: (request) async {
    final path = request.url.path;
    if (path == '/api/me') return _json({'user': _sadia});
    if (request.method == 'GET' && !path.startsWith('/api/auth/')) {
      return null;
    }
    calls.add((
      call: '${request.method} $path',
      body: request.body.isEmpty ? null : jsonDecode(request.body)
    ));
    final answer = await auth?.call(request);
    if (answer != null) return answer;
    if (path == '/api/settings') {
      return _json({
        'settings': {
          'rate': 18.2,
          'threshold': 0.8,
          'pcsRates': <String, Object?>{}
        }
      });
    }
    return _json({'ok': true});
  });
  final session = SessionController(
      store: store,
      auth: AuthRepository(api, store: store),
      biometrics: biometrics ?? _FakeBiometrics());
  if (signedIn) {
    session
      ..user = SessionUser.fromJson(_sadia)
      ..ready = true;
  }
  return (session: session, store: store, calls: calls);
}

Widget _scoped(SessionController session, Widget home) => AppScope.wired(
    session: session,
    api: session.auth.api,
    child: MaterialApp(theme: buildAppTheme(), home: home));

Widget _more(SessionController session) =>
    _scoped(session, MoreScreen(user: session.user!, session: session));

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

/// Tall enough that the whole More list is built.
void _tall(WidgetTester t) {
  t.view.physicalSize = const Size(390, 1900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Future<void> _reveal(WidgetTester t, Finder finder) async {
  await t.scrollUntilVisible(finder, 200,
      scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
}

Future<void> _tap(WidgetTester t, Finder finder) async {
  await _reveal(t, finder);
  await t.tap(finder);
  await t.pumpAndSettle();
}

Finder get _fingerprintSwitch =>
    find.byKey(const Key('more-fingerprint-switch'));

bool _switchOn(WidgetTester t) => t.widget<Switch>(_fingerprintSwitch).value;

/// The overview with one late payment of each kind and one more not listed.
Map<String, Object?> _lateOverview() => {
      ...overviewBody(),
      'latePayments': [
        {
          'kind': 'after_delivery',
          'customerCode': 'C-21',
          'customerName': 'Bismillah Telecom',
          'shipmentCode': 'SH-14',
          'amount': 6300,
          'days': 12,
          'since': '2026-10-15',
        },
        {
          'kind': 'monthly',
          'customerCode': 'C-15',
          'customerName': 'Rahman Traders',
          'month': '2026-09',
          'monthLabel': 'September 2026',
          'amount': 15400,
          'days': 27,
        },
      ],
      'latePaymentsCount': 3,
    };

void main() {
  group('Remember me', () {
    test('the login sends remember', () async {
      final setup = _setup(
          signedIn: false,
          auth: (request) async {
            if (request.url.path != '/api/auth/login') return null;
            return _json({'token': 'new', 'user': _sadia});
          });
      await setup.session.login('sadia@sbexpress.com', 'secret', false);
      expect(setup.calls.single.call, 'POST /api/auth/login');
      expect(setup.calls.single.body, {
        'email': 'sadia@sbexpress.com',
        'password': 'secret',
        'remember': false
      });
      expect(setup.store.token, 'new');
      await setup.session.login('sadia@sbexpress.com', 'secret');
      expect((setup.calls.last.body as Map)['remember'], isTrue);
    });

    testWidgets('remember me is on by default and can be unticked', (t) async {
      _phone(t);
      final sent = <bool>[];
      await t.pumpWidget(MaterialApp(
          theme: buildAppTheme(),
          home: LoginScreen(onSubmit: (email, password, remember) async {
            sent.add(remember);
          })));
      expect(find.text(tr('Remember me')), findsOneWidget);
      expect(find.text(tr('Stay signed in on this phone for 30 days')),
          findsOneWidget);
      expect(find.byKey(const Key('login-fingerprint')), findsNothing);
      await t.enterText(
          find.byKey(const Key('login-email')), 'sadia@sbexpress.com');
      await t.enterText(find.byKey(const Key('login-password')), 'secret');
      await _tap(t, find.byKey(const Key('login-submit')));
      await _tap(t, find.byKey(const Key('login-remember')));
      await _tap(t, find.byKey(const Key('login-submit')));
      expect(sent, [true, false]);
    });
  });

  group('Fingerprint sign-in from More', () {
    testWidgets('turning it on asks, creates a key and stores it', (t) async {
      _tall(t);
      final biometrics = _FakeBiometrics();
      final setup = _setup(
          biometrics: biometrics,
          auth: (request) async => request.url.path == '/api/auth/device'
              ? _json({'deviceToken': 'dev-key-1'}, 201)
              : null);
      await t.pumpWidget(_more(setup.session));
      await t.pumpAndSettle();
      expect(find.text(tr('Fingerprint sign-in')), findsOneWidget);
      expect(_switchOn(t), isFalse);

      await _tap(t, _fingerprintSwitch);
      expect(biometrics.reasons,
          [tr('Touch the fingerprint sensor to turn on fingerprint sign-in.')]);
      expect(setup.calls.single.call, 'POST /api/auth/device');
      expect(setup.store.deviceKey, 'dev-key-1');
      final owner = jsonDecode(setup.store.deviceOwnerJson!) as Map;
      expect(owner,
          {'id': 'u7', 'name': 'Sadia Karim', 'email': 'sadia@sbexpress.com'});
      expect(setup.session.fingerprintOn, isTrue);
      expect(_switchOn(t), isTrue);
      expect(t.takeException(), isNull);
    });

    testWidgets('turning it off revokes the key and deletes it here',
        (t) async {
      _tall(t);
      final setup = _setup();
      setup.store
        ..deviceKey = 'dev-key-1'
        ..deviceOwnerJson = _owner;
      await setup.session.restore();
      expect(setup.session.fingerprintOn, isTrue);
      await t.pumpWidget(_more(setup.session));
      await t.pumpAndSettle();
      expect(_switchOn(t), isTrue);

      await _tap(t, _fingerprintSwitch);
      expect(setup.calls.map((call) => call.call),
          contains('POST /api/auth/device/revoke'));
      expect(setup.calls.last.body, {'deviceToken': 'dev-key-1'});
      expect(setup.store.deviceKey, isNull);
      expect(setup.store.deviceOwnerJson, isNull);
      expect(_switchOn(t), isFalse);
    });

    test('turning it off deletes the key even when the server fails', () async {
      final setup = _setup(
          auth: (request) async =>
              _json({'error': 'Server is restarting'}, 503));
      setup.store
        ..deviceKey = 'dev-key-1'
        ..deviceOwnerJson = _owner;
      await setup.session.restore();
      await setup.session.disableFingerprint();
      expect(setup.calls.last.call, 'POST /api/auth/device/revoke');
      expect(setup.store.deviceKey, isNull);
      expect(setup.session.fingerprint, isNull);
    });

    testWidgets('a phone without a fingerprint says so and calls nothing',
        (t) async {
      _tall(t);
      final biometrics = _FakeBiometrics(enrolled: false);
      final setup = _setup(biometrics: biometrics);
      await t.pumpWidget(_more(setup.session));
      await t.pumpAndSettle();
      await _tap(t, _fingerprintSwitch);
      expect(find.text(tr('This phone has no fingerprint set up.')),
          findsOneWidget);
      expect(biometrics.reasons, isEmpty);
      expect(setup.calls, isEmpty);
      expect(setup.store.deviceKey, isNull);
      expect(_switchOn(t), isFalse);
    });

    testWidgets('an older server asks for an update', (t) async {
      _tall(t);
      final setup =
          _setup(auth: (request) async => _json({'error': 'Not found'}, 404));
      await t.pumpWidget(_more(setup.session));
      await t.pumpAndSettle();
      await _tap(t, _fingerprintSwitch);
      expect(
          find.text(tr(
              'The server needs an update before fingerprint sign-in works.')),
          findsOneWidget);
      expect(setup.store.deviceKey, isNull);
      expect(_switchOn(t), isFalse);
    });

    test('logging out keeps the fingerprint key', () async {
      final setup = _setup();
      setup.store
        ..deviceKey = 'dev-key-1'
        ..deviceOwnerJson = _owner;
      await setup.session.restore();
      await setup.session.logout();
      expect(setup.session.user, isNull);
      expect(setup.store.token, isNull);
      expect(setup.store.deviceKey, 'dev-key-1');
      expect(setup.session.fingerprint?.firstName, 'Sadia');
    });
  });

  group('Fingerprint sign-in on the login screen', () {
    Future<
            ({
              SessionController session,
              MemorySessionStore store,
              List<_Call> calls
            })>
        pumpLogin(WidgetTester t,
            {_FakeBiometrics? biometrics,
            Future<http.Response?> Function(http.Request request)?
                auth}) async {
      _phone(t);
      final setup = _setup(biometrics: biometrics, signedIn: false, auth: auth);
      setup.store
        ..deviceKey = 'dev-key-1'
        ..deviceOwnerJson = _owner;
      await t.pumpWidget(
          SbExpressApp(session: setup.session, api: setup.session.auth.api));
      await t.pumpAndSettle();
      return setup;
    }

    testWidgets('greets the owner and signs in with the fingerprint',
        (t) async {
      final setup = await pumpLogin(t,
          auth: (request) async => request.url.path == '/api/auth/device-login'
              ? _json({'token': 'session-30d', 'user': _sadia})
              : null);
      expect(find.text(tr('Welcome back, {name}', {'name': 'Sadia'})),
          findsOneWidget);
      expect(find.byKey(const Key('login-password')), findsOneWidget);
      final email =
          t.widget<TextField>(find.byKey(const Key('login-email'))).controller;
      expect(email!.text, 'sadia@sbexpress.com');
      // The key is read only after the prompt.
      expect(setup.calls, isEmpty);

      await t.tap(find.byKey(const Key('login-fingerprint')));
      await t.pumpAndSettle();
      expect(setup.calls.single.call, 'POST /api/auth/device-login');
      expect(setup.calls.single.body, {'deviceToken': 'dev-key-1'});
      expect(setup.store.token, 'session-30d');
      expect(setup.session.user?.name, 'Sadia Karim');
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(MainShell), findsOneWidget);
    });

    testWidgets('a cancelled prompt sends nothing', (t) async {
      final setup =
          await pumpLogin(t, biometrics: _FakeBiometrics(pass: false));
      await t.tap(find.byKey(const Key('login-fingerprint')));
      await t.pumpAndSettle();
      expect(setup.calls, isEmpty);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(setup.store.deviceKey, 'dev-key-1');
    });

    testWidgets('a turned-off key is deleted and the password form stays',
        (t) async {
      final setup = await pumpLogin(t,
          auth: (request) async => _json({
                'error':
                    'Fingerprint sign-in was turned off. Sign in with your password.'
              }, 401));
      await t.tap(find.byKey(const Key('login-fingerprint')));
      await t.pumpAndSettle();
      expect(setup.calls.single.call, 'POST /api/auth/device-login');
      expect(setup.store.deviceKey, isNull);
      expect(setup.store.deviceOwnerJson, isNull);
      expect(
          find.text(tr(
              'Fingerprint sign-in was turned off. Sign in with your password.')),
          findsOneWidget);
      expect(find.byKey(const Key('login-fingerprint')), findsNothing);
      expect(find.byKey(const Key('login-password')), findsOneWidget);
      expect(find.text(tr('Sign in')), findsWidgets);
    });

    testWidgets('an older server asks for an update and keeps the key',
        (t) async {
      final setup = await pumpLogin(t,
          auth: (request) async => _json({'error': 'Not found'}, 404));
      await t.tap(find.byKey(const Key('login-fingerprint')));
      await t.pumpAndSettle();
      expect(
          find.text(tr(
              'The server needs an update before fingerprint sign-in works.')),
          findsOneWidget);
      expect(setup.store.deviceKey, 'dev-key-1');
      expect(find.byKey(const Key('login-fingerprint')), findsOneWidget);
    });
  });

  group('More', () {
    testWidgets('one list with the new groups and no duplicates', (t) async {
      _tall(t);
      final setup = _setup();
      await t.pumpWidget(_more(setup.session));
      await t.pumpAndSettle();
      for (final group in ['People', 'Money', 'Shipment tools', 'Work']) {
        expect(find.text(tr(group).toUpperCase()), findsOneWidget,
            reason: group);
      }
      for (final title in [
        'Customers',
        'Flyers',
        'Team',
        'Payment review',
        'Payment methods',
        'Exchange rate',
        'Bills and customer links',
        'Photos and media',
        'Weight alert',
        'Tasks and notes',
        'Security',
        'Fingerprint sign-in',
        'System check',
        'Log out',
      ]) {
        final finder = find
            .text(title == 'Security' ? tr(title).toUpperCase() : tr(title));
        await t.scrollUntilVisible(finder, 200,
            scrollable: find.byType(Scrollable).first);
        expect(finder, findsOneWidget, reason: title);
      }
      for (final gone in [
        'Flights',
        'Finance overview',
        'Shipment intake',
        'Settings',
        'Staff',
        'Add admin or hub manager',
        'Assign tasks',
        'Usual shipment costs',
      ]) {
        expect(find.text(tr(gone)), findsNothing, reason: gone);
      }
      // Live figures: receipts waiting and the rate.
      await t.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await t.pumpAndSettle();
      expect(find.text(tr('{n} waiting', {'n': 2})), findsOneWidget);
      expect(
          find.text('${tr('{rate} per ¥1', {'rate': '৳17.50'})} · '
              '${tr('Confirmed')}'),
          findsOneWidget);
      expect(find.text('0.5 kg'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('the exchange rate sheet saves through settings', (t) async {
      _phone(t);
      final setup = _setup();
      await t.pumpWidget(_more(setup.session));
      await t.pumpAndSettle();
      await _tap(t, find.text(tr('Change')));
      expect(find.byKey(const Key('rate-field')), findsOneWidget);
      await t.enterText(find.byKey(const Key('rate-field')), '0');
      await t.tap(find.byKey(const Key('rate-save')));
      await t.pumpAndSettle();
      expect(
          find.text(
              tr('Enter the real CNY rate. Blank or 0 will not be saved.')),
          findsOneWidget);
      expect(setup.calls, isEmpty);

      await t.enterText(find.byKey(const Key('rate-field')), '18.2');
      await t.tap(find.byKey(const Key('rate-save')));
      await t.pumpAndSettle();
      expect(setup.calls.single.call, 'PATCH /api/settings');
      expect(setup.calls.single.body, {'rate': 18.2});
      expect(find.byKey(const Key('rate-field')), findsNothing);
    });

    testWidgets('the weight alert sheet saves through settings', (t) async {
      _phone(t);
      final setup = _setup();
      await t.pumpWidget(_more(setup.session));
      await t.pumpAndSettle();
      await _tap(t, find.text('0.5 kg'));
      await t.enterText(find.byKey(const Key('weight-field')), '0.8');
      await t.tap(find.byKey(const Key('weight-save')));
      await t.pumpAndSettle();
      expect(setup.calls.single.call, 'PATCH /api/settings');
      expect(setup.calls.single.body, {'threshold': 0.8});
      expect(find.byKey(const Key('weight-field')), findsNothing);
    });

    testWidgets('hub More has its tools, security, language and log out',
        (t) async {
      _phone(t);
      final setup = _setup();
      const hub = SessionUser(
          id: 'h1',
          name: 'Mina',
          email: 'mina@sbx.test',
          role: UserRole.hub,
          roleLabel: 'Hub Manager · Dhaka');
      await t.pumpWidget(_scoped(
          setup.session, MoreScreen(user: hub, session: setup.session)));
      await t.pumpAndSettle();
      expect(find.text(tr('IMEI photos')), findsOneWidget);
      expect(find.text(tr('Photos / media')), findsOneWidget);
      expect(find.text(tr('Fingerprint sign-in')), findsOneWidget);
      expect(find.text('EN'), findsOneWidget);
      expect(find.text(tr('Log out')), findsOneWidget);
      for (final gone in [
        'Team',
        'Payment review',
        'Exchange rate',
        'System check',
        'Customers'
      ]) {
        expect(find.text(tr(gone)), findsNothing, reason: gone);
      }
      expect(find.textContaining('৳'), findsNothing);
    });

    testWidgets('assigning hub tasks is reached from inside Tasks', (t) async {
      _phone(t);
      final setup = _setup();
      await t.pumpWidget(_scoped(
          setup.session,
          Builder(
              builder: (context) => TasksScreen(
                  role: UserRole.admin, tasks: AppScope.of(context).tasks))));
      await t.pumpAndSettle();
      await _tap(t, find.byKey(const Key('tasks-assign')));
      expect(find.byType(AssignTaskScreen), findsOneWidget);
    });
  });

  group('Home → Needs attention', () {
    Future<void> pumpHome(WidgetTester t, Map<String, Object?> overview) async {
      _phone(t);
      final setup = _setup(auth: (request) async => null);
      final api = screenFixtureApi(
          intercept: (request) async =>
              request.url.path == '/api/dashboard/overview'
                  ? _json(overview)
                  : null);
      await t.pumpWidget(AppScope.wired(
          session: setup.session,
          api: api,
          child: MaterialApp(
              theme: buildAppTheme(),
              home: Builder(
                  builder: (context) => AdminHomeScreen(
                      dashboard: AppScope.of(context).dashboard)))));
      await t.pumpAndSettle();
    }

    testWidgets('late payments of both kinds lead the list', (t) async {
      await pumpHome(t, _lateOverview());
      final afterDelivery = find.text(tr('{name} is {days} days late',
          {'name': 'Bismillah Telecom', 'days': 12}));
      await _reveal(t, afterDelivery);
      expect(afterDelivery, findsOneWidget);
      expect(
          find.text(tr('{amount} · {shipment} delivered {date}', {
            'amount': wholeBdt(6300),
            'shipment': 'SH-14',
            'date': '15 Oct'
          })),
          findsOneWidget);
      expect(
          find.text(tr('{name}: {month} bill unpaid',
              {'name': 'Rahman Traders', 'month': tr('September')})),
          findsOneWidget);
      expect(
          find.text(tr('{amount} · {days} days after the month ended',
              {'amount': wholeBdt(15400), 'days': 27})),
          findsOneWidget);
      expect(find.text(tr('Late')), findsNWidgets(2));
      expect(
          find.text(trn(1, '{n} more late payment', '{n} more late payments')),
          findsOneWidget);
      // The late rows replace the overdue sum; missing costs are gone.
      expect(
          find.text(trn(1, '{n} bill is overdue after delivery',
              '{n} bills are overdue after delivery')),
          findsNothing);
      expect(
          find.text(trn(2, '{n} shipment is missing costs',
              '{n} shipments are missing costs')),
          findsNothing);

      await t.tap(afterDelivery);
      await t.pumpAndSettle();
      expect(find.byType(GetPaidScreen), findsOneWidget);
      Navigator.of(t.element(find.byType(GetPaidScreen))).pop();
      await t.pumpAndSettle();
      final monthly = find.text(tr('{name}: {month} bill unpaid',
          {'name': 'Rahman Traders', 'month': tr('September')}));
      await _reveal(t, monthly);
      await t.tap(monthly);
      await t.pumpAndSettle();
      final statement = t.widget<StatementScreen>(find.byType(StatementScreen));
      expect(statement.code, 'C-15');
      expect(statement.month, '2026-09');
      expect(t.takeException(), isNull);
    });

    testWidgets('an older server without late payments shows no late rows',
        (t) async {
      await pumpHome(t, overviewBody());
      expect(find.text(tr('Late')), findsNothing);
      expect(
          find.text(trn(2, '{n} shipment is missing costs',
              '{n} shipments are missing costs')),
          findsNothing);
      expect(
          find.text(trn(1, '{n} bill is overdue after delivery',
              '{n} bills are overdue after delivery')),
          findsOneWidget);
    });
  });
}
