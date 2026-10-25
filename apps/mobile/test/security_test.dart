import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sbexpress/app.dart';
import 'package:sbexpress/config.dart';
import 'package:sbexpress/data/api/api_client.dart';
import 'package:sbexpress/data/api/api_exception.dart';
import 'package:sbexpress/data/repositories/auth_repository.dart';
import 'package:sbexpress/data/models/session_user.dart';
import 'package:sbexpress/data/session/session_controller.dart';
import 'package:sbexpress/data/session/session_store.dart';
import 'package:sbexpress/data/uploads/image_prepare.dart';
import 'package:sbexpress/data/uploads/picked_photo_file.dart';
import 'package:sbexpress/data/uploads/upload_flow.dart';
import 'package:sbexpress/features/shipments/shipment_process_screen.dart';

Map<String, Object?> _userJson() => {
      'id': 'u-hub',
      'name': 'Mina',
      'email': 'hub@sbx.test',
      'role': 'hub',
      'roleLabel': 'Hub Manager Dhaka',
    };

Map<String, Object?> _shipment() => {
      'code': 'SH-SEC',
      'supplierCode': 'C-1',
      'flightCode': null,
      'flightDate': null,
      'bookedKg': 1,
      'weighedKg': null,
      'effectiveKg': 1,
      'weightDelta': null,
      'description': 'box',
      'categories': ['general'],
      'status': 'received_bd_hub',
      'statusIndex': 5,
      'statusLabel': 'Received at BD Hub',
      'exception': null,
      'exceptionReason': '',
      'date': '2026-10-18',
    };

