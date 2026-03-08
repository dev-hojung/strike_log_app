import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/services/game_api_service.dart';
import '../../../home/data/models/home_dashboard_data.dart';

/// 사용자의 과거 볼링 경기 기록 목록을 보여주는 페이지입니다.
class GameHistoryPage extends StatefulWidget {
  const GameHistoryPage({super.key});

  @override
  State<GameHistoryPage> createState() => _GameHistoryPageState();
}

class _GameHistoryPageState extends State<GameHistoryPage> {
  final GameApiService _apiService = GameApiService();
  late Future<List<RecentGame>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  void _fetchHistory() {
    setState(() {
      _historyFuture = _loadUserIdAndFetchHistory();
    });
  }

  Future<List<RecentGame>> _loadUserIdAndFetchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return [];
    return _apiService.fetchGameHistory(userId);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '경기 기록',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _fetchHistory();
          await _historyFuture;
        },
        child: FutureBuilder<List<RecentGame>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('오류가 발생했습니다: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState(isDark);
            }

            final history = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                return _buildHistoryItem(context, history[index], isDark);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Symbols.history,
            size: 64,
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          const SizedBox(height: 16),
          Text(
            '아직 기록된 경기가 없습니다.',
            style: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '새 게임을 시작하고 기록을 남겨보세요!',
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, RecentGame game, bool isDark) {
    final formattedDate = DateFormat('yyyy. MM. dd').format(game.playDate);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: InkWell(
        onTap: () {
          // TODO: 경기 상세 페이지로 이동
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 점수 표시 영역
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${game.totalScore}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 정보 표시 영역
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.location ?? '장소 정보 없음',
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Symbols.chevron_right,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
