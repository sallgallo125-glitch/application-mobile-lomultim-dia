import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../api/api_client.dart';
import '../../api/repositories/home_repository.dart';
import '../../contracts/home.dart';
import '../../mocks/mock_http_client.dart';
import '../persistence.dart';

/// route -> screen -> feature hook (provider) -> repository -> apiClient -> mock
/// mirrors the RN app's mandatory layering (see DEVELOPMENT_RULES.md); a
/// screen must never call ApiClient or the mock transport directly.
/// Real backend root, set at build time:
/// `flutter run --dart-define=API_BASE_URL=https://api.lomultimedia.com`.
/// Empty (default) keeps the in-app mock backend.
const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

final httpClientProvider = Provider<http.Client>((ref) => apiBaseUrl.isEmpty
    ? MockHttpClient(persistence: ref.watch(localPersistenceProvider))
    : http.Client());

final apiClientProvider = Provider<ApiClient>((ref) {
  assert(apiBaseUrl.isEmpty || apiBaseUrl.startsWith('https://'),
      'API_BASE_URL must use HTTPS');
  return ApiClient(
      client: ref.watch(httpClientProvider),
      baseUrl: apiBaseUrl.isEmpty ? 'http://mock.lo.local' : apiBaseUrl,
      cache: ref.watch(localPersistenceProvider));
});

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(apiClientProvider));
});

final homeContentProvider = FutureProvider<HomeContent>((ref) {
  return ref
      .watch(homeRepositoryProvider)
      .getHomeContent(onRefreshed: ref.invalidateSelf);
});

final globalSearchQueryProvider = StateProvider<String>((ref) => '');
