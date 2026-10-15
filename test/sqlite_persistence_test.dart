import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/api/api_client.dart';
import 'package:mobile_app/api/repositories/account_repository.dart';
import 'package:mobile_app/api/repositories/cart_repository.dart';
import 'package:mobile_app/api/repositories/checkout_repository.dart';
import 'package:mobile_app/features/account/account_providers.dart';
import 'package:mobile_app/features/persistence.dart';
import 'package:mobile_app/mocks/mock_http_client.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late SqliteLocalPersistence persistence;
  late String databasePath;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lo-sqlite-test-');
    databasePath = p.join(directory.path, 'test.sqlite');
    persistence =
        await SqliteLocalPersistence.openWith(databaseFactoryFfi, databasePath);
  });

  tearDown(() async {
    await persistence.close();
    await directory.delete(recursive: true);
  });

  test('comptes et préférences survivent à une réouverture SQLite', () async {
    final firstLaunch = ProviderContainer(overrides: [
      localPersistenceProvider.overrideWithValue(persistence),
    ]);
    firstLaunch.read(registeredAccountsProvider.notifier).state = [
      const RegisteredAccount(
        firstName: 'Moussa',
        lastName: 'Ndiaye',
        email: 'moussa@example.com',
        phone: '76 123 45 67',
        address: 'Médina, Dakar',
        password: 'local-test-password',
      )
    ];
    firstLaunch.read(sessionUserProvider.notifier).state =
        const SessionUser(name: 'Moussa Ndiaye', phone: '76 123 45 67');
    await persistence.write('favorite_ids', jsonEncode(['p-001', 'p-003']));

    await persistence.close();
    persistence =
        await SqliteLocalPersistence.openWith(databaseFactoryFfi, databasePath);

    final afterRestart = ProviderContainer(overrides: [
      localPersistenceProvider.overrideWithValue(persistence),
    ]);
    expect(afterRestart.read(sessionUserProvider)?.name, 'Moussa Ndiaye');
    expect(
      findAccount(afterRestart.read(registeredAccountsProvider),
              'moussa@example.com', 'local-test-password')
          ?.fullName,
      'Moussa Ndiaye',
    );
    expect(jsonDecode(persistence.read('favorite_ids')!), ['p-001', 'p-003']);
    firstLaunch.dispose();
    afterRestart.dispose();
  });

  test('migre les anciennes préférences vers SQLite une seule fois', () async {
    SharedPreferences.setMockInitialValues({
      'session_user': jsonEncode({'name': 'Aissatou', 'phone': '771234567'}),
    });
    final preferences = await SharedPreferences.getInstance();

    await persistence.migrateFrom(preferences);

    expect(
      jsonDecode(persistence.read('session_user')!),
      {'name': 'Aissatou', 'phone': '771234567'},
    );
    expect(preferences.getString('session_user'), isNull);
  });

  test('panier et commandes mockées survivent aux redémarrages du client',
      () async {
    final firstApi =
        ApiClient(client: MockHttpClient(persistence: persistence));
    final firstCart = CartRepository(firstApi);
    await firstCart.addItem('p-005');
    await firstApi.post('/api/v1/loyalty/me/conversions', {
      'rewardId': 'CAT-001',
      'points': 50,
    });

    await persistence.close();
    persistence =
        await SqliteLocalPersistence.openWith(databaseFactoryFfi, databasePath);
    final resumedApi =
        ApiClient(client: MockHttpClient(persistence: persistence));
    final persistedCart = await CartRepository(resumedApi).getCart();
    expect(persistedCart.items.single.productId, 'p-005');

    final order = await CheckoutRepository(resumedApi).createOrder(
      guest: false,
      deliveryMethod: 'PICKUP',
      zoneId: 'dakar-centre',
      payment: 'CASH_ON_DELIVERY',
      name: 'Moussa Ndiaye',
      phone: '761234567',
    );

    await persistence.close();
    persistence =
        await SqliteLocalPersistence.openWith(databaseFactoryFfi, databasePath);
    final restartedApi =
        ApiClient(client: MockHttpClient(persistence: persistence));

    final orders = await AccountRepository(restartedApi).listOrders();
    final cart = await CartRepository(restartedApi).getCart();
    final loyalty =
        await restartedApi.get('/api/v1/loyalty/me') as Map<String, dynamic>;
    expect(orders.any((saved) => saved.number == order.number), isTrue);
    expect(cart.items, isEmpty);
    expect((loyalty['data'] as Map<String, dynamic>)['points'], 28);
  });
}
