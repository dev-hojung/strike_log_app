import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/help_content.dart';

/// 앱 사용 가이드 + 볼링 용어 사전.
///
/// 탭 2개:
/// 1. 사용 가이드 — 카테고리별 ExpansionTile
/// 2. 볼링 용어 — 검색바 + 가나다순 카드 리스트
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        appBar: AppBar(
          title: const Text('도움말'),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            tabs: const [
              Tab(text: '사용 가이드'),
              Tab(text: '볼링 용어'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _GuideTab(),
            _TermsTab(),
          ],
        ),
      ),
    );
  }
}

class _GuideTab extends StatelessWidget {
  const _GuideTab();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: kHelpGuideSections.length,
      itemBuilder: (_, sectionIdx) {
        final section = kHelpGuideSections[sectionIdx];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _sectionCard(isDark, section),
        );
      },
    );
  }

  Widget _sectionCard(bool isDark, HelpGuideSection section) {
    final border = isDark ? Colors.white12 : Colors.black12;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        // 기본 ExpansionTile divider 라인을 카드 모서리에 맞춰 숨김.
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          section.title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: section.items
            .map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _TermsTab extends StatefulWidget {
  const _TermsTab();

  @override
  State<_TermsTab> createState() => _TermsTabState();
}

class _TermsTabState extends State<_TermsTab> {
  String _query = '';

  List<BowlingTerm> get _filtered {
    if (_query.isEmpty) return kBowlingTerms;
    final q = _query.toLowerCase();
    return kBowlingTerms.where((t) {
      return t.term.toLowerCase().contains(q) ||
          (t.english?.toLowerCase().contains(q) ?? false) ||
          t.description.toLowerCase().contains(q) ||
          (t.symbol?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final primaryText =
        isDark ? Colors.white : AppColors.textPrimaryLight;
    final terms = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            style: TextStyle(color: primaryText),
            decoration: InputDecoration(
              hintText: '용어 검색…',
              hintStyle: TextStyle(color: mutedText, fontSize: 14),
              prefixIcon: Icon(Symbols.search, color: mutedText),
              filled: true,
              fillColor: isDark ? AppColors.surfaceDark : Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),
        Expanded(
          child: terms.isEmpty
              ? Center(
                  child: Text(
                    '검색 결과가 없습니다.',
                    style: TextStyle(color: mutedText),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: terms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _termCard(terms[i], isDark, primaryText, mutedText),
                ),
        ),
      ],
    );
  }

  Widget _termCard(BowlingTerm t, bool isDark, Color primaryText, Color mutedText) {
    final border = isDark ? Colors.white12 : Colors.black12;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (t.symbol != null) ...[
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    t.symbol!,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  t.term,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (t.english != null) ...[
                const SizedBox(width: 6),
                Text(
                  '· ${t.english!}',
                  style: TextStyle(color: mutedText, fontSize: 12),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t.description,
            style: TextStyle(
              color: mutedText,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
