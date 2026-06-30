import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/services/club_events_api_service.dart';
import '../../data/services/groups_api_service.dart';

/// 정기전 생성 페이지.
///
/// 필드: 이름, 날짜(datePicker), 목표 게임 수(optional), 참가자 선택(멤버 멀티선택 바텀시트).
/// 성공 시 pop(true) 반환.
class CreateClubEventPage extends StatefulWidget {
  const CreateClubEventPage({
    super.key,
    required this.groupId,
  });

  final int groupId;

  @override
  State<CreateClubEventPage> createState() => _CreateClubEventPageState();
}

class _CreateClubEventPageState extends State<CreateClubEventPage> {
  final ClubEventsApiService _api = ClubEventsApiService();
  final GroupsApiService _groupsApi = GroupsApiService();

  final _nameController = TextEditingController();
  final _gameTargetController = TextEditingController();

  DateTime? _selectedDate;
  List<Map<String, dynamic>> _allMembers = const [];
  final Set<String> _selectedUserIds = {};
  bool _loadingMembers = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gameTargetController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final members = await _groupsApi.getMembers(widget.groupId);
      if (!mounted) return;
      setState(() {
        _allMembers = members;
        _loadingMembers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMembers = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      locale: const Locale('ko'),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _openMemberPicker() async {
    if (_loadingMembers) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final mutedText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    // 바텀시트 내부에서 선택 상태를 독립적으로 관리
    final tempSelected = Set<String>.from(_selectedUserIds);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 핸들
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: Row(
                      children: [
                        Text(
                          '참가자 선택',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${tempSelected.length}명 선택됨',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: _allMembers.length,
                      itemBuilder: (_, i) {
                        final m = _allMembers[i];
                        final userId =
                            (m['user_id'] ?? m['user']?['id'])?.toString() ??
                                '';
                        final nickname =
                            (m['user']?['nickname'] ?? m['nickname'] ?? '')
                                .toString();
                        final avgScore = m['avg_score'];
                        final isSelected = tempSelected.contains(userId);

                        return ListTile(
                          onTap: () {
                            setSheetState(() {
                              if (isSelected) {
                                tempSelected.remove(userId);
                              } else {
                                tempSelected.add(userId);
                              }
                            });
                          },
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSelected ? Symbols.check : Symbols.person,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.primary,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            nickname,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: avgScore != null
                              ? Text(
                                  '평균 ${(avgScore as num).toStringAsFixed(1)}점',
                                  style: TextStyle(
                                    color: mutedText,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                          trailing: isSelected
                              ? const Icon(Symbols.check_circle,
                                  color: AppColors.primary, size: 22)
                              : Icon(Symbols.radio_button_unchecked,
                                  color: mutedText, size: 22),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          '${tempSelected.length}명 선택 완료',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (confirmed == true) {
      setState(() {
        _selectedUserIds
          ..clear()
          ..addAll(tempSelected);
      });
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정기전 이름을 입력해주세요.')),
      );
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('날짜를 선택해주세요.')),
      );
      return;
    }

    final gameTargetText = _gameTargetController.text.trim();
    final gameTarget =
        gameTargetText.isNotEmpty ? int.tryParse(gameTargetText) : null;

    final dateStr =
        '${_selectedDate!.year.toString().padLeft(4, '0')}-'
        '${_selectedDate!.month.toString().padLeft(2, '0')}-'
        '${_selectedDate!.day.toString().padLeft(2, '0')}';

    setState(() => _saving = true);
    try {
      await _api.createEvent(
        groupId: widget.groupId,
        name: name,
        eventDate: dateStr,
        gameTarget: gameTarget,
        participantUserIds: _selectedUserIds.toList(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map
          ? (e.response!.data['message']?.toString() ?? '생성에 실패했습니다.')
          : '생성에 실패했습니다.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final mutedText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderColor = isDark ? Colors.white10 : Colors.black12;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '정기전 만들기',
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 이름
                  _label('정기전 이름', textColor),
                  const SizedBox(height: 8),
                  _textField(
                    controller: _nameController,
                    hint: '예: 6월 4주차 정모',
                    surfaceColor: surfaceColor,
                    textColor: textColor,
                    mutedText: mutedText,
                    borderColor: borderColor,
                  ),
                  const SizedBox(height: 24),

                  // 날짜
                  _label('날짜', textColor),
                  const SizedBox(height: 8),
                  _datePicker(surfaceColor, textColor, mutedText, borderColor),
                  const SizedBox(height: 24),

                  // 목표 게임 수 (optional)
                  _label('목표 게임 수 (선택)', textColor),
                  const SizedBox(height: 8),
                  _textField(
                    controller: _gameTargetController,
                    hint: '예: 3',
                    keyboardType: TextInputType.number,
                    surfaceColor: surfaceColor,
                    textColor: textColor,
                    mutedText: mutedText,
                    borderColor: borderColor,
                  ),
                  const SizedBox(height: 24),

                  // 참가자 선택
                  _label('참가자 선택', textColor),
                  const SizedBox(height: 8),
                  _participantSelector(
                      surfaceColor, textColor, mutedText, borderColor),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          '정기전 만들기',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, Color color) => Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    required Color surfaceColor,
    required Color textColor,
    required Color mutedText,
    required Color borderColor,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: textColor, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: mutedText),
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
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _datePicker(Color surfaceColor, Color textColor, Color mutedText,
      Color borderColor) {
    final label = _selectedDate == null
        ? '날짜 선택'
        : '${_selectedDate!.year}년 ${_selectedDate!.month}월 ${_selectedDate!.day}일';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _pickDate,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedDate != null ? AppColors.primary : borderColor,
          ),
        ),
        child: Row(
          children: [
            Icon(Symbols.calendar_today,
                color: _selectedDate != null ? AppColors.primary : mutedText,
                size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: _selectedDate != null ? textColor : mutedText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _participantSelector(Color surfaceColor, Color textColor,
      Color mutedText, Color borderColor) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _openMemberPicker,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedUserIds.isNotEmpty
                ? AppColors.primary
                : borderColor,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Symbols.group_add,
              color: _selectedUserIds.isNotEmpty
                  ? AppColors.primary
                  : mutedText,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _selectedUserIds.isEmpty
                  ? Text(
                      '멤버를 선택하세요',
                      style: TextStyle(color: mutedText, fontSize: 14),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _buildSelectedChips(textColor),
                    ),
            ),
            Icon(Symbols.keyboard_arrow_down, color: mutedText, size: 20),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSelectedChips(Color textColor) {
    final selected = _allMembers.where((m) {
      final userId = (m['user_id'] ?? m['user']?['id'])?.toString() ?? '';
      return _selectedUserIds.contains(userId);
    }).toList();

    if (selected.length <= 3) {
      return selected.map((m) {
        final nickname =
            (m['user']?['nickname'] ?? m['nickname'] ?? '').toString();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            nickname,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList();
    }

    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${_selectedUserIds.length}명 선택됨',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ];
  }
}
