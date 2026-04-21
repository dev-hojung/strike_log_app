import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/unread_notifications_service.dart';
import '../../data/models/notification_item.dart';
import '../../data/services/notifications_api_service.dart';

/// 알림 페이지.
///
/// 표시 대상 이벤트:
/// - 클럽 게임 생성/초대
/// - 클럽 가입 신청 및 승인/거절
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationsApiService _api = NotificationsApiService();

  List<NotificationItem> _items = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final list = await _api.fetchList(userId);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!mounted) return;
    setState(() {
      _userId = userId;
      _items = list;
      _isLoading = false;
    });
  }

  Future<void> _markAllAsRead() async {
    final userId = _userId;
    if (userId == null || _items.every((n) => n.isRead)) return;
    final ok = await _api.markAllAsRead(userId);
    if (!ok || !mounted) return;
    setState(() {
      _items = _items.map((n) => n.copyWith(isRead: true)).toList();
    });
    UnreadNotificationsService.instance.reset();
  }

  Future<void> _onTapItem(NotificationItem item) async {
    if (!item.isRead) {
      final ok = await _api.markAsRead(item.id);
      if (ok && mounted) {
        setState(() {
          final idx = _items.indexWhere((n) => n.id == item.id);
          if (idx >= 0) _items[idx] = item.copyWith(isRead: true);
        });
        UnreadNotificationsService.instance.decrement();
      }
    }
    // TODO: 타입별 네비게이션 (게임 상세 / 클럽 관리 페이지)
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUnread = _items.any((n) => !n.isRead);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '알림',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
        centerTitle: true,
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('모두 읽음',
                  style: TextStyle(color: AppColors.primary)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmpty(isDark)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _buildItem(context, _items[i], isDark),
                  ),
                ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 120),
        Container(
          width: 88,
          height: 88,
          margin: const EdgeInsets.symmetric(horizontal: 120),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Symbols.notifications_off,
            size: 40,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '새로운 알림이 없어요',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '게임 초대와 클럽 가입 소식을 여기서 확인할 수 있어요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildItem(
      BuildContext context, NotificationItem item, bool isDark) {
    final icon = _iconFor(item.type);
    final iconColor = _iconColorFor(item.type);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onTapItem(item),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.isRead
                ? (isDark ? AppColors.surfaceDark : Colors.white)
                : AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: item.isRead
                  ? (isDark ? Colors.white10 : Colors.black12)
                  : AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: item.isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8, top: 6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (item.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _relativeTime(item.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(NotificationType t) {
    switch (t) {
      case NotificationType.clubGameCreated:
        return Symbols.sports_score;
      case NotificationType.clubJoinRequest:
        return Symbols.person_add;
      case NotificationType.clubJoinApproved:
        return Symbols.check_circle;
      case NotificationType.clubJoinRejected:
        return Symbols.cancel;
      case NotificationType.unknown:
        return Symbols.notifications;
    }
  }

  Color _iconColorFor(NotificationType t) {
    switch (t) {
      case NotificationType.clubGameCreated:
        return AppColors.primary;
      case NotificationType.clubJoinRequest:
        return Colors.orange;
      case NotificationType.clubJoinApproved:
        return Colors.green;
      case NotificationType.clubJoinRejected:
        return Colors.redAccent;
      case NotificationType.unknown:
        return Colors.grey;
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}
