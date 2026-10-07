import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/api/api_client.dart';
import 'package:mobile_app/api/errors.dart';
import 'package:mobile_app/api/repositories/home_repository.dart';

class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => _handler(request);
}

http.StreamedResponse _jsonResponse(http.BaseRequest request, int status, Object body) {
  final bytes = utf8.encode(jsonEncode(body));
  return http.StreamedResponse(Stream.value(bytes), status, request: request);
}

const _validHomePayload = {
  'data': {
    'banners': [
      {'id': 'b-1', 'icon': 'wifi', 'badgeLabel': 'PROMO', 'title': 'Titre', 'subtitle': 'Sous-titre', 'ctaLabel': 'Voir'},
    ],
    'categories': [
      {'id': 'c-1', 'name': 'Informatique', 'icon': 'laptop-outline'},
    ],
    'flashProducts': <Map<String, dynamic>>[],
    'bestSellers': <Map<String, dynamic>>[],
  },
};

void main() {
  test('getHomeContent returns parsed content on success', () async {
    final client = _FakeClient((request) async => _jsonResponse(request, 200, _validHomePayload));
    final repository = HomeRepository(ApiClient(client: client));

    final content = await repository.getHomeContent();

    expect(content.banners, hasLength(1));
    expect(content.categories.single.name, 'Informatique');
    expect(content.flashProducts, isEmpty);
  });

  test('getHomeContent throws ApiHttpError on non-2xx', () async {
    final client = _FakeClient((request) async => _jsonResponse(request, 500, {'code': 'error', 'message': 'boom'}));
    final repository = HomeRepository(ApiClient(client: client));

    expect(repository.getHomeContent(), throwsA(isA<ApiHttpError>()));
  });

  test('getHomeContent throws ApiParseError on invalid payload', () async {
    final client = _FakeClient(
      (request) async => _jsonResponse(request, 200, {
            'data': {'banners': 'not-a-list'},
          }),
    );
    final repository = HomeRepository(ApiClient(client: client));

    expect(repository.getHomeContent(), throwsA(isA<ApiParseError>()));
  });
}
