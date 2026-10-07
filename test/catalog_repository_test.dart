import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_app/api/api_client.dart';
import 'package:mobile_app/api/errors.dart';
import 'package:mobile_app/api/repositories/catalog_repository.dart';

class _FakeClient extends http.BaseClient {
  _FakeClient(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);
}

http.StreamedResponse _response(http.BaseRequest request, int status, Object body) {
  return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(body))), status, request: request);
}

void main() {
  test('listProducts parses the API envelope', () async {
    final repository = CatalogRepository(
      ApiClient(client: _FakeClient((request) async => _response(request, 200, {
        'data': [
          {'id': 'p-1', 'name': 'Laptop', 'brand': 'LO', 'categoryId': 'c-1', 'priceXof': 1000, 'inStock': true, 'badges': []},
        ],
      }))),
    );

    final products = await repository.listProducts();
    expect(products.single.name, 'Laptop');
  });

  test('listCategories rejects an invalid payload', () async {
    final repository = CatalogRepository(
      ApiClient(client: _FakeClient((request) async => _response(request, 200, {'data': 'not-a-list'}))),
    );
    expect(repository.listCategories(), throwsA(isA<ApiParseError>()));
  });

  test('getProduct parses product detail fields', () async {
    final repository = CatalogRepository(
      ApiClient(client: _FakeClient((request) async => _response(request, 200, {
        'data': {
          'id': 'p-1', 'name': 'Laptop', 'brand': 'LO', 'categoryId': 'c-1', 'priceXof': 1000, 'inStock': true, 'badges': [],
          'images': [], 'specifications': {'Garantie': '12 mois'}, 'variants': [], 'addons': [], 'reviews': [],
        },
      }))),
    );

    final product = await repository.getProduct('p-1');
    expect(product.specifications['Garantie'], '12 mois');
  });
}
