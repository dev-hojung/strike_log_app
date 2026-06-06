import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/avatar_image.dart';
import '../../data/services/announcements_api_service.dart';

/// 클럽 공지사항 목록 페이지.
///
/// - 멤버 누구나 진입 가능.
/// - 운영자(`isAdmin=true`)면 우상단 + 버튼으로 작성 진입, 항목 ⋮ 메뉴로 편집/삭제.
class ClubAnnouncementsPage extends StatefulWidget {
  const ClubAnnouncementsPage({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.isAdmin,
  });

  final int groupId;
  final String groupName;
  final bool isAdmin;

  @override
  State<ClubAnnouncementsPage> createState() => _ClubAnnouncementsPageState();
}

class _ClubAnnouncementsPageState extends State<ClubAnnouncementsPage> {
  final AnnouncementsApiService _api = AnnouncementsApiService();
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      _items = await _api.list(widget.groupId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공지 목록을 불러오지 못했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openWrite({Map<String, dynamic>? edit}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WriteAnnouncementPage(
          groupId: widget.groupId,
          edit: edit,
        ),
      ),
    );
    if (saved == true) await _refresh();
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('공지를 삭제할까요?'),
        content: Text("'${item['title'] ?? ''}'을(를) 삭제합니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.delete(
        groupId: widget.groupId,
        announcementId: (item['id'] as num).toInt(),
      );
      await _refresh();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map
          ? (e.response!.data['message']?.toString() ?? '삭제에 실패했습니다.')
          : '삭제에 실패했습니다.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('${widget.groupName} 공지'),
        actions: [
          if (widget.isAdmin)
            IconButton(
              tooltip: '새 공지',
              icon: const Icon(Symbols.add),
              onPressed: () => _openWrite(),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: _items.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.symmetric(vertical: 80),
                      children: [
                        Center(
                          child: Text(
                            '아직 작성된 공지가 없어요.',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) =>
                          _buildCard(_items[i], isDark),
                    ),
            ),
    );
  }

  Widget _buildCard(Map<String, dynamic> a, bool isDark) {
    final title = a['title']?.toString() ?? '';
    final body = a['body']?.toString() ?? '';
    final pinned = a['pinned'] == true;
    final author = (a['author'] as Map?) ?? const {};
    final createdRaw = a['created_at']?.toString();
    DateTime? created;
    if (createdRaw != null) created = DateTime.tryParse(createdRaw)?.toLocal();

    final surface = isDark ? AppColors.surfaceDark : Colors.white;
    final border = isDark ? Colors.white12 : Colors.black12;
    final primaryText =
        isDark ? Colors.white : AppColors.textPrimaryLight;
    final mutedText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pinned ? AppColors.primary.withValues(alpha: 0.6) : border,
          width: pinned ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (pinned) ...[
                Icon(Symbols.push_pin, color: AppColors.primary, size: 16),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (widget.isAdmin)
                PopupMenuButton<String>(
                  icon: Icon(Symbols.more_vert, color: mutedText),
                  onSelected: (v) {
                    if (v == 'edit') _openWrite(edit: a);
                    if (v == 'delete') _confirmDelete(a);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('수정')),
                    PopupMenuItem(value: 'delete', child: Text('삭제')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: TextStyle(color: primaryText, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: ClipOval(
                  child: AvatarImage(
                    url: author['profile_image_url']?.toString(),
                    fallback: Icon(Symbols.person, size: 14, color: mutedText),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                author['nickname']?.toString() ?? '운영자',
                style: TextStyle(color: mutedText, fontSize: 12),
              ),
              if (created != null) ...[
                Text(' · ', style: TextStyle(color: mutedText, fontSize: 12)),
                Text(
                  DateFormat('yyyy.MM.dd HH:mm').format(created),
                  style: TextStyle(color: mutedText, fontSize: 12),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// 공지 작성/수정 페이지. 운영자만 진입.
/// pop 결과로 `true` 반환 시 호출자에서 목록 새로고침.
class WriteAnnouncementPage extends StatefulWidget {
  const WriteAnnouncementPage({
    super.key,
    required this.groupId,
    this.edit,
  });

  final int groupId;
  final Map<String, dynamic>? edit;

  @override
  State<WriteAnnouncementPage> createState() => _WriteAnnouncementPageState();
}

class _WriteAnnouncementPageState extends State<WriteAnnouncementPage> {
  final AnnouncementsApiService _api = AnnouncementsApiService();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _pinned = false;
  bool _saving = false;

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.edit;
    if (edit != null) {
      _titleController.text = edit['title']?.toString() ?? '';
      _bodyController.text = edit['body']?.toString() ?? '';
      _pinned = edit['pinned'] == true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 본문을 모두 입력해주세요.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _api.update(
          groupId: widget.groupId,
          announcementId: (widget.edit!['id'] as num).toInt(),
          title: title,
          body: body,
          pinned: _pinned,
        );
      } else {
        await _api.create(
          groupId: widget.groupId,
          title: title,
          body: body,
          pinned: _pinned,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map
          ? (e.response!.data['message']?.toString() ?? '저장에 실패했습니다.')
          : '저장에 실패했습니다.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surfaceDark : Colors.white;
    final border = isDark ? Colors.white12 : Colors.black12;
    final textColor =
        isDark ? Colors.white : AppColors.textPrimaryLight;

    InputDecoration field(String hint) => InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        );

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(_isEdit ? '공지 수정' : '새 공지 작성'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEdit ? '저장' : '게시',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                maxLength: 200,
                style: TextStyle(color: textColor),
                decoration: field('제목'),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _bodyController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(color: textColor),
                  decoration: field('공지 내용을 입력하세요.'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Switch(
                    value: _pinned,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) => setState(() => _pinned = v),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '상단 고정',
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
