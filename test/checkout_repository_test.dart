import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/api/api_client.dart';
import 'package:mobile_app/api/errors.dart';
import 'package:mobile_app/api/repositories/cart_repository.dart';
import 'package:mobile_app/api/repositories/checkout_repository.dart';
import 'package:mobile_app/mocks/mock_http_client.dart';

void main() {
  late CartRepository cart;
  late CheckoutRepository checkout;

  setUp(() {
    final api = ApiClient(client: MockHttpClient());
    cart = CartRepository(api);
    checkout = CheckoutRepository(api);
  });

  test('la commande facture comme le site (express + LO10)', () async {
    await cart.addItem('p-005'); // 142 000
    final order = await checkout.createOrder(
        deliveryMethod: 'EXPRESS',
        zoneId: 'dakar-centre',
        payment: 'CASH_ON_DELIVERY',
        promoCode: 'lo10',
        name: 'Aissatou',
        phone: '776211111',
        address: 'Plateau, rue 10');
    // 142 000 − 14 200 (10 %) + 4 500 express
    expect(order.totalXof, 132300);
    // (142 000 − 14 200) / 10 000 = 12 points
    expect(order.pointsToEarn, 12);
  });

  test('paiement Wave accepté, moyen inconnu refusé', () async {
    await cart.addItem('p-005');
    final order = await checkout.createOrder(
        deliveryMethod: 'PICKUP',
        zoneId: 'dakar-centre',
        payment: 'WAVE',
        name: 'Aissatou',
        phone: '776211111');
    expect(order.paymentMethod, 'WAVE');
    await cart.addItem('p-005');
    expect(
        () => checkout.createOrder(
            deliveryMethod: 'PICKUP',
            zoneId: 'dakar-centre',
            payment: 'BITCOIN',
            name: 'Aissatou',
            phone: '776211111'),
        throwsA(isA<ApiHttpError>()));
  });
}
