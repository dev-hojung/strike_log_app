import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/share_capture.dart';
import '../../../game/presentation/pages/frame_entry_page.dart';
import '../../../game/presentation/widgets/location_input_dialog.dart';
import '../../data/models/club_event.dart';
import '../../data/models/club_event_result.dart';
import '../../data/services/club_events_api_service.dart';

/// 정기전 상세 페이지.
///
/// - 참가자/레인/팀 보드
/// - 순위표(result)·평균
/// - STAFF+: ⋮ 오버플로 메뉴 (레인 배치, 완료 처리, 정기전 수정, 취소)
/// - 결과 공유 (share_capture) — 결과가 있을 때만 AppBar 아이콘 노출
/// - 참가자(STAFF 포함): "게임 시작" 버튼 — 하단 바에서 참석 버튼과 함께 노출.
///   개인 게임으로 저장되며 event_id가 games 테이블에 기록됨 (개인 통계에 반영).
///   완료 후 결과 새로고침.
class ClubEventDetailPage extends StatefulWidget {
  const ClubEventDetailPage({
    super.key,
    required this.groupId,
    required this.eventId,
    required this.canManage,
  });

  final int groupId;
  final int eventId;
  final bool canManage;

  @override
  State<ClubEventDetailPage> createState() => _ClubEventDetailPageState();
}

