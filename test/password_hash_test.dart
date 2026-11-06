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
}
