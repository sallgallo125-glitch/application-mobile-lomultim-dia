import 'dart:convert';

import 'package:http/http.dart' as http;

import '../features/persistence.dart';
import 'errors.dart';

/// Mirrors ../mobile-app/src/api/client.ts — a single narrow transport used
/// by every repository. The mock transport is swapped in by passing a
/// [MockHttpClient] (see lib/mocks/mock_http_client.dart) as [client]; no
/// repository code needs to know which one it's talking to.
class ApiClient {
  ApiClient(
      {required http.Client client,
      this.baseUrl = 'http://mock.lo.local',
      this.cache})
      : _client = client;

  final http.Client _client;
  final String baseUrl;

  /// Where cached GET responses are kept between launches (SQLite).
  final LocalPersistence? cache;

  /// One network call per path at a time, shared by concurrent readers.
  final Map<String, Future<dynamic>> _inFlight = {};

  static const _cachePrefix = 'http_cache:';

  /// Stale-while-revalidate GET, for public catalogue data only (never the
  /// cart, checkout, orders or account):
  /// - saved response younger than [maxAge]: returned, no network call;
  /// - older: returned at once, refreshed in the background, then
  ///   [onRefreshed] is called so the caller can show the new data;
  /// - nothing saved: waits for the network.
  /// A failed background refresh keeps the saved copy (offline use).
  Future<dynamic> getCached(String path,
      {required Duration maxAge, void Function()? onRefreshed}) async {
    final saved = _readCache(path);
    if (saved == null) return _fetchAndSave(path);
    if (DateTime.now().difference(saved.savedAt) >= maxAge) {
      _fetchAndSave(path)
          .then((_) => onRefreshed?.call(), onError: (Object _) {});
    }
    return saved.body;
  }

  /// Drops the saved copy of [path], after a change made by the user (a
  /// posted review…), so the next read goes to the network.
  void forget(String path) =>
      cache?.write('$_cachePrefix$path', null).catchError((Object _) {});

  Future<dynamic> _fetchAndSave(String path) =>
      _inFlight[path] ??= get(path).then((body) {
        cache
            ?.write(
                '$_cachePrefix$path',
                jsonEncode(
                    {'t': DateTime.now().millisecondsSinceEpoch, 'b': body}))
            .catchError((Object _) {});
        return body;
      }).whenComplete(() {
        // Block body: returning the removed Future would make whenComplete
        // wait for itself, and the request would never finish.
        _inFlight.remove(path);
      });

  ({DateTime savedAt, dynamic body})? _readCache(String path) {
    final raw = cache?.read('$_cachePrefix$path');
    if (raw == null) return null;
    try {
      final entry = jsonDecode(raw) as Map<String, dynamic>;
      return (
        savedAt: DateTime.fromMillisecondsSinceEpoch(entry['t'] as int),
        body: entry['b'],
      );
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> get(String path) async {
    final response = await _client.get(Uri.parse('$baseUrl$path'));
    return _decode(response, path);
  }

  Future<dynamic> post(String path, [Object? body]) async => _decode(
      await _client.post(Uri.parse('$baseUrl$path'),
          headers: {'content-type': 'application/json'},
          body: body == null ? null : jsonEncode(body)),
      path);
  Future<dynamic> patch(String path, Object body) async => _decode(
      await _client.patch(Uri.parse('$baseUrl$path'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode(body)),
      path);
  Future<dynamic> delete(String path) async =>
      _decode(await _client.delete(Uri.parse('$baseUrl$path')), path);

  dynamic _decode(http.Response response, String path) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? code;
      String? message;
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          code = body['code'] as String?;
          message = body['message'] as String?;
        }
      } catch (_) {}
      throw ApiHttpError(path, response.statusCode,
          code: code, message: message);
    }
    return jsonDecode(response.body);
  }
}
