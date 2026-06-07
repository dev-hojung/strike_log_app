import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/system_notice.dart';
import '../../presentation/widgets/system_notice_dialog.dart';
import 'system_notices_api_service.dart';

/// 시스템 공지 단일 진입점.
///
/// 앱 시작 시점에 [maybeShowAll]을 호출하면:
/// 1. /system-notices/active 조회
/// 2. SharedPreferences의 dismissed_until과 비교해 만료 안 된 공지만 필터링
/// 3. 남은 공지를 우선순위(critical → warning → info) 순으로 순차 노출
/// 4. "오늘 하루 안 보기" 누른 공지는 KST 23:59:59까지 차단
class SystemNoticesService {
  SystemNoticesService._();
  static final SystemNoticesService instance = SystemNoticesService._();

  static const _prefsKey = 'system_notices_dismissed_v1';

  final SystemNoticesApiService _api = SystemNoticesApiService();

  /// 이번 앱 실행에서 이미 한 번 보여줬는지 여부 — 라우트 전환 시 재중복 방지.
  bool _shownThisRun = false;

  /// 가능한 모든 활성 공지를 순서대로 노출.
  /// 네트워크 실패 등은 조용히 무시.
  Future<void> maybeShowAll(BuildContext context) async {
    if (_shownThisRun) return;
    _shownThisRun = true;

    List<SystemNotice> notices;
    try {
      notices = await _api.fetchActive();
    } catch (_) {
      return;
    }
    if (notices.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final dismissedMap = _loadDismissedMap(prefs);
    final now = DateTime.now();

    // dismiss 만료 안 된 항목은 제외
    final toShow = notices.where((n) {
      final until = dismissedMap[n.id.toString()];
      if (until == null) return true;
      final parsed = DateTime.tryParse(until);
      if (parsed == null) return true;
      return now.isAfter(parsed);
    }).toList();

    if (toShow.isEmpty) return;

    // 우선순위 정렬 (critical > warning > info), 동순위는 최신순(서버가 이미 created_at DESC 정렬)
    toShow.sort((a, b) => _priorityRank(b.priority) - _priorityRank(a.priority));

    for (final notice in toShow) {
      if (!context.mounted) break;
      final result = await showSystemNoticeDialog(context, notice);
      if (result == 'dismiss_today' && notice.dismissible) {
        dismissedMap[notice.id.toString()] =
            _endOfTodayKst().toIso8601String();
        await prefs.setString(_prefsKey, jsonEncode(dismissedMap));
      }
    }
  }

  /// 다음 실행에서 다시 노출되도록 메모리 플래그 리셋.
  /// 로그아웃 → 다른 계정 로그인 같은 시나리오 대비.
  void resetShownFlag() {
    _shownThisRun = false;
  }

  Map<String, String> _loadDismissedMap(SharedPreferences prefs) {
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return <String, String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return <String, String>{};
  }

  int _priorityRank(SystemNoticePriority p) {
    switch (p) {
      case SystemNoticePriority.critical:
        return 2;
      case SystemNoticePriority.warning:
        return 1;
      case SystemNoticePriority.info:
        return 0;
    }
  }

  /// KST 기준 오늘 23:59:59의 UTC 시각.
  /// Railway가 UTC로 동작해도, 사용자 폰의 로컬 시간으로 "오늘 종료"를 결정해야
  /// 사용자 체감상 자연스러움. 단순화를 위해 폰 로컬 자정 직전 시각을 사용.
  DateTime _endOfTodayKst() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59);
  }
}
