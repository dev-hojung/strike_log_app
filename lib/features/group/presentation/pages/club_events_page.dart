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
      floatingActionButton: widget.canManage
          ? FloatingActionButton.extended(
              onPressed: _openCreate,
              backgroundColor: AppColors.primary,
              icon: const Icon(Symbols.add, color: Colors.white),
              label: const Text(
                '정기전 만들기',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_scheduled, isDark),
                _buildList(_inProgress, isDark),
                _buildList(_completed, isDark),
              ],
            ),
    );
  }

  Widget _buildList(List<ClubEvent> events, bool isDark) {
    if (events.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 80),
          children: [
            Center(
              child: Text(
                '정기전이 없어요.',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontSize: 15,
                ),
              ),
            ),
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

  Widget _buildEventCard(ClubEvent event, bool isDark) {
    final surface = isDark ? AppColors.surfaceDark : Colors.white;
    final border = isDark ? Colors.white12 : Colors.black12;
    final primaryText = isDark ? Colors.white : AppColors.textPrimaryLight;
    final mutedText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final statusColor = _statusColor(event.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetail(event),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              // 날짜 세로 블럭
              _buildDateBlock(event.eventDate, isDark),
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
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Symbols.group, size: 14, color: mutedText),
                        const SizedBox(width: 4),
                        Text(
                          '${event.participantCount}명',
                          style: TextStyle(color: mutedText, fontSize: 12),
                        ),
                        if (event.gameTarget != null) ...[
                          Text(' · ', style: TextStyle(color: mutedText, fontSize: 12)),
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
              // 상태 배지
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  event.status.label,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateBlock(String eventDate, bool isDark) {
    // eventDate: 'YYYY-MM-DD'
    final parts = eventDate.split('-');
    final month = parts.length >= 2 ? parts[1] : '';
    final day = parts.length >= 3 ? parts[2] : '';

    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            month,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            day,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.1,
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
        return Colors.orange;
      case ClubEventStatus.completed:
        return Colors.green;
      case ClubEventStatus.cancelled:
        return Colors.redAccent;
    }
  }
}
