import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/services/club_events_api_service.dart';

/// 정기전 생성 페이지.
///
/// 필드: 이름, 날짜(datePicker), 목표 게임 수(optional).
/// 참가자는 생성 후 멤버 각자가 직접 참석 신청(self-RSVP)한다.
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

  final _nameController = TextEditingController();
  final _gameTargetController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _gameTargetController.dispose();
    super.dispose();
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

  Future<void> _pickTime() async {
    final initial = _selectedTime ?? const TimeOfDay(hour: 19, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Localizations.override(
        context: context,
        locale: const Locale('ko'),
        child: child,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
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
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시간을 선택해주세요.')),
      );
      return;
    }

    final gameTargetText = _gameTargetController.text.trim();
    final gameTarget =
        gameTargetText.isNotEmpty ? int.tryParse(gameTargetText) : null;

    final d = _selectedDate!;
    final t = _selectedTime!;
    final dateStr =
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:00';

    setState(() => _saving = true);
    try {
      await _api.createEvent(
        groupId: widget.groupId,
        name: name,
        eventDate: dateStr,
        gameTarget: gameTarget,
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 섹션: 기본 정보
                  _sectionHeader('기본 정보', textColor, mutedText),
                  const SizedBox(height: 14),

                  // 이름
                  _fieldLabel('정기전 이름', textColor),
                  const SizedBox(height: 8),
                  _textField(
                    controller: _nameController,
                    hint: '예: 6월 4주차 정모',
                    surfaceColor: surfaceColor,
                    textColor: textColor,
                    mutedText: mutedText,
                    borderColor: borderColor,
                    prefixIcon: Symbols.edit,
                  ),
                  const SizedBox(height: 20),

                  // 날짜
                  _fieldLabel('날짜', textColor),
                  const SizedBox(height: 8),
                  _datePicker(surfaceColor, textColor, mutedText, borderColor),
                  const SizedBox(height: 20),

                  // 시간
                  _fieldLabel('시간', textColor),
                  const SizedBox(height: 8),
                  _timePicker(surfaceColor, textColor, mutedText, borderColor),

                  const SizedBox(height: 28),
                  _sectionDivider(isDark),
                  const SizedBox(height: 20),

                  // 섹션: 게임 설정
                  _sectionHeader('게임 설정', textColor, mutedText),
                  const SizedBox(height: 14),

                  // 목표 게임 수 (optional)
                  _fieldLabel('목표 게임 수', textColor, optional: true),
                  const SizedBox(height: 8),
                  _textField(
                    controller: _gameTargetController,
                    hint: '미입력 시 제한 없음',
                    keyboardType: TextInputType.number,
                    surfaceColor: surfaceColor,
                    textColor: textColor,
                    mutedText: mutedText,
                    borderColor: borderColor,
                    prefixIcon: Symbols.sports_score,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Symbols.info, size: 13, color: mutedText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '정기전 생성 후 멤버들이 직접 참석 신청할 수 있습니다.',
                          style: TextStyle(color: mutedText, fontSize: 12, height: 1.5),
                        ),
                      ),
                    ],
                  ),
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

  Widget _sectionHeader(String title, Color textColor, Color mutedText) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: mutedText,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _sectionDivider(bool isDark) {
    return Container(
      height: 1,
      color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.07),
    );
  }

  Widget _fieldLabel(String text, Color color, {bool optional = false}) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        if (optional) ...[
          const SizedBox(width: 6),
          Text(
            '선택',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    required Color surfaceColor,
    required Color textColor,
    required Color mutedText,
    required Color borderColor,
    IconData? prefixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: textColor, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: mutedText),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: mutedText, size: 18)
            : null,
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _datePicker(Color surfaceColor, Color textColor, Color mutedText,
      Color borderColor) {
    final hasDate = _selectedDate != null;
    final label = hasDate
        ? '${_selectedDate!.year}년 ${_selectedDate!.month}월 ${_selectedDate!.day}일'
        : '날짜 선택';
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _pickDate,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasDate ? AppColors.primary : borderColor,
            width: hasDate ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Symbols.calendar_today,
              color: hasDate ? AppColors.primary : mutedText,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: hasDate ? textColor : mutedText,
                  fontSize: 15,
                ),
              ),
            ),
            if (hasDate)
              Icon(Symbols.check_circle, color: AppColors.primary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _timePicker(Color surfaceColor, Color textColor, Color mutedText,
      Color borderColor) {
    final hasTime = _selectedTime != null;
    String label;
    if (hasTime) {
      final t = _selectedTime!;
      final period = t.hour < 12 ? '오전' : '오후';
      final displayHour = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
      final minuteStr = t.minute.toString().padLeft(2, '0');
      label = '$period $displayHour:$minuteStr';
    } else {
      label = '시간 선택';
    }
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _pickTime,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasTime ? AppColors.primary : borderColor,
            width: hasTime ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Symbols.schedule,
              color: hasTime ? AppColors.primary : mutedText,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: hasTime ? textColor : mutedText,
                  fontSize: 15,
                ),
              ),
            ),
            if (hasTime)
              Icon(Symbols.check_circle, color: AppColors.primary, size: 18),
          ],
        ),
      ),
    );
  }
}
