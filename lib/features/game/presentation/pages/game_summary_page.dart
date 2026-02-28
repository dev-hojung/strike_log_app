import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/constants/app_colors.dart';

/// 볼링 게임 종료 후 결과를 보여주는 요약 페이지입니다.
///
/// 주요 기능:
/// - 총점(Total Score) 및 게임 날짜 표시
/// - 스코어카드(Scorecard) 상세 내역 표시
/// - 주요 통계(스트라이크, 스페어, 오픈 수) 표시
/// - 게임 저장 및 공유 기능 제공
class GameSummaryPage extends StatelessWidget {
  const GameSummaryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Symbols.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('게임 요약', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 24),
            // 총점 헤더
            const Text('총점', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const Text('237', style: TextStyle(color: AppColors.primary, fontSize: 64, fontWeight: FontWeight.bold, height: 1)),
            const SizedBox(height: 8),
            // 비교 및 날짜 정보
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Text('평균 대비 +12', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                const Text('2023년 10월 24일', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 32),
            // 스코어카드 상세
            _buildScorecard(isDark),
            const SizedBox(height: 32),
            // 게임 통계 섹션 제목
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('게임 통계', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
            const SizedBox(height: 16),
            // 통계 박스 목록
            Row(
              children: [
                _buildStatBox('7', '스트라이크', Symbols.sports_golf, Colors.blue, isDark),
                const SizedBox(width: 12),
                _buildStatBox('3', '스페어', Symbols.north_east, Colors.purple, isDark),
                const SizedBox(width: 12),
                _buildStatBox('1', '오픈', Symbols.remove_circle_outline, Colors.amber, isDark),
              ],
            ),
            const SizedBox(height: 48),
            // 저장 및 공유 버튼
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  /// 프레임별 점수를 보여주는 스코어카드 위젯입니다.
  ///
  /// 1~10 프레임의 점수를 그리드 형태로 표시합니다.
  Widget _buildScorecard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Text('스코어카드', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, childAspectRatio: 1),
            itemCount: 10,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                  color: index == 9 ? AppColors.primary.withOpacity(0.1) : null,
                ),
                padding: const EdgeInsets.all(4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Align(alignment: Alignment.topLeft, child: Text('${index + 1}', style: const TextStyle(color: Colors.grey, fontSize: 10))),
                    const Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text('X', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))]),
                    Text('${(index + 1) * 20}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: index == 9 ? AppColors.primary : null)),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  /// 게임 저장 및 공유 버튼을 포함하는 위젯입니다.
  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Symbols.save, color: Colors.white),
            label: const Text('게임 저장', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity, height: 56,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Symbols.ios_share),
            label: const Text('점수 공유', style: TextStyle(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          ),
        ),
      ],
    );
  }
}
