import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/services/inquiry_api_service.dart';

/// 관리자에게 문의하는 폼 페이지.
/// 카테고리 / 제목 / 내용 / 회신 이메일(선택) 입력 후 POST /inquiries 호출.
///
/// [initialCategory]를 지정하면 카테고리 드롭다운의 초기값으로 설정된다.
/// 예: `InquiryPage(initialCategory: 'club_trial')`
class InquiryPage extends StatefulWidget {
  const InquiryPage({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  State<InquiryPage> createState() => _InquiryPageState();
}

class _InquiryPageState extends State<InquiryPage> {
  static const _categories = [
    ('general', '일반 문의'),
    ('club_trial', '클럽 구독'),
    ('bug', '버그 신고'),
  ];

  late String _category;
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final _contactEmailController = TextEditingController();
  bool _submitting = false;

  final _service = InquiryApiService();

  @override
  void initState() {
    super.initState();
    final valid = _categories.any((c) => c.$1 == widget.initialCategory);
    _category = valid ? widget.initialCategory! : 'general';
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    _contactEmailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectController.text.trim();
    final body = _bodyController.text.trim();
    final contactEmail = _contactEmailController.text.trim();

    if (subject.isEmpty) {
      _showSnackBar('제목을 입력해주세요.');
      return;
    }
    if (subject.length > 120) {
      _showSnackBar('제목은 120자 이하로 입력해주세요.');
      return;
    }
    if (body.isEmpty) {
      _showSnackBar('내용을 입력해주세요.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.submit(
        category: _category,
        subject: subject,
        body: body,
        contactEmail: contactEmail.isNotEmpty ? contactEmail : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('문의가 전송됐습니다. 빠른 시일 내 답변드릴게요.'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('전송에 실패했어요. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 문의 카테고리를 전체 폭 바텀시트로 띄워 하나를 고른다.
  Future<String?> _pickCategory({
    required Color surfaceColor,
    required Color textColor,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Text(
                  '카테고리 선택',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              for (final c in _categories)
                ListTile(
                  title: Text(
                    c.$2,
                    style: TextStyle(
                      color: c.$1 == _category ? AppColors.primary : textColor,
                      fontSize: 15,
                      fontWeight: c.$1 == _category
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: c.$1 == _category
                      ? const Icon(Symbols.check,
                          color: AppColors.primary, size: 20)
                      : null,
                  onTap: () => Navigator.pop(ctx, c.$1),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey.shade200;
    final textColor = isDark ? const Color(0xFFF1F5F9) : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondaryLight;
    final hintColor = isDark ? const Color(0xFF475569) : Colors.grey.shade400;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '관리자에게 문의',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 672),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // 카테고리
                    _SectionLabel(label: '카테고리', textColor: textColor),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final picked = await _pickCategory(
                          surfaceColor: surfaceColor,
                          textColor: textColor,
                        );
                        if (picked != null) {
                          setState(() => _category = picked);
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _categories
                                    .firstWhere((c) => c.$1 == _category)
                                    .$2,
                                style: TextStyle(
                                    color: textColor, fontSize: 16),
                              ),
                            ),
                            Icon(Symbols.keyboard_arrow_down,
                                color: secondaryColor),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 제목
                    _SectionLabel(label: '제목', textColor: textColor),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _subjectController,
                      maxLength: 120,
                      buildCounter: (context,
                              {required currentLength,
                              required isFocused,
                              maxLength}) =>
                          Text(
                        '$currentLength/120',
                        style: TextStyle(color: hintColor, fontSize: 12),
                      ),
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: '문의 제목을 입력해주세요',
                        hintStyle: TextStyle(color: hintColor),
                        filled: true,
                        fillColor: surfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: 20),

                    // 내용
                    _SectionLabel(label: '내용', textColor: textColor),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _bodyController,
                      maxLines: 8,
                      maxLength: 10000,
                      buildCounter: (context,
                              {required currentLength,
                              required isFocused,
                              maxLength}) =>
                          null,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: '문의 내용을 자세히 입력해주세요',
                        hintStyle: TextStyle(color: hintColor),
                        filled: true,
                        fillColor: surfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 회신 이메일 (선택)
                    _SectionLabel(label: '회신 이메일 (선택)', textColor: textColor),
                    const SizedBox(height: 4),
                    Text(
                      '입력하지 않으면 계정 이메일로 답변을 드립니다.',
                      style: TextStyle(color: secondaryColor, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _contactEmailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: '내 계정 이메일로 받음',
                        hintStyle: TextStyle(color: hintColor),
                        filled: true,
                        fillColor: surfaceColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // 보내기 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                '보내기',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.textColor});
  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: textColor,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
