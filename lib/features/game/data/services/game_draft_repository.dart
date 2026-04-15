import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 네트워크 실패로 저장되지 못한 게임 payload를 로컬에 보관하는 저장소.
///
/// 각 드래프트는 고유 [id]와 원본 [payload], 저장 실패 시점 [failedAt]을 가진다.
/// 앱 재시작이나 홈 진입 시 자동으로 재시도하기 위한 소스.
class GameDraftRepository {
  static const _key = 'pending_game_drafts';

  Future<List<GameDraft>> getAllDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => GameDraft.fromJson(e))
          .toList();
    } catch (_) {
      // JSON 손상 시 안전하게 초기화
      await prefs.remove(_key);
      return [];
    }
  }

  /// 새 드래프트 추가. id는 밀리초 epoch + random으로 고유 생성.
  Future<GameDraft> addDraft(Map<String, dynamic> payload) async {
    final drafts = await getAllDrafts();
    final draft = GameDraft(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      payload: payload,
      failedAt: DateTime.now(),
    );
    drafts.add(draft);
    await _persist(drafts);
    return draft;
  }

  Future<void> removeDraft(String id) async {
    final drafts = await getAllDrafts();
    drafts.removeWhere((d) => d.id == id);
    await _persist(drafts);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> _persist(List<GameDraft> drafts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(drafts.map((d) => d.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}

class GameDraft {
  final String id;
  final Map<String, dynamic> payload;
  final DateTime failedAt;

  const GameDraft({
    required this.id,
    required this.payload,
    required this.failedAt,
  });

  factory GameDraft.fromJson(Map<String, dynamic> json) => GameDraft(
        id: json['id']?.toString() ?? '',
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        failedAt: DateTime.tryParse(json['failedAt']?.toString() ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'payload': payload,
        'failedAt': failedAt.toIso8601String(),
      };
}
