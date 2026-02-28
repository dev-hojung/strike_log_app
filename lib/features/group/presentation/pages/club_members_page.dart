import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/constants/app_colors.dart';

/// 클럽의 멤버 목록을 보여주는 페이지입니다.
///
/// 주요 기능:
/// - 클럽 이름 및 리그 정보 표시
/// - 멤버 검색 기능
/// - 멤버 정렬 옵션 제공
/// - 현재 사용자와 다른 멤버들의 목록 및 평균 점수 표시
class ClubMembersPage extends StatelessWidget {
  const ClubMembersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.backgroundDark.withOpacity(0.8) : AppColors.backgroundLight.withOpacity(0.8),
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 70,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Symbols.sports_score, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '스트라이크 포스 클럽',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  '엘리트 리그',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.more_vert),
            onPressed: () {},
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar Area
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: '멤버 검색...',
                hintStyle: TextStyle(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Symbols.search,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                filled: true,
                fillColor: isDark ? AppColors.surfaceDark : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          
          // Members Count & Sort
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '멤버 (24)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    letterSpacing: 1.2,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '점수순 정렬',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Member List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Current User (Highlighted)
                _buildMemberItem(
                  context,
                  name: 'Sarah Chen',
                  avgScore: '210',
                  imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuD1kKXS6j0jr4jDMjLaUNQOc4HXxTq9bEw0Z8AL8oKda-KHKM_ki37tCdvYT1-VUmHwqEsE8euKRYDi9NaHaf4Bty1wOz-TrYjEJJDb0RIJPNheuHHYlvl__-mr7kdvhLroC-qDeeL2MvvYPxhzmy6YOnK3jXW4LuWOFJlb8P22SH-EE8LoXPaw5I41HUJaw3gTUPkW6UHSbLcW5fmtQIo137B1Bjag40gtd3I6tW1DwLbZzudKy9z4TLFMzcHqQdri3StsJwi6Y1zY',
                  isMe: true,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                
                // Other Members
                _buildMemberItem(
                  context,
                  name: 'Marcus Thorne',
                  avgScore: '198',
                  imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAT786m9AG8ftpnhSgj1lv2Fh774bfXILGxFz2P22XsejJ15XmxXg6do38py1-L4ggOHiNd55CxHcB4uBarYQ1JthC2kuHVxLkL3_iE95bP6bfT3BIPv38qYxNqizJpzyh83JFVhb6GxbUKTz6ty9yqwGRVIujV416wrYCjZQJ6e-wll_BpdU5zmf1nMji4J8s2o8nRXo-lgGCy9J-O21suA7PbhfvBDYPDl-9Gq6jyMPEF4wbblYh7nIkHxiNCPDNRmrjU1_gMYl9y',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                
                _buildMemberItem(
                  context,
                  name: 'Elena Rodriguez',
                  avgScore: '185',
                  imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCdE341sTCsYOftbNA17M8YwGooN5Eg377yqF8_P5xgooBxZvfP-AYTStpTiiGNjeLB0qZkBfeBwpARIdIkgCVled2kcm5MZKsys8er1kMfgcbTdpOlqRgs194WcCwlRedxgcJjRrIdoFOv4BwGg4UwDCiYRG8FEULteJQC9fOi7z_KSry1GVzCbbqCvasoNXwZAKvEsP6IGuk8HVy3uR3mLZviBSA1R9XScs715i_bCP6TQmmi3tlmfj0gOIbH1FobumVajWOD1wbZ',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                
                _buildMemberItem(
                  context,
                  name: 'James Wilson',
                  avgScore: '204',
                  imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAMAL2xIpB4PXmv1uz6nphBZi9VIndK5pSgVMEJiXtIZzJPPdWu8sWHVN_mp3Bm5ggKn5q6ZCllBSzmJg_clk6GcqzqPnWoqbgmCOrokEF811MBn3WZAiQ2r2aY2q9fBnHvKribSGfkGwsCcJsyFTGV50Au5owkskWC1YV4Gr9Rvt36xALMNaZlkdYO48so4gwRk7NtH_Nd9x5qC69tPJmH16NFolcFwRgcnztdpgl85BiCaqOeB6eDNYAG9TXSgHOsGrmsaFKHo40_',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                
                _buildMemberItem(
                  context,
                  name: 'Chloe Kim',
                  avgScore: '177',
                  imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDcZgr0SA4WGQFEtV9VcVaU_OPEHfr22O944bZdR-43BT6QFCtNy6ZXhMU0aqiboMl3JY2sJA7n-c_p8bCmYGWG8oH9nhXu9wlEF23M2yWiCzfR1QNy0riL9zPtP8v2W60n0ZxuSoFd1CTBMFKEoFo_RuAfaN1PmvI5XXnRu6FcJX7TJx6NQ77rUJMCLRWSNaMe_JiejfXw0_gdscVKI2lNCMslxOoNvMroQdz1l5sLz0apQFP2_CoThwW96-tjNKyk8bIvPKzbbjvn',
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                
                _buildMemberItem(
                  context,
                  name: 'David Park',
                  avgScore: '162',
                  imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuD4yztNf-dU0JBkhDrGcINw2Pbl-M40U0B81RetQ_7X6xFmBxI-3IswWv2Olo0xcNHiENc-4As804FhMt2dmP57_RMRclVEs31TPhJG6BLECt56B4sGtHH9Dy_4EgAoyv0EjhnDjrdC4Xz9g3NUqjZhWjDNFjnwelElosJr0FGNsRk2o3DEoWE7Fh5VWteSywjnyByUwDZmtqBfz0gY_plcPHo3cL_N0iXbBYmy41mzQubPwRQpZpH9mFAkyQGTV4n1lSLTn-krEYzL',
                  isDark: isDark,
                ),
                const SizedBox(height: 100), // Bottom padding
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 개별 멤버 아이템을 생성하는 위젯입니다.
  ///
  /// [isMe]가 true일 경우 강조 스타일(테두리, 뱃지 등)이 적용됩니다.
  Widget _buildMemberItem(
    BuildContext context, {
    required String name,
    required String avgScore,
    required String imageUrl,
    bool isMe = false,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMe 
            ? AppColors.primary.withOpacity(isDark ? 0.05 : 0.1) 
            : (isDark ? AppColors.surfaceDark : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe 
              ? AppColors.primary.withOpacity(0.4) 
              : (isDark ? Colors.white10 : Colors.black12),
          width: isMe ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Indicator line for current user
          if (isMe) ...[
            Container(
              height: 32,
              width: 4,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
          ],
          
          // Profile Image
          Stack(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isMe ? AppColors.primary : (isDark ? Colors.white10 : Colors.black12),
                    width: isMe ? 2 : 1,
                  ),
                  image: DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              if (isMe)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          
          // Member Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '나',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (isMe)
                      const Icon(Symbols.analytics, size: 16, color: AppColors.primary),
                    if (isMe) const SizedBox(width: 4),
                    Text(
                      '평균 점수: $avgScore',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isMe 
                            ? AppColors.primary 
                            : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Action Button
          if (isMe)
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: AppColors.primary.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: const Size(0, 36),
              ),
              child: const Text(
                '통계',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            )
          else
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary.withOpacity(0.05),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: AppColors.primary.withOpacity(isDark ? 0.4 : 0.2),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: const Size(0, 36),
              ),
              child: const Text(
                '통계 보기',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
