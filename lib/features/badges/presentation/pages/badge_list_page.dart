import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/api_error.dart';
import '../../../../core/errors/api_error_classifier.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/widgets/error_retry_view.dart';
import '../../data/models/badge_item.dart';
import '../../data/services/badges_api_service.dart';

/// 사용자가 획득한/잠긴 배지를 카테고리별로 보여주는 페이지.
///
/// [highlightKey]가 주어지면 해당 배지가 첫 화면에 노출되도록 카드 강조.
class BadgeListPage extends StatefulWidget {
  final String? highlightKey;
  const BadgeListPage({super.key, this.highlightKey});

  @override
  State<BadgeListPage> createState() => _BadgeListPageState();
}

class _BadgeListPageState extends State<BadgeListPage> {
  final BadgesApiService _api = BadgesApiService();
  List<BadgeItem> _items = [];
  bool _isLoading = true;
  ApiError? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _api.fetchAll();
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
        _error = null;
      });
    } catch (e, st) {
      final err = ApiErrorClassifier.from(e, st);
      if (err.type != ApiErrorType.unauthorized) {
        AppLogger.captureError(e, stackTrace: st, context: 'badge_list_load');
      }
      if (!mounted) return;
      setState(() {
        _error = err;
        _isLoading = false;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary = isDark ? Colors.white : AppColors.textPrimaryLight;

    final earnedCount = _items.where((b) => b.earned).length;
    final totalCount = _items.length;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '배지',
          style: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _items.isEmpty
                ? ErrorRetryView(error: _error!, onRetry: _retry)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _buildBody(isDark, earnedCount, totalCount),
                  ),
      ),
    );
  }

  Widget _buildBody(bool isDark, int earned, int total) {
    final groups = <BadgeCategory, List<BadgeItem>>{};
    for (final item in _items) {
      groups.putIfAbsent(item.category, () => []).add(item);
    }
    // 카테고리 표시 순서 — enum 정의 순서 보존.
    final orderedCategories = BadgeCategory.values
        .where((c) => groups.containsKey(c))
        .toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryHeader(isDark, earned, total),
          const SizedBox(height: 20),
          for (final cat in orderedCategories) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                cat.label,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.4,
              children: groups[cat]!
                  .map((b) => _buildBadgeCard(b, isDark))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(bool isDark, int earned, int total) {
    final surface = isDark ? AppColors.surfaceDark : Colors.white;
    final border = isDark ? Colors.white10 : Colors.black12;
    final ratio = total == 0 ? 0.0 : earned / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Symbols.emoji_events,
                color: Colors.amber, size: 32, fill: 1),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$earned / $total 배지 획득',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.white10 : Colors.black12,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(BadgeItem b, bool isDark) {
    final isHighlight = widget.highlightKey == b.key;
    final surface = isDark ? AppColors.surfaceDark : Colors.white;
    final border = isHighlight
        ? AppColors.primary
        : (isDark ? Colors.white10 : Colors.black12);
    final iconColor = b.earned ? _categoryColor(b.category) : Colors.grey;
    final titleColor = b.earned
        ? (isDark ? Colors.white : AppColors.textPrimaryLight)
        : (isDark ? Colors.white38 : Colors.black38);
    final subColor = b.earned
        ? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)
        : (isDark ? Colors.white24 : Colors.black26);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: border,
          width: isHighlight ? 2 : 1,
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
            child: Icon(
              _categoryIcon(b.category),
              color: iconColor,
              size: 22,
              fill: b.earned ? 1 : 0,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  b.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  b.earned && b.earnedAt != null
                      ? DateFormat('yyyy.MM.dd').format(b.earnedAt!.toLocal())
                      : b.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: subColor,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(BadgeCategory c) {
    switch (c) {
      case BadgeCategory.milestone:
        return Symbols.flag;
      case BadgeCategory.score:
        return Symbols.scoreboard;
      case BadgeCategory.strike:
        return Symbols.bolt;
      case BadgeCategory.series:
        return Symbols.timeline;
      case BadgeCategory.streak:
        return Symbols.local_fire_department;
      case BadgeCategory.club:
        return Symbols.groups;
      case BadgeCategory.unknown:
        return Symbols.workspace_premium;
    }
  }

  Color _categoryColor(BadgeCategory c) {
    switch (c) {
      case BadgeCategory.milestone:
        return AppColors.primary;
      case BadgeCategory.score:
        return Colors.amber;
      case BadgeCategory.strike:
        return Colors.blue;
      case BadgeCategory.series:
        return Colors.purple;
      case BadgeCategory.streak:
        return Colors.deepOrange;
      case BadgeCategory.club:
        return Colors.teal;
      case BadgeCategory.unknown:
        return Colors.grey;
    }
  }
}
