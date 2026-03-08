import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/constants/app_colors.dart';

/// 새로운 클럽(그룹)을 생성하는 페이지입니다.
///
/// 주요 기능:
/// - 클럽 프로필 이미지 선택
/// - 클럽 이름 및 소개 입력
/// - 클럽 생성 API 호출 (추후 연동)
class CreateClubPage extends StatefulWidget {
  const CreateClubPage({super.key});

  @override
  State<CreateClubPage> createState() => _CreateClubPageState();
}

class _CreateClubPageState extends State<CreateClubPage> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _handleCreate() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('클럽 이름을 입력해주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // TODO: 백엔드 API 연동 (POST /groups)
    await Future.delayed(const Duration(seconds: 1)); // API 호출 대기 시뮬레이션

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('클럽이 성공적으로 생성되었습니다.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: isDark ? Colors.white : AppColors.textPrimaryLight),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '클럽 생성',
          style: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Image Upload Area
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : Colors.grey.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                          ),
                          child: Icon(
                            Symbols.photo_camera,
                            size: 40,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Symbols.add,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Club Name Field
                  Text(
                    '클럽 이름',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                    decoration: InputDecoration(
                      hintText: '클럽 이름을 입력하세요',
                      hintStyle: TextStyle(
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Club Description Field
                  Text(
                    '클럽 소개',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descController,
                    maxLines: 5,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                    decoration: InputDecoration(
                      hintText: '클럽을 소개해주세요',
                      hintStyle: TextStyle(
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Create Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleCreate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          '생성하기',
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
}
