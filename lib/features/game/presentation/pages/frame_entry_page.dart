import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/constants/app_colors.dart';

/// 볼링 게임의 점수를 입력하는 페이지입니다.
///
/// 사용자는 이 페이지에서 각 프레임의 투구 결과를 입력하고,
/// 실시간으로 총점과 프레임별 점수를 확인할 수 있습니다.
/// 다크 테마를 기반으로 한 디자인이 적용되어 있습니다.
class FrameEntryPage extends StatelessWidget {
  const FrameEntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 디자인 레퍼런스에 따라 다크 모드 색상을 강제로 적용하거나 시스템 테마에 맞춥니다.
    // 현재는 레퍼런스 디자인이 다크 모드이므로 true로 설정합니다.
    final isDark = true; 
    
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back, color: Colors.white), 
          onPressed: () => Navigator.pop(context)
        ),
        title: const Text('1게임', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Symbols.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // 총점 표시 영역 (Total Score Section)
          Column(
            children: [
              Text(
                '86',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '총점',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondaryDark,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // 프레임 스크롤 영역 (Frame Scroll Section)
          // 가로 스크롤을 통해 1~10 프레임의 점수 상황을 보여줍니다.
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: 10,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final isCurrent = index == 4; // 현재 진행 중인 프레임 (임시 값)
                final frameNum = index + 1;
                
                return Container(
                  width: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent 
                          ? AppColors.primary 
                          : AppColors.primary.withOpacity(0.2),
                      width: isCurrent ? 2 : 1,
                    ),
                    boxShadow: isCurrent 
                        ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))] 
                        : null,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Stack(
                    children: [
                      // 프레임 번호 (Frame Number)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: Text(
                          '$frameNum',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      ),
                      // 투구 결과 (Throws - Top Right)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                             Text(
                                index < 4 ? 'X' : (index == 4 ? '' : ''),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                             if (index == 4) ...[
                               Container(
                                 width: 14,
                                 height: 20,
                                 alignment: Alignment.center,
                                 decoration: BoxDecoration(
                                   color: AppColors.surfaceDark,
                                   borderRadius: BorderRadius.circular(4),
                                 ),
                                 child: const Text('8', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                               ),
                               const SizedBox(width: 2),
                               Container(
                                 width: 14,
                                 height: 20,
                                 alignment: Alignment.center,
                                 decoration: BoxDecoration(
                                   color: AppColors.surfaceDark,
                                   borderRadius: BorderRadius.circular(4),
                                 ),
                                 child: const Text('', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                               ),
                             ]
                          ],
                        ),
                      ),
                      // 누적 점수 (Cumulative Score - Bottom Center)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            index < 5 ? '${(index + 1) * 15}' : '',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          const Spacer(),
          
          // 키패드 영역 (Keypad Section)
          // 점수 입력을 위한 숫자 및 특수 키(스트라이크, 스페어 등)를 제공합니다.
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildKeypadRow(['1', '2', '3']),
                const SizedBox(height: 16),
                _buildKeypadRow(['4', '5', '6']),
                const SizedBox(height: 16),
                _buildKeypadRow(['7', '8', '9']),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildKey('X', color: AppColors.primary, isAction: true),
                    _buildKey('0'),
                    _buildKey('/', color: AppColors.primary, isAction: true),
                  ],
                ),
                const SizedBox(height: 20), // 하단 패딩
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 키패드의 한 행을 생성하는 위젯입니다.
  ///
  /// [keys] 리스트에 포함된 키 라벨들을 가로로 배치합니다.
  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: keys.map((k) => _buildKey(k)).toList(),
    );
  }

  /// 개별 키 버튼을 생성하는 위젯입니다.
  ///
  /// [label]은 버튼에 표시될 텍스트입니다.
  /// [isAction]이 true일 경우, 일반 숫자 키와 다른 스타일(색상 등)이 적용됩니다.
  /// [color]는 텍스트 또는 강조 색상을 지정합니다.
  Widget _buildKey(String label, {bool isAction = false, Color? color}) {
    // 화면 너비에 반응하여 버튼 크기를 조절하기 위해 Expanded를 사용합니다.
    
    return Expanded(
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Material(
          color: isAction ? (color?.withOpacity(0.15)) : const Color(0xFF111721),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {},
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: isAction ? FontWeight.bold : FontWeight.w500,
                  color: isAction ? color : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
