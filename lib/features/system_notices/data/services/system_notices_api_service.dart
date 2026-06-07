import '../../../../core/services/api_client.dart';
import '../models/system_notice.dart';

class SystemNoticesApiService {
  final ApiClient _apiClient = ApiClient();

  Future<List<SystemNotice>> fetchActive() async {
    final res = await _apiClient.dio.get('/system-notices/active');
    final data = res.data;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => SystemNotice.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
