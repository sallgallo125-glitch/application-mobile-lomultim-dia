import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/account/account_providers.dart';
import 'package:mobile_app/features/cart/cart_providers.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/navigation/app_router.dart';

/// Renders every screen on small phones through tablets, with enlarged text,
/// scrolls each one (and its horizontal rails) to the end so content below
/// the fold is built too, and fails listing every RenderFlex overflow.
void main() {
  const sizes = {
    'iPhone SE 1': Size(320, 568),
    'Galaxy A 360': Size(360, 780),
    'iPhone 14': Size(390, 844),
    'Pixel 412': Size(412, 915),
    'Pro Max 430': Size(430, 932),
    'paysage': Size(844, 390),
    'tablette': Size(768, 1024),
    'grande tablette': Size(1280, 800),
  };
  const routes = [
    '/',
    '/boutique',
    '/panier',
    '/lo',
    '/compte',
    '/produit/p-001',
    '/produit/p-010',
    '/produit/p-030',
    '/produit/p-200',
    '/produit/p-213',
    '/commande/paiement',
    '/commandes',
    '/commandes/LO-2026-00142',
    '/commandes/LO-2026-00118',
    '/mes-codes',
    '/mes-codes/dc-1',
    '/mes-codes/dc-3',
    '/mes-codes/dc-5',
    '/connexion',
    '/inscription',
    '/recherche',
    '/favoris',
    '/sav',
    '/showrooms',
    '/notifications',
    '/chat',
    '/lo/carte',
    '/lo/historique',
    '/lo/parrainage',
    '/compte/infos',
    '/carte-cadeau',
    '/cartes-cadeaux',
    '/faq',
    '/contact',
    '/legal',
    '/suivi',
    '/legal/livraison',
    '/legal/garantie',
  ];
  final found = <String>{};

  for (final entry in sizes.entries) {
    for (final textScale in [1.0, 1.3, 2.0]) {
      testWidgets('${entry.key} x$textScale', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        var route = '';
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          final text = details.toString();
          final what = RegExp(r'overflowed by [0-9.]+ pixels on the \w+')
                  .firstMatch(text)
                  ?.group(0) ??
              text.split('\n').first;
          final where =
              RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(text)?.group(0) ?? '?';
          found.add('$where | $what | $route | ${entry.key} x$textScale');
        };
        addTearDown(() => FlutterError.onError = previous);

        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(sessionUserProvider.notifier).state =
            const SessionUser(name: 'Aissatou Diop', phone: '76 621 11 11');
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: const LoMultimediaApp(useGoogleFonts: false)));
        await tester
            .runAsync(() => container.read(cartActionsProvider).add('p-001'));

        for (final r in routes) {
          route = r;
          appRouter.go(r);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          // Scroll every scrollable to its end, step by step, so content
          // below the fold is built too.
          for (var pass = 0; pass < 2; pass++) {
            final states = tester
                .stateList<ScrollableState>(find.byType(Scrollable))
                .toList();
            for (final s in states) {
              if (!s.mounted || !s.position.hasContentDimensions) continue;
              final p = s.position;
              var guard = 0;
              while (p.pixels < p.maxScrollExtent && guard++ < 40) {
                p.jumpTo((p.pixels + p.viewportDimension * .8)
                    .clamp(0, p.maxScrollExtent));
                await tester.pump(const Duration(milliseconds: 50));
                if (!s.mounted) break;
              }
            }
          }
          await tester.pump(const Duration(seconds: 1));
        }
        appRouter.go('/');
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
  tearDownAll(() {
    // file:line | overflow | route | device
    expect(found.toList()..sort(), isEmpty);
  });
}
