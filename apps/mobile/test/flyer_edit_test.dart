import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sbexpress/data/models/flyer.dart';
import 'package:sbexpress/features/flyers/flyer_detail_screen.dart';
import 'package:sbexpress/features/flyers/flyer_form_screen.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'restructured_flow_test.dart' show app, phone;
import 'support/team_fixtures.dart';

http.Response _ok(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});

/// The text field that shows [text].
Finder _field(String text) =>
    find.byWidgetPredicate((w) => w is TextField && w.controller?.text == text);

void main() {
  test('an edit sends every field, with cleared ones emptied', () {
    const draft = FlyerDraft(
        firstName: ' Arif ',
        lastName: 'Hossain',
        bdPhone: '',
        cnPhone: '+86 13800000000',
        batch: ' ');
    expect(draft.toPatchJson(), {
      'firstName': 'Arif',
      'lastName': 'Hossain',
      'cnPhone': '+86 13800000000',
      'bdPhone': '—',
      'university': '—',
      'batch': '',
      'program': '—',
      'wechat': '—',
      'emergencyContact': '—',
    });
  });

  testWidgets(
      'a flyer is edited from their page and reopens under the new name',
      (t) async {
    phone(t);
    final patches = <({String path, Map<String, dynamic> body})>[];
    await t.pumpWidget(
        app(const FlyerDetailScreen(name: 'Arif Rahman'), intercept: (r) async {
      if (r.method == 'PATCH') {
        patches.add((
          path: Uri.decodeComponent(r.url.path),
          body: jsonDecode(r.body) as Map<String, dynamic>
        ));
        return _ok({'name': 'Arif Hossain'});
      }
      return teamFixtures(r);
    }));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('flyer-edit')));
    await t.pumpAndSettle();
    expect(find.text(tr('Edit flyer')), findsOneWidget);
    // Documents and the passport scan stay on the flyer's page.
    expect(find.byKey(const Key('flyer-scan')), findsNothing);
    expect(find.byKey(const ValueKey('flyer-doc-visa')), findsNothing);
    expect(_field('Arif'), findsOneWidget);
    expect(_field('Sichuan University'), findsOneWidget);

    await t.enterText(_field('Rahman'), 'Hossain');
    await t.tap(find.byKey(const Key('flyer-save')));
    await t.pumpAndSettle();

    expect(patches.single.path, '/api/flyers/Arif Rahman');
    expect(patches.single.body['firstName'], 'Arif');
    expect(patches.single.body['lastName'], 'Hossain');
    expect(patches.single.body['university'], 'Sichuan University');
    expect(find.byType(FlyerFormScreen), findsNothing);
    expect(
        find.byWidgetPredicate(
            (w) => w is FlyerDetailScreen && w.name == 'Arif Hossain'),
        findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the first name is required on an edit', (t) async {
    phone(t);
    var patched = false;
    await t.pumpWidget(
        app(const FlyerDetailScreen(name: 'Arif Rahman'), intercept: (r) async {
      if (r.method == 'PATCH') patched = true;
      return teamFixtures(r);
    }));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('flyer-edit')));
    await t.pumpAndSettle();
    await t.enterText(_field('Arif'), '');
    await t.tap(find.byKey(const Key('flyer-save')));
    await t.pumpAndSettle();
    expect(patched, isFalse);
    expect(find.text(tr('Enter the first name.')), findsOneWidget);
  });
}
