import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/data/korea_regions.dart';
import '../../data/services/group_creation_requests_service.dart';

/// 새로운 클럽(그룹)을 생성하는 페이지입니다.
class CreateClubPage extends StatefulWidget {
  const CreateClubPage({super.key});

  @override
  State<CreateClubPage> createState() => _CreateClubPageState();
}

class _CreateClubPageState extends State<CreateClubPage> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _isLoading = false;

  // 활동 지역 — 시/도 + 시/군/구 2단계 드롭다운.
  // 백엔드에는 `composeRegion()`으로 단일 문자열("시/도 시/군/구")로 합쳐 전송.
  String? _selectedProvince;
  String? _selectedCity;
  File? _selectedImage;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _handleCreate() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('클럽 이름을 입력해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) {
        throw StateError('로그인이 필요합니다.');
      }

      await GroupCreationRequestsService().createRequest(
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        activityRegion: composeRegion(_selectedProvince, _selectedCity),
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('신청이 접수되었습니다'),
          content: const Text(
            '관리자 승인 후 클럽이 생성됩니다.\n승인 결과는 알림으로 받아보실 수 있어요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } on CreationRequestConflictException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } on CreationRequestFailedException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('신청 실패: ${e.message}')),
        );
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('[createClub] unexpected error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('클럽 생성 신청에 실패했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
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
          '클럽 생성하기',
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
                  // 클럽 대표 이미지 업로드
                  _buildImageUploadArea(surfaceColor, secondaryColor, borderColor),
                  const SizedBox(height: 28),

                  // 클럽 이름
                  _buildLabel('클럽 이름', textColor),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _nameController,
                    hintText: '클럽 이름을 입력하세요',
                    surfaceColor: surfaceColor,
                    textColor: textColor,
                    secondaryColor: secondaryColor,
                    borderColor: borderColor,
                  ),
                  const SizedBox(height: 24),

                  // 클럽 소개
                  _buildLabel('클럽 소개', textColor),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _descController,
                    hintText: '클럽을 소개해주세요',
                    maxLines: 5,
                    surfaceColor: surfaceColor,
                    textColor: textColor,
                    secondaryColor: secondaryColor,
                    borderColor: borderColor,
                  ),
                  const SizedBox(height: 24),

                  // 활동 지역
                  _buildLabel('활동 지역', textColor),
                  const SizedBox(height: 8),
                  _buildRegionDropdown(surfaceColor, textColor, secondaryColor, borderColor),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // 생성하기 버튼
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleCreate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          '생성 신청하기',
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

  Widget _buildLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  Widget _buildImageUploadArea(Color surfaceColor, Color secondaryColor, Color borderColor) {
    if (_selectedImage != null) {
      return GestureDetector(
        onTap: _pickImage,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                _selectedImage!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  _buildImageActionButton(
                    icon: Symbols.edit,
                    onTap: _pickImage,
                  ),
                  const SizedBox(width: 6),
                  _buildImageActionButton(
                    icon: Symbols.close,
                    onTap: () => setState(() => _selectedImage = null),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _pickImage,
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: secondaryColor.withValues(alpha: 0.5),
          borderRadius: 16,
          dashWidth: 6,
          dashSpace: 4,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Symbols.cloud_upload,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '이미지 업로드',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: secondaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'JPG, PNG (최대 5MB)',
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryColor.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '파일 선택',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageActionButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    required Color surfaceColor,
    required Color textColor,
    required Color secondaryColor,
    required Color borderColor,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: textColor, fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: secondaryColor),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildRegionDropdown(
    Color surfaceColor, Color textColor, Color secondaryColor, Color borderColor,
  ) {
    Widget dropdown({
      required String? value,
      required String hint,
      required List<String> items,
      required void Function(String?)? onChanged,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            hint: Text(hint,
                style: TextStyle(color: secondaryColor, fontSize: 14)),
            isExpanded: true,
            icon: Icon(Symbols.keyboard_arrow_down, color: secondaryColor),
            dropdownColor: surfaceColor,
            style: TextStyle(color: textColor, fontSize: 14),
            items: items
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: dropdown(
            value: _selectedProvince,
            hint: '시/도 선택',
            items: kProvinces,
            onChanged: (v) => setState(() {
              _selectedProvince = v;
              _selectedCity = null; // 시/도 바뀌면 시/군/구 리셋
            }),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: dropdown(
            value: _selectedCity,
            hint: '시/군/구 선택',
            items: citiesOf(_selectedProvince),
            onChanged: _selectedProvince == null
                ? null
                : (v) => setState(() => _selectedCity = v),
          ),
        ),
      ],
    );
  }

}

/// 대시 점선 테두리를 그리는 CustomPainter
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;
  final double dashWidth;
  final double dashSpace;

  _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    required this.dashWidth,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = distance + dashWidth;
        dashPath.addPath(
          metric.extractPath(distance, end.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = end + dashSpace;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
