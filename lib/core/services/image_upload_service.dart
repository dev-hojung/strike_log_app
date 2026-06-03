import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import 'app_logger.dart';

/// 이미지 선택 → 압축 → Firebase Storage 업로드 헬퍼.
///
/// 백엔드에는 파일 수신 인프라가 없어, 클라가 직접 Firebase Storage에 업로드한 뒤
/// 받은 다운로드 URL을 `PATCH /users/:id`의 `profile_image_url`로 전송하는 방식.
///
/// 보안 룰(Firebase Console > Storage > Rules) 예시:
/// ```
/// rules_version = '2';
/// service firebase.storage {
///   match /b/{bucket}/o {
///     match /profile_images/{userId}/{file=**} {
///       allow read: if true;
///       allow write: if request.auth != null && request.auth.uid == userId
///                    && request.resource.size < 5 * 1024 * 1024;
///     }
///   }
/// }
/// ```
class ImageUploadService {
  ImageUploadService._();

  static final _picker = ImagePicker();
  static final _storage = FirebaseStorage.instance;

  /// 갤러리 또는 카메라에서 이미지 선택.
  ///
  /// 사용자가 선택을 취소하면 null 반환.
  static Future<XFile?> pickImage({required ImageSource source}) {
    return _picker.pickImage(
      source: source,
      // image_picker 자체에서도 1차 리사이즈 (디바이스 메모리 보호).
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
  }

  /// 선택된 이미지를 JPEG 압축.
  ///
  /// 프로필 이미지는 96x96~200x200 정도로 표시되므로 1024px + 품질 70이면 충분.
  /// 실패 시 원본 바이트 반환.
  static Future<Uint8List> compress(
    XFile file, {
    int quality = 70,
    int maxWidth = 1024,
  }) async {
    try {
      final input = await file.readAsBytes();
      final result = await FlutterImageCompress.compressWithList(
        input,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxWidth,
        format: CompressFormat.jpeg,
      );
      return result;
    } catch (e, st) {
      AppLogger.captureError(e, stackTrace: st, context: 'image_compress');
      return file.readAsBytes();
    }
  }

  /// 프로필 이미지를 Firebase Storage에 업로드하고 다운로드 URL을 반환.
  ///
  /// 경로: `profile_images/{userId}/{timestamp}.jpg`
  /// 동일 사용자가 새로 올릴 때마다 새 객체 생성 → 캐시 무효화 자동.
  static Future<String> uploadProfileImage({
    required String userId,
    required Uint8List bytes,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref('profile_images/$userId/$ts.jpg');
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }
}
