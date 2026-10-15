import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/boutique_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/account_screen.dart';
import '../screens/checkout_screen.dart';
import '../screens/confirmation_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/sav_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../screens/photo_search_screen.dart';
import '../screens/search_screen.dart';
import '../screens/showrooms_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/chat_screen.dart';
import '../contracts/account.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/loyalty_screen.dart';
import '../screens/order_detail_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/product_screen.dart';
import '../screens/gift_card_screens.dart';
import '../screens/info_screens.dart';
import '../screens/loyalty_member_screens.dart';
import 'main_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen())
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/boutique',
              builder: (context, state) => const BoutiqueScreen())
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/panier', builder: (context, state) => const CartScreen())
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/lo',
              builder: (context, state) => LoyaltyScreen(
                  // Opened from another tab (e.g. Compte): show a back arrow.
                  backTo: state.uri.queryParameters['from']))
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/compte',
              builder: (context, state) => const AccountScreen())
        ]),
      ],
    ),
    GoRoute(
      path: '/produit/:id',
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) =>
          // Keyed by product: going from one product to another builds a
          // fresh page (quantity, option, "recently viewed" all reset).
          ProductScreen(
              key: ValueKey(state.pathParameters['id']),
              productId: state.pathParameters['id']!),
    ),
    GoRoute(
        path: '/commande/paiement',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CheckoutScreen()),
    GoRoute(
        path: '/commande/confirmation',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            ConfirmationScreen(order: state.extra as OrderSummary?)),
    GoRoute(
        path: '/commandes',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OrdersScreen()),
    GoRoute(
        path: '/commandes/:number',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            OrderDetailScreen(number: state.pathParameters['number']!)),
    GoRoute(
        path: '/connexion',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LoginScreen()),
    GoRoute(
        path: '/inscription',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const RegisterScreen()),
    GoRoute(
        path: '/recherche/photo',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            PhotoSearchScreen(photo: state.extra as XFile?)),
    GoRoute(
        path: '/recherche',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SearchScreen()),
    GoRoute(
        path: '/favoris',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FavoritesScreen()),
    GoRoute(
        path: '/sav',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SavScreen()),
    GoRoute(
        path: '/showrooms',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ShowroomsScreen()),
    GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen()),
    GoRoute(
        path: '/chat',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ChatScreen()),
    GoRoute(
        path: '/lo/carte',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LoyaltyCardScreen()),
    GoRoute(
        path: '/lo/historique',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LoyaltyHistoryScreen()),
    GoRoute(
        path: '/lo/parrainage',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LoyaltyReferralScreen()),
    GoRoute(
        path: '/carte-cadeau',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const GiftCardScreen()),
    GoRoute(
        path: '/cartes-cadeaux',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MyGiftCardsScreen()),
    GoRoute(
        path: '/faq',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FaqScreen()),
    GoRoute(
        path: '/contact',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ContactScreen()),
    GoRoute(
        path: '/legal',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LegalIndexScreen()),
    GoRoute(
        path: '/suivi',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => TrackingScreen(
            initialOrderNumber: state.uri.queryParameters['commande'],
            initialPhone: state.uri.queryParameters['tel'])),
    GoRoute(
        path: '/legal/:slug',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            LegalScreen(slug: state.pathParameters['slug']!)),
  ],
);
