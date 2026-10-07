import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../l10n/tr.dart';
import '../widgets/tr_text.dart';

import '../models/question_model.dart';
import '../models/exam_composition_model.dart';
import '../services/curriculum.dart';
import '../services/firestore_service.dart';
import '../services/word_question_parser.dart';
import '../theme/app_theme.dart';
import '../widgets/math_text.dart';

class TeacherWordImportScreen extends StatefulWidget {
  final String teacherId;
  final int? initialGrade;
  final String? classId;
  final String assignmentType;

  const TeacherWordImportScreen({
    super.key,
    required this.teacherId,
    this.initialGrade,
    this.classId,
    this.assignmentType = 'Đề kiểm tra',
  });

  @override
  State<TeacherWordImportScreen> createState() =>
      _TeacherWordImportScreenState();
}

class _TeacherWordImportScreenState extends State<TeacherWordImportScreen> {
  final _service = FirestoreService();
  final _parser = const WordQuestionParser();
  final _sourceNameController = TextEditingController();
  final _sourceUrlController = TextEditingController();
  Uint8List? _bytes;
  String? _fileName;
  static const String _subject = 'Toán';
  int? _grade;
  bool _isPublic = false;
  WordImportResult? _result;
  ComposedExam? _composed;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _grade = widget.initialGrade;
  }

  @override
  void dispose() {
    _sourceNameController.dispose();
    _sourceUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickWord() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['docx'],
    );
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      setState(() {
        _bytes = bytes;
        _fileName = file.name;
        _result = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không đọc được tệp Word: $e')),
        );
      }
    }
  }

  void _preview() {
    final bytes = _bytes;
    final sourceName = _sourceNameController.text.trim().isEmpty
        ? (_fileName ?? 'Tài liệu Word của giáo viên')
        : _sourceNameController.text.trim();
    final sourceUrl = _sourceUrlController.text.trim().isEmpty
        ? 'docx://${_fileName ?? 'teacher-import'}'
        : _sourceUrlController.text.trim();
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy chọn tệp DOCX trước.')),
      );
      return;
    }
    final result = _parser.parse(
      bytes: bytes,
      subject: _subject,
      grade: _grade,
      sourceId: 'word_${DateTime.now().millisecondsSinceEpoch}',
      sourceName: sourceName,
      sourceUrl: sourceUrl,
      createdBy: widget.teacherId,
    );
    setState(() {
      _result = result;
      // Trộn đề xem trước từ các câu HỢP LỆ, kể cả khi có vài câu lỗi —
      // lỗi chỉ chặn riêng những câu đó, không chặn phần còn lại.
      _composed = result.questions.isNotEmpty
          ? const ExamComposer().compose(
              questions: result.questions,
              title: _fileName ?? 'Đề nhập từ Word',
              assignmentType: widget.assignmentType,
            )
          : null;
    });
  }

  Future<void> _save() async {
    final result = _result;
    if (result == null) {
      _preview();
      return;
    }
    // Chỉ cần có ít nhất 1 câu hợp lệ là lưu được — các câu lỗi (nếu có)
    // vẫn hiển thị ở trên để giáo viên biết mà sửa lại trong file gốc và
    // nhập lại riêng, nhưng không chặn những câu đã hợp lệ.
    if (result.questions.isEmpty) return;
    setState(() => _saving = true);
    try {
      final uploadedMedia = <String, String>{};
      for (final asset in result.mediaAssets) {
        uploadedMedia[asset.path] = await _service.uploadQuestionMedia(
          bytes: asset.bytes,
          fileName: asset.fileName,
          teacherId: widget.teacherId,
        );
      }
      final questionIds = <String>[];
      for (final question in result.questions) {
        final mediaUrls = question.mediaUrls.map((url) {
          if (!url.startsWith('docx:')) return url;
          return uploadedMedia[url.substring(5)] ?? url;
        }).toList();
        questionIds.add(await _service.createQuestion(
          question.copyWith(mediaUrls: mediaUrls, isPublic: _isPublic),
        ));
      }
      if (widget.classId != null && _composed != null) {
        await _service.createAssignmentFromComposedExam(
          classId: widget.classId!,
          teacherId: widget.teacherId,
          title: _composed!.title,
          subject: _subject,
          assignmentType: widget.assignmentType,
          questionIds: questionIds,
          sections: _composed!.sections,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu câu hỏi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _fieldSummary(QuestionModel question, int index) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('${index + 1}')),
        title: MathText(
          question.content,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${question.isMultipleChoice ? '4 lựa chọn' : question.isTrueFalse ? 'Đúng/Sai' : 'Trả lời ngắn'}'
          ' · Độ khó ${question.difficulty}'
          '${question.topic == null ? '' : ' · ${question.topic}'}'
          '${question.mediaUrls.isEmpty ? '' : ' · Có media'}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grades = Curriculum.allGrades;
    final result = _result;
    return ScreenScaffold(bg: BgKind.lavender, headerStrip: true, 
      appBar: AppBar(
        title: const Text('Nhập đề từ Microsoft Word'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text(
            'Mẫu cú pháp DOCX',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Câu 1. Nội dung câu hỏi\nChuyên đề: Hàm số\nDạng: Trắc nghiệm\nA. Lựa chọn A\nB. Lựa chọn B\nC. Lựa chọn C\nD. Lựa chọn D\nĐáp án: B',
                  style:
                      TextStyle(color: AppColors.textSecondary, height: 1.45),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                const Text(
                  'Câu 2. Cho hàm số y = x² − 2x. Xét các mệnh đề sau:\nDạng: Đúng/Sai\nA. Hàm số nghịch biến trên (−∞; 1)\nB. Hàm số đồng biến trên (−∞; 1)\nC. Đồ thị cắt trục hoành tại 2 điểm\nD. Giá trị nhỏ nhất của hàm số là −1',
                  style:
                      TextStyle(color: AppColors.textSecondary, height: 1.45),
                ),
                const SizedBox(height: 4),
                RichText(
                  text:  TextSpan(
                    style:
                        TextStyle(color: AppColors.textSecondary, height: 1.45),
                    children: [
                      TextSpan(
                          text: tr('Đáp án: '),
                          style: TextStyle(color: AppColors.textSecondary)),
                      TextSpan(
                          text: tr('Đ, S, Đ, S'),
                          style: TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 14),
                const Text(
                  'Câu 3. Tính giá trị\nDạng: Trả lời ngắn\nĐáp án: 8',
                  style:
                      TextStyle(color: AppColors.textSecondary, height: 1.45),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Dòng "Chuyên đề:" (hoặc "Chủ đề:") ghi tên bài/chuyên đề '
                  'của câu hỏi đó (như ví dụ Câu 1) — cùng với Độ khó, '
                  'Hình 3D, Ảnh, đều là tùy chọn, có thể bỏ qua.',
                  style:
                      TextStyle(color: AppColors.textSecondary, height: 1.45),
                ),
                const SizedBox(height: 10),
                const Text(
                  '⚠️ Riêng dạng Đúng/Sai: dòng "Đáp án:" phải liệt kê ĐỦ 1 ký tự Đ hoặc S cho TỪNG mệnh đề phía trên, đúng thứ tự A → B → C → D, cách nhau bằng dấu phẩy (như ví dụ Câu 2). KHÔNG viết kiểu "B/Đúng", "Đ/S" (chỉ 1 cặp), hay chỉ nêu 1 đáp án chung — thiếu đáp án cho bất kỳ mệnh đề nào cũng sẽ bị báo lỗi và KHÔNG lưu được câu đó.',
                  style: TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickWord,
            icon: const Icon(Icons.upload_file),
            label: Text(_fileName ?? 'Chọn tệp DOCX'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _grade,
            decoration:  InputDecoration(labelText: tr('Khối')),
            items: Curriculum.gradeDropdownItems(grades),
            onChanged: (value) => setState(() => _grade = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sourceNameController,
            decoration:  InputDecoration(
              labelText: tr('Tên nguồn tài liệu (có thể bỏ qua)'),
              hintText: tr('VD: Tài liệu Toán THPT được cấp phép'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sourceUrlController,
            keyboardType: TextInputType.url,
            decoration:  InputDecoration(
              labelText: tr('URL nguồn / giấy phép (có thể bỏ qua)'),
              hintText: 'https://...',
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: _isPublic
                  ? AppColors.success.withValues(alpha: 0.08)
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              value: _isPublic,
              activeColor: AppColors.success,
              onChanged: (v) => setState(() => _isPublic = v),
              title: const Text(
                  'Chia sẻ công khai cả lô câu hỏi này cho giáo viên khác',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                _isPublic
                    ? 'Mọi giáo viên khác sẽ thấy toàn bộ câu hỏi trong tệp này ở "Kho công khai".'
                    : 'Chỉ riêng bạn dùng được các câu hỏi này. Bật lên để đóng góp vào kho chung.',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12, height: 1.35),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _preview,
            icon: const Icon(Icons.fact_check),
            label: const Text('Kiểm tra và xem trước'),
          ),
          if (result != null) ...[
            const SizedBox(height: 18),
            if (result.errors.isNotEmpty)
              Card(
                color: AppColors.danger.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result.errors.join('\n'),
                          style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 6),
                      const Text(
                        'Các câu này sẽ KHÔNG được lưu. Sửa lại trong tệp Word rồi nhập lại nếu cần — không ảnh hưởng đến những câu hợp lệ bên dưới.',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
            Text(
              'Hợp lệ: ${result.questions.length} câu · Media trong Word: ${result.mediaAssets.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_composed != null) ...[
              const Text('Cấu trúc đề sau khi trộn',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ..._composed!.sections.map((section) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.view_list_outlined),
                    title: Text(section.title),
                    subtitle: Text(
                        '${section.questionIds.length} câu · ${section.instructions}'),
                  )),
              Text(widget.classId == null
                  ? 'Lưu để đưa câu hỏi vào ngân hàng. Mở màn hình này từ dashboard lớp để giao đề ngay.'
                  : 'Lưu để đưa câu hỏi vào ngân hàng và giao đề này cho lớp.'),
              const SizedBox(height: 8),
            ],
            ...result.questions.take(10).toList().asMap().entries.map(
                  (entry) => _fieldSummary(entry.value, entry.key),
                ),
            if (result.questions.length > 10)
              Text('... và ${result.questions.length - 10} câu khác'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving || result.questions.isEmpty ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_saving
                  ? 'Đang lưu...'
                  : widget.classId == null
                      ? 'Lưu ${result.questions.length} câu vào ngân hàng câu hỏi'
                      : 'Lưu ${result.questions.length} câu và giao đề cho lớp'),
            ),
          ],
        ],
      ),
    );
  }
}
