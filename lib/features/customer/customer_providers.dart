import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../contracts/product.dart';
import '../persistence.dart';

/// Favourite product ids, kept on the device between launches.
final favoriteIdsProvider =
    StateNotifierProvider<StateController<Set<String>>, Set<String>>((ref) {
  const key = 'favorite_ids';
  final controller = StateController<Set<String>>(readStored(
          ref, key, (json) => (json as List<dynamic>).cast<String>().toSet()) ??
      <String>{});
  controller.addListener((next) => writeStored(ref, key, next.toList()),
      fireImmediately: false);
  return controller;
});

/// One in-app notification. [link] is the route opened when it is tapped.
typedef AppNotification = ({
  String title,
  String message,
  bool read,
  DateTime date,
  String? link,
});

final notificationsProvider = StateNotifierProvider<
    StateController<List<AppNotification>>, List<AppNotification>>((ref) {
  const key = 'notifications';
  final now = DateTime.now();
  final controller =
      StateController<List<AppNotification>>(readStored(ref, key, (json) {
            final rows = json as List<dynamic>;
            return [
              for (final value in rows)
                (
                  title: (value as Map<String, dynamic>)['title'] as String,
                  message: value['message'] as String,
                  read: value['read'] as bool,
                  date:
                      DateTime.tryParse(value['date'] as String? ?? '') ?? now,
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
          ]);
  controller.addListener(
      (next) => writeStored(ref, key, [
            for (final item in next)
              {
                'title': item.title,
                'message': item.message,
                'read': item.read,
                'date': item.date.toIso8601String(),
                'link': item.link,
              }
          ]),
      fireImmediately: false);
  return controller;
});

/// Notification kinds the customer chose to receive ('order', 'loyalty',
/// 'promo', 'info'), kept on the device.
final notificationPrefsProvider =
    StateNotifierProvider<StateController<Set<String>>, Set<String>>((ref) {
  const key = 'notification_prefs';
  final controller = StateController<Set<String>>(readStored(
          ref, key, (json) => (json as List<dynamic>).cast<String>().toSet()) ??
      {'order', 'loyalty', 'promo', 'info'});
  controller.addListener((next) => writeStored(ref, key, next.toList()),
      fireImmediately: false);
  return controller;
});
final chatMessagesProvider = StateNotifierProvider<
    StateController<List<({bool mine, String text})>>,
    List<({bool mine, String text})>>((ref) {
  const key = 'chat_messages';
  final controller = StateController<List<({bool mine, String text})>>(
      readStored(ref, key, (json) {
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
          ]);
  controller.addListener(
      (next) => writeStored(ref, key, [
            for (final item in next) {'mine': item.mine, 'text': item.text}
          ]),
      fireImmediately: false);
  return controller;
});
final savTicketsProvider = StateNotifierProvider<
    StateController<List<({String number, String product, String status})>>,
    List<({String number, String product, String status})>>((ref) {
  const key = 'sav_tickets';
  final controller =
      StateController<List<({String number, String product, String status})>>(
          readStored(ref, key, (json) {
                final rows = json as List<dynamic>;
                return [
                  for (final value in rows)
                    (
                      number:
                          (value as Map<String, dynamic>)['number'] as String,
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
              ]);
  controller.addListener(
      (next) => writeStored(ref, key, [
            for (final item in next)
              {
                'number': item.number,
                'product': item.product,
                'status': item.status,
              }
          ]),
      fireImmediately: false);
  return controller;
});
final favoriteProductsProvider =
    Provider<List<ProductSummary>>((ref) => const []);

/// Products the customer opened, most recent first (max 12), kept on the
/// device between launches.
final recentlyViewedProvider =
    StateNotifierProvider<StateController<List<String>>, List<String>>((ref) {
  const key = 'recently_viewed';
  final controller = StateController<List<String>>(
      readStored(ref, key, (json) => (json as List<dynamic>).cast<String>()) ??
          const <String>[]);
  controller.addListener((next) => writeStored(ref, key, next),
      fireImmediately: false);
  return controller;
});

/// Searches the customer ran, most recent first (max 6), kept on the device.
final recentSearchesProvider =
    StateNotifierProvider<StateController<List<String>>, List<String>>((ref) {
  const key = 'recent_searches';
  final controller = StateController<List<String>>(
      readStored(ref, key, (json) => (json as List<dynamic>).cast<String>()) ??
          const <String>[]);
  controller.addListener((next) => writeStored(ref, key, next),
      fireImmediately: false);
  return controller;
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
