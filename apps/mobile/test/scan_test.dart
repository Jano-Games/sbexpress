import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:sbexpress/data/scan/mrz.dart';
import 'package:sbexpress/data/scan/read_text.dart';
import 'package:sbexpress/data/uploads/photo_upload.dart';
import 'package:sbexpress/data/uploads/quick_uploads.dart';
import 'package:sbexpress/features/flyers/flyer_detail_screen.dart';
import 'package:sbexpress/features/flyers/flyer_form_screen.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'package:sbexpress/widgets/scan_parts.dart';
import 'restructured_flow_test.dart' show app, phone;
import 'support/team_fixtures.dart';

// ICAO 9303 specimens: a TD3 passport and the MRV-A and MRV-B visas.
const _passport1 = 'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
const _passport2 = 'L898902C36UTO7408122F1204159ZE184226B<<<<<10';
const _visaA1 = 'V<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<';
const _visaA2 = 'L8988901C4XXX4009078F96121096ZE184226B<<<<<<';
const _visaB1 = 'V<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<';
const _visaB2 = 'L8988901C4XXX4009078F9612109<<<<<<<<';

// Made-up Bangladeshi documents with correct check digits.
const _bgd1 = 'P<BGDSHAHRIAR<<MD<RIFAT<<<<<<<<<<<<<<<<<<<<<';
const _bgd2 = 'A012345678BGD0102030M3001019<<<<<<<<<<<<<<08';
const _chnVisa1 = 'V<CHNAKTER<<MST<SUMI<<<<<<<<<<<<<<<<<<<<<<<<';
const _chnVisa2 = 'E123456782BGD0311258F2706306<<<<<<<<<<<<<<<<';

/// What the reader returns for a whole passport page: the printed fields,
/// then the two lines at the bottom.
const _passportPage = 'PASSPORT\nPASSEPORT\nUtopia\nType P  Code UTO\n'
    'Surname ERIKSSON\nGiven names ANNA MARIA\n$_passport1\n$_passport2';

