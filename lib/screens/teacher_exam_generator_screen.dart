import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../l10n/tr.dart';
import '../widgets/tr_text.dart';

import '../models/exam_template_model.dart';
import '../models/question_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

/// Màn hình tạo bài/đề theo ma trận. Toàn bộ câu hỏi được chọn từ ngân hàng
/// giáo viên, nên tính năng tạo đề một nhấn vẫn miễn phí và có thể kiểm soát
/// nguồn dữ liệu.
class TeacherExamGeneratorScreen extends StatefulWidget {
  final String teacherId;
  final String classId;
  final int? grade;

  const TeacherExamGeneratorScreen({
    super.key,
    required this.teacherId,
    required this.classId,
    this.grade,
  });

  @override
  State<TeacherExamGeneratorScreen> createState() =>
      _TeacherExamGeneratorScreenState();
}

class _TeacherExamGeneratorScreenState
    extends State<TeacherExamGeneratorScreen> {
  final _service = FirestoreService();
  final _titleController = TextEditingController(text: tr('Đề Toán tự động'));
  static const String _subject = 'Toán';
  String _type = 'Đề kiểm tra';
  DateTime? _dueDate;
  bool _saving = false;
  final Map<String, int> _questionTypeCounts = {
    'multiple_choice': 12,
    'true_false': 4,
    'short_answer': 6,
  };

  // null = "Cả năm" (không lọc học kỳ). Đây là chốt chặn chính để đề không
  // bị lẫn câu hỏi của học kỳ học sinh chưa học tới — xem thêm ghi chú lọc
  // trong `FirestoreService.generateExamFromMatrix`.
  int? _semester;

  // Rỗng = không giới hạn chuyên đề/bài học. Chọn đúng 1 chuyên đề khi ra
  // kiểm tra ngắn (VD 15 phút) cho 1 bài để tránh lẫn câu của bài khác.
  final Set<String> _selectedTopics = {};

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  int get _total =>
      _questionTypeCounts.values.fold(0, (sum, value) => sum + value);

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _generate({required bool oneClick}) async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên đề.')),
      );
      return;
    }
    if (_total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ma trận phải có ít nhất 1 câu.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final matrix = ExamMatrix(
        topicCounts: const {},
        difficultyCounts: const {},
        questionTypeCounts: Map.unmodifiable(_questionTypeCounts),
      );
      await _service.generateExamFromMatrix(
        teacherId: widget.teacherId,
        classId: widget.classId,
        template: ExamTemplate(
          id: '',
          title: _titleController.text.trim(),
          subject: _subject,
          grade: widget.grade,
          assignmentType: _type,
          dueDate: _dueDate,
          matrix: matrix,
        ),
        semester: _semester,
        topics: _selectedTopics.isEmpty ? null : _selectedTopics.toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(oneClick
                  ? 'Đã tạo $_type một nhấn với $_total câu.'
                  : 'Đã tạo $_type theo ma trận với $_total câu.')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tạo đề: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _counter(
      {required String label,
      required int value,
      required VoidCallback onMinus,
      required VoidCallback onPlus}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            IconButton(
                onPressed: value == 0 ? null : onMinus,
                icon: const Icon(Icons.remove_circle_outline)),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
                onPressed: onPlus, icon: const Icon(Icons.add_circle_outline)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(bg: BgKind.lavender, headerStrip: true, 
      appBar: AppBar(
        title: const Text('Tạo đề nâng cao'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<QuestionModel>>(
        stream: _service.watchTeacherQuestions(
          teacherId: widget.teacherId,
          subject: _subject,
          grade: widget.grade,
        ),
        builder: (context, snapshot) {
          // Câu hỏi trong NGÂN HÀNG RIÊNG của giáo viên (đã lọc theo Môn
          // học + Khối lớp), dùng để: (1) liệt kê chuyên đề đang có, và
          // (2) ước lượng số câu khớp bộ lọc trước khi bấm tạo đề. Lúc tạo
          // đề thật còn cộng thêm câu công khai từ giáo viên khác nên số
          // thật có thể nhiều hơn số xem trước ở đây.
          final ownQuestions = snapshot.data ?? const <QuestionModel>[];
          // Khớp đúng logic lọc trong generateExamFromMatrix: câu CHƯA GÁN
          // học kỳ (semester == null) được coi là phù hợp với mọi học kỳ.
          final inSemesterScope = ownQuestions
              .where((q) =>
                  _semester == null ||
                  q.semester == null ||
                  q.semester == _semester)
              .toList();
          final availableTopics = inSemesterScope
              .map((q) => (q.topic ?? '').trim())
              .where((t) => t.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          final matchingCount = inSemesterScope
              .where((q) =>
                  _selectedTopics.isEmpty ||
                  _selectedTopics.contains((q.topic ?? '').trim()))
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              TextField(
                controller: _titleController,
                decoration:  InputDecoration(
                  labelText: tr('Tên bài/đề'),
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration:  InputDecoration(labelText: tr('Loại')),
                items: const [
                  DropdownMenuItem(value: 'Bài tập', child: Text('Bài tập')),
                  DropdownMenuItem(
                      value: 'Đề kiểm tra', child: Text('Đề kiểm tra')),
                ],
                onChanged: (value) => setState(() => _type = value ?? _type),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDueDate,
                icon: const Icon(Icons.event),
                label: Text(_dueDate == null
                    ? 'Chọn hạn nộp (không bắt buộc)'
                    : 'Hạn ${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'),
              ),
              const SizedBox(height: 22),
              const Text('Học kỳ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  'Chỉ lấy câu đã gán ĐÚNG học kỳ này (câu chưa gán học kỳ vẫn '
                  'được tính là phù hợp) — tránh đề hỏi nội dung học sinh chưa '
                  'học tới.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
              SegmentedButton<int?>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('Học kỳ 1')),
                  ButtonSegment(value: 2, label: Text('Học kỳ 2')),
                  ButtonSegment(value: null, label: Text('Cả năm')),
                ],
                selected: {_semester},
                onSelectionChanged: (s) => setState(() {
                  _semester = s.first;
                  _selectedTopics.clear();
                }),
              ),
              const SizedBox(height: 22),
              const Text('Chuyên đề / Bài học',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  'Ra kiểm tra ngắn cho 1 bài? Chọn đúng 1 chuyên đề dưới đây để '
                  'đề không lẫn câu của bài khác. Không chọn gì = lấy mọi '
                  'chuyên đề.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
              if (availableTopics.isEmpty)
                const Text(
                  'Ngân hàng chưa có câu hỏi nào được gán "Chuyên đề" trong phạm vi đang lọc.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final topic in availableTopics)
                      FilterChip(
                        label: Text(topic),
                        selected: _selectedTopics.contains(topic),
                        onSelected: (v) => setState(() {
                          if (v) {
                            _selectedTopics.add(topic);
                          } else {
                            _selectedTopics.remove(topic);
                          }
                        }),
                      ),
                  ],
                ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fact_check_rounded,
                        size: 18, color: AppColors.info),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ngân hàng của bạn đang có $matchingCount câu khớp đúng phạm vi trên '
                        '(chưa tính câu công khai từ giáo viên khác có thể được cộng thêm lúc tạo đề).',
                        style: const TextStyle(
                            color: AppColors.info, fontSize: 11.5, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Ma trận đề THPT — ba phần',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 6),
                child: Text(
                  'Các số lượng dưới đây là cấu hình mặc định có thể chỉnh. Hệ thống chỉ lấy đúng dạng câu tương ứng từ ngân hàng.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
              _counter(
                label: 'Phần I — Trắc nghiệm 4 lựa chọn',
                value: _questionTypeCounts['multiple_choice'] ?? 0,
                onMinus: () => setState(() =>
                    _questionTypeCounts['multiple_choice'] =
                        (_questionTypeCounts['multiple_choice'] ?? 0) - 1),
                onPlus: () => setState(() =>
                    _questionTypeCounts['multiple_choice'] =
                        (_questionTypeCounts['multiple_choice'] ?? 0) + 1),
              ),
              _counter(
                label: 'Phần II — Đúng / Sai',
                value: _questionTypeCounts['true_false'] ?? 0,
                onMinus: () => setState(() =>
                    _questionTypeCounts['true_false'] =
                        (_questionTypeCounts['true_false'] ?? 0) - 1),
                onPlus: () => setState(() => _questionTypeCounts['true_false'] =
                    (_questionTypeCounts['true_false'] ?? 0) + 1),
              ),
              _counter(
                label: 'Phần III — Trả lời ngắn',
                value: _questionTypeCounts['short_answer'] ?? 0,
                onMinus: () => setState(() =>
                    _questionTypeCounts['short_answer'] =
                        (_questionTypeCounts['short_answer'] ?? 0) - 1),
                onPlus: () => setState(() =>
                    _questionTypeCounts['short_answer'] =
                        (_questionTypeCounts['short_answer'] ?? 0) + 1),
              ),
              const SizedBox(height: 18),
              Text('Tổng số câu: $_total',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : () => _generate(oneClick: false),
                icon: const Icon(Icons.auto_awesome),
                label: Text(_saving ? 'Đang tạo...' : 'Tạo đề theo ma trận'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _generate(oneClick: true),
                icon: const Icon(Icons.flash_on),
                label: const Text('Tạo đề một nhấn'),
              ),
            ],
          );
        },
      ),
    );
  }
}
