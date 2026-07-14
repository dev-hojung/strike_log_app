import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/services/groups_api_service.dart';

/// 초대 코드로 클럽에 가입하는 페이지.
///
/// 코드 입력 → 미리보기 조회 → 즉시 가입(승인 생략, 1인 1클럽 정책 유지).
/// 가입 성공 시 `Navigator.pop(context, true)` 로 호출자에 알린다.
class JoinByCodePage extends StatefulWidget {
  const JoinByCodePage({super.key});

  @override
  State<JoinByCodePage> createState() => _JoinByCodePageState();
}

class _JoinByCodePageState extends State<JoinByCodePage> {
  final GroupsApiService _api = GroupsApiService();
  final TextEditingController _controller = TextEditingController();

  Map<String, dynamic>? _preview;
  bool _looking = false;
  bool _joining = false;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _code => _controller.text.trim().toUpperCase();

  /// 백엔드 에러 메시지를 최대한 사용자 친화적으로 추출.
  String _dioMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map) {
      final m = data['message'];
      if (m is String && m.isNotEmpty) return m;
      if (m is List && m.isNotEmpty) return m.first.toString();
    }
    return fallback;
  }

  Future<void> _lookup() async {
    final code = _code;
    if (code.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _looking = true;
      _message = null;
      _preview = null;
    });
    try {
      final preview = await _api.previewByInviteCode(code);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _looking = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _looking = false;
        _message = _dioMessage(e, '유효하지 않은 초대 코드입니다.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _looking = false;
        _message = '코드를 확인하지 못했습니다. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  Future<void> _join() async {
    final code = _code;
    if (code.isEmpty) return;
    setState(() {
      _joining = true;
      _message = null;
    });
    try {
      await _api.joinByInviteCode(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_preview?['name'] ?? '클럽'}에 가입했어요!')),
      );
      Navigator.pop(context, true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _joining = false;
        _message = _dioMessage(e, '가입에 실패했습니다.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _joining = false;
        _message = '가입에 실패했습니다. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textColor =
        isDark ? const Color(0xFFF1F5F9) : AppColors.textPrimaryLight;
    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : Colors.black12;

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
          '코드로 가입',
          style: TextStyle(
              color: textColor, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              '초대 코드를 입력하세요',
              style: TextStyle(
                  color: textColor, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '클럽 운영진에게 받은 코드를 입력하면 승인 없이 바로 가입할 수 있어요.',
              style: TextStyle(color: secondaryColor, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            // 코드 입력 필드
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _lookup(),
                onChanged: (_) {
                  if (_preview != null || _message != null) {
                    setState(() {
                      _preview = null;
                      _message = null;
                    });
                  }
                },
                inputFormatters: [
                  UpperCaseTextFormatter(),
                  LengthLimitingTextInputFormatter(12),
                ],
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
                decoration: InputDecoration(
                  hintText: 'ABCD2345',
                  hintStyle: TextStyle(
                    color: isDark ? const Color(0xFF64748B) : secondaryColor,
                    fontSize: 20,
                    letterSpacing: 4,
                  ),
                  prefixIcon: Icon(Symbols.key, color: secondaryColor, size: 20),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 코드 확인 버튼
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _looking ? null : _lookup,
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(color: borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _looking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('코드 확인'),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Symbols.info, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _message!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ],
            if (_preview != null) ...[
              const SizedBox(height: 24),
              _buildPreviewCard(
                  isDark, textColor, secondaryColor, surfaceColor, borderColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(
    bool isDark,
    Color textColor,
    Color secondaryColor,
    Color surfaceColor,
    Color borderColor,
  ) {
    final preview = _preview!;
    final name = (preview['name'] ?? '').toString();
    final description = (preview['description'] ?? '').toString();
    final region = (preview['activity_region'] ?? '').toString();
    final memberCount = (preview['memberCount'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF32343E) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Symbols.groups,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _metaChip(Symbols.person, '$memberCount명', secondaryColor),
              if (region.isNotEmpty)
                _metaChip(Symbols.location_on, region, secondaryColor),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                  color: secondaryColor, fontSize: 13, height: 1.5),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _joining ? null : _join,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: _joining
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      '가입하기',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}

/// 입력값을 대문자로 강제하는 포매터.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
