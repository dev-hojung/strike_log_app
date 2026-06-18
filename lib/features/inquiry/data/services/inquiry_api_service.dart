import '../../../../core/services/api_client.dart';

class InquiryApiService {
  final ApiClient _apiClient = ApiClient();

  /// POST /inquiries — 문의 제출
  Future<void> submit({
    required String category,
    required String subject,
    required String body,
    String? contactEmail,
  }) async {
    final payload = <String, dynamic>{
      'category': category,
      'subject': subject,
      'body': body,
    };
    if (contactEmail != null && contactEmail.isNotEmpty) {
      payload['contact_email'] = contactEmail;
    }
    await _apiClient.dio.post('/inquiries', data: payload);
  }
}
