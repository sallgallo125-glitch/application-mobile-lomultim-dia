import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/account/account_providers.dart';
import 'package:mobile_app/features/biometric/biometric_providers.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/navigation/app_router.dart';
import 'package:mobile_app/screens/digital_codes_screen.dart'
    show DigitalCodeTile;

class FakeAuthenticator implements BiometricAuthenticator {
  FakeAuthenticator({this.capable = true});
  bool capable;
  bool allow = true;
  int calls = 0;

  @override
  Future<bool> canAuthenticate() async => capable;

  @override
  Future<bool> authenticate({required String reason}) async {
    calls++;
    return allow;
  }
}

class FakeStore implements SecureKeyValueStore {
  final _values = <String, String?>{};
  Map<String, String?> get values => _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }
}

/// Quick sign-in toggle (Compte), refused then accepted quick login,
/// and the lock state of the digital codes screens.
void main() {
  late FakeAuthenticator authenticator;
  late FakeStore store;
  late ProviderContainer container;

  setUp(() {
    authenticator = FakeAuthenticator();
    store = FakeStore();
    container = ProviderContainer(overrides: [
      biometricAuthenticatorProvider.overrideWithValue(authenticator),
      secureStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  Widget app(WidgetTester tester) {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return UncontrolledProviderScope(
        container: container,
        child: const LoMultimediaApp(useGoogleFonts: false));
  }

  const session = SessionUser(name: 'Aissatou Diop', phone: '77 123 45 67');

  test('enable refuse: rien ne sont enregistré sans validation biométrique',
      () async {
    authenticator.allow = false;
    final ok = await container.read(biometricActionsProvider).enable(session);
    expect(ok, isFalse);
    expect(store.values, isEmpty);
  });

  test('refreshStoredLogin sans activation ne sauvegarde rien', () async {
    await container.read(biometricActionsProvider).refreshStoredLogin(session);
    expect(store.values, isEmpty);
  });

  test("refreshStoredLogin ne remplace pas le compte d'un autre utilisateur",
      () async {
    final actions = container.read(biometricActionsProvider);
    expect(await actions.enable(session), isTrue);
    await actions.refreshStoredLogin(
        const SessionUser(name: 'Moussa Ndiaye', phone: '78 000 00 00'));
    expect(store.values['biometric_session'], contains('Aissatou Diop'));
    expect(store.values['biometric_session'], isNot(contains('Moussa')));
  });

  testWidgets('Connexion rapide : activation, refus, puis connexion',
      (tester) async {
    await tester.pumpWidget(app(tester));
    container.read(sessionUserProvider.notifier).state = session;
    appRouter.go('/compte');
    await settle(tester);

    expect(find.textContaining('Face ID / empreinte'), findsOneWidget);
    expect(find.text('Désactivée'), findsOneWidget);

    await tester.tap(find.textContaining('Face ID / empreinte'));
    await settle(tester);

    expect(find.text('Activée'), findsOneWidget);
    expect(authenticator.calls, 1);
    expect(store.values['biometric_session'], contains('Aissatou Diop'));

    // Signed out: the quick button appears on the login page.
    container.read(sessionUserProvider.notifier).state = null;
    appRouter.go('/connexion');
    await settle(tester);
    final button = find.text('Se connecter avec Face ID / empreinte');
    expect(button, findsOneWidget);

    authenticator.allow = false;
    await tester.tap(button);
    await settle(tester);
    expect(find.textContaining('Authentification refusée'), findsOneWidget);
    expect(container.read(sessionUserProvider), isNull);

    authenticator.allow = true;
    await tester.tap(button);
    await settle(tester);
    expect(container.read(sessionUserProvider)?.name, 'Aissatou Diop');

    // Disabling from Compte clears the saved identity.
    appRouter.go('/compte');
    await settle(tester);
    await tester.tap(find.textContaining('Face ID / empreinte'));
    await settle(tester);
    expect(find.text('Désactivée'), findsOneWidget);
    expect(store.values['biometric_session'], isNull);

    // Without a saved login the quick button disappears.
    container.read(sessionUserProvider.notifier).state = null;
    appRouter.go('/connexion');
    await settle(tester);
    expect(find.text('Se connecter avec Face ID / empreinte'), findsNothing);
  });

  testWidgets('Mes codes : liste libre, détail verrouillé puis déverrouillé',
      (tester) async {
    await tester.pumpWidget(app(tester));
    container.read(sessionUserProvider.notifier).state = session;
    final ok = await container.read(biometricActionsProvider).enable(session);
    expect(ok, isTrue);
    final callsAfterEnable = authenticator.calls;

    authenticator.allow = false;
    appRouter.go('/mes-codes');
    await settle(tester);

    // The list shows no code: no prompt there.
    expect(find.byType(DigitalCodeTile), findsWidgets);
    expect(authenticator.calls, callsAfterEnable);

    await tester.tap(find.byType(DigitalCodeTile).first);
    await settle(tester);
    expect(find.text('Contenu protégé'), findsOneWidget);
    expect(find.textContaining('Authentification refusée.'), findsOneWidget);

    authenticator.allow = true;
    await tester.tap(find.text('Déverrouiller'));
    await settle(tester);
    expect(find.text('Contenu protégé'), findsNothing);
  });

  test("la connexion rapide d'un autre compte ne s'applique pas à la session",
      () async {
    final actions = container.read(biometricActionsProvider);
    container.read(sessionUserProvider.notifier).state = session;
    expect(await actions.enable(session), isTrue);
    expect(
        await container.read(biometricEnabledForSessionProvider.future), isTrue);

    container.read(sessionUserProvider.notifier).state =
        const SessionUser(name: 'Moussa Ndiaye', phone: '78 000 00 00');
    expect(await container.read(biometricEnabledForSessionProvider.future),
        isFalse);
  });

  testWidgets('désactivation possible même sans biométrie disponible',
      (tester) async {
    await tester.pumpWidget(app(tester));
    container.read(sessionUserProvider.notifier).state = session;
    expect(await container.read(biometricActionsProvider).enable(session),
        isTrue);

    authenticator.capable = false;
    container.invalidate(biometricAvailableProvider);
    appRouter.go('/compte');
    await settle(tester);
    expect(find.text('Activée'), findsOneWidget);

    await tester.tap(find.textContaining('Face ID / empreinte'));
    await settle(tester);
    expect(store.values['biometric_session'], isNull);
    expect(find.text('Indisponible'), findsOneWidget);
  });
}
