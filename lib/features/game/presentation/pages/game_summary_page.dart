import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_client.dart';
import 'package:intl/intl.dart';

/// 볼링 게임 종료 후 결과를 보여주는 요약 페이지입니다.
///
/// 주요 기능:
/// - 총점(Total Score) 및 게임 날짜 표시
/// - 스코어카드(Scorecard) 상세 내역 표시
/// - 주요 통계(스트라이크, 스페어, 오픈 수) 표시
/// - 게임 저장 기능 제공
class GameSummaryPage extends StatefulWidget {
  final List<List<int>> frames;
  final List<int?> cumulativeScores;
  final int totalScore;
  final int strikeCount;
  final int spareCount;
  final int openCount;
  final String? location;

  const GameSummaryPage({
    super.key,
    required this.frames,
    required this.cumulativeScores,
    required this.totalScore,
    required this.strikeCount,
    required this.spareCount,
    required this.openCount,
    this.location,
  });

  @override
  State<GameSummaryPage> createState() => _GameSummaryPageState();
}

class _GameSummaryPageState extends State<GameSummaryPage> {
  bool _isSaving = false;

  String _getThrowDisplay(int frameIndex, int throwIndex) {
    final frame = widget.frames[frameIndex];
    if (throwIndex >= frame.length) return '';

    final pins = frame[throwIndex];

    if (frameIndex < 9) {
      if (throwIndex == 0 && pins == 10) return 'X';
      if (throwIndex == 1 && frame[0] + pins == 10) return '/';
    } else {
      // 10프레임
      if (throwIndex == 0 && pins == 10) return 'X';
      if (throwIndex == 1) {
        if (frame[0] == 10 && pins == 10) return 'X';
        if (frame[0] == 10) return pins == 0 ? '-' : '$pins';
        if (frame[0] + pins == 10) return '/';
      }
      if (throwIndex == 2) {
        if (pins == 10) return 'X';
        // 2투 후 스페어 체크
        if (throwIndex == 2 && frame.length == 3) {
          if (frame[1] != 10 && frame[0] == 10 && frame[1] + pins == 10) return '/';
          if (frame[0] + frame[1] == 10 && pins == 10) return 'X';
        }
      }
    }

    return pins == 0 ? '-' : '$pins';
  }

  Future<void> _saveGame() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id'); 

      if (userId == null) {
        throw Exception('로그인된 사용자 정보가 없습니다.');
      }

      // API가 요구하는 형식에 맞게 프레임 데이터 매핑
      final mappedFrames = [];
      for (int i = 0; i < widget.frames.length; i++) {
        final frame = widget.frames[i];
        if (frame.isNotEmpty) {
          mappedFrames.add({
            'frame_number': i + 1,
            'first_roll': frame.isNotEmpty ? frame[0] : null,
            'second_roll': frame.length > 1 ? frame[1] : null,
            'third_roll': frame.length > 2 ? frame[2] : null,
            'score': widget.cumulativeScores[i] ?? 0,
          });
        }
      }

      // API 호출
      final response = await ApiClient().dio.post('/games', data: {
        'user_id': userId,
        'total_score': widget.totalScore,
        'play_date': DateTime.now().toIso8601String(),
        if (widget.location != null && widget.location!.isNotEmpty) 'location': widget.location,
        'frames': mappedFrames,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('게임이 성공적으로 저장되었습니다.')),
          );
          // 홈 화면 등으로 이동 (여기서는 뒤로 2번 가서 홈으로 간다고 가정)
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        throw Exception('Failed to save game');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy년 MM월 dd일').format(now);
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: textColor),
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
        title: Text(
          '경기 요약',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // 최종 점수 헤더
                  const Text(
                    '최종 점수',
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.totalScore}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 날짜 정보
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // 스코어카드 상세
                  _buildScorecard(isDark),
                  const SizedBox(height: 40),
                  
                  // 경기 통계 섹션 제목
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '경기 통계',
                      style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 통계 박스 목록
                  Row(
                    children: [
                      _buildStatBox('${widget.strikeCount}', '스트라이크', Symbols.sports_golf, Colors.blue, isDark),
                      const SizedBox(width: 12),
                      _buildStatBox('${widget.spareCount}', '스페어', Symbols.north_east, Colors.purple, isDark),
                      const SizedBox(width: 12),
                      _buildStatBox('${widget.openCount}', '오픈', Symbols.remove_circle_outline, Colors.amber, isDark),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          
          // 하단 버튼 고정 영역
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: _buildActionButtons(),
            ),
          ),
        ],
      ),
    ));
  }

  /// 프레임별 점수를 보여주는 스코어카드 위젯입니다.
  ///
  /// 1~10 프레임의 점수를 그리드 형태로 표시합니다.
  Widget _buildScorecard(bool isDark) {
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.black12;
    
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: const Text(
              '스코어카드',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 0.9,
            ),
            itemCount: 10,
            itemBuilder: (context, index) {
              final scoreText = widget.cumulativeScores[index]?.toString() ?? '';
              final frameSlotCount = index == 9 ? 3 : 2;
              final isLastFrame = index == 9;

              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                  color: isLastFrame ? AppColors.primary.withOpacity(0.05) : null,
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: List.generate(frameSlotCount, (tIndex) {
                        final display = _getThrowDisplay(index, tIndex);
                        final isStrikeOrSpare = display == 'X' || display == '/';
                        return Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            display,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isStrikeOrSpare 
                                  ? AppColors.primary 
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        );
                      }),
                    ),
                    Text(
                      scoreText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isLastFrame 
                            ? AppColors.primary 
                            : (isDark ? Colors.white : AppColors.textPrimaryLight),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 게임의 주요 통계(스트라이크, 스페어 등)를 박스 형태로 보여주는 위젯입니다.
  Widget _buildStatBox(String value, String label, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 게임 저장 버튼을 포함하는 위젯입니다.
  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveGame,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                '경기 저장하기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
