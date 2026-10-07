import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../l10n/tr.dart';
import '../widgets/tr_text.dart';
import '../models/question_model.dart';
import '../services/curriculum.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/vietnamese_utils.dart';
import '../widgets/math_text.dart';
import 'teacher_home_screen.dart';
import 'teacher_question_edit_screen.dart';
import 'teacher_word_import_screen.dart';

/// Ngân hàng câu hỏi của Giáo viên. Mỗi giáo viên chỉ thấy và quản lý
/// câu hỏi do chính mình tạo. Câu Toán THPT phải có metadata nguồn để được
/// đưa vào luồng luyện tập/đề kiểm tra.
class TeacherQuestionBankScreen extends StatefulWidget {
  final String teacherId;
  const TeacherQuestionBankScreen({super.key, required this.teacherId});

  @override
  State<TeacherQuestionBankScreen> createState() =>
      _TeacherQuestionBankScreenState();
}

class _TeacherQuestionBankScreenState extends State<TeacherQuestionBankScreen> {
  final _firestoreService = FirestoreService();
  int? _gradeFilter;
  // null = Tất cả, 0 = Chưa gán, 1 = Học kỳ 1, 2 = Học kỳ 2. Lọc phía client
  // vì watchTeacherQuestions/watchPublicQuestions chưa hỗ trợ tham số này.
  int? _semesterFilter;
  // false = "Của tôi" (ngân hàng riêng), true = "Kho công khai" (câu hỏi do
  // giáo viên khác chia sẻ). Xem [QuestionModel.isPublic].
  bool _showPublicPool = false;

  // Tìm theo "Tên bài" (field `topic`) — bật/tắt bằng nút kính lúp trên
  // header. Gõ không dấu vẫn tìm được nhờ [foldVietnamese].
  bool _searchExpanded = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _semesterFilterLabel => switch (_semesterFilter) {
        0 => 'Chưa gán',
        1 => 'Học kỳ 1',
        2 => 'Học kỳ 2',
        _ => 'Tất cả',
      };

  List<QuestionModel> _applySemesterFilter(List<QuestionModel> questions) {
    if (_semesterFilter == null) return questions;
    if (_semesterFilter == 0) {
      return questions.where((q) => q.semester == null).toList();
    }
    return questions.where((q) => q.semester == _semesterFilter).toList();
  }

  /// So khớp theo "Tên bài" (field `topic`), không phân biệt hoa/thường và
  /// không phân biệt có dấu hay không (gõ "ham so" vẫn ra "Hàm số ..."),
  /// theo đúng ví dụ giáo viên mô tả: gõ "hàm số" ra mọi bài có chứa cụm đó
  /// (Hàm số đồng biến, nghịch biến, ...).
  List<QuestionModel> _applySearchFilter(List<QuestionModel> questions) {
    final query = foldVietnamese(_searchQuery.trim());
    if (query.isEmpty) return questions;
    return questions
        .where((q) => foldVietnamese(q.topic ?? '').contains(query))
        .toList();
  }