http.Response _json(Object body, int status) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  test('release refuses non-https API origins, including localhost', () {
    expect(apiBaseUrl, 'http://localhost:3002');
    expect(
      () => requireApiBaseUrl('http://localhost:3002', releaseMode: true, debugMode: false),
      throwsFormatException,
    );
    expect(
      () => requireApiBaseUrl('http://10.0.2.2:3002', releaseMode: true, debugMode: false),
      throwsFormatException,
    );
    expect(
      requireApiBaseUrl('https://api.sbx.example/', releaseMode: true, debugMode: false),
      'https://api.sbx.example',
    );
  });

  test('debug allows http only for loopback hosts', () {
    expect(
      requireApiBaseUrl('http://localhost:3002', releaseMode: false, debugMode: true),
      'http://localhost:3002',
    );
    expect(
      requireApiBaseUrl('http://10.0.2.2:3002', releaseMode: false, debugMode: true),
      'http://10.0.2.2:3002',
    );
    expect(
      () => requireApiBaseUrl('http://api.sbx.example', releaseMode: false, debugMode: true),
      throwsFormatException,
    );
    expect(
      () => requireApiBaseUrl('http://localhost:3002', releaseMode: false, debugMode: false),
      throwsFormatException,
    );
    expect(
      () => requireApiBaseUrl('https://user:secret@api.sbx.example', releaseMode: true, debugMode: false),
      throwsFormatException,
    );
  });

  test('presigned upload URLs must be https outside debug loopback', () {
    expect(
      () => assertPresignedUploadUrl('http://uploads.example/obj', releaseMode: false, debugMode: true),
      throwsFormatException,
    );
    expect(
      () => assertPresignedUploadUrl('http://localhost:9000/obj', releaseMode: true, debugMode: false),
      throwsFormatException,
    );
    assertPresignedUploadUrl('https://uploads.example/obj', releaseMode: true, debugMode: false);
    assertPresignedUploadUrl('http://127.0.0.1:9000/obj', releaseMode: false, debugMode: true);
  });

  test('a non-https presigned URL fails before the bytes are sent', () async {
    final seen = <String>[];
    final api = ApiClient(
      baseUrl: 'http://localhost:3002',
      session: MemorySessionStore()..token = 'tok',
      httpClient: MockClient((request) async {
        seen.add(request.url.toString());
        return _json({'ok': true}, 200);
      }),
    );
    await expectLater(
      transferPreparedUpload(
        file: PreparedImage(bytes: Uint8List.fromList([1]), filename: 'a.jpg', contentType: 'image/jpeg'),
        reserve: (_) async => const UploadReservation(reference: 'r', uploadUrl: 'http://uploads.example/obj', expiresAt: 'later'),
        put: (reservation, file, onProgress) => api.putBytes(reservation.uploadUrl, file.bytes, file.contentType, onProgress),
        complete: (_) async {},
      ),
      throwsFormatException,
    );
    expect(seen, isEmpty);
  });

  test('401 clears the stored session and does not call logout', () async {
    final store = MemorySessionStore()..token = 'tok'..userJson = jsonEncode(_userJson());
    final paths = <String>[];
    late SessionController session;
    final api = ApiClient(
      baseUrl: 'http://localhost:3002',
      session: store,
      onUnauthorized: () => session.handleUnauthorized(),
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        return _json({'error': 'unauthorized'}, request.url.path == '/api/health' ? 500 : 401);
      }),
    );
    session = SessionController(store: store, auth: AuthRepository(api));
    session.user = SessionUser.fromJson(_userJson());
    await expectLater(
      api.getJson('/api/shipments'),
      throwsA(isA<ApiException>().having((error) => error.status, 'status', 401)),
    );
    expect(store.token, isNull);
    expect(store.userJson, isNull);
    expect(session.user, isNull);
    expect(paths, ['/api/shipments']);

    await expectLater(api.getJson('/api/health'), throwsA(isA<ApiException>().having((error) => error.status, 'status', 500)));
    expect(paths, ['/api/shipments', '/api/health']);
  });

  test('files over 25MB are rejected before decode', () async {
    var decoded = false;
    await expectLater(
      prepareForUpload(
        Uint8List(imageInputMaxBytes + 1),
        name: 'huge.jpg',
        decodeHeic: (_) async {
          decoded = true;
          return Uint8List(0);
        },
      ),
      throwsA(isA<FormatException>().having((error) => error.message, 'message', contains('25 MB'))),
    );
    expect(decoded, isFalse);
    expect(imageInputMaxBytes, 25 * 1024 * 1024);
  });

  test('the picker temp file is deleted after the caller finishes', () async {
    final file = File('${Directory.systemTemp.path}/sbx-exif-${DateTime.now().microsecondsSinceEpoch}.jpg');
    await file.writeAsBytes([0xff, 0xd8, 0xff, 0xe1]);
    expect(await file.exists(), isTrue);
    await deletePickedPhotoFile(file.path);
    expect(await file.exists(), isFalse);
    await deletePickedPhotoFile(file.path);
    await deletePickedPhotoFile(null);
  });

  testWidgets('a mid-session 401 drops the open screen and returns to login', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = MemorySessionStore()
      ..token = 'tok'
      ..userJson = jsonEncode(_userJson());
    var arm401 = false;
    late SessionController session;
    final api = ApiClient(
      baseUrl: 'http://localhost:3002',
      session: store,
      onUnauthorized: () => session.handleUnauthorized(),
      httpClient: MockClient((request) async {
        if (arm401) return _json({'error': 'Account changed — sign in again'}, 401);
        final path = request.url.path;
        if (path == '/api/me') return _json({'user': _userJson()}, 200);
        if (path == '/api/dashboard/hub') {
          return _json({
            'todayLabel': 'Sun 18 Oct 2026',
            'atHubCount': 1,
            'incoming': {'kg': 1, 'count': 1, 'flightCode': 'BG-1', 'flightDate': '20 Oct'},
            'openTodoCount': 1,
            'notices': <Map<String, Object?>>[],
            'toProcess': [_shipment()],
          }, 200);
        }
        if (path == '/api/shipments') return _json({'shipments': [_shipment()]}, 200);
        if (path == '/api/todos') return _json({'todos': <Map<String, Object?>>[]}, 200);
        return _json({'error': 'unexpected $path'}, 500);
      }),
    );
    session = SessionController(store: store, auth: AuthRepository(api));
    await tester.pumpWidget(SbExpressApp(session: session, api: api));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('আজকের কাজ'), findsOneWidget);
    expect(find.text('SH-SEC'), findsWidgets);

    arm401 = true;
    Navigator.of(tester.element(find.text('আজকের কাজ'))).push(
      MaterialPageRoute<void>(builder: (_) => const ShipmentProcessScreen(code: 'SH-SEC')),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Account changed — sign in again'), findsNothing);
    expect(find.text('আবার চেষ্টা'), findsNothing);
    expect(find.text('SH-SEC'), findsNothing);
    expect(find.text('আজকের কাজ'), findsNothing);
    expect(find.byKey(const Key('login-email')), findsOneWidget);
    expect(store.token, isNull);
    expect(session.user, isNull);
  });
}
