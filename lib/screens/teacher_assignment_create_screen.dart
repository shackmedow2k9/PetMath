import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../l10n/tr.dart';
import '../widgets/tr_text.dart';
import '../models/question_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/vietnamese_utils.dart';
import '../widgets/math_text.dart';

/// Giáo viên chọn môn + câu hỏi từ Ngân hàng câu hỏi của mình để "Giao bài"
/// cho 1 lớp, kèm tiêu đề và hạn nộp (không bắt buộc). [grade] (nếu lớp đã
/// có khối) dùng để chỉ hiện môn học phù hợp và lọc câu hỏi đúng khối.
class TeacherAssignmentCreateScreen extends StatefulWidget {
  final String teacherId;
  final String classId;
  final int? grade;
  const TeacherAssignmentCreateScreen(
      {super.key, required this.teacherId, required this.classId, this.grade});

  @override
  State<TeacherAssignmentCreateScreen> createState() =>
      _TeacherAssignmentCreateScreenState();
}

class _TeacherAssignmentCreateScreenState
    extends State<TeacherAssignmentCreateScreen> {
  final _firestoreService = FirestoreService();
  final _titleController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  static const String _subject = 'Toán';
  String _assignmentType = 'Bài tập';
  DateTime? _dueDate;
  final Set<String> _selectedIds = {};
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _create() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tiêu đề bài tập')),
      );
      return;
    }
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chọn ít nhất 1 câu hỏi')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _firestoreService.createAssignment(
        classId: widget.classId,
        teacherId: widget.teacherId,
        title: _titleController.text.trim(),
        subject: _subject,
        questionIds: _selectedIds.toList(),
        dueDate: _dueDate,
        assignmentType: _assignmentType,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi giao bài: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(bg: BgKind.lavender, headerStrip: true, 
      appBar: AppBar(
        title: const Text('Giao bài kiểm tra'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration:  InputDecoration(
                        labelText: tr('Tiêu đề bài tập'),
                        hintText: tr('VD: Ôn tập chương 1')),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _assignmentType,
                    decoration:  InputDecoration(labelText: tr('Loại bài')),
                    items: const [
                      DropdownMenuItem(
                          value: 'Bài tập', child: Text('Bài tập')),
                      DropdownMenuItem(
                          value: 'Đề kiểm tra', child: Text('Đề kiểm tra')),
                    ],
                    onChanged: (value) => setState(
                        () => _assignmentType = value ?? _assignmentType),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickDueDate,
                    icon: const Icon(Icons.event),
                    label: Text(_dueDate == null
                        ? 'Hạn nộp'
                        : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: tr('Tìm theo tên bài'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Chọn câu hỏi từ Ngân hàng câu hỏi của bạn:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textSecondary)),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<QuestionModel>>(
                stream: _firestoreService.watchTeacherQuestions(
                    teacherId: widget.teacherId,
                    subject: _subject,
                    grade: widget.grade),
                builder: (context, snapshot) {
                  final allQuestions = snapshot.data ?? [];
                  final query = foldVietnamese(_searchQuery.trim());
                  final questions = query.isEmpty
                      ? allQuestions
                      : allQuestions
                          .where((q) =>
                              foldVietnamese(q.topic ?? '').contains(query))
                          .toList();
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (allQuestions.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Bạn chưa có câu hỏi môn $_subject trong Ngân hàng '
                          'câu hỏi. Hãy vào tab "Ngân hàng câu hỏi" để tạo '
                          'câu hỏi trước.',
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }
                  if (questions.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Không tìm thấy câu hỏi nào có tên bài khớp '
                          '"$_searchQuery".',
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: questions.length,
                    itemBuilder: (context, index) {
                      final q = questions[index];
                      final checked = _selectedIds.contains(q.id);
                      return CheckboxListTile(
                        value: checked,
                        title: MathText(
                          q.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: (q.topic == null || q.topic!.isEmpty)
                            ? null
                            : Text(q.topic!,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selectedIds.add(q.id);
                          } else {
                            _selectedIds.remove(q.id);
                          }
                        }),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: _saving ? null : _create,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Giao bài (${_selectedIds.length} câu)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
