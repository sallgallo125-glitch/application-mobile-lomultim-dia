import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/account/account_providers.dart';
import 'package:mobile_app/features/cart/cart_providers.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/navigation/app_router.dart';

/// Renders every screen on small phones through tablets, with enlarged text,
/// and fails on any RenderFlex overflow.
void main() {
  const sizes = {
    'petit téléphone': Size(320, 568),
    'téléphone': Size(360, 740),
    'grand téléphone': Size(412, 915),
    'paysage': Size(915, 412),
    'tablette': Size(800, 1280),
    'grande tablette': Size(1280, 800),
  };
  const routes = [
    '/', '/boutique', '/panier', '/lo', '/compte', '/produit/p-001',
    '/commande/paiement', '/commandes', '/connexion', '/inscription', '/favoris', '/sav',
    '/showrooms', '/notifications', '/chat',
    '/lo/carte', '/lo/historique', '/lo/echanger', '/lo/parrainage',
    '/lo/defis', '/carte-cadeau', '/cartes-cadeaux', '/suivi', '/faq',
    '/contact', '/recherche', '/legal', '/legal/livraison', '/legal/garantie',
  ];

  for (final entry in sizes.entries) {
    for (final textScale in [1.0, 1.3]) {
      testWidgets('${entry.key} ${entry.value} texte x$textScale',
          (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = textScale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(sessionUserProvider.notifier).state =
            const SessionUser(name: 'Aissatou Diop', phone: '76 621 11 11');

        await tester.pumpWidget(UncontrolledProviderScope(
            container: container, child: const LoMultimediaApp(useGoogleFonts: false)));
        await tester.runAsync(
            () => container.read(cartActionsProvider).add('p-001'));

        for (final route in routes) {
          appRouter.go(route);
          // Loading skeleton, then content (mock latency is 350 ms).
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull, reason: route);
        }
        appRouter.go('/');
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
