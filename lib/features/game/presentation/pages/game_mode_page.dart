import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_client.dart';
import '../../data/services/series_api_service.dart';
import 'frame_entry_page.dart';
import 'game_room_page.dart';
import '../widgets/location_input_dialog.dart';

/// 게임 모드 선택 페이지
///
/// - 개인 게임: 혼자 점수 기록 (단일)
/// - 시리즈 게임: 한 세션의 여러 게임을 묶어 기록 (3/6게임 기본 옵션)
/// - 클럽 게임: 소켓으로 방 생성, 여러 유저가 참가하여 점수 입력
class GameModePage extends StatefulWidget {
  const GameModePage({super.key});

  @override
  State<GameModePage> createState() => _GameModePageState();
}

class _GameModePageState extends State<GameModePage> {
  // 클럽 게임은 클럽 구독(체험 또는 정식)이 활성일 때만 노출.
  // 서버 game-rooms 게이트 / ClubAccessGuard와 동일 기준(subscription_status).
  // 내기/시리즈/개인은 누구나 사용 가능.
  bool _clubAccessActive = false;

  @override
  void initState() {
    super.initState();
    _loadClubAccess();
  }

  /// 가입한 클럽 중 구독이 유효한(active, 또는 trial이고 만료 전) 클럽이 있으면 클럽 게임 노출.
  Future<void> _loadClubAccess() async {
    try {
      final res = await ApiClient().dio.get('/groups/me');
      final data = res.data;
      bool active = false;
      if (data is List) {
        final now = DateTime.now();
        for (final raw in data) {
          if (raw is! Map) continue;
          final status = raw['subscription_status']?.toString();
          if (status == 'active') {
            active = true;
            break;
          }
          if (status == 'trial') {
            final exp =
                DateTime.tryParse(raw['trial_expires_at']?.toString() ?? '');
            if (exp != null && exp.isAfter(now)) {
              active = true;
              break;
            }
          }
        }
      }
      if (mounted && active != _clubAccessActive) {
        setState(() => _clubAccessActive = active);
      }
    } catch (_) {
      // 조회 실패 시 클럽 카드는 숨김 유지 (안전 기본값).
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '새 게임',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          // iPad/소형 화면에서 카드 4개가 세로로 넘쳐 하단이 잘리던 문제 대응:
          // 고정 Column 대신 스크롤 가능하게 하고 하단 여백을 SafeArea로 확보.
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              '게임 모드를 선택하세요',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '혼자 기록하거나, 클럽 멤버들과 함께 플레이하세요.',
              style: TextStyle(
                fontSize: 14,
                color: subTextColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),

            // 개인 게임
            _buildModeCard(
              context,
              icon: Symbols.person,
              title: '개인 게임',
              description: '혼자서 게임 점수를 기록합니다.',
              iconBgColor: AppColors.primary.withValues(alpha: 0.1),
              iconColor: AppColors.primary,
              isDark: isDark,
              onTap: () async {
                final location = await showLocationInputDialog(context);
                if (location != null && context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FrameEntryPage(isClubGame: false, location: location),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),

            // 시리즈 게임 (3/6 게임 묶음)
            _buildModeCard(
              context,
              icon: Symbols.format_list_numbered,
              title: '시리즈 게임',
              description: '여러 게임을 묶어 합계/평균으로 기록합니다.',
              iconBgColor: const Color(0xFFFF9800).withValues(alpha: 0.1),
              iconColor: const Color(0xFFFF9800),
              isDark: isDark,
              onTap: () => _startSeriesFlow(context),
            ),
            const SizedBox(height: 16),

            // 클럽 게임 (클럽 구독이 활성일 때만 노출)
            if (_clubAccessActive) ...[
              _buildModeCard(
                context,
                icon: Symbols.groups,
                title: '클럽 게임',
                description: '방을 만들어 클럽 멤버들과 함께 점수를 기록합니다.',
                iconBgColor: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                iconColor: const Color(0xFF4CAF50),
                isDark: isDark,
                onTap: () => _startClubGame(context),
              ),
              const SizedBox(height: 16),
            ],

            // 내기 게임
            _buildModeCard(
              context,
              icon: Symbols.casino,
              title: '내기 게임',
              description: '핸디캡을 정하고 친구들과 한 판 — 1등·꼴찌를 가립니다.',
              iconBgColor: const Color(0xFFC084FC).withValues(alpha: 0.1),
              iconColor: const Color(0xFFC084FC),
              isDark: isDark,
              onTap: () => _startBetGame(context),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startSeriesFlow(BuildContext context) async {
    final count = await _pickSeriesGameCount(context);
    if (count == null) return;
    if (!context.mounted) return;

    final location = await showLocationInputDialog(context);
    if (location == null) return;
    if (!context.mounted) return;

    // 시리즈 시작 API 호출.
    final messenger = ScaffoldMessenger.of(context);
    int? seriesId;
    try {
      seriesId = await SeriesApiService().startSeries(
        targetGameCount: count,
        startedAt: DateTime.now(),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('시리즈 시작에 실패했습니다: $e')),
      );
      return;
    }

    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FrameEntryPage(
          isClubGame: false,
          location: location,
          seriesId: seriesId,
          seriesIndex: 1,
          targetGameCount: count,
        ),
      ),
    );
  }

  Future<int?> _pickSeriesGameCount(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '몇 게임을 칠 예정인가요?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '시리즈는 게임을 묶어 합계와 평균을 기록합니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                for (final c in const [3, 6])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _seriesCountTile(ctx, c, isDark),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                          color:
                              isDark ? Colors.white24 : Colors.black26),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final custom = await _pickCustomCount(ctx);
                      if (custom != null && ctx.mounted) {
                        Navigator.pop(ctx, custom);
                      }
                    },
                    child: Text(
                      '직접 입력',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _seriesCountTile(BuildContext context, int count, bool isDark) {
    return InkWell(
      onTap: () => Navigator.pop(context, count),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          color: AppColors.primary.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            Icon(Symbols.sports_score, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Text(
              '$count게임 시리즈',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<int?> _pickCustomCount(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('게임 수 직접 입력'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '예: 4',
            counterText: '',
          ),
          maxLength: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text);
              if (v == null || v < 1 || v > 20) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('1~20 사이 값으로 입력해주세요.')),
                );
                return;
              }
              Navigator.pop(ctx, v);
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _startBetGame(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
      }
      return;
    }

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const GameRoomPage(mode: 'bet'),
        ),
      );
    }
  }

  Future<void> _startClubGame(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
      }
      return;
    }

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const GameRoomPage(),
        ),
      );
    }
  }

  Widget _buildModeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color iconBgColor,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black12,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: subTextColor,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Symbols.chevron_right, color: subTextColor, size: 20),
          ],
        ),
      ),
    );
  }
}
