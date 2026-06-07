import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_colors.dart';

/// 개인정보처리방침 정적 페이지.
///
/// 운영자 정보(회사명/주소/책임자/연락처)는 `{...}` 플레이스홀더로 표기되어 있으며,
/// 정식 출시 전 실제 정보로 교체해야 한다.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const String _effectiveDate = '2026-05-22';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '개인정보처리방침',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: DefaultTextStyle(
          style: TextStyle(
            color: textPrimary,
            fontSize: 14,
            height: 1.6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '시행일: $_effectiveDate',
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
              const SizedBox(height: 16),
              const Text(
                '김호정(이하 "운영자")는 「개인정보 보호법」 등 관련 법령을 준수하여 '
                '이용자의 개인정보를 안전하게 처리하기 위해 본 개인정보처리방침을 마련합니다.',
              ),
              const SizedBox(height: 24),
              _section(
                isDark,
                title: '1. 수집하는 개인정보 항목',
                bullets: const [
                  '필수: 이메일 주소, 비밀번호(단방향 암호화), 닉네임',
                  '선택: 전화번호, 프로필 이미지',
                  '서비스 이용 과정 자동 수집: 게임 점수·플레이 일자·위치(볼링장명), 시리즈 기록, 클럽 가입/활동 내역, 기기 식별자, FCM 토큰, OS/앱 버전, 오류 로그',
                ],
              ),
              _section(
                isDark,
                title: '2. 개인정보 수집 및 이용 목적',
                bullets: const [
                  '회원 식별 및 로그인 인증',
                  '볼링 점수·통계·랭킹 산출 및 표시',
                  '클럽 가입 신청 및 멤버 관리, 클럽 게임 알림',
                  '서비스 이용 관련 푸시 알림(베스트 갱신, 배지 획득 등)',
                  '오류 진단 및 서비스 품질 개선',
                  '문의 응대 및 분쟁 처리',
                ],
              ),
              _section(
                isDark,
                title: '3. 개인정보의 보유 및 이용 기간',
                bullets: const [
                  '회원 탈퇴 시 또는 보유 목적 달성 시 지체 없이 파기',
                  '관련 법령에 따라 일정 기간 보관이 필요한 경우 해당 기간 동안 보관 (예: 「전자상거래 등에서의 소비자보호에 관한 법률」에 따른 계약/청약철회·대금결제·소비자 불만 또는 분쟁처리에 관한 기록 등)',
                ],
              ),
              _section(
                isDark,
                title: '4. 개인정보의 제3자 제공',
                bullets: const [
                  '운영자는 이용자의 개인정보를 본 방침에서 명시한 범위를 넘어 제3자에게 제공하지 않습니다.',
                  '법령에 의거하거나 수사 목적으로 적법한 절차에 따라 요구되는 경우 예외로 합니다.',
                ],
              ),
              _section(
                isDark,
                title: '5. 개인정보 처리의 위탁',
                bullets: const [
                  'Google LLC (Firebase Cloud Messaging) — 푸시 알림 전송',
                  'Functional Software, Inc. (Sentry) — 오류 진단 로그 수집',
                  '각 수탁사는 위탁 업무 수행 목적 이외에 개인정보를 이용하지 않으며, 운영자는 수탁사가 정한 개인정보 보호 약관을 준수합니다.',
                ],
              ),
              _section(
                isDark,
                title: '6. 이용자 및 법정대리인의 권리',
                bullets: const [
                  '이용자는 언제든지 본인의 개인정보 열람·정정·삭제·처리정지를 요청할 수 있습니다.',
                  '계정 삭제는 앱 내 설정 또는 운영자 이메일로 요청할 수 있으며, 운영자는 지체 없이 처리합니다.',
                ],
              ),
              _section(
                isDark,
                title: '7. 개인정보의 안전성 확보 조치',
                bullets: const [
                  '비밀번호는 단방향 암호화하여 저장',
                  '전송 구간 HTTPS 암호화',
                  '서버 접근 권한 최소화 및 접근 기록 보관',
                  '주기적인 보안 점검 및 취약점 패치',
                ],
              ),
              _section(
                isDark,
                title: '8. 자동 수집 장치(쿠키 등)',
                bullets: const [
                  '본 앱은 웹 쿠키를 사용하지 않습니다.',
                  '단, 푸시 알림 전송을 위해 기기별 FCM 토큰을 수집·저장하며, 이용자는 앱 알림 권한을 통해 거부할 수 있습니다.',
                ],
              ),
              _section(
                isDark,
                title: '9. 개인정보 보호책임자 및 문의',
                bullets: const [
                  '책임자: 김호정',
                  '연락처: dev.hojung@gmail.com',
                ],
              ),
              _section(
                isDark,
                title: '10. 고지의 의무',
                bullets: const [
                  '본 방침의 내용 추가·삭제·수정이 있을 경우, 시행 7일 전부터 앱 내 공지 또는 푸시 알림을 통해 사전 안내합니다.',
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _section(bool isDark,
      {required String title, required List<String> bullets}) {
    final subColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: subColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(child: Text(b)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
