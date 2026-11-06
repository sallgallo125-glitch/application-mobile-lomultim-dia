import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/account/account_providers.dart';

void main() {
  test('le mot de passe stocké est haché, salé et vérifiable', () {
    final a = hashPassword('secret123');
    final b = hashPassword('secret123');
    expect(a, isNot(contains('secret123')));
    expect(a, isNot(b)); // different salt each time
    expect(verifyPassword(a, 'secret123'), isTrue);
    expect(verifyPassword(a, 'mauvais'), isFalse);
  });

  test(
      'les comptes enregistrés en clair par une ancienne version restent valides',
      () {
    expect(verifyPassword('ancien-mdp', 'ancien-mdp'), isTrue);
    expect(verifyPassword('ancien-mdp', 'autre'), isFalse);
  });

  test('connexion avec un compte au mot de passe haché', () {
    final account = RegisteredAccount(
        firstName: 'Moussa',
        lastName: 'Ndiaye',
        email: 'moussa@example.com',
        phone: '76 123 45 67',
        address: 'Médina, Dakar',
        password: hashPassword('pass1234'));
    expect(findAccount([account], 'moussa@example.com', 'pass1234'), account);
    expect(findAccount([account], '76 123 45 67', 'pass1234'), account);
    expect(findAccount([account], 'moussa@example.com', 'faux'), isNull);
  });

  test('format PBKDF2, rejet des valeurs corrompues', () {
    final h = hashPassword('secret123');
    expect(h, startsWith('pbkdf2\$$pbkdf2Iterations\$'));
    expect(needsRehash(h), isFalse);
    expect(needsRehash('ancien-mdp'), isTrue);
    expect(verifyPassword(r'pbkdf2$60000$%%%$@@@', 'x'), isFalse);
  });

  testWidgets('un ancien mot de passe en clair est re-haché à la connexion',
      (tester) async {
    const legacy = RegisteredAccount(
        firstName: 'Moussa',
        lastName: 'Ndiaye',
        email: 'moussa@example.com',
        phone: '76 123 45 67',
        address: 'Médina, Dakar',
        password: 'ancien-mdp');
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(registeredAccountsProvider.notifier).state = [legacy];
    late WidgetRef widgetRef;
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: Consumer(builder: (context, ref, _) {
          widgetRef = ref;
          return const SizedBox();
        })));

    final found = findAccount(container.read(registeredAccountsProvider),
        'moussa@example.com', 'ancien-mdp')!;
    upgradeStoredPassword(widgetRef, found, 'ancien-mdp');

    final stored = container.read(registeredAccountsProvider).single.password;
    expect(stored, startsWith('pbkdf2\$'));
    expect(verifyPassword(stored, 'ancien-mdp'), isTrue);
  });
}
