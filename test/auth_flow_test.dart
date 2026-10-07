import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/account/account_providers.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/navigation/app_router.dart';

/// Sign-up with the 7 fields, then sign-in by e-mail and by phone.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Finder field(String hint) => find.widgetWithText(TextFormField, hint);

  testWidgets('inscription puis connexion', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const LoMultimediaApp(useGoogleFonts: false)));

    appRouter.go('/inscription');
    await settle(tester);
    await tester.tap(find.text("S'inscrire").last);
    await settle(tester);
    expect(find.text('Indiquez votre prénom.'), findsOneWidget);

    await tester.enterText(field('Prénom'), 'Moussa');
    await tester.enterText(field('Nom'), 'Ndiaye');
    await tester.enterText(field('Email'), 'moussa@example.com');
    await tester.enterText(field('Téléphone'), '76 123 45 67');
    await tester.enterText(field('Adresse'), 'Médina, Dakar');
    await tester.enterText(field('Mot de passe'), 'secret1');
    await tester.enterText(field('Confirmer le mot de passe'), 'autre');
    await tester.tap(find.text("S'inscrire").last);
    await settle(tester);
    expect(find.text('Les mots de passe ne correspondent pas.'), findsOneWidget);

    await tester.enterText(field('Confirmer le mot de passe'), 'secret1');
    await tester.tap(find.text("S'inscrire").last);
    await settle(tester);
    expect(container.read(sessionUserProvider)?.name, 'Moussa Ndiaye');

    // Sign out, then sign in with the phone number.
    container.read(sessionUserProvider.notifier).state = null;
    appRouter.go('/connexion');
    await settle(tester);
    await tester.enterText(field('Email ou téléphone'), '761234567');
    await tester.enterText(field('Mot de passe'), 'mauvais');
    await tester.tap(find.text('Se connecter').last);
    await settle(tester);
    expect(find.textContaining('incorrect'), findsOneWidget);
    await tester.enterText(field('Mot de passe'), 'secret1');
    await tester.tap(find.text('Se connecter').last);
    await settle(tester);
    expect(container.read(sessionUserProvider)?.name, 'Moussa Ndiaye');

    // Demo account by e-mail.
    container.read(sessionUserProvider.notifier).state = null;
    appRouter.go('/connexion');
    await settle(tester);
    await tester.enterText(field('Email ou téléphone'), 'demo@lomultimedia.com');
    await tester.enterText(field('Mot de passe'), 'lo123456');
    await tester.tap(find.text('Se connecter').last);
    await settle(tester);
    expect(container.read(sessionUserProvider)?.name, 'Aïssatou Diop');

    appRouter.go('/');
    await settle(tester);
  });
}