http.Response _ok(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

Uint8List _jpeg() =>
    Uint8List.fromList(img.encodeJpg(img.Image(width: 4, height: 3)));

/// A reader that finds [text] on any photo, like ML Kit would.
ScanTravelDocument _reads(String text) => (photo) async => readMrz(text);

/// Lets queued uploads run to the end; the signed PUT needs real turns of
/// the event loop.
Future<void> _settleUploads(WidgetTester t) async {
  for (var i = 0; i < 16; i++) {
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    await t.pump(const Duration(milliseconds: 50));
  }
  await t.pumpAndSettle();
}

String _field(WidgetTester t, int index) =>
    t.widget<TextField>(find.byType(TextField).at(index)).controller!.text;

Finder _slotText(String kind, String text) => find.descendant(
    of: find.byKey(ValueKey('flyer-doc-$kind')), matching: find.text(text));

Future<void> _reveal(WidgetTester t, Finder finder) async {
  await t.scrollUntilVisible(finder, 200,
      scrollable: find.byType(Scrollable).first);
  await t.pumpAndSettle();
}

Future<void> _scan(WidgetTester t, {String key = 'scan-camera'}) async {
  await t.tap(find.byKey(Key(key)));
  await t.pumpAndSettle();
}

void main() {
  group('MRZ parser', () {
    test('reads the ICAO passport specimen', () {
      final reading = readMrz('$_passport1\n$_passport2')!;
      expect(reading.kind, TravelDocument.passport);
      expect(reading.surname, 'Eriksson');
      expect(reading.givenNames, 'Anna Maria');
      expect(reading.issuingCountry, 'UTO');
      expect(reading.firstName, 'Anna Maria');
      expect(reading.lastName, 'Eriksson');
    });

    test('reads the MRV-A and MRV-B visa specimens', () {
      for (final lines in [
        '$_visaA1\n$_visaA2',
        '$_visaB1\n$_visaB2',
      ]) {
        final reading = readMrz(lines)!;
        expect(reading.kind, TravelDocument.visa);
        expect(reading.surname, 'Eriksson');
        expect(reading.givenNames, 'Anna Maria');
        expect(reading.issuingCountry, 'UTO');
      }
    });

    test('finds the lines among the rest of the page', () {
      final reading = readMrz(_passportPage)!;
      expect(reading.kind, TravelDocument.passport);
      expect(reading.firstName, 'Anna Maria');
    });

    test('check digits follow ICAO 9303 (7-3-1)', () {
      expect(mrzCheckDigit('L898902C3'), 6);
      expect(mrzCheckDigit('740812'), 2);
      expect(mrzCheckDigit('120415'), 9);
      expect(mrzCheckDigit('L8988901C'), 4);
      expect(mrzCheckDigit('<<<<<<<<<<<<<<'), 0);
      expect(mrzCheckDigit('AB-1'), isNull);
    });

    test('cleans up OCR noise: case, spaces, « ‹ ( and an O for a zero', () {
      final noisy = [
        'p< uto eriksson«anna‹maria «««««««««<',
        'L898902C3 6UTO 74O812 2F1204159ZE184226B««(10',
      ].join('\n');
      final reading = readMrz(noisy)!;
      expect(reading.surname, 'Eriksson');
      expect(reading.givenNames, 'Anna Maria');
      expect(reading.issuingCountry, 'UTO');
      // A « right after the P stands for one filler.
      expect(readMrz('P«UTOERIKSSON«ANNA<MARIA«««««««««\n$_passport2')!.surname,
          'Eriksson');
    });

    test('accepts lines up to two characters long or short', () {
      final short = _passport1.substring(0, 42);
      final long = '$_passport2<<';
      expect(readMrz('$short\n$long')!.givenNames, 'Anna Maria');
      final tooShort = _passport1.substring(0, 41);
      final cut = _passport2.substring(0, 41);
      expect(readMrz('$tooShort\n$cut'), isNull);
    });

    test('joins a line the reader broke in two', () {
      final reading = readMrz('${_passport1.substring(0, 20)}\n'
          '${_passport1.substring(20)}\n$_passport2')!;
      expect(reading.givenNames, 'Anna Maria');
    });

    test('rejects a reading whose check digits fail', () {
      // Document number check 6 → 7.
      final badNumber = _passport2.replaceRange(9, 10, '7');
      expect(readMrz('$_passport1\n$badNumber'), isNull);
      // Birth date check 2 → 3.
      final badBirth = _passport2.replaceRange(19, 20, '3');
      expect(readMrz('$_passport1\n$badBirth'), isNull);
      // A misread digit in the birth date.
      final misread = _passport2.replaceRange(14, 15, '9');
      expect(readMrz('$_passport1\n$misread'), isNull);
    });

    test('gives nothing for a page without the lines', () {
      expect(readMrz(''), isNull);
      expect(readMrz('Student ID\nShanghai University\n2024'), isNull);
      expect(readMrz(_passport1), isNull);
    });

    test('keeps MD and MST as name words', () {
      final passport = readMrz('$_bgd1\n$_bgd2')!;
      expect(passport.kind, TravelDocument.passport);
      expect(passport.issuingCountry, 'BGD');
      expect(passport.firstName, 'Md Rifat');
      expect(passport.lastName, 'Shahriar');
      final visa = readMrz('$_chnVisa1\n$_chnVisa2')!;
      expect(visa.kind, TravelDocument.visa);
      expect(visa.issuingCountry, 'CHN');
      expect(visa.firstName, 'Mst Sumi');
      expect(visa.lastName, 'Akter');
    });

    test('a document with one name fills the first name only', () {
      const one = 'P<BGD<<MD<RIFAT<SHAHRIAR<<<<<<<<<<<<<<<<<<<<';
      final reading = readMrz('$one\n$_bgd2')!;
      expect(reading.surname, '');
      expect(reading.firstName, 'Md Rifat Shahriar');
      expect(reading.lastName, '');
    });

    test('a filler read as K does not become a name', () {
      const noisy = 'P<UTOERIKSSON<<ANNA<MARIA<<K<<<<<<<<<<<<<<<<';
      expect(readMrz('$noisy\n$_passport2')!.givenNames, 'Anna Maria');
      const kkk = 'P<UTOERIKSSON<<ANNA<MARIAKKKKKKKKKKKKKKKKKKK';
      expect(readMrz('$kkk\n$_passport2')!.givenNames, 'Anna Maria');
    });
  });

  group('reading a photo', () {
    test('the photo is written for the reader and deleted right after',
        () async {
      String? seen;
      Uint8List? bytes;
      final photo =
          PickedPhoto(bytes: _jpeg(), name: 'IMG_1.JPG', mime: 'image/jpeg');
      final reading = await scanTravelDocument(photo, readText: (path) async {
        seen = path;
        bytes = File(path).readAsBytesSync();
        return _passportPage;
      });
      expect(reading!.lastName, 'Eriksson');
      expect(seen, endsWith('.jpg'));
      expect(bytes, photo.bytes);
      expect(File(seen!).existsSync(), isFalse);
      expect(File(seen!).parent.existsSync(), isFalse);
    });

    test('the photo is deleted when the reader fails', () async {
      String? seen;
      final photo = PickedPhoto(bytes: _jpeg(), name: 'scan', mime: null);
      await expectLater(
          scanTravelDocument(photo, readText: (path) async {
            seen = path;
            throw StateError('no reader');
          }),
          throwsStateError);
      expect(File(seen!).existsSync(), isFalse);
    });
  });

  group('flyer form scan', () {
    Future<PickedPhoto?> pickPassport(FileSource source) async =>
        PickedPhoto(bytes: _jpeg(), name: 'passport.jpg', mime: 'image/jpeg');

    testWidgets(
        'a passport fills the names, queues the photo as Passport and sends '
        'only the name and the photo', (t) async {
      phone(t);
      final sent = <String>[];
      final reserved = <Map<String, Object?>>[];
      Map<String, Object?>? created;
      await t.pumpWidget(app(
          FlyerFormScreen(
              pickFile: pickPassport,
              scanDocument: _reads(_passportPage)), intercept: (r) async {
        sent.add('${r.method} ${r.url} ${r.method == 'PUT' ? '' : r.body}');
        if (r.method == 'POST' && r.url.path == '/api/flyers') {
          created = jsonDecode(r.body) as Map<String, Object?>;
          return _ok({'name': 'Anna Maria Eriksson'}, 201);
        }
        if (r.method == 'POST' && r.url.path.endsWith('/documents/upload')) {
          reserved.add(jsonDecode(r.body) as Map<String, Object?>);
          return _ok({
            'reference': 'ref-1',
            'uploadUrl': 'https://storage.test/put/1',
            'expiresAt': '2026-10-27T12:00:00.000Z',
          }, 201);
        }
        if (r.method == 'PUT' && r.url.host == 'storage.test') {
          return http.Response('', 200);
        }
        if (r.method == 'POST' && r.url.path.endsWith('/complete')) {
          return _ok({'ok': true});
        }
        return teamFixtures(r);
      }));
      await t.pumpAndSettle();
      expect(find.text(tr('Scan passport or visa')), findsOneWidget);
      await _scan(t);
      expect(_field(t, 0), 'Anna Maria');
      expect(_field(t, 1), 'Eriksson');
      expect(find.text(tr('Filled from the passport · check the spelling')),
          findsOneWidget);
      await _reveal(t, find.byKey(const ValueKey('flyer-doc-passport')));
      expect(
          _slotText('passport',
              tr('{file} · ready to upload', {'file': 'passport.jpg'})),
          findsOneWidget);
      expect(find.text(tr('{n} of {total} added', {'n': 1, 'total': 4})),
          findsOneWidget);
      await t.tap(find.byKey(const Key('flyer-save')));
      await _settleUploads(t);
      expect(created, {'firstName': 'Anna Maria', 'lastName': 'Eriksson'});
      expect(reserved.single['kind'], 'passport');
      expect(reserved.single['contentType'], 'image/jpeg');
      // The number, dates, sex and nationality never leave the phone.
      for (final secret in [
        'L898902C3',
        '740812',
        '120415',
        'UTO',
        'ZE184226B',
        _passport2,
      ]) {
        expect(sent.where((line) => line.contains(secret)), isEmpty,
            reason: secret);
      }
      expect(find.byType(FlyerDetailScreen), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('a visa queues the photo as Visa', (t) async {
      phone(t);
      await t.pumpWidget(app(FlyerFormScreen(
          pickFile: pickPassport,
          scanDocument: _reads('$_chnVisa1\n$_chnVisa2'))));
      await t.pumpAndSettle();
      await _scan(t, key: 'scan-gallery');
      expect(_field(t, 0), 'Mst Sumi');
      expect(_field(t, 1), 'Akter');
      expect(find.text(tr('Filled from the visa · check the spelling')),
          findsOneWidget);
      await _reveal(t, find.byKey(const ValueKey('flyer-doc-visa')));
      expect(
          _slotText(
              'visa', tr('{file} · ready to upload', {'file': 'passport.jpg'})),
          findsOneWidget);
      expect(_slotText('passport', tr('Photo or PDF')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('an unreadable photo says so and can still be attached',
        (t) async {
      phone(t);
      await t.pumpWidget(app(FlyerFormScreen(
          pickFile: pickPassport, scanDocument: _reads('Blurry\nP<UTO ERIK'))));
      await t.pumpAndSettle();
      await _scan(t);
      expect(
          find.text(tr(
              "Couldn't read the lines at the bottom of the page. Try a sharper photo, or type the name.")),
          findsOneWidget);
      expect(find.text(tr('Attach as passport')), findsOneWidget);
      expect(find.text(tr('Attach as visa')), findsOneWidget);
      expect(_field(t, 0), '');
      await t.tap(find.byKey(const Key('scan-attach-passport')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('scan-unreadable')), findsNothing);
      expect(find.text(tr('Passport added to Documents')), findsOneWidget);
      expect(_field(t, 0), '');
      await _reveal(t, find.byKey(const ValueKey('flyer-doc-passport')));
      expect(
          _slotText('passport',
              tr('{file} · ready to upload', {'file': 'passport.jpg'})),
          findsOneWidget);
      // The user can remove it again.
      await t.tap(find.byTooltip(
          tr('Remove {document} file', {'document': tr('Passport')})));
      await t.pumpAndSettle();
      expect(_slotText('passport', tr('Photo or PDF')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('a reader that fails reads as unreadable', (t) async {
      phone(t);
      await t.pumpWidget(app(FlyerFormScreen(
          pickFile: pickPassport,
          scanDocument: (photo) async => throw StateError('no model'))));
      await t.pumpAndSettle();
      await _scan(t);
      expect(find.byKey(const Key('scan-unreadable')), findsOneWidget);
      await t.tap(find.byKey(const Key('scan-attach-visa')));
      await t.pumpAndSettle();
      expect(find.text(tr('Visa added to Documents')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('shows Reading… while the photo is read', (t) async {
      phone(t);
      final done = Completer<MrzReading?>();
      await t.pumpWidget(app(FlyerFormScreen(
          pickFile: pickPassport, scanDocument: (photo) => done.future)));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('scan-camera')));
      await t.pump();
      expect(find.text(tr('Reading…')), findsOneWidget);
      expect(find.byKey(const Key('scan-camera')), findsNothing);
      done.complete(readMrz('$_bgd1\n$_bgd2'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('scan-reading')), findsNothing);
      expect(_field(t, 0), 'Md Rifat');
      expect(_field(t, 1), 'Shahriar');
    });

    testWidgets('typed names are replaced only after asking', (t) async {
      phone(t);
      await t.pumpWidget(app(FlyerFormScreen(
          pickFile: pickPassport, scanDocument: _reads('$_bgd1\n$_bgd2'))));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).at(0), 'Rifat');
      await _scan(t);
      expect(find.text(tr('Replace the typed name?')), findsOneWidget);
      expect(
          find.text(
              tr('The passport shows {name}.', {'name': 'Md Rifat Shahriar'})),
          findsOneWidget);
      await t.tap(find.byKey(const Key('scan-keep')));
      await t.pumpAndSettle();
      expect(_field(t, 0), 'Rifat');
      expect(_field(t, 1), '');
      // The photo still goes to Documents.
      expect(find.text(tr('Passport added to Documents')), findsOneWidget);
      await _scan(t);
      await t.tap(find.byKey(const Key('scan-replace')));
      await t.pumpAndSettle();
      expect(_field(t, 0), 'Md Rifat');
      expect(_field(t, 1), 'Shahriar');
      expect(find.text(tr('Filled from the passport · check the spelling')),
          findsOneWidget);
      // The same name typed in another case is not a clash.
      await t.enterText(find.byType(TextField).at(0), 'MD RIFAT');
      await _scan(t);
      expect(find.text(tr('Replace the typed name?')), findsNothing);
      expect(_field(t, 0), 'Md Rifat');
      expect(t.takeException(), isNull);
    });

    test('the note names the document', () {
      expect(scanNote(TravelDocument.visa, filled: false),
          tr('Visa added to Documents'));
    });
  });
}
