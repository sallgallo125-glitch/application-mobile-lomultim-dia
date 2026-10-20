import '../../contracts/home.dart';
import '../api_client.dart';
import '../errors.dart';

/// Mirrors ../mobile-app/src/api/repositories/homeRepository.ts
class HomeRepository {
  HomeRepository(this._apiClient);

  final ApiClient _apiClient;

  static const _path = '/api/v1/home';

  /// Banners and home sections, cached 30 min (see [ApiClient.getCached]).
  Future<HomeContent> getHomeContent({void Function()? onRefreshed}) async {
    final raw = await _apiClient.getCached(_path,
        maxAge: const Duration(minutes: 30), onRefreshed: onRefreshed);

    if (raw is! Map<String, dynamic> || raw['data'] is! Map<String, dynamic>) {
      throw ApiParseError(_path, 'expected {"data": {...}}, got $raw');
    }

    try {
      return HomeContent.fromJson(raw['data'] as Map<String, dynamic>);
    } catch (error) {
      throw ApiParseError(_path, error);
    }
  }
}
