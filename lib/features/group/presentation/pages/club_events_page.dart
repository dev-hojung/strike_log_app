import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/club_event.dart';
import '../../data/services/club_events_api_service.dart';
import 'club_event_detail_page.dart';
import 'create_club_event_page.dart';

/// 정기전/모임 목록 페이지.
///
/// 예정 / 진행 중 / 완료 탭으로 상태별 분류.
/// STAFF 이상이면 FAB "정기전 만들기" 노출.
class ClubEventsPage extends StatefulWidget {
  const ClubEventsPage({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.canManage,
  });

  final int groupId;
  final String groupName;

  /// GroupRole.canManage() 결과 — OWNER 또는 STAFF이면 true.
  final bool canManage;

  @override
  State<ClubEventsPage> createState() => _ClubEventsPageState();
}

class _ClubEventsPageState extends State<ClubEventsPage>
    with SingleTickerProviderStateMixin {
  final ClubEventsApiService _api = ClubEventsApiService();

  late final TabController _tabController;

  // 각 탭(예정/진행/완료)의 이벤트 리스트
  List<ClubEvent> _scheduled = const [];
  List<ClubEvent> _inProgress = const [];
  List<ClubEvent> _completed = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      final results = await Future.wait([
        _api.listEvents(widget.groupId, status: 'scheduled'),
        _api.listEvents(widget.groupId, status: 'in_progress'),
        _api.listEvents(widget.groupId, status: 'completed'),
      ]);
      if (!mounted) return;
      setState(() {
        _scheduled = results[0];
        _inProgress = results[1];
        _completed = results[2];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정기전 목록을 불러오지 못했습니다.')),
      );
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateClubEventPage(
          groupId: widget.groupId,
        ),
      ),
    );
    if (created == true) await _refresh();
  }

  Future<void> _openDetail(ClubEvent event) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'club_event_detail'),
        builder: (_) => ClubEventDetailPage(
          groupId: widget.groupId,
          eventId: event.id,
          canManage: widget.canManage,
        ),
      ),
    );
    if (changed == true) await _refresh();
  }

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
          '정기전',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor:
              isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: '예정'),
            Tab(text: '진행 중'),
            Tab(text: '완료'),
          ],
        ),
      ),
      bottomNavigationBar: widget.canManage
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _openCreate,
                    icon: const Icon(Symbols.add, color: Colors.white, size: 20),
                    label: const Text(
                      '정기전 만들기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_scheduled, ClubEventStatus.scheduled, isDark),
                _buildList(_inProgress, ClubEventStatus.inProgress, isDark),
                _buildList(_completed, ClubEventStatus.completed, isDark),
              ],
            ),
    );
  }

  Widget _buildList(
      List<ClubEvent> events, ClubEventStatus tabStatus, bool isDark) {
    if (events.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 80),
          children: [
            _buildEmptyState(tabStatus, isDark),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _buildEventCard(events[i], isDark),
      ),
    );
  }

  Widget _buildEmptyState(ClubEventStatus tabStatus, bool isDark) {
    final mutedText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final accentColor = _statusColor(tabStatus);

    final (icon, message) = switch (tabStatus) {
      ClubEventStatus.scheduled => (
          Symbols.event_upcoming,
          '예정된 정기전이 없어요.\n새 정기전을 만들어 보세요.',
        ),
      ClubEventStatus.inProgress => (
          Symbols.sports_score,
          '현재 진행 중인 정기전이 없어요.',
        ),
      ClubEventStatus.completed => (
          Symbols.emoji_events,
          '완료된 정기전이 없어요.',
        ),
      ClubEventStatus.cancelled => (
          Symbols.event_busy,
          '취소된 정기전이 없어요.',
        ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor.withValues(alpha: 0.6), size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: mutedText,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(ClubEvent event, bool isDark) {
    final surface = isDark ? AppColors.surfaceDark : Colors.white;
    final primaryText = isDark ? Colors.white : AppColors.textPrimaryLight;
    final mutedText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final statusColor = _statusColor(event.status);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.07);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetail(event),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 상태색 좌측 액센트 바
                  Container(width: 3, color: statusColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Row(
              children: [
                // 날짜 세로 블럭
                _buildDateBlock(event, isDark),
                const SizedBox(width: 14),
                // 이름 + 메타
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.name,
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                        softWrap: true,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Symbols.group, size: 13, color: mutedText),
                          const SizedBox(width: 4),
                          Text(
                            '${event.participantCount}명',
                            style: TextStyle(color: mutedText, fontSize: 12),
                          ),
                          if (event.formattedTime != null) ...[
                            Text(
                              ' · ',
                              style: TextStyle(color: mutedText, fontSize: 12),
                            ),
                            Icon(Symbols.schedule, size: 13, color: mutedText),
                            const SizedBox(width: 3),
                            Text(
                              event.formattedTime!,
                              style: TextStyle(color: mutedText, fontSize: 12),
                            ),
                          ],
                          if (event.gameTarget != null) ...[
                            Text(
                              ' · ',
                              style: TextStyle(color: mutedText, fontSize: 12),
                            ),
                            Icon(Symbols.sports_score, size: 13, color: mutedText),
                            const SizedBox(width: 3),
                            Text(
                              '${event.gameTarget}게임',
                              style: TextStyle(color: mutedText, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // 상태 배지
                _buildStatusPill(event.status, statusColor),
              ],
            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(ClubEventStatus status, Color statusColor) {
    final icon = switch (status) {
      ClubEventStatus.scheduled => Symbols.schedule,
      ClubEventStatus.inProgress => Symbols.play_circle,
      ClubEventStatus.completed => Symbols.check_circle,
      ClubEventStatus.cancelled => Symbols.cancel,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: statusColor),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateBlock(ClubEvent event, bool isDark) {
    final (month, day) = event.dateComponents;
    final timeStr = event.formattedTime;

    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$month월',
            style: TextStyle(
              color: AppColors.primary.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            '$day',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
          if (timeStr != null)
            Text(
              timeStr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primary.withValues(alpha: 0.7),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
        ],
      ),
    );
  }

  Color _statusColor(ClubEventStatus status) {
    switch (status) {
      case ClubEventStatus.scheduled:
        return AppColors.primary;
      case ClubEventStatus.inProgress:
        return const Color(0xFFE8860A);
      case ClubEventStatus.completed:
        return const Color(0xFF16A34A);
      case ClubEventStatus.cancelled:
        return const Color(0xFFDC2626);
    }
  }
}
