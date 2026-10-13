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
final httpClientProvider = Provider<http.Client>(
    (ref) => MockHttpClient(persistence: ref.watch(localPersistenceProvider)));

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(client: ref.watch(httpClientProvider));
});

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(apiClientProvider));
});

final homeContentProvider = FutureProvider<HomeContent>((ref) {
  return ref.watch(homeRepositoryProvider).getHomeContent();
});

final globalSearchQueryProvider = StateProvider<String>((ref) => '');
