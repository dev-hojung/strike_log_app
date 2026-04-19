import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_client.dart';

/// 클럽 멤버 개인의 볼링 통계를 보여주는 페이지.
///
/// 두 API를 동시에 호출하여 통계 데이터를 구성합니다:
/// - `GET /games/users/:user_id/statistics` — 평균 점수, 최고 점수, 최근 트렌드, 월간 비교
/// - `GET /games/users/:user_id/monthly-frame-stats` — 이번 달 스트라이크/스페어/오픈/올커버
class MemberStatsPage extends StatefulWidget {
  final String userId;
  final String nickname;
  final bool isMe;

  const MemberStatsPage({
    super.key,
    required this.userId,
    required this.nickname,
    this.isMe = false,
  });

  @override
  State<MemberStatsPage> createState() => _MemberStatsPageState();
}

class _MemberStatsPageState extends State<MemberStatsPage> {
  bool _isLoading = true;
  String? _error;

  // statistics API
  int _averageScore = 0;
  int _highestScore = 0;
  List<Map<String, dynamic>> _recentTrend = [];
  Map<String, dynamic> _monthlyTrend = {};

  // monthly-frame-stats API
  int _strikes = 0;
  int _spares = 0;
  int _opens = 0;
  int _allCoverGames = 0;
  int _monthGameCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = ApiClient().dio;
      final results = await Future.wait([
        dio.get('/games/users/${widget.userId}/statistics'),
        dio.get('/games/users/${widget.userId}/monthly-frame-stats'),
      ]);

      final stats = results[0].data as Map<String, dynamic>;
      final frameStats = results[1].data as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _averageScore = (stats['averageScore'] as num?)?.toInt() ?? 0;
          _highestScore = (stats['highestScore'] as num?)?.toInt() ?? 0;
          _recentTrend = (stats['recentTrend'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];
          _monthlyTrend =
              Map<String, dynamic>.from(stats['monthlyTrend'] as Map? ?? {});

          _strikes = (frameStats['strikes'] as num?)?.toInt() ?? 0;
          _spares = (frameStats['spares'] as num?)?.toInt() ?? 0;
          _opens = (frameStats['opens'] as num?)?.toInt() ?? 0;
          _allCoverGames = (frameStats['allCoverGames'] as num?)?.toInt() ?? 0;
          _monthGameCount = (frameStats['gameCount'] as num?)?.toInt() ?? 0;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '통계를 불러오는데 실패했습니다.';
        });
      }
    }
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
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.nickname}${widget.isMe ? ' (나)' : ''}의 통계',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(isDark)
              : RefreshIndicator(
                  onRefresh: _fetchStats,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 핵심 통계 카드
                        _buildCoreStats(isDark),
                        const SizedBox(height: 24),
                        // 월간 프레임 통계
                        _buildSectionTitle('이번 달 프레임 통계', isDark),
                        const SizedBox(height: 12),
                        _buildFrameStats(isDark),
                        const SizedBox(height: 24),
                        // 월간 비교
                        if (_monthlyTrend['status'] != 'none') ...[
                          _buildSectionTitle('월간 비교', isDark),
                          const SizedBox(height: 12),
                          _buildMonthlyTrend(isDark),
                          const SizedBox(height: 24),
                        ],
                        // 최근 10경기 트렌드
                        if (_recentTrend.isNotEmpty) ...[
                          _buildSectionTitle('최근 경기 트렌드', isDark),
                          const SizedBox(height: 12),
                          _buildRecentTrend(isDark),
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Symbols.cloud_off,
              size: 48,
              color: isDark ? Colors.white38 : Colors.black26),
          const SizedBox(height: 16),
          Text(_error!,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              )),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _fetchStats,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  /// 평균 점수, 최고 점수, 이번 달 경기 수
  Widget _buildCoreStats(bool isDark) {
    return Row(
      children: [
        _buildStatCard(
          label: '평균 점수',
          value: '$_averageScore',
          icon: Symbols.equalizer,
          color: AppColors.primary,
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          label: '최고 점수',
          value: '$_highestScore',
          icon: Symbols.emoji_events,
          color: Colors.amber,
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          label: '이번 달',
          value: '$_monthGameCount경기',
          icon: Symbols.history,
          color: Colors.orange,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 이번 달 스트라이크/스페어/오픈/올커버
  Widget _buildFrameStats(bool isDark) {
    return Row(
      children: [
        _buildFrameChip('X', '$_strikes', Colors.blue, isDark),
        const SizedBox(width: 8),
        _buildFrameChip('/', '$_spares', Colors.purple, isDark),
        const SizedBox(width: 8),
        _buildFrameChip('-', '$_opens', Colors.amber, isDark),
        const SizedBox(width: 8),
        _buildFrameChip('올커버', '$_allCoverGames', Colors.green, isDark),
      ],
    );
  }

  Widget _buildFrameChip(
      String symbol, String count, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                symbol,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 월간 비교 (이번 달 vs 지난 달 평균)
  Widget _buildMonthlyTrend(bool isDark) {
    final status = _monthlyTrend['status']?.toString() ?? 'none';
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.black12;

    String message;
    Color trendColor;
    IconData trendIcon;

    if (status == 'both') {
      final current = _monthlyTrend['currentMonthAvg'] ?? 0;
      final last = _monthlyTrend['lastMonthAvg'] ?? 0;
      final percentage = (_monthlyTrend['percentage'] as num?)?.toDouble() ?? 0;
      final isUp = percentage >= 0;
      trendColor = isUp ? Colors.green : Colors.red;
      trendIcon = isUp ? Symbols.trending_up : Symbols.trending_down;
      message = '이번 달 평균 $current점 (지난 달 $last점 대비 ${isUp ? '+' : ''}${percentage.toStringAsFixed(1)}%)';
    } else if (status == 'current_only') {
      final current = _monthlyTrend['currentMonthAvg'] ?? 0;
      final count = _monthlyTrend['currentMonthGameCount'] ?? 0;
      trendColor = AppColors.primary;
      trendIcon = Symbols.equalizer;
      message = '이번 달 평균 $current점 ($count경기). 지난 달 데이터 없음.';
    } else if (status == 'last_only') {
      final last = _monthlyTrend['lastMonthAvg'] ?? 0;
      trendColor = AppColors.textSecondaryDark;
      trendIcon = Symbols.history;
      message = '이번 달 경기 없음. 지난 달 평균 $last점.';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: trendColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(trendIcon, color: trendColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 최근 10경기 점수 리스트
  Widget _buildRecentTrend(bool isDark) {
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.black12;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _recentTrend.length,
        separatorBuilder: (_, __) => Divider(
          color: isDark ? Colors.white10 : Colors.black12,
          height: 1,
          indent: 16,
          endIndent: 16,
        ),
        itemBuilder: (context, index) {
          final game = _recentTrend[index];
          final score = (game['score'] as num?)?.toInt() ?? 0;

          // 점수 색상 (평균 대비)
          Color scoreColor;
          if (_averageScore > 0 && score >= _averageScore + 20) {
            scoreColor = Colors.green;
          } else if (_averageScore > 0 && score <= _averageScore - 20) {
            scoreColor = Colors.red;
          } else {
            scoreColor = isDark ? Colors.white : AppColors.textPrimaryLight;
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // 순번
                SizedBox(
                  width: 28,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // 점수 바
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: (score / 300).clamp(0, 1).toDouble(),
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: scoreColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 점수
                SizedBox(
                  width: 40,
                  child: Text(
                    '$score',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
