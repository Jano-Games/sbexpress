import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sbexpress/app_scope.dart';
import 'package:sbexpress/data/models/session_user.dart';
import 'package:sbexpress/data/models/ticket_import.dart';
import 'package:sbexpress/data/repositories/auth_repository.dart';
import 'package:sbexpress/data/session/session_controller.dart';
import 'package:sbexpress/data/session/session_store.dart';
import 'package:sbexpress/features/flights/ticket_import_screen.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'package:sbexpress/theme/app_theme.dart';
import 'support/screen_fixtures.dart';

Map<String, Object?> _leg(String code, String date, String from, String to,
        String dep, String arr) =>
    {
      'source': 'ticket',
      'code': code,
      'airline': 'China Eastern Airlines',
      'date': date,
      'arrDate': date,
      'fromIata': from,
      'fromCity': from,
      'toIata': to,
      'toCity': to,
      'depTime': dep,
      'arrTime': arr,
      'status': 'Confirmed',
    };

// Synthetic passenger and numbers.
final _ticket = {
  'ticket': {
    'agency': 'DESH TRAVELER',
    'passenger': 'KHAN / MD ARIF HOSSAIN SD',
    'pnr': 'TEST01',
    'ticketNumber': '781-0000000001',
    'issuedOn': '2026-10-24',
  },
  'flyerMatches': [
    {'name': 'KHAN Arif Hossain', 'score': 1},
  ],
  'journeys': [
    {
      'direction': 'to_bangladesh',
      'date': '2026-11-13',
      'legs': [
        _leg('MU5842', '2026-11-13', 'TFU', 'KMG', '21:00', '22:30'),
        _leg('MU2035', '2026-11-14', 'KMG', 'DAC', '12:10', '13:00'),
      ],
    },
    {
      'direction': 'from_bangladesh',
      'date': '2026-11-23',
      'legs': [
        _leg('MU2036', '2026-11-23', 'DAC', 'KMG', '14:00', '18:20'),
        _leg('MU5843', '2026-11-24', 'KMG', 'CTU', '08:40', '10:05'),
      ],
    },
  ],
};

Map<String, Object?> _flyer(String name) => {
      'name': name,
      'firstName': name,
      'lastName': '',
      'cnPhone': '—',
      'bdPhone': '—',
      'university': '—',
      'batch': '—',
      'program': '—',
      'wechat': '—',
      'docStudentId': false,
      'docVisa': false,
      'docAdmission': false,
      'documentCount': 0,
      'verifiedDocumentCount': 0,
      'archivedAt': null,
    };

void main() {
  setUp(() => appLanguage.value = AppLanguage.en);

  test('a reviewed journey posts as a ticket-sourced connection flight', () {
    final draft = TicketFlightDraft.fromImport(TicketImport.fromJson(_ticket))
        .first
      ..actualCost = 42000
      ..agencyShare = 8000;
    expect(draft.problem, isNull);
    expect(draft.route, 'TFU → KMG → DAC');
    final body = draft.toJson('KHAN Arif Hossain');
    expect(body['code'], 'MU5842+MU2035');
    expect(body['date'], '2026-11-13');
    expect(body['flyerNames'], ['KHAN Arif Hossain']);
    expect((body['legs'] as List).first, containsPair('source', 'ticket'));
    draft.legs.first.toIata = '';
    expect(draft.problem, 'Use three-letter airport codes.');
  });

  testWidgets('import reads the PDF, drops a journey and creates the rest',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final posted = <Map<String, Object?>>[];
    String? sentPdf;
    final api = screenFixtureApi(intercept: (request) async {
      final path = request.url.path;
      if (path == '/api/flyers') {
        return http.Response(
            jsonEncode({
              'flyers': [_flyer('KHAN Arif Hossain'), _flyer('RAHMAN Sumi')]
            }),
            200);
      }
      if (request.method == 'POST' && path == '/api/flights/ticket') {
        sentPdf = (jsonDecode(request.body) as Map)['file'] as String;
        return http.Response(jsonEncode(_ticket), 200);
      }
      if (request.method == 'POST' && path == '/api/flights') {
        posted.add(Map<String, Object?>.from(jsonDecode(request.body) as Map));
        return http.Response(jsonEncode({'code': 'MU5842+MU2035-x'}), 201);
      }
      return null;
    });
    final session = SessionController(
        store: MemorySessionStore()..token = 'tok', auth: AuthRepository(api))
      ..user = const SessionUser(
          id: 'u',
          name: 'Admin',
          email: 'admin@sbx.test',
          role: UserRole.admin,
          roleLabel: 'Administrator')
      ..ready = true;
    bool? popped;
    await tester.pumpWidget(AppScope.wired(
        session: session,
        api: api,
        child: MaterialApp(
            theme: buildAppTheme(),
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () async => popped =
                            await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                    builder: (_) => TicketImportScreen(
                                        pickPdf: () async =>
                                            utf8.encode('%PDF-1.4 test')))),
                        child: const Text('open')))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Import from ticket'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ticket-pick')));
    await tester.pumpAndSettle();
    expect(base64Decode(sentPdf!), utf8.encode('%PDF-1.4 test'));
    expect(find.text('KHAN / MD ARIF HOSSAIN SD'), findsOneWidget);
    expect(find.text('KHAN Arif Hossain · matches ticket'), findsOneWidget);
    expect(find.text('Create 2 flights'), findsOneWidget);
    await tester.dragUntilVisible(find.text('Flight 1 · To Bangladesh'),
        find.byType(ListView), const Offset(0, -150));
    await tester.dragUntilVisible(find.text('Flight 2 · From Bangladesh'),
        find.byType(ListView), const Offset(0, -150));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('ticket-remove-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ticket-remove-1')));
    await tester.pumpAndSettle();
    expect(find.text('Flight 2 · From Bangladesh'), findsNothing);
    expect(find.text('Create 1 flight'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ticket-save')));
    await tester.pumpAndSettle();
    expect(posted, hasLength(1));
    expect(posted.single['code'], 'MU5842+MU2035');
    expect(posted.single['flyerNames'], ['KHAN Arif Hossain']);
    expect(posted.single['actualCost'], 0);
    expect(popped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the review screen reads in Bangla when chosen', (tester) async {
    appLanguage.value = AppLanguage.bn;
    addTearDown(() => appLanguage.value = AppLanguage.en);
    final api = screenFixtureApi();
    final session = SessionController(
        store: MemorySessionStore()..token = 'tok', auth: AuthRepository(api))
      ..ready = true;
    await tester.pumpWidget(AppScope.wired(
        session: session,
        api: api,
        child: MaterialApp(
            theme: buildAppTheme(),
            home: TicketImportScreen(pickPdf: () async => null))));
    await tester.pumpAndSettle();
    expect(find.text('টিকিট থেকে ইমপোর্ট'), findsOneWidget);
    expect(find.text('Import from ticket'), findsNothing);
  });
}
