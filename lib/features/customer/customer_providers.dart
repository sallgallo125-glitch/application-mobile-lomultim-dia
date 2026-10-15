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
/// One in-app notification. [link] is the route opened when it is tapped.
typedef AppNotification = ({
  String title,
  String message,
  bool read,
  DateTime date,
  String? link,
});

final notificationsProvider = StateProvider<List<AppNotification>>((ref) {
  const key = 'notifications';
  ref.listenSelf((_, next) => writeStored(ref, key, [
        for (final item in next)
          {
            'title': item.title,
            'message': item.message,
            'read': item.read,
            'date': item.date.toIso8601String(),
            'link': item.link,
          }
      ]));
  final now = DateTime.now();
  return readStored(ref, key, (json) {
        final rows = json as List<dynamic>;
        return [
          for (final value in rows)
            (
              title: (value as Map<String, dynamic>)['title'] as String,
              message: value['message'] as String,
              read: value['read'] as bool,
              date: DateTime.tryParse(value['date'] as String? ?? '') ?? now,
              link: value['link'] as String?,
            )
        ];
      }) ??
      [
        (
          title: 'Ventes flash',
          message: 'De nouvelles promotions sont disponibles.',
          read: false,
          date: now.subtract(const Duration(hours: 2)),
          link: '/boutique',
        ),
        (
          title: 'Commande LO-2026-00142',
          message: 'Votre commande est en préparation.',
          read: false,
          date: now.subtract(const Duration(days: 1, hours: 3)),
          link: '/commandes',
        ),
        (
          title: 'Lo+',
          message: 'Vous avez gagné 20 points.',
          read: true,
          date: now.subtract(const Duration(days: 9)),
          link: '/lo',
        ),
      ];
});

/// Notification kinds the customer chose to receive ('order', 'loyalty',
/// 'promo', 'info'), kept on the device.
final notificationPrefsProvider = StateProvider<Set<String>>((ref) {
  const key = 'notification_prefs';
  ref.listenSelf((_, next) => writeStored(ref, key, next.toList()));
  return readStored(
          ref, key, (json) => (json as List<dynamic>).cast<String>().toSet()) ??
      {'order', 'loyalty', 'promo', 'info'};
});
final chatMessagesProvider =
    StateProvider<List<({bool mine, String text})>>((ref) {
  const key = 'chat_messages';
  ref.listenSelf((_, next) => writeStored(ref, key, [
        for (final item in next) {'mine': item.mine, 'text': item.text}
      ]));
  return readStored(ref, key, (json) {
        final rows = json as List<dynamic>;
        return [
          for (final value in rows)
            (
              mine: (value as Map<String, dynamic>)['mine'] as bool,
              text: value['text'] as String,
            )
        ];
      }) ??
      [
        (
          mine: false,
          text: 'Bonjour, je suis Arame. Comment puis-je vous aider ?'
        )
      ];
});
final savTicketsProvider =
    StateProvider<List<({String number, String product, String status})>>(
        (ref) {
  const key = 'sav_tickets';
  ref.listenSelf((_, next) => writeStored(ref, key, [
        for (final item in next)
          {
            'number': item.number,
            'product': item.product,
            'status': item.status,
          }
      ]));
  return readStored(ref, key, (json) {
        final rows = json as List<dynamic>;
        return [
          for (final value in rows)
            (
              number: (value as Map<String, dynamic>)['number'] as String,
              product: value['product'] as String,
              status: value['status'] as String,
            )
        ];
      }) ??
      [
        (
          number: 'SAV-2026-042',
          product: 'Galaxy S24',
          status: 'Diagnostic en cours'
        )
      ];
});
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
