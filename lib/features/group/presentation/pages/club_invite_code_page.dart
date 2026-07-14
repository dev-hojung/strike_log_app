import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/services/groups_api_service.dart';

/// 클럽 초대 코드 관리 페이지 (STAFF+ 전용).
///
/// 코드 표시 · 복사 · 공유 · 재발급.
/// 초대 코드를 아는 사용자는 운영진 승인 없이 즉시 가입한다(1인 1클럽 정책은 유지).
/// 재발급(회전) 시 이전 코드는 즉시 무효화된다.
class ClubInviteCodePage extends StatefulWidget {
  const ClubInviteCodePage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  final int groupId;
  final String groupName;

  @override
  State<ClubInviteCodePage> createState() => _ClubInviteCodePageState();
}

class _ClubInviteCodePageState extends State<ClubInviteCodePage> {
  final GroupsApiService _api = GroupsApiService();

  String? _code;
  bool _loading = true;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final code = await _api.getInviteCode(widget.groupId);
      if (!mounted) return;
      setState(() {
        _code = code;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _rotate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('초대 코드 재발급'),
        content: const Text(
          '새 코드를 발급하면 기존 코드는 더 이상 사용할 수 없습니다.\n이미 공유한 코드가 있다면 다시 공유해야 해요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('재발급'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final code = await _api.rotateInviteCode(widget.groupId);
      if (!mounted) return;
      setState(() {
        _code = code;
        _busy = false;
      });
      _snack('새 초대 코드를 발급했어요. 이전 코드는 더 이상 쓸 수 없습니다.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('재발급에 실패했습니다. 잠시 후 다시 시도해주세요.');
    }
  }

  void _copy() {
    final code = _code;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    _snack('초대 코드를 복사했어요.');
  }

  Future<void> _share() async {
    final code = _code;
    if (code == null) return;
    final message = '[Strike Log] "${widget.groupName}" 클럽에 초대합니다!\n'
        '앱에서 클럽 탐색 → "코드로 가입"에 아래 코드를 입력하세요.\n\n'
        '초대 코드: $code';
    await SharePlus.instance.share(ShareParams(text: message));
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
          '초대 코드',
          style: TextStyle(
              color: textColor, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _failed
                ? _buildError(textColor, secondaryColor)
                : _buildContent(
                    isDark, textColor, secondaryColor, surfaceColor, borderColor),
      ),
    );
  }

  Widget _buildError(Color textColor, Color secondaryColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.error, color: secondaryColor, size: 40),
          const SizedBox(height: 12),
          Text(
            '초대 코드를 불러오지 못했습니다.',
            style: TextStyle(color: textColor, fontSize: 14),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _load,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    bool isDark,
    Color textColor,
    Color secondaryColor,
    Color surfaceColor,
    Color borderColor,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // 안내 문구
        Text(
          '"${widget.groupName}" 클럽 초대 코드',
          style: TextStyle(
              color: textColor, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          '아래 코드를 아는 사람은 승인 없이 바로 가입할 수 있어요.\n'
          '한 번에 하나의 클럽에만 가입할 수 있습니다.',
          style: TextStyle(color: secondaryColor, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 24),
        // 코드 카드
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Icon(Symbols.key, color: AppColors.primary, size: 28),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _code ?? '--------',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // 복사 · 공유
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _copy,
                icon: const Icon(Symbols.content_copy, size: 18),
                label: const Text('복사'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(color: borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _share,
                icon: const Icon(Symbols.share, size: 18),
                label: const Text('공유'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 재발급
        TextButton.icon(
          onPressed: _busy ? null : _rotate,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Symbols.autorenew, size: 18, color: secondaryColor),
          label: Text(
            '코드 재발급',
            style: TextStyle(color: secondaryColor, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
