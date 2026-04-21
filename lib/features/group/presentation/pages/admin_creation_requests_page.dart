import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/services/group_creation_requests_service.dart';

/// 플랫폼 관리자 전용: 클럽 생성 신청 관리 페이지.
class AdminCreationRequestsPage extends StatefulWidget {
  const AdminCreationRequestsPage({super.key});

  @override
  State<AdminCreationRequestsPage> createState() =>
      _AdminCreationRequestsPageState();
}

class _AdminCreationRequestsPageState extends State<AdminCreationRequestsPage>
    with SingleTickerProviderStateMixin {
  final _service = GroupCreationRequestsService();
  String? _adminUserId;
  late TabController _tabController;

  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _approved = [];
  List<Map<String, dynamic>> _rejected = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('user_id');
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    _adminUserId = uid;

    final results = await Future.wait([
      _service.listForAdmin(adminUserId: uid, status: 'pending'),
      _service.listForAdmin(adminUserId: uid, status: 'approved'),
      _service.listForAdmin(adminUserId: uid, status: 'rejected'),
    ]);
    if (!mounted) return;
    setState(() {
      _pending = results[0];
      _approved = results[1];
      _rejected = results[2];
      _isLoading = false;
    });
  }

  Future<void> _approve(Map<String, dynamic> req) async {
    final id = _idOf(req);
    if (id == 0 || _adminUserId == null) return;
    final confirmed = await _confirm('신청 승인', '"${req['name']}" 클럽을 생성합니다.');
    if (confirmed != true) return;
    final ok = await _service.approve(requestId: id, adminUserId: _adminUserId!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '승인 완료' : '승인 실패')),
    );
    if (ok) _fetchAll();
  }

  Future<void> _reject(Map<String, dynamic> req) async {
    final id = _idOf(req);
    if (id == 0 || _adminUserId == null) return;

    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => const _RejectReasonSheet(),
    );
    if (reason == null) return;

    final ok = await _service.reject(
      requestId: id,
      adminUserId: _adminUserId!,
      reason: reason,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '반려 완료' : '반려 실패')),
    );
    if (ok) _fetchAll();
  }

  Future<bool?> _confirm(String title, String body) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('진행'),
          ),
        ],
      ),
    );
  }

  int _idOf(Map<String, dynamic> req) {
    final v = req['id'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('클럽 생성 신청 관리'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '대기 (${_pending.length})'),
            Tab(text: '승인 (${_approved.length})'),
            Tab(text: '반려 (${_rejected.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_pending, isDark, interactive: true),
                _buildList(_approved, isDark),
                _buildList(_rejected, isDark),
              ],
            ),
    );
  }

  Widget _buildList(
    List<Map<String, dynamic>> items,
    bool isDark, {
    bool interactive = false,
  }) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 400,
              child: Center(
                child: Text(
                  '내역이 없습니다.',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => _buildCard(items[i], isDark, interactive),
      ),
    );
  }

  Widget _buildCard(
    Map<String, dynamic> req,
    bool isDark,
    bool interactive,
  ) {
    final surface = isDark ? AppColors.surfaceDark : Colors.white;
    final text = isDark ? Colors.white : AppColors.textPrimaryLight;
    final sub =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final status = req['status']?.toString() ?? '';
    final createdAt = DateTime.tryParse(req['created_at']?.toString() ?? '');
    final createdLabel = createdAt == null
        ? ''
        : '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
    final rejectReason = req['reject_reason']?.toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatusBadge(status),
              const Spacer(),
              if (createdLabel.isNotEmpty)
                Text(createdLabel,
                    style: TextStyle(color: sub, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(req['name']?.toString() ?? '',
              style: TextStyle(
                  color: text, fontSize: 16, fontWeight: FontWeight.bold)),
          if ((req['description']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              req['description'].toString(),
              style:
                  TextStyle(color: sub, fontSize: 13, height: 1.5),
            ),
          ],
          const SizedBox(height: 8),
          Text('신청자: ${req['requester_id']}',
              style: TextStyle(color: sub, fontSize: 12)),
          if (rejectReason != null && rejectReason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('반려 사유: ${_rejectReasonLabel(rejectReason)}',
                style: TextStyle(color: sub, fontSize: 12)),
          ],
          if (interactive) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reject(req),
                    icon: const Icon(Symbols.close),
                    label: const Text('반려'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approve(req),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Symbols.check),
                    label: const Text('승인'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    late Color color;
    late String label;
    switch (status) {
      case 'pending':
        color = AppColors.primary;
        label = '대기';
        break;
      case 'approved':
        color = Colors.green;
        label = '승인';
        break;
      case 'rejected':
        color = Colors.redAccent;
        label = '반려';
        break;
      case 'cancelled':
        color = Colors.grey;
        label = '취소';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  String _rejectReasonLabel(String key) {
    switch (key) {
      case 'inappropriate_name':
        return '부적절한 이름';
      case 'duplicate':
        return '유사 클럽 이미 존재';
      case 'incomplete_info':
        return '정보 불충분';
      case 'other':
        return '기타';
      default:
        return key;
    }
  }
}

class _RejectReasonSheet extends StatefulWidget {
  const _RejectReasonSheet();

  @override
  State<_RejectReasonSheet> createState() => _RejectReasonSheetState();
}

class _RejectReasonSheetState extends State<_RejectReasonSheet> {
  String _selected = 'inappropriate_name';

  static const _reasons = [
    ('inappropriate_name', '부적절한 이름'),
    ('duplicate', '유사 클럽 이미 존재'),
    ('incomplete_info', '정보 불충분'),
    ('other', '기타'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '반려 사유 선택',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            ..._reasons.map((r) => RadioListTile<String>(
                  value: r.$1,
                  groupValue: _selected,
                  title: Text(r.$2),
                  onChanged: (v) => setState(() => _selected = v!),
                )),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, _selected),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('반려하기'),
            ),
          ],
        ),
      ),
    );
  }
}
