import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:sbexpress/app_scope.dart';
import 'package:sbexpress/data/api/api_exception.dart';
import 'package:sbexpress/data/models/flyer.dart';
import 'package:sbexpress/data/models/session_user.dart';
import 'package:sbexpress/data/repositories/auth_repository.dart';
import 'package:sbexpress/data/session/session_controller.dart';
import 'package:sbexpress/data/session/session_store.dart';
import 'package:sbexpress/data/uploads/photo_upload.dart';
import 'package:sbexpress/data/uploads/quick_uploads.dart';
import 'package:sbexpress/data/uploads/signed_photos.dart';
import 'package:sbexpress/features/admin/admin_shipment_screen.dart';
import 'package:sbexpress/features/flyers/flyer_detail_screen.dart';
import 'package:sbexpress/features/imei/imei_guide_screen.dart';
import 'package:sbexpress/features/shipments/shipment_process_screen.dart';
import 'package:sbexpress/l10n/l10n.dart';
import 'package:sbexpress/theme/app_theme.dart';
import 'package:sbexpress/widgets/photo_parts.dart';

import 'support/screen_fixtures.dart';
import 'support/team_fixtures.dart';

final _jpeg = Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));

PickedPhoto _photo(String name) =>
    PickedPhoto(bytes: _jpeg, name: name, mime: 'image/jpeg');

Map<String, Object?> _media(String reference,
        {String name = 'photo.jpg', bool shared = false, String? category}) =>
    {
      'reference': reference,
      'name': name,
      'contentType': 'image/jpeg',
      'size': 1200,
      'shared': shared,
      'deviceCategory': category,
    };

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

/// A server that stores SH-18's photos and Arif Rahman's documents in
/// storage.test, signs links for them and records every call.
class _Server {
  _Server({List<Map<String, Object?>>? media}) : media = media ?? [];

  final List<Map<String, Object?>> media;
  final calls = <String>[];

  /// File names of the upload reservations, in order.
  final reserved = <String>[];

  /// File names whose upload storage refuses.
  final failing = <String>{};

  /// References whose download storage refuses.
  final broken = <String>{};
  var links = true;
  var configured = true;

  /// Holds the next upload to storage until completed.
  Completer<void>? hold;

  int count(String call) => calls.where((c) => c == call).length;
  List<String> get signed => [
        for (final call in calls)
          if (call.endsWith('/url')) call
      ];

  Future<http.Response?> call(http.Request r) async {
    final path = Uri.decodeComponent(r.url.path);
    if (r.url.host == 'storage.test') {
      calls.add('${r.method} storage$path');
      if (r.method == 'PUT') {
        final name = reserved[int.parse(path.split('/').last) - 1];
        final waiting = hold;
        hold = null;
        if (waiting != null) await waiting.future;
        return failing.contains(name)
            ? http.Response('storage refused', 500)
            : http.Response('', 200);
      }
      if (broken.contains(path.split('/').last)) {
        return http.Response('expired', 403);
      }
      return http.Response.bytes(_jpeg, 200,
          headers: {'content-type': 'image/jpeg'});
    }
    calls.add('${r.method} $path');
    const shipment = '/api/shipments/SH-18';
    const flyer = '/api/flyers/Arif Rahman';
    if (r.method == 'GET' && path == '$shipment/media') {
      return _json({'configured': configured, 'media': media});
    }
    if (r.method == 'POST' &&
        (path == '$shipment/media/upload' ||
            path == '$shipment/device-photo' ||
            path == '$flyer/documents/upload')) {
      final body = jsonDecode(r.body) as Map<String, Object?>;
      reserved.add(body['name']! as String);
      final n = reserved.length;
      return _json({
        'reference': 'ref-$n',
        'uploadUrl': 'https://storage.test/put/$n',
        'expiresAt': '2026-10-27T12:00:00.000Z'
      }, 201);
    }
    if (r.method == 'POST' && path.endsWith('/complete')) {
      final parts = path.split('/');
      final reference = parts[parts.length - 2];
      final n = int.parse(reference.substring(4));
      if (path.startsWith('$shipment/media/')) {
        media.add(_media(reference, name: reserved[n - 1]));
      }
      return _json({'ok': true, 'reference': reference});
    }
    if (r.method == 'GET' && path.endsWith('/url')) {
      if (!links) return http.Response('404 Not Found', 404);
      final parts = path.split('/');
      final reference = parts[parts.length - 2];
      return _json(
          {'url': 'https://storage.test/get/$reference?X-Amz-Expires=120'});
    }
    if (r.method == 'PATCH' && path.startsWith('$shipment/media/')) {
      final body = jsonDecode(r.body) as Map<String, Object?>;
      final reference = path.split('/').last;
      final index = media.indexWhere((row) => row['reference'] == reference);
      media[index] = {...media[index], 'shared': body['shared']};
      return _json({'ok': true});
    }
    return null;
  }
}

