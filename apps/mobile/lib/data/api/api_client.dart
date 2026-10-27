import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config.dart';
import '../json_read.dart';
import '../session/session_store.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.session,
    this.onUnauthorized,
    http.Client? httpClient,
  })  : baseUrl = requireApiBaseUrl(baseUrl, releaseMode: kReleaseMode, debugMode: kDebugMode),
        _http = httpClient ?? http.Client();

  final String baseUrl;
  final SessionStore session;
  final Future<void> Function()? onUnauthorized;
  final http.Client _http;

  Future<void> _unauthorized(int status) async {
    if (status != 401 || onUnauthorized == null) return;
    await onUnauthorized!();
  }

  Future<Map<String, Object?>> getJson(String path) => _send('GET', path);

  Future<Map<String, Object?>> postJson(String path, {Object? body, bool idempotent = false}) {
    return _send('POST', path, body: body ?? const <String, Object?>{}, idempotent: idempotent);
  }

  Future<Map<String, Object?>> patchJson(String path, {required Object? body}) {
    return _send('PATCH', path, body: body ?? const <String, Object?>{});
  }

  Future<Map<String, Object?>> deleteJson(String path) => _send('DELETE', path);

  Future<List<int>> getBytes(String path) async {
    final headers = <String, String>{'accept': '*/*'};
    final token = await session.readToken();
    if (token != null && token.isNotEmpty) headers['authorization'] = 'Bearer $token';
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await _http.get(uri, headers: headers);
      if (response.statusCode >= 400) {
        await _unauthorized(response.statusCode);
        throw ApiException(status: response.statusCode, message: _errorMessage(response.statusCode, response.body), path: path);
      }
      return response.bodyBytes;
    } on ApiException {
      rethrow;
    } on SocketException catch (error) {
      throw ApiException(status: 0, message: error.message, path: path);
    } on http.ClientException catch (error) {
      throw ApiException(status: 0, message: error.message, path: path);
    }
  }

  /// Downloads a short-lived storage link from the server. The session
  /// token is never sent with it, and a failure does not sign out.
  Future<Uint8List> getSignedBytes(String url) async {
    final uri = Uri.tryParse(url);
    final allowed = uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'https' ||
            (uri.scheme == 'http' && !kReleaseMode && kDebugMode && isLoopbackHost(uri.host)));
    if (!allowed) {
      throw ApiException(status: 0, message: 'The download link must use HTTPS.', path: url);
    }
    try {
      final response = await _http.get(uri, headers: const {'accept': 'image/*,*/*'});
      if (response.statusCode >= 400) {
        throw ApiException(
            status: response.statusCode, message: _errorMessage(response.statusCode, response.body), path: url);
      }
      return response.bodyBytes;
    } on SocketException catch (error) {
      throw ApiException(status: 0, message: error.message, path: url);
    } on http.ClientException catch (error) {
      throw ApiException(status: 0, message: error.message, path: url);
    }
  }

  Future<void> putBytes(
    String url,
    List<int> bytes,
    String contentType,
    void Function(double progress) onProgress,
  ) async {
    assertPresignedUploadUrl(url, releaseMode: kReleaseMode, debugMode: kDebugMode);
    final request = http.StreamedRequest('PUT', Uri.parse(url));
    request.headers['content-type'] = contentType;
    request.contentLength = bytes.length;
    const chunk = 64 * 1024;
    var sent = 0;
    try {
      final responseFuture = _http.send(request);
      for (var offset = 0; offset < bytes.length; offset += chunk) {
        final end = min(offset + chunk, bytes.length);
        request.sink.add(bytes.sublist(offset, end));
        sent = end;
        onProgress(bytes.isEmpty ? 1 : sent / bytes.length);
      }
      if (bytes.isEmpty) onProgress(1);
      await request.sink.close();
      final response = await responseFuture;
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode >= 400) {
        await _unauthorized(response.statusCode);
        throw ApiException(
          status: response.statusCode,
          message: _errorMessage(response.statusCode, responseBody),
          path: url,
        );
      }
    } on ApiException {
      rethrow;
    } on SocketException catch (error) {
      throw ApiException(status: 0, message: error.message, path: url);
    } on http.ClientException catch (error) {
      throw ApiException(status: 0, message: error.message, path: url);
    }
  }

  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    Object? body,
    bool idempotent = false,
  }) async {
    final headers = <String, String>{'accept': 'application/json'};
    final token = await session.readToken();
    if (token != null && token.isNotEmpty) headers['authorization'] = 'Bearer $token';
    if (body != null) headers['content-type'] = 'application/json';
    if (idempotent) headers['idempotency-key'] = newIdempotencyKey();
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await _http.send(http.Request(method, uri)
        ..headers.addAll(headers)
        ..body = body == null ? '' : jsonEncode(body));
      final responseBody = await response.stream.bytesToString();
      if (response.statusCode >= 400) {
        await _unauthorized(response.statusCode);
        throw ApiException(status: response.statusCode, message: _errorMessage(response.statusCode, responseBody), path: path);
      }
      if (responseBody.trim().isEmpty) return <String, Object?>{};
      final decoded = jsonDecode(responseBody);
      return asJsonMap(decoded, 'response');
    } on ApiException {
      rethrow;
    } on FormatException catch (error) {
      throw ApiException(status: 200, message: error.message, path: path);
    } on SocketException catch (error) {
      throw ApiException(status: 0, message: error.message, path: path);
    } on http.ClientException catch (error) {
      throw ApiException(status: 0, message: error.message, path: path);
    }
  }
}

String _errorMessage(int status, String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map && decoded['error'] is String) return decoded['error'] as String;
  } on FormatException {
    // Non-JSON error body.
  }
  if (body.trim().isNotEmpty && body.length < 240) return body.trim();
  return 'Request failed ($status)';
}

String newIdempotencyKey() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int value) => value.toRadixString(16).padLeft(2, '0');
  final text = bytes.map(hex).join();
  return '${text.substring(0, 8)}-${text.substring(8, 12)}-${text.substring(12, 16)}-${text.substring(16, 20)}-${text.substring(20)}';
}
