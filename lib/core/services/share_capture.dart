import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show GlobalKey;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_logger.dart';

/// RepaintBoundary 위젯을 PNG으로 캡처해 시스템 공유 시트로 띄우는 유틸.
///
/// [key]는 공유 대상 영역을 감싼 RepaintBoundary의 GlobalKey.
/// [filename]은 임시 파일명 (확장자 없이). [text]는 공유 메시지로 첨부.
/// [pixelRatio]는 캡처 해상도 배율 (기본 3.0 = 레티나 품질).
class ShareCapture {
  ShareCapture._();

  static Future<bool> sharePng({
    required GlobalKey key,
    String filename = 'strike-log',
    String? text,
    double pixelRatio = 3.0,
  }) async {
    try {
      final boundary = key.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('[ShareCapture] RepaintBoundary not found for key');
        return false;
      }
      // 위젯이 완전히 페인트된 후에 캡처되도록 다음 프레임 종료를 대기.
      // 주의: RenderObject.debugNeedsPaint 는 release/profile 빌드에서
      // (assert 제거로 인해) LateInitializationError 를 던지므로 사용 금지.
      await WidgetsBinding.instance.endOfFrame;

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return false;
      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/$filename-$timestamp.png');
      await file.writeAsBytes(pngBytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: text,
        ),
      );
      return true;
    } catch (e, st) {
      AppLogger.captureError(e,
          stackTrace: st, context: 'share_capture.sharePng');
      return false;
    }
  }

  /// 캡처만 하고 바이트 반환 (테스트/저장용).
  static Future<Uint8List?> capturePng({
    required GlobalKey key,
    double pixelRatio = 3.0,
  }) async {
    try {
      final boundary = key.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e, st) {
      AppLogger.captureError(e,
          stackTrace: st, context: 'share_capture.capturePng');
      return null;
    }
  }
}
