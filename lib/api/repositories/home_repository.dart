import '../../contracts/home.dart';
import '../api_client.dart';
import '../errors.dart';

/// Mirrors ../mobile-app/src/api/repositories/homeRepository.ts
class HomeRepository {
  HomeRepository(this._apiClient);

  final ApiClient _apiClient;

  static const _path = '/api/v1/home';

  Future<HomeContent> getHomeContent() async {
    final raw = await _apiClient.get(_path);

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