  Future<void> _addQuestion() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TeacherQuestionEditScreen(
          teacherId: widget.teacherId,
          initialGrade: _gradeFilter,
        ),
      ),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm câu hỏi')),
      );
    }
  }

  Future<void> _importWord() async {
    final imported = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TeacherWordImportScreen(
          teacherId: widget.teacherId,
          initialGrade: _gradeFilter,
        ),
      ),
    );
    if (imported == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã nhập câu hỏi từ Word')),
      );
    }
  }

  /// Bấm nút "+" nổi: gọn lại còn 2 lựa chọn thay vì lúc nào cũng chiếm chỗ
  /// bằng một nút "Nhập Word" to nằm riêng trên đầu trang.
  void _openAddOptionsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('Câu hỏi mới',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 4),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.edit_note_rounded,
                      color: AppColors.primary),
                ),
                title: const Text('Nhập thủ công',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Tự soạn từng câu một'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _addQuestion();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.upload_file_rounded,
                      color: AppColors.secondary),
                ),
                title: const Text('Nhập Word (nhập hàng loạt)',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Tải tệp DOCX để thêm nhiều câu cùng lúc'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _importWord();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Nút lọc gọn ở góc header: bấm vào hiện 2 dòng "Môn học" / "Khối lớp"
  /// (mặc định Tất cả / Mọi khối) thay vì 2 hàng chip cuộn ngang chiếm hết
  /// chỗ như trước.
  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Bộ lọc',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 4),
                ListTile(
                  leading: const Icon(Icons.school_rounded,
                      color: AppColors.primary),
                  title: const Text('Khối lớp',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          _gradeFilter == null
                              ? 'Mọi khối'
                              : 'Lớp $_gradeFilter',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600)),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondary),
                    ],
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _pickGrade();
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.class_rounded, color: AppColors.primary),
                  title: const Text('Học kỳ',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_semesterFilterLabel,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600)),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondary),
                    ],
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _pickSemester();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickSemester() async {
    const options = <int?, String>{
      null: 'Tất cả',
      0: 'Chưa gán',
      1: 'Học kỳ 1',
      2: 'Học kỳ 2',
    };
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            for (final entry in options.entries)
              _pickerTile(
                label: entry.value,
                selected: _semesterFilter == entry.key,
                onTap: () {
                  setState(() => _semesterFilter = entry.key);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickGrade() async {
    final grades = Curriculum.sortGradesByEnabled(Curriculum.allGrades);
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            _pickerTile(
              label: 'Mọi khối',
              selected: _gradeFilter == null,
              onTap: () {
                setState(() => _gradeFilter = null);
                Navigator.of(sheetContext).pop();
              },
            ),
            for (final g in grades)
              _pickerTile(
                label: 'Lớp $g',
                selected: _gradeFilter == g,
                enabled: Curriculum.isGradeEnabled(g),
                onTap: () {
                  setState(() => _gradeFilter = g);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _pickerTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return ListTile(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      title: Text(label,
          style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: !enabled
                  ? AppColors.textSecondary.withValues(alpha: 0.5)
                  : selected
                      ? AppColors.primary
                      : AppColors.textPrimary)),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: AppColors.primary)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(bg: BgKind.lavender, headerStrip: true, 
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddOptionsSheet,
        backgroundColor: AppColors.primary,
        tooltip: tr('Câu hỏi mới'),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            TeacherHeroHeader(
              title: 'Ngân hàng câu hỏi',
              subtitle: 'Tự tạo câu hỏi để dùng khi Giao bài cho lớp',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _HeaderIconButton(
                    icon: _searchExpanded
                        ? Icons.close_rounded
                        : Icons.search_rounded,
                    onTap: () => setState(() {
                      _searchExpanded = !_searchExpanded;
                      if (!_searchExpanded) {
                        _searchController.clear();
                        _searchQuery = '';
                      }
                    }),
                  ),
                  const SizedBox(width: 8),
                  _HeaderIconButton(
                    icon: Icons.tune_rounded,
                    onTap: _openFilterSheet,
                  ),
                ],
              ),
            ),
            if (_searchExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: tr('Tìm theo tên bài'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            }),
                          ),
                    filled: true,
                    fillColor: AppColors.surfaceMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _PoolTab(
                        icon: Icons.lock_outline_rounded,
                        label: 'Của tôi',
                        selected: !_showPublicPool,
                        onTap: () => setState(() => _showPublicPool = false),
                      ),
                    ),
                    Expanded(
                      child: _PoolTab(
                        icon: Icons.public_rounded,
                        label: 'Kho công khai',
                        selected: _showPublicPool,
                        onTap: () => setState(() => _showPublicPool = true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<QuestionModel>>(
                stream: _showPublicPool
                    ? _firestoreService.watchPublicQuestions(
                        grade: _gradeFilter, excludeTeacherId: widget.teacherId)
                    : _firestoreService.watchTeacherQuestions(
                        teacherId: widget.teacherId, grade: _gradeFilter),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final questions = _applySearchFilter(
                      _applySemesterFilter(snapshot.data ?? []));
                  final list = questions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              _showPublicPool
                                  ? 'Chưa có câu hỏi công khai nào từ TÀI KHOẢN GIÁO VIÊN KHÁC.\n\nLưu ý: câu do chính bạn bật công khai sẽ KHÔNG hiện lại ở đây — vào tab "Của tôi" để xem, chúng có nhãn "Đã chia sẻ". Tab này chỉ hiện câu của những tài khoản giáo viên khác.'
                                  : _searchQuery.trim().isNotEmpty
                                      ? 'Không tìm thấy câu hỏi nào có tên bài khớp "$_searchQuery".'
                                      : _semesterFilter != null
                                          ? 'Không có câu hỏi nào khớp bộ lọc học kỳ hiện tại.'
                                          : 'Chưa có câu hỏi nào.\nBấm "Câu hỏi mới" để tạo câu hỏi đầu tiên.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      : _buildQuestionList(context, questions);
                  if (!_showPublicPool) return list;
                  // Luôn nhắc lại lý do câu của chính mình không xuất hiện ở
                  // đây, kể cả khi tab đã có dữ liệu (từ giáo viên khác) —
                  // tránh hiểu nhầm "thiếu mất câu mình vừa thêm".
                  return Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 16, color: AppColors.info),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Chỉ hiện câu của giáo viên khác. Câu bạn tự chia sẻ nằm ở tab "Của tôi".',
                                style: const TextStyle(
                                    color: AppColors.info, fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: list),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionList(
      BuildContext context, List<QuestionModel> questions) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: questions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final q = questions[index];
        return _QuestionTile(
          question: q,
          isMine: !_showPublicPool,
          onTap: () async {
            if (_showPublicPool) {
              _showReadOnlyPreview(context, q);
              return;
            }
            final updated = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => TeacherQuestionEditScreen(
                  teacherId: widget.teacherId,
                  initialGrade: q.grade,
                  existing: q,
                ),
              ),
            );
            if (updated == true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã lưu thay đổi')),
              );
            }
          },
          onDelete: !_showPublicPool
              ? () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Xoá câu hỏi?'),
                      content:
                          Text('Xoá "${q.content}" khỏi ngân hàng câu hỏi?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Hủy'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Xoá',
                              style: TextStyle(color: AppColors.danger)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _firestoreService.deleteQuestion(q.id);
                  }
                }
              : null,
        );
      },
    );
  }

  /// Xem nhanh 1 câu hỏi công khai của giáo viên khác — chỉ đọc, không cho
  /// sửa/xoá vì đây không phải câu hỏi do mình tạo.
  void _showReadOnlyPreview(BuildContext context, QuestionModel q) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const Icon(Icons.public_rounded, color: AppColors.success),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Câu hỏi công khai — chỉ xem',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (q.grade != null)
                _Tag(text: tr('Lớp ${q.grade}'), color: AppColors.info),
              _Tag(
                text: q.isMultipleChoice
                    ? '4 lựa chọn'
                    : q.isTrueFalse
                        ? 'Đúng/Sai'
                        : 'Trả lời ngắn',
                color: AppColors.secondary,
              ),
            ]),
            const SizedBox(height: 14),
            MathText(q.content,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            if (q.isMultipleChoice)
              for (var i = 0; i < q.options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${String.fromCharCode(65 + i)}. ${q.options[i]}',
                    style: TextStyle(
                        fontWeight: i == q.correctOptionIndex
                            ? FontWeight.w800
                            : FontWeight.normal,
                        color: i == q.correctOptionIndex
                            ? AppColors.success
                            : AppColors.textPrimary),
                  ),
                )
            else if (q.isShortAnswer)
              Text('Đáp án: ${q.shortAnswer ?? ''}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.success)),
            if (q.explanation != null && q.explanation!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Giải thích: ${q.explanation}',
                  style: const TextStyle(color: AppColors.textSecondary)),
            ],
            if (q.sourceName != null && q.sourceName!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Nguồn: ${q.sourceName}',
                  style: const TextStyle(color: AppColors.info, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Nút icon kính mờ đặt trên banner gradient — dùng cho nút lọc ở header
/// Ngân hàng câu hỏi, cùng phong cách với [TeacherHeroChip].
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

/// Tab bo tròn "Của tôi" / "Kho công khai" — cùng phong cách pill-switch
/// nhất quán với toàn app (xem AppTheme.chipTheme).
class _PoolTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PoolTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected ? AppShadows.card : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  final QuestionModel question;
  final bool isMine;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _QuestionTile({
    required this.question,
    required this.onTap,
    this.isMine = true,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Tag(
                          text: question.isMultipleChoice
                              ? '4 lựa chọn'
                              : question.isTrueFalse
                                  ? 'Đúng/Sai'
                                  : 'Trả lời ngắn',
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 6),
                        if (question.grade != null) ...[
                          _Tag(
                              text: tr('Lớp ${question.grade}'),
                              color: AppColors.info),
                          const SizedBox(width: 6),
                        ],
                        _Tag(
                          text: switch (question.difficulty) {
                            3 => 'Khó',
                            2 => 'Vừa',
                            _ => 'Dễ',
                          },
                          color: switch (question.difficulty) {
                            3 => AppColors.danger,
                            2 => AppColors.secondary,
                            _ => AppColors.success,
                          },
                        ),
                        const SizedBox(width: 6),
                        // Nhãn Học kỳ — câu "Chưa gán" dùng màu cảnh báo để
                        // giáo viên dễ nhận ra và gán bổ sung nếu muốn giới
                        // hạn câu này đúng 1 học kỳ khi tạo đề.
                        _Tag(
                          text: switch (question.semester) {
                            1 => 'HK1',
                            2 => 'HK2',
                            _ => 'Chưa gán HK',
                          },
                          color: question.semester == null
                              ? AppColors.danger
                              : AppColors.info,
                        ),
                        // Đánh dấu câu hỏi công khai — ở tab "Của tôi" đây là
                        // xác nhận đã chia sẻ; ở tab "Kho công khai" đây là
                        // câu của giáo viên khác.
                        if (question.isPublic) ...[
                          const SizedBox(width: 6),
                          _Tag(
                            text: isMine ? 'Đã chia sẻ' : 'Cộng đồng',
                            color: AppColors.success,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (question.topic != null && question.topic!.isNotEmpty)
                      Text(question.topic!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    if (question.sourceName != null &&
                        question.sourceName!.isNotEmpty)
                      Text('Nguồn: ${question.sourceName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.info, fontSize: 11)),
                    const SizedBox(height: 4),
                    MathText(
                      question.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              // Câu của giáo viên khác trong "Kho công khai" không được
              // xoá/sửa — chỉ hiện icon xem, không hiện nút xoá.
              if (isMine && onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon:
                      const Icon(Icons.delete_outline, color: AppColors.danger),
                )
              else if (!isMine)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag({required this.text, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
