import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/api/api_client.dart';
import 'package:mobile_app/api/repositories/cart_repository.dart';
import 'package:mobile_app/mocks/mock_http_client.dart';

void main() {
  group('CartRepository with MockHttpClient', () {
    late MockHttpClient mockClient;
    late CartRepository repository;

    setUp(() {
      mockClient = MockHttpClient();
      repository = CartRepository(ApiClient(client: mockClient));
    });

    test('getCart returns empty cart initially', () async {
      final cart = await repository.getCart();
      expect(cart.items, isEmpty);
      expect(cart.subtotalXof, 0);
      expect(cart.totalXof, 0);
    });

    test('addItem adds product to cart', () async {
      await repository.addItem('p-001');
      final cart = await repository.getCart();
      expect(cart.items.length, 1);
      expect(cart.items.first.productId, 'p-001');
      expect(cart.items.first.name,
          'HP ProBook 450 G10 — Intel Core i5 · 16 Go · 512 Go SSD · Sans licence');
      expect(cart.items.first.quantity, 1);
      expect(cart.items.first.unitPriceXof, 795000);
      expect(cart.subtotalXof, 795000);
      expect(cart.deliveryFeeXof, 0); // free standard delivery from 500k
      expect(cart.totalXof, 795000);
    });

    test('addItem increments quantity for existing product', () async {
      await repository.addItem('p-001');
      await repository.addItem('p-001');
      final cart = await repository.getCart();
      expect(cart.items.length, 1);
      expect(cart.items.first.quantity, 2);
      expect(cart.subtotalXof, 1590000);
    });

    test('updateItem changes quantity', () async {
      final lineId = (await repository.addItem('p-001')).items.single.id;
      await repository.updateItem(lineId, 5);
      final cart = await repository.getCart();
      expect(cart.items.first.quantity, 5);
    });

    test('removeItem removes product from cart', () async {
      final lineId = (await repository.addItem('p-001')).items.single.id;
      await repository.removeItem(lineId);
      final cart = await repository.getCart();
      expect(cart.items, isEmpty);
    });

    test('delivery fee applied for orders under 500k (Dakar Centre)', () async {
      await repository.addItem('p-005'); // Onduleur 1500 VA - 142000
      final cart = await repository.getCart();
      expect(cart.subtotalXof, 142000);
      expect(cart.deliveryFeeXof, 2500);
      expect(cart.totalXof, 144500);
    });

    test('portable configuré : RAM, stockage, Windows et accessoire', () async {
      // HP ProBook: 795 000 FCFA in 16 Go / 512 Go SSD / Sans licence.
      await repository.addItem('p-001', options: {
        'ram': 'ram-32-go',
        'storage': 'storage-1-to-ssd',
        'os': 'os-windows-11-pro',
      }, addonIds: [
        'p-001-souris'
      ]);
      final cart = await repository.getCart();
      final line = cart.items.single;
      // +50 000 (16→32 Go) +75 000 (1 To) +65 000 (Windows) +15 000 (souris)
      expect(line.unitPriceXof, 795000 + 50000 + 75000 + 65000 + 15000);
      expect(line.name,
          'HP ProBook 450 G10 — Intel Core i5 · 32 Go · 1 To SSD · Windows 11 Pro · Souris');
      expect(line.options, {
        'ram': 'ram-32-go',
        'storage': 'storage-1-to-ssd',
        'os': 'os-windows-11-pro',
      });
      expect(line.addonIds, ['p-001-souris']);
    });

    test('ajout rapide = configuration par défaut, même ligne', () async {
      await repository.addItem('p-001');
      await repository.addItem('p-001', options: {
        'ram': 'ram-16-go',
        'storage': 'storage-512-go-ssd',
        'os': 'os-sans-licence',
      });
      final cart = await repository.getCart();
      expect(cart.items.single.quantity, 2);
      expect(cart.items.single.unitPriceXof, 795000);
    });

    test('plus d’options génériques sur les autres produits', () async {
      await repository.addItem('p-005');
      final cart = await repository.getCart();
      expect(cart.items.single.name, 'Onduleur 1500 VA — protection réseau');
    });
  });
}
