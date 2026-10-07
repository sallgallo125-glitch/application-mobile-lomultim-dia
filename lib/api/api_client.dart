import 'dart:convert';

import 'package:http/http.dart' as http;

import 'errors.dart';

/// Mirrors ../mobile-app/src/api/client.ts — a single narrow transport used
/// by every repository. The mock transport is swapped in by passing a
/// [MockHttpClient] (see lib/mocks/mock_http_client.dart) as [client]; no
/// repository code needs to know which one it's talking to.
class ApiClient {
  ApiClient(
      {required http.Client client, this.baseUrl = 'http://mock.lo.local'})
      : _client = client;

  final http.Client _client;
  final String baseUrl;

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
