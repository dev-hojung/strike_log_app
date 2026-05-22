import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../constants/app_colors.dart';
import '../errors/api_error.dart';

/// 페이지/섹션 내부에 인라인으로 표시하는 에러 + 재시도 UI.
///
/// - 에러 타입별로 아이콘과 강조 색상 자동 결정
/// - [onRetry]가 주어지고 [ApiError.isRetryable]가 true인 경우에만 재시도 버튼 노출
/// - [compact]를 켜면 작은 카드 형태(리스트 안에서 사용)로 표시
class ErrorRetryView extends StatelessWidget {
  final ApiError error;
  final VoidCallback? onRetry;
  final bool compact;

  /// 에러 위에 표시할 제목 오버라이드. 미지정 시 타입 기본값 사용.
  final String? title;

  const ErrorRetryView({
    super.key,
    required this.error,
    this.onRetry,
    this.compact = false,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final accent = _accentColor(error.type);
    final icon = _iconFor(error.type);
    final showRetry = onRetry != null && error.isRetryable;

    final inner = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 24,
        vertical: compact ? 16 : 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 48 : 64,
            height: compact ? 48 : 64,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, color: accent, size: compact ? 24 : 32),
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
          Text(
            title ?? _titleFor(error.type),
            style: TextStyle(
              fontSize: compact ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            error.message,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: subColor,
            ),
            textAlign: TextAlign.center,
          ),
          if (showRetry) ...[
            SizedBox(height: compact ? 16 : 20),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Symbols.refresh,
                    color: Colors.white, size: 18),
                label: const Text(
                  '다시 시도',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (compact) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: inner,
      );
    }
    return Center(child: inner);
  }

  static IconData _iconFor(ApiErrorType type) {
    switch (type) {
      case ApiErrorType.network:
        return Symbols.wifi_off;
      case ApiErrorType.timeout:
        return Symbols.schedule;
      case ApiErrorType.server:
        return Symbols.dns;
      case ApiErrorType.client:
        return Symbols.error;
      case ApiErrorType.unauthorized:
        return Symbols.lock;
      case ApiErrorType.unknown:
        return Symbols.warning;
    }
  }

  static Color _accentColor(ApiErrorType type) {
    switch (type) {
      case ApiErrorType.network:
        return Colors.orange;
      case ApiErrorType.timeout:
        return Colors.amber;
      case ApiErrorType.server:
        return Colors.red;
      case ApiErrorType.client:
        return Colors.deepOrange;
      case ApiErrorType.unauthorized:
        return Colors.blueGrey;
      case ApiErrorType.unknown:
        return Colors.grey;
    }
  }

  static String _titleFor(ApiErrorType type) {
    switch (type) {
      case ApiErrorType.network:
        return '네트워크 연결 실패';
      case ApiErrorType.timeout:
        return '응답 지연';
      case ApiErrorType.server:
        return '서버 오류';
      case ApiErrorType.client:
        return '요청 처리 실패';
      case ApiErrorType.unauthorized:
        return '인증 만료';
      case ApiErrorType.unknown:
        return '알 수 없는 오류';
    }
  }
}
