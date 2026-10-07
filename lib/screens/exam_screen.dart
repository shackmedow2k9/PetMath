import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../l10n/tr.dart';
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';
import '../l10n/gen/app_localizations.dart';
import '../models/pet_model.dart';
import '../models/question_model.dart';
import '../providers/auth_provider.dart';
import '../providers/pet_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/math_3d_visuals.dart';
import '../widgets/math_text.dart';
import 'ai_tutor_screen.dart';
import 'exam_result_screen.dart';

/// Màn hình làm bài — vòng lặp cốt lõi của app:
/// làm đúng câu -> +EXP/câu (xem FirestoreService.xpPerCorrectAnswer)
/// -> EXP dư tự cộng dồn sang cấp kế tiếp -> pet lên level.
class ExamScreen extends StatefulWidget {
  final String subject;
  // Tên hiển thị tùy theo phiên học (luyện nhanh, đề giữa kỳ...).
  final String? displayTitle;
  final String? topic;
  final String? bookSeries;
  final String? sourceId;
  // Khối lớp/chuyên đề/bộ sách dùng để lọc đúng ngân hàng nguồn khi
  // presetQuestions không được truyền vào.
  final int? grade;
  // Nếu khác null, đây là 1 bài được Giáo viên GIAO cho lớp: dùng đúng bộ
  // câu hỏi cố định này (không random như luồng "Làm bài" thường ngày), và
  // sau khi nộp bài sẽ ghi kết quả vào assignment tương ứng ([assignmentId])
  // để giáo viên theo dõi tiến độ cả lớp.
  final List<QuestionModel>? presetQuestions;
  final String? assignmentId;

  const ExamScreen({
    super.key,
    required this.subject,
    this.displayTitle,
    this.topic,
    this.bookSeries,
    this.sourceId,
    this.grade,
    this.presetQuestions,
    this.assignmentId,
  });

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  final _firestoreService = FirestoreService();
  List<QuestionModel> _questions = [];
  int _currentIndex = 0;
  int _correctCount = 0;
  int? _selectedOptionIndex;
  final Map<int, bool> _trueFalseSelections = {};
  String _shortAnswerDraft = '';
  bool _hasSelection = false;
  bool _answerSubmitted = false;
  bool _isLoading = true;
  final List<String> _wrongIds = [];