class _ClubEventDetailPageState extends State<ClubEventDetailPage>
    with SingleTickerProviderStateMixin {
  final ClubEventsApiService _api = ClubEventsApiService();

  ClubEvent? _event;
  ClubEventResult? _result;
  bool _loading = true;
  bool _busy = false;
  String? _myUserId;

  /// 뒤로 나갈 때 목록이 새로고침되어야 하는지 여부.
  bool _changed = false;

  // RepaintBoundary key for share capture
  final GlobalKey _shareKey = GlobalKey();

  late final TabController _tabController;

  // 레인 배치 시트의 레인 수. 시트 생명주기와 분리해 페이지에 묶는다
  // (시트 닫힘 애니메이션 중 dispose된 컨트롤러 접근 방지).
  // Fix #9: 프리셋 칩으로 교체하므로 TextEditingController 대신 int 값으로 관리.
  int _selectedLaneCount = 2;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMyUserId();
    _refresh();
  }

  Future<void> _loadMyUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('user_id');
    if (mounted) setState(() => _myUserId = id);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final event =
          await _api.getEvent(widget.groupId, widget.eventId);
      ClubEventResult? result;
      if (event.status == ClubEventStatus.completed ||
          event.status == ClubEventStatus.inProgress) {
        try {
          result =
              await _api.getEventResult(widget.groupId, widget.eventId);
        } catch (_) {
          // 결과가 아직 없을 수 있음 — 무시
        }
      }
      if (!mounted) return;
      setState(() {
        _event = event;
        _result = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정기전 정보를 불러오지 못했습니다.')),
      );
    }
  }

  // ── 레인 배치 ────────────────────────────────────────────────────────────

  Future<void> _showAssignLanesSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final mutedText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    String? selectedMode;
    // Fix #9: 레인 수는 프리셋 칩으로 선택 (초기값 유지)
    int laneCount = _selectedLaneCount;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 핸들
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      '레인 배치',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 배치 모드 선택
                    ...[
                      ('random', Symbols.shuffle, '랜덤 배치',
                          '참가자를 무작위로 레인에 배정합니다.'),
                      ('balanced', Symbols.equalizer, '에버리지 균형',
                          '평균 점수 기준으로 각 레인 평균합이 균형을 이루도록 배정합니다.'),
                      ('team', Symbols.groups, '팀전',
                          '평균 점수로 팀을 나눠 team_no를 부여합니다.'),
                    ].map((entry) {
                      final (mode, icon, label, desc) = entry;
                      final isSelected = selectedMode == mode;
                      return GestureDetector(
                        onTap: () =>
                            setSheetState(() => selectedMode = mode),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : (isDark
                                    ? AppColors.backgroundDark
                                    : AppColors.backgroundLight),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark
                                      ? Colors.white12
                                      : Colors.black12),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                icon,
                                color: isSelected
                                    ? AppColors.primary
                                    : mutedText,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      label,
                                      style: TextStyle(
                                        color: isSelected
                                            ? AppColors.primary
                                            : textColor,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      desc,
                                      style: TextStyle(
                                          color: mutedText, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Symbols.check_circle,
                                    color: AppColors.primary, size: 20),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    // Fix #9: 레인 수 — 프리셋 칩 (2·3·4·5·6)
                    Text(
                      '레인 수',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [2, 3, 4, 5, 6].map((n) {
                        final isSelected = laneCount == n;
                        return ChoiceChip(
                          label: Text('$n'),
                          selected: isSelected,
                          onSelected: (_) =>
                              setSheetState(() => laneCount = n),
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          backgroundColor: isDark
                              ? AppColors.backgroundDark
                              : AppColors.backgroundLight,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : textColor,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? Colors.white12 : Colors.black12),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          showCheckmark: false,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: selectedMode == null
                            ? null
                            : () {
                                // 선택된 레인 수를 페이지 상태에 기억해 다음 열 때 유지
                                setState(() => _selectedLaneCount = laneCount);
                                Navigator.pop(ctx);
                                _doAssignLanes(selectedMode!, laneCount);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor:
                              AppColors.primary.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          '배치 실행',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _doAssignLanes(String mode, int laneCount) async {
    setState(() => _busy = true);
    try {
      await _api.assignLanes(
        groupId: widget.groupId,
        eventId: widget.eventId,
        mode: mode,
        laneCount: laneCount,
      );
      _changed = true;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('레인 배치가 완료되었습니다.')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map
          ? (e.response!.data['message']?.toString() ?? '배치에 실패했습니다.')
          : '배치에 실패했습니다.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── 완료 처리 ────────────────────────────────────────────────────────────

  // Fix #4: 완료 후 Navigator.pop 제거 → 순위표 탭으로 전환 + _changed=true.
  Future<void> _confirmComplete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('정기전을 완료 처리할까요?'),
        content: const Text(
          '완료 처리 후 순위·평균이 스냅샷으로 저장됩니다.\n이 작업은 되돌릴 수 없어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('완료 처리'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _api.completeEvent(widget.groupId, widget.eventId);
      _changed = true;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정기전이 완료 처리되었습니다.')),
      );
      // 완료 후 순위표 탭(index 1)으로 자동 전환
      _tabController.animateTo(1);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map
          ? (e.response!.data['message']?.toString() ?? '완료 처리에 실패했습니다.')
          : '완료 처리에 실패했습니다.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── 정기전 수정 (Fix #8) ──────────────────────────────────────────────────

  Future<void> _showEditEventDialog() async {
    final event = _event;
    if (event == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: event.name);
    DateTime selectedDate = _parseDateStr(event.eventDate) ?? DateTime.now();

    Future<void> pickDate(StateSetter setDialogState) async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 2),
        locale: const Locale('ko'),
      );
      if (picked != null) setDialogState(() => selectedDate = picked);
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
          final mutedText = isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight;
          final surfaceColor =
              isDark ? AppColors.surfaceDark : Colors.white;
          final borderColor = isDark ? Colors.white10 : Colors.black12;

          final dateLabel =
              '${selectedDate.year}년 ${selectedDate.month}월 ${selectedDate.day}일';

          return AlertDialog(
            backgroundColor: surfaceColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              '정기전 정보 수정',
              style: TextStyle(
                color: textColor,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('이름',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark
                        ? AppColors.backgroundDark
                        : AppColors.backgroundLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                Text('날짜',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => pickDate(setDialogState),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.backgroundDark
                          : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Row(
                      children: [
                        const Icon(Symbols.calendar_today,
                            color: AppColors.primary, size: 16),
                        const SizedBox(width: 8),
                        Text(dateLabel,
                            style: TextStyle(color: textColor, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('취소', style: TextStyle(color: mutedText)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text('저장',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );

    if (ok != true) {
      nameController.dispose();
      return;
    }

    final newName = nameController.text.trim();
    nameController.dispose();

    if (newName.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해주세요.')),
      );
      return;
    }

    final dateStr =
        '${selectedDate.year.toString().padLeft(4, '0')}-'
        '${selectedDate.month.toString().padLeft(2, '0')}-'
        '${selectedDate.day.toString().padLeft(2, '0')}';

    setState(() => _busy = true);
    try {
      await _api.updateEvent(
        groupId: widget.groupId,
        eventId: widget.eventId,
        name: newName,
        eventDate: dateStr,
      );
      _changed = true;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정기전 정보가 수정되었습니다.')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map
          ? (e.response!.data['message']?.toString() ?? '수정에 실패했습니다.')
          : '수정에 실패했습니다.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  DateTime? _parseDateStr(String s) {
    // 'YYYY-MM-DD'
    final parts = s.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  // ── 정기전 취소 (Fix #8) ──────────────────────────────────────────────────

  Future<void> _confirmCancelEvent() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('정기전을 취소할까요?'),
        content: const Text('취소된 정기전은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('정기전 취소'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _api.updateEvent(
        groupId: widget.groupId,
        eventId: widget.eventId,
        status: 'cancelled',
      );
      _changed = true;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정기전이 취소되었습니다.')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map
          ? (e.response!.data['message']?.toString() ?? '취소에 실패했습니다.')
          : '취소에 실패했습니다.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── 정기전 게임 시작 (Fix #1, #2, #6, #7) ────────────────────────────────

  /// 정기전에서 개인 게임을 시작한다.
  ///
  /// Fix #1: 참석 중이 아니면 먼저 attend() 호출 (게임 참여 = 참가 의사 포함).
  /// Fix #2: 이벤트가 scheduled 상태면 in_progress로 자동 전환 (최초 1회).
  /// Fix #6: 마지막 입력 장소를 SharedPreferences에 저장하고 다음 실행 시 프리필.
  /// Fix #7: isClubGame=false (개인 게임) + event_id 태깅 방식 유지.
  ///   정기전 게임은 개인 게임으로 저장되어 개인 통계에 반영되며,
  ///   event_id를 통해 해당 정기전 순위표에서 집계된다.
  Future<void> _startEventGame() async {
    // Fix #6: 마지막 사용 장소 불러오기
    final prefs = await SharedPreferences.getInstance();
    final lastLocation = prefs.getString('last_event_location');

    if (!mounted) return;
    final location =
        await showLocationInputDialog(context, initialValue: lastLocation);
    if (location == null) return;
    if (!mounted) return;

    // Fix #6: 입력한 장소 저장 (공백 아닐 때만)
    if (location.isNotEmpty) {
      await prefs.setString('last_event_location', location);
    }

    // Fix #1: 참석 중이 아니면 자동으로 참석 신청
    if (!_isAttending) {
      try {
        await _api.attend(
            groupId: widget.groupId, eventId: widget.eventId);
        _changed = true;
        await _refresh();
      } on DioException catch (_) {
        // 참석 신청 실패해도 게임 진행은 허용
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('참석 신청에 실패했지만 게임을 시작합니다.')),
          );
        }
      }
    }

    if (!mounted) return;

    // Fix #2: scheduled 상태일 때 in_progress로 자동 전환 (최초 1회)
    if (_event?.status == ClubEventStatus.scheduled) {
      try {
        await _api.updateEvent(
          groupId: widget.groupId,
          eventId: widget.eventId,
          status: 'in_progress',
        );
        _changed = true;
        await _refresh();
      } on DioException catch (_) {
        // 상태 전환 실패는 무시하고 게임 진행
      }
    }

    if (!mounted) return;

    // Fix #7: isClubGame=false — 정기전 게임은 개인 게임으로 저장 + event_id 태깅.
    // 이 방식으로 개인 통계에 반영되면서 event_id를 통해 정기전 순위표에 집계된다.
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FrameEntryPage(
          isClubGame: false,
          location: location,
          eventId: widget.eventId,
        ),
      ),
    );

    // 게임이 저장됐을 수 있으므로 결과 새로고침
    if (mounted) {
      _changed = true;
      _refresh();
    }
  }

  // ── 참석/참석취소 ─────────────────────────────────────────────────────────

  bool get _isAttending {
    final id = _myUserId;
    if (id == null || _event == null) return false;
    return _event!.participants.any((p) => p.userId == id);
  }

  Future<void> _toggleAttend() async {
    final attending = _isAttending;
    setState(() => _busy = true);
    try {
      if (attending) {
        await _api.unattend(
            groupId: widget.groupId, eventId: widget.eventId);
      } else {
        await _api.attend(
            groupId: widget.groupId, eventId: widget.eventId);
      }
      _changed = true;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(attending ? '참석을 취소했습니다.' : '참석 신청이 완료됐습니다.'),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map
          ? (e.response!.data['message']?.toString() ?? '요청에 실패했습니다.')
          : '요청에 실패했습니다.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── 결과 공유 ────────────────────────────────────────────────────────────

  Future<void> _shareResult() async {
    await ShareCapture.sharePng(
      key: _shareKey,
      filename: 'strikelog-event',
      text:
          '${_event?.name ?? '정기전'} 결과 — Strike Log',
    );
  }

  // ── 빌드 ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final event = _event;
    final isActive = event != null &&
        event.status != ClubEventStatus.cancelled &&
        event.status != ClubEventStatus.completed;
    final canModify = widget.canManage &&
        event != null &&
        event.status != ClubEventStatus.completed &&
        event.status != ClubEventStatus.cancelled;

    // Fix #4: PopScope로 _changed 전달
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _changed) {
          // 이미 pop 됐으므로 결과 전달은 Navigator.pop 시점에서 처리 — 아래 back button 처리 참고
        }
      },
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor:
              isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          // Fix #3: 뒤로 가기 버튼 — _changed 전달
          leading: IconButton(
            icon: const Icon(Symbols.arrow_back),
            onPressed: () => Navigator.pop(context, _changed),
          ),
          title: Text(
            event?.name ?? '정기전',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            // Fix #3: 결과 공유 아이콘 — 결과 있을 때만
            if (_result != null)
              IconButton(
                icon: const Icon(Symbols.share),
                tooltip: '결과 공유',
                onPressed: _shareResult,
              ),
            // Fix #3: 관리 액션 — ⋮ 오버플로 메뉴 (canManage일 때만)
            if (widget.canManage && event != null)
              PopupMenuButton<String>(
                icon: const Icon(Symbols.more_vert),
                tooltip: '관리',
                onSelected: (value) {
                  switch (value) {
                    case 'lanes':
                      if (!_busy) _showAssignLanesSheet();
                    case 'complete':
                      if (!_busy) _confirmComplete();
                    case 'edit':
                      if (!_busy) _showEditEventDialog();
                    case 'cancel':
                      if (!_busy) _confirmCancelEvent();
                  }
                },
                itemBuilder: (_) => [
                  if (isActive)
                    const PopupMenuItem(
                      value: 'lanes',
                      child: Text('레인 배치'),
                    ),
                  if (isActive)
                    const PopupMenuItem(
                      value: 'complete',
                      child: Text('완료 처리'),
                    ),
                  if (canModify)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('정기전 정보 수정'),
                    ),
                  if (canModify)
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text('정기전 취소'),
                    ),
                ],
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: '참가자/레인'),
              Tab(text: '순위표'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildParticipantsTab(isDark),
                        _buildResultTab(isDark),
                      ],
                    ),
                  ),
                  // Fix #3: 하단 바 — 참석 버튼 + 게임 시작 버튼 (예정·진행 중)
                  if (event != null && isActive)
                    _buildBottomBar(isDark, event),
                ],
              ),
      ),
    );
  }

  // ── 하단 바 (Fix #3) ───────────────────────────────────────────────────────

  Widget _buildBottomBar(bool isDark, ClubEvent event) {
    final attending = _isAttending;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ),
        ),
        child: Row(
          children: [
            // 참석/참석취소 버튼
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _toggleAttend,
                  icon: Icon(
                    attending ? Symbols.event_busy : Symbols.event_available,
                    size: 20,
                  ),
                  label: Text(
                    attending ? '참석 취소' : '참석',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        attending ? Colors.red.shade600 : AppColors.primary,
                    disabledBackgroundColor: (attending
                            ? Colors.red.shade600
                            : AppColors.primary)
                        .withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 게임 시작 버튼 (Fix #3: 아이콘만이 아닌 레이블 있는 버튼)
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _startEventGame,
                icon: const Icon(Symbols.sports_score, size: 20),
                label: const Text(
                  '게임 시작',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.15),
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.07),
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 참가자/레인 탭 ────────────────────────────────────────────────────────

  Widget _buildParticipantsTab(bool isDark) {
    final event = _event;
    if (event == null) return const SizedBox.shrink();

    final participants = event.participants;
    if (participants.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 60),
          children: [
            Center(
              child: Text(
                '참가자가 없어요.',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 레인별 그룹핑
    final hasLanes = participants.any((p) => p.laneNo != null);
    if (hasLanes) {
      return _buildLaneBoard(participants, isDark);
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: participants.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _buildParticipantTile(participants[i], isDark),
      ),
    );
  }

  Widget _buildLaneBoard(
      List<ClubEventParticipant> participants, bool isDark) {
    // 레인 번호별 그룹
    final Map<int, List<ClubEventParticipant>> byLane = {};
    for (final p in participants) {
      final lane = p.laneNo ?? 0;
      byLane.putIfAbsent(lane, () => []).add(p);
    }
    final laneKeys = byLane.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: laneKeys.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final lane = laneKeys[i];
          final list = byLane[lane]!;
          return _buildLaneCard(lane, list, isDark);
        },
      ),
    );
  }

  Widget _buildLaneCard(
      int lane, List<ClubEventParticipant> members, bool isDark) {
    final surface = isDark ? AppColors.surfaceDark : Colors.white;
    final border = isDark ? Colors.white12 : Colors.black12;
    final primaryText =
        isDark ? Colors.white : AppColors.textPrimaryLight;
    final mutedText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(Symbols.view_column,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  '$lane번 레인',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (members.first.teamNo != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${members.first.teamNo}팀',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...members.map((p) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color:
                            AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Symbols.person,
                          color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.nickname,
                        style: TextStyle(
                          color: primaryText,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (p.handicap > 0)
                      Text(
                        '+${p.handicap}H',
                        style: TextStyle(
                          color: mutedText,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildParticipantTile(
      ClubEventParticipant p, bool isDark) {
    final surface = isDark ? AppColors.surfaceDark : Colors.white;
    final border = isDark ? Colors.white12 : Colors.black12;
    final primaryText =
        isDark ? Colors.white : AppColors.textPrimaryLight;
    final mutedText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Symbols.person,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              p.nickname,
              style: TextStyle(
                color: primaryText,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (p.handicap > 0)
            Text(
              '+${p.handicap}H',
              style: TextStyle(color: mutedText, fontSize: 12),
            ),
        ],
      ),
    );
  }

  // ── 순위표 탭 ────────────────────────────────────────────────────────────

  Widget _buildResultTab(bool isDark) {
    final result = _result;
    final event = _event;

    if (result == null) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 16),
          children: [
            Center(
              child: Text(
                event?.status == ClubEventStatus.scheduled
                    ? '아직 게임이 시작되지 않았어요.'
                    : '아직 결과가 없어요.\n게임을 진행하면 순위가 표시됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: RepaintBoundary(
          key: _shareKey,
          child: _buildResultCard(result, event, isDark),
        ),
      ),
    );
  }

  Widget _buildResultCard(
      ClubEventResult result, ClubEvent? event, bool isDark) {
    final cardBg = isDark ? AppColors.surfaceDark : Colors.white;
    final border = isDark ? Colors.white12 : Colors.black12;
    final primaryText =
        isDark ? Colors.white : AppColors.textPrimaryLight;
    final mutedText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Symbols.emoji_events,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.eventName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  result.eventDate,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // 팀 결과 (팀전일 때)
          if (result.teams != null && result.teams!.isNotEmpty) ...[
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '팀 순위',
                style: TextStyle(
                  color: primaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...result.teams!.map((t) => _buildTeamRow(t, mutedText, primaryText)),
            Divider(
                height: 24,
                color: isDark ? Colors.white12 : Colors.black12),
          ],

          // 개인 순위
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '개인 순위',
              style: TextStyle(
                color: primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...result.participants
              .map((p) => _buildParticipantResultRow(p, mutedText, primaryText)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTeamRow(ClubEventResultTeam team, Color mutedText,
      Color primaryText) {
    final medal = _medalIcon(team.rank);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              medal ?? '${team.rank}위',
              style: TextStyle(
                  fontSize: medal != null ? 18 : 13, color: primaryText),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${team.teamNo}팀',
              style: TextStyle(
                color: primaryText,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                team.avgScore.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                '${team.gameCount}게임',
                style: TextStyle(color: mutedText, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantResultRow(ClubEventResultParticipant p,
      Color mutedText, Color primaryText) {
    final medal = _medalIcon(p.rank);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              medal ?? '${p.rank}위',
              style: TextStyle(
                  fontSize: medal != null ? 18 : 13, color: primaryText),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nickname,
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (p.laneNo != null || p.teamNo != null)
                  Text(
                    [
                      if (p.laneNo != null) '${p.laneNo}레인',
                      if (p.teamNo != null) '${p.teamNo}팀',
                    ].join(' · '),
                    style: TextStyle(color: mutedText, fontSize: 11),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                p.avgScore.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                '${p.gameCount}게임',
                style: TextStyle(color: mutedText, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _medalIcon(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return null;
    }
  }
}
