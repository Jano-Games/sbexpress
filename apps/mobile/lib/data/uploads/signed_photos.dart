import 'package:flutter/foundation.dart';

import '../api/api_exception.dart';

/// How long a signed storage link lasts: its `X-Amz-Expires`, else the two
/// minutes the server signs for.
Duration signedLinkLifetime(String url) {
  final query = Uri.tryParse(url)?.queryParameters ?? const {};
  final seconds = int.tryParse(query['X-Amz-Expires'] ?? '');
  return Duration(seconds: seconds == null || seconds <= 0 ? 120 : seconds);
}

/// Short-lived download links, kept in memory until shortly before they
/// expire. The lifetime counts from when the link arrived, so a phone clock
/// that is off does not matter.
class SignedUrlCache {
  SignedUrlCache(
      {DateTime Function()? now, this.margin = const Duration(seconds: 30)})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// How long before the link expires it stops being reused.
  final Duration margin;

  final _links = <String, ({String url, DateTime until})>{};
  final _signing = <String, Future<String>>{};

  /// The cached link for [key], or a new one from [sign].
  Future<String> get(String key, Future<String> Function() sign) {
    final cached = _links[key];
    if (cached != null && _now().isBefore(cached.until)) {
      return Future.value(cached.url);
    }
    _links.remove(key);
    return _signing[key] ??= sign().then((url) {
      _links[key] = (
        url: url,
        until: _now().add(signedLinkLifetime(url) - margin),
      );
      return url;
    }).whenComplete(() {
      _signing.remove(key);
    });
  }

  /// Drops the link for [key], e.g. after storage refused it.
  void forget(String key) => _links.remove(key);
}

/// The server answered 404 for the link itself: it is older than the photo
/// links, not missing one photo (that 404 names the attachment).
bool isMissingLinkRoute(Object error) =>
    error is ApiException &&
    error.status == 404 &&
    !RegExp('attachment|document|photo', caseSensitive: false)
        .hasMatch(error.message);

/// Thrown for every photo once the server turned out to have no links.
class PhotoLinksUnsupported implements Exception {
  const PhotoLinksUnsupported();
}

/// Stored photos for one screen: a signed link for each (cached), its
/// bytes downloaded once and kept while the screen is open, so the grid and
/// the full-screen viewer show the same photo without loading it again.
class SignedPhotoLoader extends ChangeNotifier {
  SignedPhotoLoader(
      {required this.link,
      required this.download,
      this.forget,
      this.keep = 30});

  /// A signed download link for a stored reference.
  final Future<String> Function(String reference) link;

  /// Drops a cached link that storage refused, so a retry signs again.
  final void Function(String reference)? forget;
  final Future<Uint8List> Function(String url) download;

  /// How many photos stay in memory; the oldest seen goes first.
  final int keep;

  final _bytes = <String, Uint8List>{};
  final _loading = <String, Future<Uint8List>>{};
  var _unsupported = false;
  var _disposed = false;

  /// True once the server answered that it has no photo links.
  bool get unsupported => _unsupported;

  /// Bytes already loaded for [reference].
  Uint8List? cached(String reference) {
    final bytes = _bytes.remove(reference);
    if (bytes != null) _bytes[reference] = bytes;
    return bytes;
  }

  /// Loads [reference]; callers loading the same photo share one request.
  Future<Uint8List> load(String reference) {
    final hit = cached(reference);
    if (hit != null) return Future.value(hit);
    if (_unsupported) return Future.error(const PhotoLinksUnsupported());
    // A block body: returning the removed future would wait on itself.
    return _loading[reference] ??= _fetch(reference).whenComplete(() {
      _loading.remove(reference);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _bytes.clear();
    super.dispose();
  }

  Future<Uint8List> _fetch(String reference) async {
    final String url;
    try {
      url = await link(reference);
    } catch (error) {
      if (isMissingLinkRoute(error)) {
        if (!_unsupported) {
          _unsupported = true;
          if (!_disposed) notifyListeners();
        }
        throw const PhotoLinksUnsupported();
      }
      rethrow;
    }
    try {
      final bytes = await download(url);
      _bytes[reference] = bytes;
      while (_bytes.length > keep) {
        _bytes.remove(_bytes.keys.first);
      }
      return bytes;
    } catch (_) {
      forget?.call(reference);
      rethrow;
    }
  }
}
