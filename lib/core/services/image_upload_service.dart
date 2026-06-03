import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import 'app_logger.dart';

/// 이미지 선택 → 압축 → base64 Data URI 변환 헬퍼.
///
/// 백엔드는 파일 수신 인프라 없이 `profile_image_url`을 단순 string으로 받는 구조라,
/// 클라가 압축한 이미지 바이트를 `data:image/jpeg;base64,...` Data URI로 인코딩해
/// 그대로 PATCH 본문에 실어 보낸다.
///
/// DB·페이로드 부담 때문에 압축은 공격적으로 적용 (quality 50, minWidth 400).
/// 아바타 표시는 96~200px 수준이라 손실 화질은 체감 어렵다.
class ImageUploadService {
  ImageUploadService._();

  static final _picker = ImagePicker();

  /// Data URI 최대 길이(권장). 약 250KB 정도까지만 허용 — 그 이상이면 호출 측에서 차단.
  static const int maxDataUriLength = 350 * 1024;

  /// 갤러리 또는 카메라에서 이미지 선택.
  ///
  /// 사용자가 선택을 취소하면 null 반환.
  static Future<XFile?> pickImage({required ImageSource source}) {
    return _picker.pickImage(
      source: source,
      // 디바이스 메모리 보호 위해 image_picker 자체에서도 1차 리사이즈.
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
  }

  /// 이미지를 압축한 뒤 `data:image/jpeg;base64,...` Data URI로 반환.
  ///
  /// [quality] 기본 50, [maxWidth] 기본 400 — 프로필 아바타 용도라 충분.
  static Future<String> toBase64DataUri(
    XFile file, {
    int quality = 50,
    int maxWidth = 400,
  }) async {
    Uint8List bytes;
    try {
      final input = await file.readAsBytes();
      bytes = await FlutterImageCompress.compressWithList(
        input,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxWidth,
        format: CompressFormat.jpeg,
      );
    } catch (e, st) {
      AppLogger.captureError(e, stackTrace: st, context: 'image_compress');
      bytes = await file.readAsBytes();
    }
    final b64 = base64Encode(bytes);
    return 'data:image/jpeg;base64,$b64';
  }
}
