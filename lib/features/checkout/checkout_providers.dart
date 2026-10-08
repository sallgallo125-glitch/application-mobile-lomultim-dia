import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/repositories/checkout_repository.dart';
import '../../contracts/account.dart';
import '../account/account_providers.dart';
import '../cart/cart_providers.dart';
import '../home/home_providers.dart';
import '../member/member_providers.dart';

final checkoutRepositoryProvider = Provider<CheckoutRepository>(
    (ref) => CheckoutRepository(ref.watch(apiClientProvider)));

class CheckoutActions {
  CheckoutActions(this.ref);
  final Ref ref;
  Future<OrderSummary> create(
      {required String deliveryMethod,
      required String zoneId,
      required String payment,
      String? promoCode,
      int pointsToUse = 0,
      String? giftCardCode,
      String? giftCardOtp,
      required String name,
      required String phone,
      String? address}) async {
    // No account: the order is placed as a guest (no LO+ points).
    final guest = !ref.read(signedInProvider);
    final order = await ref.read(checkoutRepositoryProvider).createOrder(
        guest: guest,
        deliveryMethod: deliveryMethod,
        zoneId: zoneId,
        payment: payment,
        promoCode: promoCode,
        pointsToUse: guest ? 0 : pointsToUse,
        giftCardCode: giftCardCode,
        giftCardOtp: giftCardOtp,
        name: name,
        phone: phone,
        address: address);
    if (guest) {
      // Remembered on the device to pre-fill the next guest checkout.
      ref.read(guestContactProvider.notifier).state =
          GuestContact(name: name, phone: phone, address: address);
      // Kept on the device: "Mes commandes" works without an account.
      ref.read(guestOrdersProvider.notifier).state = [
        GuestOrder(
            number: order.number,
            createdAt: order.createdAt,
            totalXof: order.totalXof,
            phone: phone,
            status: order.status),
        ...ref.read(guestOrdersProvider),
      ].take(30).toList();
    }
    ref.invalidate(cartProvider);
    ref.invalidate(ordersProvider);
    invalidatePoints(ref);
    ref.invalidate(myGiftCardsProvider);
    return order;
  }
}

final checkoutActionsProvider =
    Provider<CheckoutActions>((ref) => CheckoutActions(ref));
