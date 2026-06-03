import 'dart:convert';

import 'package:flutter/material.dart';

/// 사용자 아바타용 이미지 위젯.
///
/// `url`이 `data:image/...;base64,...` 형태이면 base64 decode → `Image.memory`,
/// 그 외(HTTP/HTTPS)는 `Image.network`로 렌더한다.
/// 값이 비어있거나 디코딩 실패 시 [fallback]을 표시.
///
/// 백엔드의 profile_image_url 컬럼이 LONGTEXT라 Data URI를 그대로 저장하기 때문에
/// 표시 측에서 두 형식을 모두 다뤄야 한다.
class AvatarImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final Widget fallback;

  const AvatarImage({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final raw = url;
    if (raw == null || raw.isEmpty) return fallback;

    if (raw.startsWith('data:image')) {
      try {
        final comma = raw.indexOf(',');
        if (comma < 0) return fallback;
        final bytes = base64Decode(raw.substring(comma + 1));
        return Image.memory(
          bytes,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => fallback,
        );
      } catch (_) {
        return fallback;
      }
    }

    return Image.network(
      raw,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
