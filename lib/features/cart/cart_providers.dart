import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/repositories/cart_repository.dart';
import '../../contracts/cart.dart';
import '../home/home_providers.dart';

final cartRepositoryProvider = Provider<CartRepository>(
    (ref) => CartRepository(ref.watch(apiClientProvider)));
final cartProvider =
    FutureProvider<Cart>((ref) => ref.watch(cartRepositoryProvider).getCart());

class CartActions {
  CartActions(this.ref);
  final Ref ref;
  Future<void> add(String id,
      {String? variantId,
      Iterable<String> addonIds = const [],
      Map<String, String> options = const {},
      int quantity = 1}) async {
    await ref.read(cartRepositoryProvider).addItem(id,
        variantId: variantId,
        addonIds: addonIds,
        options: options,
        quantity: quantity);
    ref.invalidate(cartProvider);
  }

  Future<void> update(String id, int quantity) async {
    await ref.read(cartRepositoryProvider).updateItem(id, quantity);
    ref.invalidate(cartProvider);
  }

  Future<void> remove(String id) async {
    await ref.read(cartRepositoryProvider).removeItem(id);
    ref.invalidate(cartProvider);
  }
}

final cartActionsProvider = Provider<CartActions>((ref) => CartActions(ref));