Widget _app(Widget home, _Server server, {UserRole role = UserRole.admin}) {
  final api = screenFixtureApi(
      intercept: (r) async => await server.call(r) ?? await teamFixtures(r));
  final session = SessionController(
      store: MemorySessionStore()..token = 'tok', auth: AuthRepository(api))
    ..user = SessionUser(
        id: 'u',
        name: 'Tester',
        email: 'test@sbx.test',
        role: role,
        roleLabel: role == UserRole.admin ? 'Administrator' : 'Hub Manager')
    ..ready = true;
  return AppScope.wired(
      session: session,
      api: api,
      child: MaterialApp(theme: buildAppTheme(), home: home));
}

void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

Finder _keyed(String prefix) => find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> && key.value.startsWith(prefix);
    });

Future<void> _tap(WidgetTester t, Finder finder) async {
  await t.scrollUntilVisible(finder, 200,
      scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

/// Storage uploads close their request stream outside the test's fake
/// clock, so each one needs a moment of real time to finish.
Future<void> _settleUploads(WidgetTester t) async {
  for (var i = 0;
      i < 40 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      i++) {
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await t.pump();
  }
  await t.pumpAndSettle();
}

/// Scrolls to [finder], taps it and lets the uploads it starts finish.
Future<void> _send(WidgetTester t, Finder finder) async {
  await t.scrollUntilVisible(finder, 200,
      scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pump();
  await _settleUploads(t);
}

/// The admin Photos tab, picking [gallery] from the gallery and one
/// `camera.jpg` from the camera.
Widget _photosTab(_Server server, {List<PickedPhoto> gallery = const []}) =>
    _app(
        AdminShipmentScreen(
            code: 'SH-18',
            initialTab: 2,
            pickPhotos: (source) async =>
                source == FileSource.camera ? [_photo('camera.jpg')] : gallery),
        server);

void main() {
  group('signed links', () {
    test('a link is reused until shortly before it expires', () async {
      var now = DateTime(2026, 10, 27, 12);
      var signed = 0;
      final cache = SignedUrlCache(now: () => now);
      Future<String> sign() async =>
          'https://storage.test/get/a?X-Amz-Expires=120&n=${++signed}';
      expect(await cache.get('a', sign), endsWith('n=1'));
      now = now.add(const Duration(seconds: 80));
      expect(await cache.get('a', sign), endsWith('n=1'));
      now = now.add(const Duration(seconds: 15));
      expect(await cache.get('a', sign), endsWith('n=2'));
      cache.forget('a');
      expect(await cache.get('a', sign), endsWith('n=3'));
      expect(
          signedLinkLifetime('https://x.test/a'), const Duration(seconds: 120));
      expect(signedLinkLifetime('https://x.test/a?X-Amz-Expires=60'),
          const Duration(seconds: 60));
    });

    test('only a 404 for the link itself means an older server', () {
      expect(
          isMissingLinkRoute(const ApiException(
              status: 404, message: '404 Not Found', path: '/url')),
          isTrue);
      expect(
          isMissingLinkRoute(const ApiException(
              status: 404, message: 'Attachment not found', path: '/url')),
          isFalse);
      expect(
          isMissingLinkRoute(
              const ApiException(status: 500, message: 'x', path: '/url')),
          isFalse);
    });
  });

  group('photo tray', () {
    testWidgets('picking previews photos and uploads nothing; × removes one',
        (t) async {
      _phone(t);
      final server = _Server();
      await t.pumpWidget(_photosTab(server,
          gallery: [_photo('a.jpg'), _photo('b.jpg'), _photo('c.jpg')]));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('photo-gallery')));
      await t.pumpAndSettle();
      // Gallery adds several at once, the camera one more.
      expect(_keyed('tray-photo-'), findsNWidgets(3));
      await t.tap(find.byKey(const Key('photo-camera')));
      await t.pumpAndSettle();
      expect(_keyed('tray-photo-'), findsNWidgets(4));
      expect(find.text(trn(4, 'Upload {n} photo', 'Upload {n} photos')),
          findsOneWidget);
      expect(find.text(tr('Location data removed')), findsOneWidget);
      expect(server.reserved, isEmpty);
      expect(server.calls.where((c) => c.startsWith('POST')), isEmpty);

      await t.tap(_keyed('tray-remove-').first);
      await t.pumpAndSettle();
      expect(_keyed('tray-photo-'), findsNWidgets(3));
      expect(find.text(trn(3, 'Upload {n} photo', 'Upload {n} photos')),
          findsOneWidget);

      // A preview opens big from the phone's own bytes.
      await t.tap(_keyed('tray-photo-').first);
      await t.pumpAndSettle();
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      expect(find.text(tr('{n} of {total}', {'n': 1, 'total': 3})),
          findsOneWidget);
      await t.tap(find.byKey(const Key('viewer-close')));
      await t.pumpAndSettle();

      await _tap(t, find.byKey(const Key('tray-clear')));
      expect(_keyed('tray-photo-'), findsNothing);
      expect(server.reserved, isEmpty);
      expect(t.takeException(), isNull);
    });

    testWidgets('Upload sends each photo in order and moves it to the list',
        (t) async {
      _phone(t);
      final hold = Completer<void>();
      final server = _Server()..hold = hold;
      await t.pumpWidget(
          _photosTab(server, gallery: [_photo('a.jpg'), _photo('b.jpg')]));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('photo-gallery')));
      await t.pumpAndSettle();
      final upload = find.byKey(const Key('tray-upload'));
      await t.scrollUntilVisible(upload, 200,
          scrollable: find.byType(Scrollable).first);
      await t.pumpAndSettle();
      await t.tap(upload);
      await t.pump();
      await t.pump();
      // The first photo is on its way: it shows a progress ring.
      expect(_keyed('tray-ring-'), findsOneWidget);
      expect(server.reserved, ['a.jpg']);
      hold.complete();
      await _settleUploads(t);

      expect(server.reserved, ['a.jpg', 'b.jpg']);
      final order = [
        for (final call in server.calls)
          if (!call.startsWith('GET')) call
      ];
      expect(order, [
        'POST /api/shipments/SH-18/media/upload',
        'PUT storage/put/1',
        'POST /api/shipments/SH-18/media/ref-1/complete',
        'POST /api/shipments/SH-18/media/upload',
        'PUT storage/put/2',
        'POST /api/shipments/SH-18/media/ref-2/complete',
      ]);
      expect(_keyed('tray-photo-'), findsNothing);
      expect(find.byKey(const ValueKey('photo-tile-ref-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-tile-ref-2')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('a failed photo stays in the tray with its error and Try again',
        (t) async {
      _phone(t);
      final server = _Server()..failing.add('b.jpg');
      await t.pumpWidget(
          _photosTab(server, gallery: [_photo('a.jpg'), _photo('b.jpg')]));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('photo-gallery')));
      await t.pumpAndSettle();
      await _send(t, find.byKey(const Key('tray-upload')));

      expect(find.byKey(const ValueKey('photo-tile-ref-1')), findsOneWidget);
      expect(_keyed('tray-photo-'), findsOneWidget);
      expect(_keyed('tray-error-'), findsOneWidget);
      expect(find.text(trn(1, 'Upload {n} photo', 'Upload {n} photos')),
          findsOneWidget);

      server.failing.clear();
      await _send(t, _keyed('tray-retry-'));
      expect(_keyed('tray-photo-'), findsNothing);
      expect(server.media.map((row) => row['name']), ['a.jpg', 'b.jpg']);
      expect(t.takeException(), isNull);
    });

    testWidgets('leaving with photos still in the tray asks to discard them',
        (t) async {
      _phone(t);
      final server = _Server();
      await t.pumpWidget(_app(
          Builder(
              builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => AdminShipmentScreen(
                              code: 'SH-18',
                              initialTab: 2,
                              pickPhotos: (_) async =>
                                  [_photo('a.jpg'), _photo('b.jpg')]))),
                  child: const Text('open'))),
          server));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('photo-gallery')));
      await t.pumpAndSettle();

      await t.tap(find.byTooltip(tr('Back')));
      await t.pumpAndSettle();
      expect(
          find.text(trn(2, 'Discard {n} photo that was not uploaded?',
              'Discard {n} photos that were not uploaded?')),
          findsOneWidget);
      await t.tap(find.byKey(const Key('tray-discard-cancel')));
      await t.pumpAndSettle();
      expect(find.byType(AdminShipmentScreen), findsOneWidget);
      expect(_keyed('tray-photo-'), findsNWidgets(2));

      await t.tap(find.byTooltip(tr('Back')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('tray-discard-confirm')));
      await t.pumpAndSettle();
      expect(find.byType(AdminShipmentScreen), findsNothing);
      expect(find.text('open'), findsOneWidget);
      expect(server.reserved, isEmpty);
      expect(t.takeException(), isNull);
    });
  });

  group('uploaded photos', () {
    List<Map<String, Object?>> three() => [
          _media('p-1', name: 'parcel.jpg', shared: true),
          _media('m-1', name: 'phone.jpg', category: 'Mobile'),
          _media('l-1', name: 'laptop.jpg', category: 'Laptop'),
        ];

    testWidgets('the grid signs a link per photo and groups them', (t) async {
      _phone(t);
      final server = _Server(media: three());
      await t.pumpWidget(_photosTab(server));
      await t.pumpAndSettle();

      expect(server.signed, [
        'GET /api/shipments/SH-18/media/p-1/url',
        'GET /api/shipments/SH-18/media/m-1/url',
        'GET /api/shipments/SH-18/media/l-1/url',
      ]);
      for (final reference in ['p-1', 'm-1', 'l-1']) {
        expect(server.count('GET storage/get/$reference'), 1);
        final image =
            t.widget<Image>(find.byKey(ValueKey('photo-image-$reference')));
        final provider = image.image as ResizeImage;
        expect((provider.imageProvider as MemoryImage).bytes, _jpeg);
      }
      // One group each, parcel photos first, with its count.
      final heads = [
        for (final element in find.byType(Text).evaluate())
          if ((element.widget as Text).textSpan?.toPlainText() case final text?)
            if (text.endsWith(' · 1')) text
      ];
      expect(heads, [
        '${tr('Parcel photos')} · 1',
        '${tr('{name} photos', {'name': 'Mobile'})} · 1',
        '${tr('{name} photos', {'name': 'Laptop'})} · 1',
      ]);
      expect(find.text(tr('Customer can see')), findsOneWidget);

      // Coming back to the tab shows the same photos without new links.
      await t.tap(find.text(tr('Overview')));
      await t.pumpAndSettle();
      await t.tap(find.text(tr('Photos · {n}', {'n': 3})));
      await t.pumpAndSettle();
      expect(server.signed, hasLength(3));
      expect(find.byKey(const ValueKey('photo-image-l-1')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('a photo that fails shows Tap to retry and loads again',
        (t) async {
      _phone(t);
      final server = _Server(media: [_media('p-1'), _media('p-2')])
        ..broken.add('p-1');
      await t.pumpWidget(_photosTab(server));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('photo-broken-p-1')), findsOneWidget);
      expect(find.text(tr('Tap to retry')), findsOneWidget);
      expect(find.byKey(const ValueKey('photo-image-p-2')), findsOneWidget);

      // The refused link is not reused: Tap to retry signs a new one.
      server.broken.clear();
      await t.tap(find.byKey(const ValueKey('photo-broken-p-1')));
      await t.pumpAndSettle();
      expect(server.count('GET /api/shipments/SH-18/media/p-1/url'), 2);
      expect(find.byKey(const ValueKey('photo-image-p-1')), findsOneWidget);
      expect(find.text(tr('Tap to retry')), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('the viewer swipes, shows the group and shares a photo',
        (t) async {
      _phone(t);
      final server = _Server(media: three());
      await t.pumpWidget(_photosTab(server));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('photo-tile-p-1')));
      await t.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsWidgets);
      String position() =>
          t.widget<Text>(find.byKey(const Key('viewer-position'))).data!;
      String group() =>
          t.widget<Text>(find.byKey(const Key('viewer-group'))).data!;
      bool shared() =>
          t.widget<Switch>(find.byKey(const Key('viewer-share'))).value;
      expect(position(), tr('{n} of {total}', {'n': 1, 'total': 3}));
      expect(group(), tr('Parcel photos'));
      expect(shared(), isTrue);

      await t.fling(
          find.byKey(const Key('viewer-pages')), const Offset(-300, 0), 1000);
      await t.pumpAndSettle();
      expect(position(), tr('{n} of {total}', {'n': 2, 'total': 3}));
      expect(group(), tr('{name} photos', {'name': 'Mobile'}));
      expect(shared(), isFalse);

      await t.tap(find.byKey(const Key('viewer-share')));
      await t.pumpAndSettle();
      expect(server.calls, contains('PATCH /api/shipments/SH-18/media/m-1'));
      expect(server.media[1]['shared'], isTrue);
      expect(shared(), isTrue);
      // The viewer reuses the photos the grid loaded.
      expect(server.signed, hasLength(3));

      await t.tap(find.byKey(const Key('viewer-close')));
      await t.pumpAndSettle();
      expect(find.text(tr('Customer can see')), findsNWidgets(2));
      expect(t.takeException(), isNull);
    });

    testWidgets('an older server without links keeps the list and says so',
        (t) async {
      _phone(t);
      final server = _Server(media: three())..links = false;
      await t.pumpWidget(_photosTab(server));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('photos-need-update')), findsOneWidget);
      expect(find.text(tr('The server needs an update to show photos.')),
          findsOneWidget);
      expect(find.text('parcel.jpg'), findsOneWidget);
      expect(find.text('laptop.jpg'), findsOneWidget);
      expect(find.byKey(const Key('photo-grid')), findsNothing);
      expect(find.byType(Switch), findsNWidgets(3));
      expect(server.calls.where((c) => c.startsWith('GET storage')), isEmpty);
      expect(t.takeException(), isNull);
    });

    testWidgets('storage that is not set up keeps the note and the list',
        (t) async {
      _phone(t);
      final server = _Server(media: three())..configured = false;
      await t.pumpWidget(_photosTab(server));
      await t.pumpAndSettle();
      expect(
          find.text(tr(
              'Storage is not set up yet. Uploads will turn on once an admin finishes storage setup.')),
          findsOneWidget);
      expect(find.byKey(const Key('photo-grid')), findsNothing);
      expect(find.byKey(const Key('photos-need-update')), findsNothing);
      expect(find.text('phone.jpg'), findsOneWidget);
      expect(server.signed, isEmpty);
      expect(t.takeException(), isNull);
    });

    testWidgets('hub staff see the photos without the share switch', (t) async {
      _phone(t);
      final server = _Server(media: three());
      await t.pumpWidget(_app(
          ShipmentProcessScreen(
              code: 'SH-18', pickPhotos: (_) async => [_photo('box.jpg')]),
          server,
          role: UserRole.hub));
      await t.pumpAndSettle();
      final tile = find.byKey(const ValueKey('photo-tile-m-1'));
      await t.scrollUntilVisible(tile, 300,
          scrollable: find.byType(Scrollable).first);
      await t.pumpAndSettle();
      expect(server.signed, hasLength(3));
      await t.tap(tile);
      await t.pumpAndSettle();
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      expect(find.byKey(const Key('viewer-share')), findsNothing);
      await t.tap(find.byKey(const Key('viewer-close')));
      await t.pumpAndSettle();

      await _tap(t, find.byKey(const Key('photo-gallery')));
      expect(_keyed('tray-photo-'), findsOneWidget);
      expect(server.reserved, isEmpty);
      await _send(t, find.byKey(const Key('tray-upload')));
      expect(server.reserved, ['box.jpg']);
      expect(server.media, hasLength(4));
      expect(_keyed('tray-photo-'), findsNothing);
      expect(t.takeException(), isNull);
    });
  });

  group('IMEI and flyer documents', () {
    const unit = DeviceUnitRef(
        itemIndex: 0,
        unitIndex: 1,
        category: 'Mobile',
        model: 'Galaxy A15',
        serial: '356938035643809',
        hasPhoto: true,
        photoRef: 'imei-1');

    testWidgets('the IMEI photo shows, and a new one waits for Upload',
        (t) async {
      _phone(t);
      final server = _Server();
      await t.pumpWidget(_app(
          ImeiGuideScreen(
              code: 'SH-18',
              unit: unit,
              pickPhotos: (_) async => [_photo('serial.jpg')]),
          server));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('imei-current')), findsOneWidget);
      expect(server.signed, ['GET /api/shipments/SH-18/media/imei-1/url']);
      expect(find.byKey(const ValueKey('photo-image-imei-1')), findsOneWidget);

      await _tap(t, find.byKey(const Key('photo-camera')));
      expect(_keyed('tray-photo-'), findsOneWidget);
      expect(server.reserved, isEmpty);
      // One photo per unit: a second pick replaces the first.
      await _tap(t, find.byKey(const Key('photo-gallery')));
      expect(_keyed('tray-photo-'), findsOneWidget);
      expect(find.text(tr('Upload photo')), findsOneWidget);

      await _send(t, find.byKey(const Key('tray-upload')));
      expect(server.calls, contains('POST /api/shipments/SH-18/device-photo'));
      expect(server.calls,
          contains('POST /api/shipments/SH-18/device-photo/ref-1/complete'));
      expect(find.text(tr('Photo saved. The customer cannot see it.')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('photo-image-ref-1')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('flyer photo documents open in the app and upload on Upload',
        (t) async {
      _phone(t);
      final server = _Server();
      await t.pumpWidget(_app(
          FlyerDetailScreen(
              name: 'Arif Rahman',
              pickFiles: (source) async => source == FileSource.pdf
                  ? [
                      PickedPhoto(
                          bytes: Uint8List.fromList(utf8.encode('%PDF-1.4')),
                          name: 'offer.pdf',
                          mime: 'application/pdf')
                    ]
                  : [_photo('id-front.jpg')]),
          server));
      await t.pumpAndSettle();

      await _tap(t, find.byKey(const ValueKey('document-view-doc-1')));
      expect(find.byType(PhotoViewerScreen), findsOneWidget);
      expect(
          server.signed, ['GET /api/flyers/Arif Rahman/documents/doc-1/url']);
      expect(t.widget<Text>(find.byKey(const Key('viewer-group'))).data,
          flyerDocumentKinds['student_id']);
      expect(find.byKey(const Key('viewer-share')), findsNothing);
      await t.tap(find.byKey(const Key('viewer-close')));
      await t.pumpAndSettle();

      await _tap(t, find.text(tr('Gallery')));
      expect(_keyed('tray-photo-'), findsOneWidget);
      expect(server.reserved, isEmpty);
      await _send(t, find.byKey(const Key('tray-upload')));
      expect(server.reserved, ['id-front.jpg']);
      expect(server.calls,
          contains('POST /api/flyers/Arif Rahman/documents/ref-1/complete'));

      // A PDF asks once, by name, before it is sent.
      await _tap(t, find.text('PDF'));
      expect(find.text(tr('Upload this PDF?')), findsOneWidget);
      expect(server.reserved, ['id-front.jpg']);
      await t.tap(find.byKey(const Key('pdf-upload-confirm')));
      await t.pump();
      await _settleUploads(t);
      expect(server.reserved, ['id-front.jpg', 'offer.pdf']);
      expect(t.takeException(), isNull);
    });
  });
}
