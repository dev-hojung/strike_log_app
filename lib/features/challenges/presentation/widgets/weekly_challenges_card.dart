import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/weekly_challenge.dart';

class WeeklyChallengesCard extends StatelessWidget {
  final List<WeeklyChallenge> challenges;
  final bool isDark;

  const WeeklyChallengesCard({
    super.key,
    required this.challenges,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (challenges.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.flag, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                '이번 주 챌린지',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'KST 월~일 기준 자동 집계',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.55)
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < challenges.length; i++) ...[
            _ChallengeRow(challenge: challenges[i], isDark: isDark),
            if (i != challenges.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  final WeeklyChallenge challenge;
  final bool isDark;

  const _ChallengeRow({required this.challenge, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final achieved = challenge.achieved;
    final progressColor = achieved ? Colors.greenAccent : AppColors.primary;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                challenge.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            if (achieved)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Symbols.check_circle,
                    color: Colors.greenAccent, size: 16),
              ),
            Text(
              '${challenge.current}/${challenge.target} ${challenge.unit}',
              style: TextStyle(
                fontSize: 12,
                color: textColor.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          challenge.description,
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? Colors.white.withValues(alpha: 0.55)
                : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: (challenge.percent / 100).clamp(0.0, 1.0),
            backgroundColor:
                progressColor.withValues(alpha: isDark ? 0.18 : 0.12),
            valueColor: AlwaysStoppedAnimation(progressColor),
          ),
        ),
      ],
    );
  }
}
