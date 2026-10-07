import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../l10n/tr.dart';
import '../widgets/tr_text.dart';
import 'package:file_picker/file_picker.dart';
import '../models/question_model.dart';
import '../services/curriculum.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

/// Form tạo mới hoặc sửa 1 câu hỏi trắc nghiệm. Nếu [existing] khác null,
/// đây là màn sửa (điền sẵn dữ liệu cũ) — ngược lại là tạo mới.
class TeacherQuestionEditScreen extends StatefulWidget {
  final String teacherId;
  final int? initialGrade;
  final QuestionModel? existing;

  const TeacherQuestionEditScreen({
    super.key,
    required this.teacherId,
    this.initialGrade,
    this.existing,
  });

  @override
  State<TeacherQuestionEditScreen> createState() =>
      _TeacherQuestionEditScreenState();
}

class _TeacherQuestionEditScreenState extends State<TeacherQuestionEditScreen> {
  final _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  late final _contentController =
      TextEditingController(text: widget.existing?.content ?? '');
  late final _explanationController =
      TextEditingController(text: widget.existing?.explanation ?? '');
  late final _topicController =
      TextEditingController(text: widget.existing?.topic ?? '');
  late final _bookSeriesController =
      TextEditingController(text: widget.existing?.bookSeries ?? '');
  late final _sourceNameController =
      TextEditingController(text: widget.existing?.sourceName ?? '');
  late final _sourceUrlController =
      TextEditingController(text: widget.existing?.sourceUrl ?? '');
  late final List<TextEditingController> _optionControllers = List.generate(
    4,
    (i) => TextEditingController(
        text: widget.existing != null && i < widget.existing!.options.length
            ? widget.existing!.options[i]
            : ''),
  );
  late final _shortAnswerController =
      TextEditingController(text: widget.existing?.shortAnswer ?? '');
  late String _questionType =
      widget.existing?.questionType ?? 'multiple_choice';
  late List<bool> _trueFalseAnswers = List.generate(
    4,
    (i) => widget.existing?.trueFalseAnswers != null &&
            i < widget.existing!.trueFalseAnswers!.length
        ? widget.existing!.trueFalseAnswers![i]
        : false,
  );
  final List<PlatformFile> _mediaFiles = [];
  // App hiện chỉ còn 1 môn (Toán) nên không cần cho giáo viên chọn nữa —
  // luôn lưu câu hỏi với môn 'Toán'.
  static const String _subject = 'Toán';
  late int? _grade = widget.existing?.grade ?? widget.initialGrade;
  late int _correctIndex = widget.existing?.correctOptionIndex ?? 0;
  late int _difficulty = widget.existing?.difficulty ?? 1;
  // 0 = Chưa gán, 1 = Học kỳ 1, 2 = Học kỳ 2 — dùng số thay vì `int?` để
  // SegmentedButton (generic non-null) dùng được như "Độ khó" bên dưới.
  late int _semesterCode = widget.existing?.semester ?? 0;
  late bool _isPublic = widget.existing?.isPublic ?? false;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _contentController.dispose();
    _explanationController.dispose();
    _topicController.dispose();
    _bookSeriesController.dispose();
    _sourceNameController.dispose();
    _sourceUrlController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    _shortAnswerController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'gif', 'webp'],
      allowMultiple: true,
    );
    if (files.isEmpty) return;
    setState(() => _mediaFiles.addAll(files));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // Thông tin chuyên đề/nguồn là KHÔNG BẮT BUỘC — nhưng nếu câu hỏi đã có
    // nhập nguồn (tên nguồn hoặc liên kết) thì bắt buộc phải nhập rõ ràng
    // cả 2, tránh nguồn nửa vời không xác minh được.
    final hasAnySource = _sourceNameController.text.trim().isNotEmpty ||
        _sourceUrlController.text.trim().isNotEmpty;
    if (hasAnySource &&
        (_sourceNameController.text.trim().isEmpty ||
            _sourceUrlController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Câu hỏi có nguồn cần nhập đầy đủ tên nguồn và liên kết nguồn.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final options = _questionType == 'short_answer'
          ? <String>[]
          : _optionControllers.map((c) => c.text.trim()).toList();
      if (_questionType != 'short_answer' &&
          options.any((value) => value.isEmpty)) {
        throw Exception('Hãy nhập đủ nội dung các mệnh đề/lựa chọn.');
      }
      if (_questionType == 'short_answer' &&
          _shortAnswerController.text.trim().isEmpty) {
        throw Exception('Hãy nhập đáp án ngắn chuẩn.');
      }
      final uploadedUrls = <String>[
        ...(widget.existing?.mediaUrls ?? const [])
      ];
      for (final file in _mediaFiles) {
        final bytes = await file.readAsBytes();
        uploadedUrls.add(await _firestoreService.uploadQuestionMedia(
          bytes: bytes,
          fileName: file.name,
          teacherId: widget.teacherId,
        ));
      }
      final question = QuestionModel(
        id: widget.existing?.id ?? '',
        subject: _subject,
        content: _contentController.text.trim(),
        options: options,
        correctOptionIndex:
            _questionType == 'multiple_choice' ? _correctIndex : 0,
        explanation: _explanationController.text.trim().isEmpty
            ? null
            : _explanationController.text.trim(),
        difficulty: _difficulty,
        createdBy: widget.existing?.createdBy ?? widget.teacherId,
        createdAt: widget.existing?.createdAt,
        grade: _grade,
        topic: _topicController.text.trim().isEmpty
            ? null
            : _topicController.text.trim(),
        semester: _semesterCode == 0 ? null : _semesterCode,
        bookSeries: _bookSeriesController.text.trim().isEmpty
            ? null
            : _bookSeriesController.text.trim(),
        sourceId: _sourceUrlController.text.trim().isEmpty
            ? null
            : _sourceUrlController.text.trim(),
        sourceName: _sourceNameController.text.trim().isEmpty
            ? null
            : _sourceNameController.text.trim(),
        sourceUrl: _sourceUrlController.text.trim().isEmpty
            ? null
            : _sourceUrlController.text.trim(),
        questionType: _questionType,
        trueFalseAnswers:
            _questionType == 'true_false' ? _trueFalseAnswers : null,
        shortAnswer: _questionType == 'short_answer'
            ? _shortAnswerController.text.trim()
            : null,
        mediaUrls: uploadedUrls,
        isPublic: _isPublic,
      );

      if (_isEditing) {
        await _firestoreService.updateQuestion(widget.existing!.id, question);
      } else {
        await _firestoreService.createQuestion(question);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi lưu câu hỏi: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(bg: BgKind.lavender, headerStrip: true, 
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_isEditing ? 'Sửa câu hỏi' : 'Câu hỏi mới'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _FormSection(
                icon: Icons.sell_rounded,
                title: 'Phân loại',
                color: AppColors.info,
                children: [
                  DropdownButtonFormField<int?>(
                    initialValue: _grade,
                    decoration:  InputDecoration(
                        labelText: tr('Khối lớp (không bắt buộc)')),
                    items: Curriculum.gradeDropdownItemsNullable(),
                    onChanged: (v) => setState(() => _grade = v),
                  ),
                  const SizedBox(height: 16),
                  const Text('Học kỳ',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          fontSize: 13)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Chưa gán')),
                        ButtonSegment(value: 1, label: Text('Học kỳ 1')),
                        ButtonSegment(value: 2, label: Text('Học kỳ 2')),
                      ],
                      selected: {_semesterCode},
                      onSelectionChanged: (s) =>
                          setState(() => _semesterCode = s.first),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _topicController,
                    decoration:  InputDecoration(
                      labelText: tr('Tên bài / Chuyên đề'),
                      hintText: tr('Ví dụ: Hàm số đồng biến, nghịch biến'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _questionType,
                    decoration:
                         InputDecoration(labelText: tr('Dạng câu hỏi')),
                    items: const [
                      DropdownMenuItem(
                          value: 'multiple_choice',
                          child: Text('Trắc nghiệm 4 lựa chọn')),
                      DropdownMenuItem(
                          value: 'true_false', child: Text('Đúng / Sai')),
                      DropdownMenuItem(
                          value: 'short_answer',
                          child: Text('Trả lời ngắn')),
                    ],
                    onChanged: (value) => setState(
                        () => _questionType = value ?? 'multiple_choice'),
                  ),
                ],
              ),
              _FormSection(
                icon: Icons.link_rounded,
                title: 'Nguồn tài liệu',
                color: AppColors.secondary,
                trailing: const Text('không bắt buộc',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic)),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Nếu câu hỏi có nguồn, cần nhập đầy đủ và rõ ràng.',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.35),
                    ),
                  ),
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(top: 10),
                      title: const Text('Nhập nguồn tài liệu',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Bộ sách, tên nguồn, liên kết'),
                      children: [
                        TextFormField(
                          controller: _bookSeriesController,
                          decoration:  InputDecoration(
                              labelText: tr('Bộ sách (nếu có)')),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _sourceNameController,
                          decoration:  InputDecoration(
                              labelText: tr('Tên nguồn tài liệu')),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _sourceUrlController,
                          keyboardType: TextInputType.url,
                          decoration:  InputDecoration(
                              labelText: tr('Liên kết nguồn tài liệu')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              _FormSection(
                icon: Icons.quiz_rounded,
                title: 'Nội dung & đáp án',
                color: AppColors.primary,
                children: [
                  TextFormField(
                    controller: _contentController,
                    minLines: 2,
                    maxLines: 4,
                    decoration:
                         InputDecoration(labelText: tr('Nội dung câu hỏi')),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Bắt buộc nhập'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  if (_questionType == 'multiple_choice') ...[
                    const Text(
                        'Bốn lựa chọn — chạm nút tròn để chọn đáp án đúng',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            fontSize: 13)),
                    const SizedBox(height: 8),
                    for (var i = 0; i < 4; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Radio<int>(
                              value: i,
                              groupValue: _correctIndex,
                              activeColor: AppColors.success,
                              onChanged: (v) =>
                                  setState(() => _correctIndex = v ?? 0),
                            ),
                            Expanded(
                              child: TextFormField(
                                controller: _optionControllers[i],
                                decoration: InputDecoration(
                                    labelText:
                                        tr('Lựa chọn ${String.fromCharCode(65 + i)}')),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ] else if (_questionType == 'true_false') ...[
                    const Text('Nhập từng mệnh đề rồi chọn Đúng hoặc Sai',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            fontSize: 13)),
                    const SizedBox(height: 8),
                    for (var i = 0; i < 4; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _optionControllers[i],
                              decoration: InputDecoration(
                                  labelText:
                                      tr('Mệnh đề ${String.fromCharCode(65 + i)}')),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                      value: true, label: Text('Đúng')),
                                  ButtonSegment(
                                      value: false, label: Text('Sai')),
                                ],
                                selected: {_trueFalseAnswers[i]},
                                onSelectionChanged: (value) => setState(
                                    () => _trueFalseAnswers[i] = value.first),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ] else ...[
                    TextFormField(
                      controller: _shortAnswerController,
                      decoration:  InputDecoration(
                        labelText: tr('Đáp án ngắn chuẩn'),
                        hintText: tr('Ví dụ: 8, 2/3 hoặc pi'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickMedia,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(_mediaFiles.isEmpty
                        ? 'Thêm ảnh, đồ thị hoặc bảng'
                        : 'Đã chọn ${_mediaFiles.length} tệp media'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _explanationController,
                    minLines: 1,
                    maxLines: 3,
                    decoration:  InputDecoration(
                        labelText: tr('Giải thích khi làm sai (không bắt buộc)')),
                  ),
                ],
              ),
              _FormSection(
                icon: Icons.tune_rounded,
                title: 'Độ khó & Chia sẻ',
                color: AppColors.success,
                children: [
                  const Text('Độ khó',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          fontSize: 13)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1, label: Text('Dễ')),
                        ButtonSegment(value: 2, label: Text('Vừa')),
                        ButtonSegment(value: 3, label: Text('Khó')),
                      ],
                      selected: {_difficulty},
                      onSelectionChanged: (s) =>
                          setState(() => _difficulty = s.first),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: _isPublic
                          ? AppColors.success.withValues(alpha: 0.08)
                          : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      value: _isPublic,
                      activeColor: AppColors.success,
                      onChanged: (v) => setState(() => _isPublic = v),
                      title: const Text('Chia sẻ công khai cho giáo viên khác',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        _isPublic
                            ? 'Mọi giáo viên khác sẽ thấy câu hỏi này trong "Kho công khai" và có thể dùng khi ra đề.'
                            : 'Chỉ riêng bạn thấy và dùng được câu hỏi này. Bật lên để đóng góp vào kho chung.',
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.35),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_isEditing ? 'Lưu thay đổi' : 'Thêm câu hỏi',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 1 nhóm trường trong form, đóng khung thành thẻ riêng với tiêu đề + icon
/// màu — giúp form dài (tạo câu hỏi) dễ quét mắt theo từng phần thay vì
/// một danh sách trường dài dằng dặc không phân đoạn.
class _FormSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget? trailing;
  final List<Widget> children;

  const _FormSection({
    required this.icon,
    required this.title,
    required this.children,
    this.color = AppColors.primary,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.5,
                        color: AppColors.textPrimary)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}