  // ---- Điểm số (thang điểm, KHÁC với _correctCount ở trên) ----
  // _correctCount/_wrongIds vẫn giữ nguyên ý nghĩa cũ (đếm câu ĐÚNG HOÀN
  // TOÀN, dùng để tính EXP/Coin/trừ HP như trước — không đổi). _totalScore/
  // _maxScore là điểm số kiểu "thang 10" cộng dồn theo từng dạng câu:
  // trắc nghiệm 0,25đ/câu đúng; đúng/sai tính điểm một phần theo số mệnh
  // đề đúng (1 mệnh đề = 0,1đ; 2 = 0,25đ; 3 = 0,5đ; 4 = 1đ); trả lời ngắn
  // 0,5đ/câu đúng. Dùng để hiển thị điểm ở màn kết quả, tách biệt khỏi
  // phần thưởng EXP/Coin/HP để không ảnh hưởng cơ chế game hiện tại.
  static const double _multipleChoicePoints = 0.25;
  static const double _shortAnswerPoints = 0.5;
  static const List<double> _trueFalsePointsByCorrectCount = [
    0, // 0 mệnh đề đúng
    0.1, // 1 mệnh đề đúng
    0.25, // 2 mệnh đề đúng
    0.5, // 3 mệnh đề đúng
    1.0, // 4 mệnh đề đúng (hoặc nhiều hơn, chặn ở mức tối đa 1đ)
  ];
  double _totalScore = 0;
  double _maxScore = 0;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final questions = widget.presetQuestions ??
        await _firestoreService.fetchQuestions(
          widget.subject,
          grade: widget.grade,
          topic: widget.topic,
          bookSeries: widget.bookSeries,
          sourceId: widget.sourceId,
        );
    setState(() {
      _questions = questions;
      _isLoading = false;
    });
  }

  void _selectOption(int index) {
    if (_answerSubmitted) return;
    setState(() {
      _selectedOptionIndex = index;
      _hasSelection = true;
    });
  }

  void _selectTrueFalse(int index, bool value) {
    if (_answerSubmitted) return;
    setState(() {
      _trueFalseSelections[index] = value;
      _hasSelection = true;
    });
  }

  bool _isShortAnswerCorrect(QuestionModel question) {
    final expected = (question.shortAnswer ?? '').trim().toLowerCase();
    final actual = _shortAnswerDraft.trim().toLowerCase();
    if (expected.isEmpty || actual.isEmpty) return false;
    return expected == actual ||
        expected.replaceAll(',', '.') == actual.replaceAll(',', '.');
  }

  bool _isCurrentAnswerCorrect(QuestionModel question) {
    if (question.isMultipleChoice) {
      return _selectedOptionIndex == question.correctOptionIndex;
    }
    if (question.isTrueFalse) {
      final expected = question.trueFalseAnswers ?? const <bool>[];
      if (expected.isEmpty || expected.length != question.options.length) {
        return false;
      }
      return List.generate(expected.length,
              (index) => _trueFalseSelections[index] == expected[index])
          .every((value) => value);
    }
    return _isShortAnswerCorrect(question);
  }

  /// Điểm tối đa có thể đạt được của 1 câu, theo dạng câu.
  double _maxPointsForQuestion(QuestionModel question) {
    if (question.isShortAnswer) return _shortAnswerPoints;
    if (question.isTrueFalse) return _trueFalsePointsByCorrectCount.last;
    return _multipleChoicePoints;
  }

  /// Điểm học sinh thực sự đạt được của câu hiện tại, dựa trên lựa chọn
  /// đã chọn — với câu đúng/sai thì tính điểm MỘT PHẦN theo số mệnh đề
  /// chọn đúng (không phải kiểu "đúng hết mới có điểm" như _correctCount).
  double _earnedPointsForQuestion(QuestionModel question) {
    if (question.isMultipleChoice) {
      return _selectedOptionIndex == question.correctOptionIndex
          ? _multipleChoicePoints
          : 0;
    }
    if (question.isShortAnswer) {
      return _isShortAnswerCorrect(question) ? _shortAnswerPoints : 0;
    }
    if (question.isTrueFalse) {
      final expected = question.trueFalseAnswers ?? const <bool>[];
      if (expected.isEmpty) return 0;
      var correctStatements = 0;
      for (var i = 0; i < expected.length; i++) {
        if (_trueFalseSelections[i] == expected[i]) correctStatements++;
      }
      final tableIndex = correctStatements
          .clamp(0, _trueFalsePointsByCorrectCount.length - 1)
          .toInt();
      return _trueFalsePointsByCorrectCount[tableIndex];
    }
    return 0;
  }

  void _commitCurrentAnswer() {
    final question = _questions[_currentIndex];
    _totalScore += _earnedPointsForQuestion(question);
    _maxScore += _maxPointsForQuestion(question);
    if (_isCurrentAnswerCorrect(question)) {
      _correctCount++;
    } else {
      _wrongIds.add(question.id);
    }
  }

  void _submitCurrentAnswer() {
    if (!_hasSelection || _answerSubmitted) return;
    _commitCurrentAnswer();
    setState(() => _answerSubmitted = true);
  }

  Future<void> _nextQuestion() async {
    if (!_answerSubmitted) return;

    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionIndex = null;
        _trueFalseSelections.clear();
        _shortAnswerDraft = '';
        _hasSelection = false;
        _answerSubmitted = false;
      });
    } else {
      await _submitExam();
    }
  }

  void _askAiTutor(QuestionModel question) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiTutorScreen(
          questionText: question.content,
          options: question.options,
          questionId: question.id,
          // Không gắn assignmentId/isExamOrAssignment: đáp án của CHÍNH
          // câu này đã hiển thị trên màn hình rồi (đã _answerSubmitted),
          // nên không cần chờ nộp toàn bộ bài mới mở được gia sư AI.
          hasSubmitted: true,
        ),
      ),
    );
  }

  Future<void> _submitExam() async {
    final auth = context.read<AuthProvider>();
    final petProvider = context.read<PetProvider>();
    final student = auth.currentStudent!;

    final result = await _firestoreService.submitExam(
      student: student,
      petId: petProvider.pet!.id,
      subject: widget.subject,
      correctCount: _correctCount,
      totalQuestions: _questions.length,
      wrongQuestionIds: _wrongIds,
      grade: widget.grade,
      topic: widget.topic,
      score: _totalScore,
      maxScore: _maxScore,
    );
    // submitExam ghi coin/EXP/streak lên Firestore, nhưng auth.currentStudent
    // chỉ nạp 1 lần lúc đăng nhập (không phải stream) nên cần nạp lại thủ
    // công ở đây, nếu không streak/coin trên giao diện sẽ hiển thị số cũ.
    await auth.refreshCurrentStudent();

    // Nếu đây là bài được giao, ghi luôn kết quả vào assignment để giáo
    // viên thấy học sinh đã làm (Dashboard "Hôm nay X em học").
    if (widget.assignmentId != null) {
      await _firestoreService.submitAssignmentResult(
        assignmentId: widget.assignmentId!,
        studentId: student.uid,
        correctCount: _correctCount,
        totalQuestions: _questions.length,
        score: _totalScore,
        maxScore: _maxScore,
      );
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ExamResultScreen(
          result: result,
          questions: _questions,
          assignmentId: widget.assignmentId,
          isExamOrAssignment: widget.assignmentId != null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ScreenScaffold(bg: BgKind.lavender, body: Center(child: CircularProgressIndicator()));
    }
    if (_questions.isEmpty) {
      return ScreenScaffold(bg: BgKind.lavender, 
        appBar: AppBar(title: Text(widget.displayTitle ?? widget.subject)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.library_books_outlined,
                    size: 54, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  widget.presetQuestions != null
                      ? 'Chưa có bài tập nội bộ cho chuyên đề này'
                      : 'Chưa có câu hỏi nguồn cho phiên này',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.presetQuestions != null
                      ? 'Hãy cập nhật math_practice_catalog.dart và chép lại file MathLessonScreen mới nhất.'
                      : 'Hãy nạp câu hỏi Toán THPT vào Firestore với khối lớp, chuyên đề và liên kết nguồn trước khi luyện tập.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return ScreenScaffold(bg: BgKind.lavender, 
      appBar: AppBar(title: Text(widget.displayTitle ?? widget.subject)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text('Câu ${_currentIndex + 1}/${_questions.length}',
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: MathText(
                    question.content,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (question.visual3d != null) ...[
                const SizedBox(height: 14),
                Parametric3DCard(
                  config: Math3DConfig.fromQuestionVisual(question.visual3d)!,
                ),
              ],
              if (question.mediaUrls
                  .any((url) => !url.startsWith('docx:'))) ...[
                const SizedBox(height: 14),
                ...question.mediaUrls
                    .where((url) => !url.startsWith('docx:'))
                    .map((url) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              url,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        )),
              ],
              const SizedBox(height: 20),
              Expanded(child: _buildAnswerArea(question)),
              if (_hasSelection) ...[
                // Nút hỏi gia sư AI chỉ xuất hiện SAU khi đã trả lời xong
                // câu hiện tại (cùng lúc với nút "Câu tiếp theo"), và nằm
                // TRÊN nút đó. Học sinh đã thấy đáp án đúng của chính câu
                // này trên màn hình rồi nên hỏi gia sư ở đây không lộ đáp
                // án trước — vì vậy không cần chờ nộp toàn bộ bài.
                // Gia sư AI chỉ xuất hiện khi pet đạt Thân thiết mức I trở lên.
                if (_answerSubmitted &&
                    (context.watch<PetProvider>().pet?.friendship.aiTutorUnlocked ??
                        false))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton.icon(
                      onPressed: () => _askAiTutor(question),
                      icon: const Icon(Icons.school_outlined),
                      label: Text(AppLocalizations.of(context)!.askAiTutorAboutQuestion),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ElevatedButton(
                    onPressed:
                        _answerSubmitted ? _nextQuestion : _submitCurrentAnswer,
                    child: Text(
                      _answerSubmitted
                          ? (_currentIndex < _questions.length - 1
                              ? 'Câu tiếp theo'
                              : 'Xem kết quả')
                          : 'Gửi đáp án',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerArea(QuestionModel question) {
    if (question.isTrueFalse) {
      return ListView.separated(
        itemCount: question.options.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _TrueFalseTile(
          statement: question.options[index],
          value: _trueFalseSelections[index],
          submitted: _answerSubmitted,
          expected: question.trueFalseAnswers != null &&
                  index < question.trueFalseAnswers!.length
              ? question.trueFalseAnswers![index]
              : null,
          onChanged: (value) => _selectTrueFalse(index, value),
        ),
      );
    }
    if (question.isShortAnswer) {
      return ListView(
        children: [
          const Text('Nhập đáp án ngắn rồi bấm Gửi đáp án.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            key: ValueKey(question.id),
            readOnly: _answerSubmitted,
            onChanged: (value) {
              if (!_answerSubmitted) {
                setState(() {
                  _shortAnswerDraft = value;
                  _hasSelection = value.trim().isNotEmpty;
                });
              }
            },
            decoration:  InputDecoration(
              labelText: tr('Câu trả lời ngắn'),
              border: OutlineInputBorder(),
            ),
          ),
          if (_answerSubmitted) ...[
            const SizedBox(height: 12),
            Text('Đáp án chuẩn: ${question.shortAnswer ?? '—'}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ],
      );
    }
    return ListView.separated(
      itemCount: question.options.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _OptionTile(
        text: question.options[index],
        state: _optionState(index, question),
        onTap: () => _selectOption(index),
      ),
    );
  }

  _OptionState _optionState(int index, QuestionModel question) {
    if (!_answerSubmitted) {
      return index == _selectedOptionIndex
          ? _OptionState.selected
          : _OptionState.neutral;
    }
    if (index == question.correctOptionIndex) return _OptionState.correct;
    if (index == _selectedOptionIndex) return _OptionState.wrong;
    return _OptionState.neutral;
  }
}

enum _OptionState { neutral, selected, correct, wrong }

class _OptionTile extends StatelessWidget {
  final String text;
  final _OptionState state;
  final VoidCallback onTap;

  const _OptionTile(
      {required this.text, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    IconData? icon;

    switch (state) {
      case _OptionState.neutral:
        bgColor = Colors.white;
        borderColor = Colors.transparent;
        icon = null;
        break;
      case _OptionState.selected:
        bgColor = AppColors.primary.withValues(alpha: 0.12);
        borderColor = AppColors.primary;
        icon = Icons.radio_button_checked_rounded;
        break;
      case _OptionState.correct:
        bgColor = AppColors.success.withValues(alpha: 0.16);
        borderColor = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case _OptionState.wrong:
        bgColor = AppColors.danger.withValues(alpha: 0.16);
        borderColor = AppColors.danger;
        icon = Icons.cancel_rounded;
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: MathText(text, style: const TextStyle(fontSize: 15)),
            ),
            if (icon != null) Icon(icon, color: borderColor),
          ],
        ),
      ),
    );
  }
}

class _TrueFalseTile extends StatelessWidget {
  final String statement;
  final bool? value;
  final bool submitted;
  final bool? expected;
  final ValueChanged<bool> onChanged;

  const _TrueFalseTile({
    required this.statement,
    required this.value,
    required this.submitted,
    required this.expected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect = submitted && value != null && expected == value;
    final isWrong = submitted && value != null && expected != value;
    final color = isCorrect
        ? AppColors.success
        : isWrong
            ? AppColors.danger
            : AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCorrect
            ? AppColors.success.withValues(alpha: 0.12)
            : isWrong
                ? AppColors.danger.withValues(alpha: 0.12)
                : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MathText(statement, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: submitted ? null : () => onChanged(true),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: value == true
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : null,
                  ),
                  child: const Text('Đúng'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: submitted ? null : () => onChanged(false),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: value == false
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : null,
                  ),
                  child: const Text('Sai'),
                ),
              ),
            ],
          ),
          if (submitted && expected != null)
            Text('Đáp án đúng: ${expected! ? 'Đúng' : 'Sai'}',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}