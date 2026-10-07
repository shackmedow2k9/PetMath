import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../l10n/tr.dart';
import '../widgets/tr_text.dart';
import 'package:flutter/services.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/assignment_model.dart';
import '../services/curriculum.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/emoji_icon.dart';
import 'teacher_assignment_create_screen.dart';
import 'teacher_exam_generator_screen.dart';
import 'teacher_word_import_screen.dart';

/// Dashboard của 1 lớp học — theo đúng ví dụ trong đặc tả:
/// "Lớp 6A · 35 HS · Điểm TB 78 · Hôm nay 31 em học, 4 em chưa học · BXH Top 10"
/// Đồng thời cho phép giáo viên Giao bài và Thưởng/Phạt học sinh.
class TeacherClassDetailScreen extends StatefulWidget {
  final ClassModel klass;
  final String teacherId;
  const TeacherClassDetailScreen(
      {super.key, required this.klass, required this.teacherId});

  @override
  State<TeacherClassDetailScreen> createState() =>
      _TeacherClassDetailScreenState();
}

class _TeacherClassDetailScreenState extends State<TeacherClassDetailScreen>
    with SingleTickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  late final TabController _tabController;
  double? _avgAccuracy;
  bool _loadingAvg = false;
  // Cập nhật ngay trên UI sau khi đặt khối lớp — widget.klass là dữ liệu
  // TĨNH truyền từ danh sách lớp (không phải stream) nên tự nó không đổi.
  int? _gradeOverride;

  int? get _effectiveGrade => _gradeOverride ?? widget.klass.grade;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshAverage(List<StudentModel> students) async {
    setState(() => _loadingAvg = true);
    final avg = await _firestoreService
        .computeClassAverageAccuracy(students.map((s) => s.uid).toList());
    if (mounted)
      setState(() {
        _avgAccuracy = avg;
        _loadingAvg = false;
      });
  }

  Future<void> _setClassGrade(BuildContext context) async {
    int? grade;
    final picked = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Chọn khối lớp'),
          content: DropdownButtonFormField<int>(
            initialValue: grade,
            decoration:  InputDecoration(labelText: tr('Khối lớp')),
            items: Curriculum.allGrades
                .map((g) => DropdownMenuItem(
                    value: g, child: Text(Curriculum.gradeLabel(g))))
                .toList(),
            onChanged: (v) => setDialogState(() => grade = v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Hủy')),
            FilledButton(
              onPressed: grade == null
                  ? null
                  : () => Navigator.of(dialogContext).pop(grade),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await _firestoreService.setClassGrade(widget.klass.id, picked);
      if (mounted) setState(() => _gradeOverride = picked);
    }
  }

  void _copyJoinCode() {
    Clipboard.setData(ClipboardData(text: widget.klass.joinCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã sao chép mã lớp ${widget.klass.joinCode}')),
    );
  }

  Future<void> _rewardStudent(StudentModel student) async {
    // Kiểm tra cooldown: mỗi học sinh chỉ được thưởng/phạt 1 lần mỗi
    // [FirestoreService.rewardCooldownDays] ngày, tính từ lần gần nhất
    // (bất kể thưởng hay phạt, bất kể giáo viên nào đã làm).
    final lastRewardAt = await _firestoreService.getLastRewardTime(student.uid);
    if (lastRewardAt != null) {
      final nextAllowedAt = lastRewardAt
          .add(const Duration(days: FirestoreService.rewardCooldownDays));
      final remaining = nextAllowedAt.difference(DateTime.now());
      if (remaining > Duration.zero) {
        final hours = remaining.inHours % 24;
        final days = remaining.inDays;
        final remainingText = days > 0
            ? '$days ngày ${hours > 0 ? '$hours giờ' : ''}'
            : '${remaining.inHours} giờ ${remaining.inMinutes % 60} phút';
        if (mounted) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Chưa thể thưởng/phạt'),
              content: Text(
                '${student.fullName} vừa được thưởng/phạt gần đây. '
                'Mỗi học sinh chỉ có thể thưởng/phạt 1 lần mỗi '
                '${FirestoreService.rewardCooldownDays} ngày.\n\n'
                'Còn khoảng $remainingText nữa mới có thể thực hiện tiếp.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đã hiểu'),
                ),
              ],
            ),
          );
        }
        return;
      }
    }
    if (!mounted) return;
    final result = await showDialog<_RewardResult>(
      context: context,
      builder: (_) => _RewardDialog(studentName: student.fullName),
    );
    if (result == null) return;
    try {
      if (result.coinDelta != 0 || result.gemDelta != 0) {
        await _firestoreService.adjustStudentReward(
          studentId: student.uid,
          teacherId: widget.teacherId,
          coinDelta: result.coinDelta,
          gemDelta: result.gemDelta,
          note: result.note,
        );
      }
      if (result.coinInfinite || result.coinZero) {
        await _firestoreService.setStudentCurrencyOverride(
          studentId: student.uid,
          teacherId: widget.teacherId,
          isCoin: true,
          infinite: result.coinInfinite,
          note: result.note,
        );
      }
      if (result.gemInfinite || result.gemZero) {
        await _firestoreService.setStudentCurrencyOverride(
          studentId: student.uid,
          teacherId: widget.teacherId,
          isCoin: false,
          infinite: result.gemInfinite,
          note: result.note,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result.isReward
                  ? 'Đã thưởng ${student.fullName}'
                  : 'Đã phạt ${student.fullName}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _removeStudent(StudentModel student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Gỡ học sinh khỏi lớp?'),
        content: Text('${student.fullName} sẽ không còn ở lớp này nữa.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child:
                  const Text('Gỡ', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirm == true) {
      await _firestoreService.leaveClass(student.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(bg: BgKind.lavender, headerStrip: true, 
      appBar: AppBar(
        title: Text(_effectiveGrade == null
            ? widget.klass.name
            : '${widget.klass.name} · ${Curriculum.gradeLabel(_effectiveGrade!)}'),
        actions: [
          IconButton(
            tooltip: tr('Nhập Word và tạo đề'),
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => TeacherWordImportScreen(
                    teacherId: widget.teacherId,
                    initialGrade: _effectiveGrade,
                    classId: widget.klass.id,
                  ),
                ),
              );
              if (created == true && mounted) _tabController.animateTo(1);
            },
          ),
          IconButton(
            tooltip: tr('Tạo đề theo ma trận / một nhấn'),
            icon: const Icon(Icons.auto_awesome),
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => TeacherExamGeneratorScreen(
                    teacherId: widget.teacherId,
                    classId: widget.klass.id,
                    grade: _effectiveGrade,
                  ),
                ),
              );
              if (created == true && mounted) _tabController.animateTo(1);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs:  [Tab(text: tr('Học sinh')), Tab(text: tr('Bài đã giao'))],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => TeacherAssignmentCreateScreen(
                  teacherId: widget.teacherId,
                  classId: widget.klass.id,
                  grade: _effectiveGrade),
            ),
          );
          if (created == true && mounted) {
            _tabController.animateTo(1);
          }
        },
        backgroundColor: const Color(0xFFE3DCFA),
        foregroundColor: const Color(0xFF3B3AB9),
        icon: Image.asset('assets/ui/ic_todo.png', width: 26, height: 26),
        label: const Text('Giao bài'),
      ),
      body: StreamBuilder<List<StudentModel>>(
        stream: _firestoreService.watchClassStudents(widget.klass.id),
        builder: (context, snapshot) {
          final students = snapshot.data ?? [];
          final studiedToday = students.where((s) => s.studiedToday).length;

          return Column(
            children: [
              if (_effectiveGrade == null)
                _MissingGradeBanner(onSetGrade: () => _setClassGrade(context)),
              _DashboardHeader(
                joinCode: widget.klass.joinCode,
                onCopyCode: _copyJoinCode,
                studentCount: students.length,
                studiedToday: studiedToday,
                avgAccuracy: _avgAccuracy,
                loadingAvg: _loadingAvg,
                onRefreshAvg:
                    students.isEmpty ? null : () => _refreshAverage(students),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _StudentList(
                      students: students,
                      isLoading:
                          snapshot.connectionState == ConnectionState.waiting,
                      onReward: _rewardStudent,
                      onRemove: _removeStudent,
                    ),
                    _AssignmentList(classId: widget.klass.id),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final String joinCode;
  final VoidCallback onCopyCode;
  final int studentCount;
  final int studiedToday;
  final double? avgAccuracy;
  final bool loadingAvg;
  final VoidCallback? onRefreshAvg;

  const _DashboardHeader({
    required this.joinCode,
    required this.onCopyCode,
    required this.studentCount,
    required this.studiedToday,
    required this.avgAccuracy,
    required this.loadingAvg,
    required this.onRefreshAvg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.vpn_key_rounded, color: AppColors.textPrimary, size: 18),
              const SizedBox(width: 6),
              Text('Mã mời lớp: $joinCode',
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                onPressed: onCopyCode,
                icon: const Icon(Icons.copy_rounded, color: AppColors.textPrimary),
                tooltip: tr('Sao chép mã'),
              ),
            ],
          ),
          const Divider(color: Colors.black12, height: 20),
          Row(
            children: [
              _StatBlock(
                  label: 'Học sinh',
                  value: '$studentCount',
                  iconAsset: 'assets/ui/ic_students.png'),
              _StatBlock(
                iconAsset: 'assets/ui/ic_grade_aplus.png',
                label: 'Điểm TB',
                value: loadingAvg
                    ? '…'
                    : (avgAccuracy == null
                        ? '—'
                        : avgAccuracy!.toStringAsFixed(0)),
                trailing: onRefreshAvg == null
                    ? null
                    : IconButton(
                        onPressed: loadingAvg ? null : onRefreshAvg,
                        icon: const Icon(Icons.refresh,
                            color: Colors.black45, size: 18),
                        tooltip: tr('Tính lại điểm TB'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
              ),
              _StatBlock(
                  iconAsset: 'assets/ui/ic_book_check.png',
                  label: 'Đã học hôm nay',
                  value: '$studiedToday/$studentCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MissingGradeBanner extends StatelessWidget {
  final VoidCallback onSetGrade;
  const _MissingGradeBanner({required this.onSetGrade});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.school_outlined,
              color: AppColors.secondary, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
                'Lớp này chưa có khối lớp — chọn để bài tập/môn học đúng trình độ.',
                style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
          ),
          TextButton(onPressed: onSetGrade, child: const Text('Chọn')),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final String iconAsset;
  final Widget? trailing;
  const _StatBlock(
      {required this.label,
      required this.value,
      required this.iconAsset,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Image.asset(iconAsset, width: 30, height: 30),
              if (trailing != null) trailing!,
            ],
          ),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _StudentList extends StatelessWidget {
  final List<StudentModel> students;
  final bool isLoading;
  final void Function(StudentModel) onReward;
  final void Function(StudentModel) onRemove;

  const _StudentList({
    required this.students,
    required this.isLoading,
    required this.onReward,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (students.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Chưa có học sinh nào.\nĐọc mã mời ở trên cho học sinh nhập ở '
            'màn Hồ sơ > Lớp học của tôi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    // Xếp hạng học sinh trong lớp theo CẤP ĐỘ PET giảm dần (giống quy tắc
    // BXH chung) — ai lên cấp đó trước thì hạng cao hơn khi hoà cấp.
    final sorted = [...students]..sort((a, b) {
        final byLevel = b.petLevel.compareTo(a.petLevel);
        if (byLevel != 0) return byLevel;
        final aTime = a.petLevelUpAt ?? DateTime(2100);
        final bTime = b.petLevelUpAt ?? DateTime(2100);
        return aTime.compareTo(bTime);
      });

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final s = sorted[index];
        final rank = index + 1;
        final medal = switch (rank) {
          1 => '🥇',
          2 => '🥈',
          3 => '🥉',
          _ => '$rank',
        };
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppShadows.card,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: s.studiedToday
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.textSecondary.withValues(alpha: 0.12),
              child: Text(medal,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            title: Text(s.fullName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Text('Cấp ${s.petLevel} · Streak ${s.displayStreak} ngày ·'),
                const EmojiIcon('🪙', size: 16),
                Text(s.coinDisplay),
                const EmojiIcon('💎', size: 16),
                Text(s.gemDisplay),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'reward') onReward(s);
                if (v == 'remove') onRemove(s);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'reward', child: Text('Thưởng / Phạt')),
                PopupMenuItem(
                    value: 'remove',
                    child: Text('Gỡ khỏi lớp',
                        style: TextStyle(color: AppColors.danger))),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AssignmentList extends StatelessWidget {
  final String classId;
  const _AssignmentList({required this.classId});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    return StreamBuilder<List<AssignmentModel>>(
      stream: firestoreService.watchClassAssignments(classId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final assignments = snapshot.data ?? [];
        if (assignments.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Chưa giao bài nào.\nBấm "Giao bài" để tạo bài kiểm tra đầu tiên.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }
        return StreamBuilder<List<StudentModel>>(
          stream: firestoreService.watchClassStudents(classId),
          builder: (context, studentSnap) {
            final totalStudents = studentSnap.data?.length ?? 0;
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              itemCount: assignments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final a = assignments[index];
                final done = a.results.length;
                return Card(
                  child: ListTile(
                    title: Text(a.title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${a.questionIds.length} câu'
                      '${a.dueDate != null ? ' · Hạn ${a.dueDate!.day}/${a.dueDate!.month}' : ''}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$done/$totalStudents',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary)),
                        const Text('đã làm',
                            style: TextStyle(
                                fontSize: 10, color: AppColors.textSecondary)),
                      ],
                    ),
                    onLongPress: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Xoá bài tập?'),
                          content: Text('Xoá "${a.title}"?'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('Hủy')),
                            TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('Xoá',
                                    style: TextStyle(color: AppColors.danger))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await firestoreService.deleteAssignment(a.id);
                      }
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RewardResult {
  final int coinDelta;
  final int gemDelta;
  // Kết quả của 2 mã ẩn (xem _RewardDialogState): đặt vô hạn hoặc reset về
  // 0 tuyệt đối — không phải cộng dồn như coinDelta/gemDelta thông thường.
  final bool coinInfinite;
  final bool gemInfinite;
  final bool coinZero;
  final bool gemZero;
  final String? note;
  final bool isReward;
  _RewardResult(
      {required this.coinDelta,
      required this.gemDelta,
      this.coinInfinite = false,
      this.gemInfinite = false,
      this.coinZero = false,
      this.gemZero = false,
      this.note,
      required this.isReward});
}

// Hai mã quản trị ẩn dùng trong _RewardDialog bên dưới — chỉ admin biết,
// không xuất hiện ở bất kỳ nhãn/gợi ý nào trong giao diện.
const String _kInfiniteCode = '*8+8+8+8+#=';
const String _kZeroOutCode = '--0';

class _RewardDialog extends StatefulWidget {
  final String studentName;
  const _RewardDialog({required this.studentName});

  @override
  State<_RewardDialog> createState() => _RewardDialogState();
}

class _RewardDialogState extends State<_RewardDialog> {
  // Giới hạn kéo của thanh trượt Coin & Gem — MỖI loại có mốc riêng theo
  // yêu cầu: Coin 0-100 (mặc định 10), Gem 0-50 (mặc định 5), mỗi vạch
  // chia nhích 1 đơn vị. Gõ trực tiếp vào ô số thì KHÔNG bị giới hạn bởi
  // các mốc này — thanh trượt chỉ hiển thị kẹp về gần nhất trong phạm vi
  // của nó để không lỗi, còn số thật dùng để thưởng/phạt vẫn giữ đúng giá
  // trị đã gõ.
  static const int _coinMinValue = 0;
  static const int _coinMaxValue = 100;
  static const int _coinStep = 1;
  static const int _coinDefaultValue = 10;
  static final int _coinSliderDivisions =
      ((_coinMaxValue - _coinMinValue) / _coinStep).round();

  static const int _gemMinValue = 0;
  static const int _gemMaxValue = 50;
  static const int _gemStep = 1;
  static const int _gemDefaultValue = 5;
  static final int _gemSliderDivisions =
      ((_gemMaxValue - _gemMinValue) / _gemStep).round();

  bool _isReward = true;
  int _coin = _coinDefaultValue;
  int _gem = _gemDefaultValue;
  // true nếu ô tương ứng đang chứa đúng mã ẩn (đã gõ khớp) — sẽ được áp
  // dụng khi bấm Xác nhận thay vì dùng _coin/_gem làm delta thông thường.
  bool _coinInfiniteCode = false;
  bool _gemInfiniteCode = false;
  bool _coinZeroCode = false;
  bool _gemZeroCode = false;
  final _noteController = TextEditingController();
  late final _coinTextController = TextEditingController(text: '$_coin');
  late final _gemTextController = TextEditingController(text: '$_gem');

  @override
  void dispose() {
    _noteController.dispose();
    _coinTextController.dispose();
    _gemTextController.dispose();
    super.dispose();
  }

  /// Khớp giá trị về đúng lưới bước [step] tính từ mốc [minValue], rồi
  /// giới hạn trong khoảng [minValue, maxValue] — chỉ dùng khi kéo Slider.
  int _snapToStep(num v,
      {required int minValue, required int maxValue, required int step}) {
    final steps = ((v - minValue) / step).round();
    return (minValue + steps * step).clamp(minValue, maxValue).toInt();
  }

  /// Kéo thanh trượt Coin -> có giới hạn min/max/step riêng của Coin, và
  /// huỷ mọi mã ẩn đang khớp ở ô Coin (đã chuyển sang nhập số bình thường).
  void _dragCoin(double v) {
    final snapped = _snapToStep(v,
        minValue: _coinMinValue, maxValue: _coinMaxValue, step: _coinStep);
    setState(() {
      _coin = snapped;
      _coinTextController.text = '$snapped';
      _coinInfiniteCode = false;
      _coinZeroCode = false;
    });
  }

  /// Kéo thanh trượt Gem -> tương tự [_dragCoin], dùng mốc riêng của Gem.
  void _dragGem(double v) {
    final snapped = _snapToStep(v,
        minValue: _gemMinValue, maxValue: _gemMaxValue, step: _gemStep);
    setState(() {
      _gem = snapped;
      _gemTextController.text = '$snapped';
      _gemInfiniteCode = false;
      _gemZeroCode = false;
    });
  }

  /// Gõ trực tiếp vào ô số Coin -> KHÔNG giới hạn min/max/step, lấy đúng
  /// số đã gõ. Đồng thời nhận diện 2 mã ẩn: mã vô hạn chỉ nhận khi đang ở
  /// chế độ Thưởng, mã reset-về-0 chỉ nhận khi đang ở chế độ Phạt — gõ sai
  /// ngữ cảnh thì bị bỏ qua như văn bản thường (không parse được số).
  void _typeCoin(String text) {
    if (_isReward && text == _kInfiniteCode) {
      setState(() {
        _coinInfiniteCode = true;
        _coinZeroCode = false;
      });
      return;
    }
    if (!_isReward && text == _kZeroOutCode) {
      setState(() {
        _coinZeroCode = true;
        _coinInfiniteCode = false;
      });
      return;
    }
    final parsed = int.tryParse(text);
    setState(() {
      _coinInfiniteCode = false;
      _coinZeroCode = false;
      if (parsed != null) _coin = parsed;
    });
  }

  /// Gõ trực tiếp vào ô số Gem -> tương tự [_typeCoin].
  void _typeGem(String text) {
    if (_isReward && text == _kInfiniteCode) {
      setState(() {
        _gemInfiniteCode = true;
        _gemZeroCode = false;
      });
      return;
    }
    if (!_isReward && text == _kZeroOutCode) {
      setState(() {
        _gemZeroCode = true;
        _gemInfiniteCode = false;
      });
      return;
    }
    final parsed = int.tryParse(text);
    setState(() {
      _gemInfiniteCode = false;
      _gemZeroCode = false;
      if (parsed != null) _gem = parsed;
    });
  }

  Widget _buildAmountRow({
    required String emoji,
    required String label,
    required int value,
    required TextEditingController textController,
    required ValueChanged<String> onTyped,
    required ValueChanged<double> onDragged,
    required bool infiniteActive,
    required bool zeroActive,
    required int minValue,
    required int maxValue,
    required int sliderDivisions,
  }) {
    final codeActive = infiniteActive || zeroActive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('$emoji $label: '),
            const Spacer(),
            SizedBox(
              width: 150,
              child: TextField(
                controller: textController,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.text,
                // Cho phép cả chữ số lẫn các ký tự cần để gõ 2 mã ẩn
                // (*, +, #, =, -) — không giới hạn chỉ số như trước.
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9*+#=\-]')),
                ],
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                onChanged: onTyped,
              ),
            ),
          ],
        ),
        // Phản hồi nhỏ khi 1 trong 2 mã ẩn vừa được gõ khớp — chỉ hiện SAU
        // khi gõ đúng, không có gợi ý/nhãn nào tiết lộ mã trước đó.
        if (infiniteActive)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.all_inclusive_rounded,
                  size: 14, color: AppColors.gold),
              SizedBox(width: 4),
              Text('Sẽ đặt vô hạn',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gold)),
            ]),
          ),
        if (zeroActive)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('Sẽ reset về 0',
                style: TextStyle(fontSize: 11, color: AppColors.danger)),
          ),
        Slider(
          // Thanh trượt chỉ hiển thị trong phạm vi min/max của nó — nếu số
          // đã gõ vượt ngoài phạm vi này, vị trí thanh sẽ kẹp về đầu/cuối
          // thanh cho tới khi được kéo lại, nhưng KHÔNG làm thay đổi số
          // thật đang lưu ở [value]/[textController]. Khi đang có 1 mã ẩn
          // khớp, tạm khoá thanh trượt để tránh vô tình huỷ mã vừa gõ.
          value: value.clamp(minValue, maxValue).toDouble(),
          min: minValue.toDouble(),
          max: maxValue.toDouble(),
          divisions: sliderDivisions,
          label: '$value',
          onChanged: codeActive ? null : onDragged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Thưởng / Phạt ${widget.studentName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Thưởng 🎉')),
                ButtonSegment(value: false, label: Text('Phạt ⚠️')),
              ],
              selected: {_isReward},
              onSelectionChanged: (s) => setState(() {
                _isReward = s.first;
                // Đổi chế độ thì mã ẩn (nếu có) không còn hợp ngữ cảnh nữa
                // (mã vô hạn chỉ dùng khi Thưởng, mã reset-0 chỉ dùng khi
                // Phạt) -> huỷ để tránh áp dụng nhầm.
                _coinInfiniteCode = false;
                _gemInfiniteCode = false;
                _coinZeroCode = false;
                _gemZeroCode = false;
              }),
            ),
            const SizedBox(height: 12),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.info),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Lưu ý: mỗi học sinh chỉ có thể thưởng/phạt 1 lần mỗi '
                      '${FirestoreService.rewardCooldownDays} ngày.',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            _buildAmountRow(
              emoji: '🪙',
              label: 'Coin',
              value: _coin,
              textController: _coinTextController,
              onTyped: _typeCoin,
              onDragged: _dragCoin,
              infiniteActive: _coinInfiniteCode,
              zeroActive: _coinZeroCode,
              minValue: _coinMinValue,
              maxValue: _coinMaxValue,
              sliderDivisions: _coinSliderDivisions,
            ),
            _buildAmountRow(
              emoji: '💎',
              label: 'Gem',
              value: _gem,
              textController: _gemTextController,
              onTyped: _typeGem,
              onDragged: _dragGem,
              infiniteActive: _gemInfiniteCode,
              zeroActive: _gemZeroCode,
              minValue: _gemMinValue,
              maxValue: _gemMaxValue,
              sliderDivisions: _gemSliderDivisions,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration:
                   InputDecoration(labelText: tr('Lý do (không bắt buộc)')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            final sign = _isReward ? 1 : -1;
            Navigator.of(context).pop(_RewardResult(
              coinDelta:
                  (_coinInfiniteCode || _coinZeroCode) ? 0 : sign * _coin,
              gemDelta: (_gemInfiniteCode || _gemZeroCode) ? 0 : sign * _gem,
              coinInfinite: _coinInfiniteCode,
              gemInfinite: _gemInfiniteCode,
              coinZero: _coinZeroCode,
              gemZero: _gemZeroCode,
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
              isReward: _isReward,
            ));
          },
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }
}
