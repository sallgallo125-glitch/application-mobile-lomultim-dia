import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../contracts/product.dart';
import '../persistence.dart';

/// Favourite product ids, kept on the device between launches.
final favoriteIdsProvider = StateProvider<Set<String>>((ref) {
  const key = 'favorite_ids';
  ref.listenSelf((_, next) => writeStored(ref, key, next.toList()));
  return readStored(
          ref, key, (json) => (json as List<dynamic>).cast<String>().toSet()) ??
      <String>{};
});
final notificationsProvider =
    StateProvider<List<({String title, String message, bool read})>>((ref) => [
          (
            title: 'Ventes flash',
            message: 'De nouvelles promotions sont disponibles.',
            read: false
          ),
          (
            title: 'Commande LO-2026-00142',
            message: 'Votre commande est en préparation.',
            read: false
          ),
          (title: 'Lo+', message: 'Vous avez gagné 20 points.', read: true),
        ]);
final chatMessagesProvider = StateProvider<List<({bool mine, String text})>>(
    (ref) => [
          (
            mine: false,
            text: 'Bonjour, je suis Arame. Comment puis-je vous aider ?'
          )
        ]);
final savTicketsProvider =
    StateProvider<List<({String number, String product, String status})>>(
        (ref) => [
              (
                number: 'SAV-2026-042',
                product: 'Galaxy S24',
                status: 'Diagnostic en cours'
              )
            ]);
final favoriteProductsProvider =
    Provider<List<ProductSummary>>((ref) => const []);

/// Products the customer opened, most recent first (max 12), kept on the
/// device between launches.
final recentlyViewedProvider = StateProvider<List<String>>((ref) {
  const key = 'recently_viewed';
  ref.listenSelf((_, next) => writeStored(ref, key, next));
  return readStored(
          ref, key, (json) => (json as List<dynamic>).cast<String>()) ??
      const <String>[];
});

/// Searches the customer ran, most recent first (max 6), kept on the device.
final recentSearchesProvider = StateProvider<List<String>>((ref) {
  const key = 'recent_searches';
  ref.listenSelf((_, next) => writeStored(ref, key, next));
  return readStored(
          ref, key, (json) => (json as List<dynamic>).cast<String>()) ??
      const <String>[];
});

/// Records [query] as the latest search.
void rememberSearch(WidgetRef ref, String query) {
  final q = query.trim();
  if (q.length < 2) return;
  final list = ref.read(recentSearchesProvider);
  ref.read(recentSearchesProvider.notifier).state = [
    q,
    ...list.where((s) => s.toLowerCase() != q.toLowerCase()),
  ].take(6).toList();
}

/// Records [productId] as just viewed.
void markViewed(WidgetRef ref, String productId) {
  final list = ref.read(recentlyViewedProvider);
  if (list.isNotEmpty && list.first == productId) return;
  ref.read(recentlyViewedProvider.notifier).state =
      [productId, ...list.where((id) => id != productId)].take(12).toList();
}
