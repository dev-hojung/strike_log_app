import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob 전면 광고(Interstitial) 싱글톤 서비스.
///
/// 사용 흐름:
/// 1. `main()`에서 `await AdsService.instance.initialize()` 호출.
/// 2. 게임 시작 시(FrameEntryPage.initState) `preloadInterstitial()` 호출 — 결과 화면 도달 전에 광고 로드.
/// 3. 저장 성공 후 `maybeShowInterstitial()` 호출 — 광고 show 후 콜백으로 기존 네비게이션 실행.
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  // 실제 AdMob 전면 광고 단위 ID (Android)
  static const _androidInterstitialAdUnitId =
      'ca-app-pub-2629679506425191/5874550886';

  // 실제 AdMob 전면 광고 단위 ID (iOS)
  static const _iosInterstitialAdUnitId =
      'ca-app-pub-2629679506425191/1756589313';

  String get _interstitialAdUnitId =>
      Platform.isIOS ? _iosInterstitialAdUnitId : _androidInterstitialAdUnitId;

  bool _initialized = false;
  InterstitialAd? _loadedAd;
  bool _isLoading = false;

  /// .env의 ADS_ENABLED 토글 — 'true'일 때만 SDK 초기화·로드·표시.
  /// 미설정/false면 모든 광고 동작이 no-op (개발 중 에뮬레이터에서
  /// Play Services dynamite 충돌 회피용).
  bool get _envEnabled => dotenv.env['ADS_ENABLED']?.toLowerCase() == 'true';

  /// MobileAds SDK 초기화. idempotent — 중복 호출 safe.
  /// ADS_ENABLED=true가 아니면 no-op으로 종료(개발 중 SDK 자체 로드를 막아
  /// dynamite 모듈 충돌·SIGKILL 회피).
  Future<void> initialize() async {
    if (_initialized) return;
    if (!_envEnabled) {
      debugPrint('[AdsService] ADS_ENABLED=false — SDK init 스킵');
      return;
    }
    if (!Platform.isAndroid && !Platform.isIOS) {
      _initialized = true;
      return;
    }
    try {
      // iOS: 광고 요청 전 ATT(앱 추적 투명성) 동의 요청.
      if (Platform.isIOS) {
        await _requestTrackingAuthorization();
      }
      await MobileAds.instance.initialize();
      _initialized = true;
      debugPrint('[AdsService] MobileAds initialized');
    } catch (e) {
      debugPrint('[AdsService] initialize error: $e');
    }
  }

  /// iOS ATT 권한 요청. 미결정 상태일 때만 시스템 프롬프트 표시.
  /// 거부해도 광고는 표시되며(비개인화), 앱 동작엔 영향 없음.
  Future<void> _requestTrackingAuthorization() async {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      debugPrint('[AdsService] ATT status before request: $status');
      if (status == TrackingStatus.notDetermined) {
        final result =
            await AppTrackingTransparency.requestTrackingAuthorization();
        debugPrint('[AdsService] ATT status after request: $result');
      }
    } catch (e) {
      debugPrint('[AdsService] ATT request error: $e');
    }
  }

  /// 전면 광고를 백그라운드로 미리 로드.
  /// 동시 다중 호출 방지: 로딩 중이거나 이미 로드된 광고가 있으면 skip.
  void preloadInterstitial() {
    if (!_envEnabled) return;
    if (!_initialized) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (_isLoading || _loadedAd != null) return;
    _isLoading = true;

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadedAd = ad;
          _isLoading = false;
          debugPrint('[AdsService] interstitial preloaded');
        },
        onAdFailedToLoad: (error) {
          _loadedAd = null;
          _isLoading = false;
          debugPrint('[AdsService] preload failed: ${error.message}');
        },
      ),
    );
  }

  /// 전면 광고를 표시한다.
  ///
  /// - [isPlatformAdmin] == true면 광고 없이 즉시 [onClose] 호출.
  /// - preload된 광고가 있으면 즉시 show → 닫힘/실패 시 [onClose] 호출 후 다음 광고 preload.
  /// - preload된 광고가 없으면 500ms 타임아웃으로 동기 로드 시도.
  ///   성공하면 show, 실패/타임아웃이면 [onClose] 즉시 호출.
  /// - 모든 예외는 silent fail — 광고 없이 [onClose] 호출 보장.
  Future<void> maybeShowInterstitial({
    required bool isPlatformAdmin,
    required void Function() onClose,
  }) async {
    // ADS_ENABLED=false면 광고 동작 전체 skip
    if (!_envEnabled) {
      onClose();
      return;
    }

    // 면제: 플랫폼 어드민
    if (isPlatformAdmin) {
      onClose();
      return;
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      onClose();
      return;
    }

    if (!_initialized) {
      onClose();
      return;
    }

    try {
      // preload된 광고가 있으면 즉시 사용
      if (_loadedAd != null) {
        await _showAd(_loadedAd!, onClose);
        return;
      }

      // 500ms 타임아웃으로 sync load 시도
      final ad = await _loadWithTimeout(
        const Duration(milliseconds: 500),
      );
      if (ad != null) {
        await _showAd(ad, onClose);
      } else {
        onClose();
      }
    } catch (e) {
      debugPrint('[AdsService] maybeShowInterstitial error: $e');
      onClose();
    }
  }

  /// 광고를 표시하고 닫힘/실패 시 [onClose]를 호출한다.
  /// 표시 후 다음 광고를 미리 로드한다.
  Future<void> _showAd(InterstitialAd ad, void Function() onClose) async {
    _loadedAd = null;

    final completer = Completer<void>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (a, error) {
        a.dispose();
        debugPrint('[AdsService] show failed: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );

    try {
      await ad.show();
    } catch (e) {
      debugPrint('[AdsService] ad.show() error: $e');
      ad.dispose();
      if (!completer.isCompleted) completer.complete();
    }

    await completer.future;
    onClose();
    // 다음 표시를 위해 미리 로드
    preloadInterstitial();
  }

  /// [timeout] 내에 광고 로드를 시도한다. 실패/타임아웃이면 null 반환.
  Future<InterstitialAd?> _loadWithTimeout(Duration timeout) async {
    final completer = Completer<InterstitialAd?>();

    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (!completer.isCompleted) completer.complete(ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdsService] sync load failed: ${error.message}');
          if (!completer.isCompleted) completer.complete(null);
        },
      ),
    );

    return completer.future.timeout(timeout, onTimeout: () {
      debugPrint('[AdsService] sync load timed out');
      return null;
    });
  }
}
