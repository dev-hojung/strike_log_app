import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

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
/// - STAFF+: 레인 배치 액션시트, 완료 처리
/// - 결과 공유 (share_capture)
/// - 참가자(STAFF 포함): "정기전에서 게임 시작" — 개인 게임 frame-entry로 진입,
///   저장 시 event_id가 games 테이블에 기록됨. 완료 후 결과 새로고침.
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

  // RepaintBoundary key for share capture
  final GlobalKey _shareKey = GlobalKey();

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refresh();
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
    final laneCountController = TextEditingController(text: '2');

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
                    // 레인 수 입력
                    Text(
                      '레인 수',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: laneCountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: '레인 수 입력',
                        hintStyle: TextStyle(color: mutedText),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.backgroundDark
                            : AppColors.backgroundLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.black12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.black12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: selectedMode == null
                            ? null
                            : () {
                                final laneCount = int.tryParse(
                                    laneCountController.text.trim());
                                if (laneCount == null || laneCount < 1) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('레인 수를 올바르게 입력해주세요.')),
                                  );
                                  return;
                                }
                                Navigator.pop(ctx);
                                _doAssignLanes(
                                    selectedMode!, laneCount);
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
    laneCountController.dispose();
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
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정기전이 완료 처리되었습니다.')),
      );
      Navigator.pop(context, true);
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

  // ── 정기전 게임 시작 ──────────────────────────────────────────────────────

  /// 정기전에서 개인 게임을 시작한다.
  /// 장소 입력 → FrameEntryPage(eventId=widget.eventId) 진입.
  /// 완료 후 돌아오면 결과를 새로고침한다.
  Future<void> _startEventGame() async {
    final location = await showLocationInputDialog(context);
    if (location == null) return;
    if (!mounted) return;

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
    if (mounted) _refresh();
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

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _event?.name ?? '정기전',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_result != null)
            IconButton(
              icon: const Icon(Symbols.share),
              tooltip: '결과 공유',
              onPressed: _shareResult,
            ),
          if (_event != null &&
              _event!.status != ClubEventStatus.cancelled &&
              _event!.status != ClubEventStatus.completed)
            IconButton(
              icon: const Icon(Symbols.sports_score),
              tooltip: '정기전에서 게임 시작',
              onPressed: _busy ? null : _startEventGame,
            ),
          if (widget.canManage && _event != null) ...[
            if (_event!.status != ClubEventStatus.completed &&
                _event!.status != ClubEventStatus.cancelled)
              IconButton(
                icon: const Icon(Symbols.view_column),
                tooltip: '레인 배치',
                onPressed: _busy ? null : _showAssignLanesSheet,
              ),
            if (_event!.status != ClubEventStatus.completed &&
                _event!.status != ClubEventStatus.cancelled)
              IconButton(
                icon: const Icon(Symbols.check_circle),
                tooltip: '완료 처리',
                onPressed: _busy ? null : _confirmComplete,
              ),
          ],
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
          : TabBarView(
              controller: _tabController,
              children: [
                _buildParticipantsTab(isDark),
                _buildResultTab(isDark),
              ],
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
