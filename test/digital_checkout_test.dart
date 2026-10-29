import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/api/api_client.dart';
import 'package:mobile_app/api/repositories/account_repository.dart';
import 'package:mobile_app/api/repositories/cart_repository.dart';
import 'package:mobile_app/api/repositories/checkout_repository.dart';
import 'package:mobile_app/mocks/mock_http_client.dart';

void main() {
  for (final payment in ['CASH_ON_DELIVERY', 'WAVE', 'ORANGE_MONEY']) {
    for (final delivery in ['STANDARD', 'EXPRESS', 'PICKUP']) {
      test('commande numérique $payment $delivery', () async {
        final api = ApiClient(client: MockHttpClient());
        final cart = CartRepository(api);
        await cart.addItem('p-200');
        await cart.addItem('p-210');
        final order = await CheckoutRepository(api).createOrder(
            deliveryMethod: delivery,
            zoneId: 'dakar-centre',
            payment: payment,
            name: 'Aissatou',
            phone: '776211111',
            address: 'Plateau');
        expect(order.status, 'Livrée');
        final orders = await AccountRepository(api).listOrders();
        await AccountRepository(api).getOrder(orders.first.number);
      });
    }
  }
}
