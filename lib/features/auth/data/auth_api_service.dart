import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase를 이용한 인증 관련 API 서비스
///
/// 이메일 OTP(인증번호) 발송 및 검증 등의 데이터 통신을 담당합니다.
class AuthApiService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// 이메일로 6자리 랜덤 인증번호를 전송하는 API
  ///
  /// [email] 사용자 이메일 주소
  /// Supabase의 `signInWithOtp`를 호출하면 Supabase 서버에서
  /// 자동으로 6자리 랜덤 코드를 생성하여 해당 이메일로 전송합니다.
  Future<void> sendEmailOtp({required String email}) async {
    try {
      await _supabase.auth.signInWithOtp(
        email: email,
      );
    } catch (e) {
      // 에러 발생 시 처리 (필요에 따라 커스텀 예외로 변환 가능)
      throw Exception('인증번호 전송 실패: $e');
    }
  }

  /// 사용자가 입력한 6자리 인증번호를 확인하는 API
  ///
  /// [email] 인증을 요청했던 이메일 주소
  /// [otpCode] 이메일로 수신한 6자리 인증번호
  ///
  /// 인증 성공 시 [AuthResponse]를 반환하게 되며, 내부적으로 세션이 생성됩니다.
  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String otpCode,
  }) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        type: OtpType.email,
        token: otpCode,
        email: email,
      );

      // 세션이 null이면 인증 실패로 간주
      if (response.session == null) {
        throw Exception('올바르지 않은 인증번호이거나 만료되었습니다.');
      }

      return response;
    } catch (e) {
      throw Exception('인증 확인 실패: $e');
    }
  }
}
