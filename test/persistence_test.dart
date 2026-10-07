import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/account/account_providers.dart';
import 'package:mobile_app/features/customer/customer_providers.dart';
import 'package:mobile_app/features/persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Session and favourites must survive an app restart (a new container
/// reading the same device storage).
void main() {
  test('session et favoris conservés après redémarrage', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer launch() => ProviderContainer(
        overrides: [preferencesProvider.overrideWithValue(prefs)]);

    final first = launch();
    first.read(sessionUserProvider.notifier).state =
        const SessionUser(name: 'Aissatou Diop', phone: '76 621 11 11');
    first.read(favoriteIdsProvider.notifier).state = {'p-001', 'p-008'};
    first.dispose();

    final second = launch();
    expect(second.read(sessionUserProvider)?.name, 'Aissatou Diop');
    expect(second.read(favoriteIdsProvider), {'p-001', 'p-008'});

    // Logging out is remembered too.
    second.read(sessionUserProvider.notifier).state = null;
    second.dispose();
    expect(launch().read(sessionUserProvider), isNull);
  });
}
