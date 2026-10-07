import 'question_model.dart';

class ExamSection {
  final String title;
  final String instructions;
  final List<String> questionIds;

  const ExamSection({
    required this.title,
    required this.instructions,
    required this.questionIds,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'instructions': instructions,
        'questionIds': questionIds,
      };
}

class ComposedExam {
  final String title;
  final String assignmentType;
  final int durationMinutes;
  final List<ExamSection> sections;
  final List<QuestionModel> questions;

  const ComposedExam({
    required this.title,
    required this.assignmentType,
    required this.durationMinutes,
    required this.sections,
    required this.questions,
  });

  List<String> get questionIds =>
      questions.map((question) => question.id).toList();

  Map<String, dynamic> toMap() => {
        'title': title,
        'assignmentType': assignmentType,
        'durationMinutes': durationMinutes,
        'sections': sections.map((section) => section.toMap()).toList(),
        'questionIds': questionIds,
      };
}

class ExamComposer {
  const ExamComposer();

  ComposedExam compose({
    required List<QuestionModel> questions,
    required String title,
    String assignmentType = 'Đề kiểm tra',
    int durationMinutes = 45,
  }) {
    final sections = <ExamSection>[];
    final hasStructuredTypes = questions
        .any((question) => question.isTrueFalse || question.isShortAnswer);
    if (hasStructuredTypes) {
      const labels = {
        'multiple_choice': 'Phần I — Trắc nghiệm nhiều lựa chọn',
        'true_false': 'Phần II — Trắc nghiệm đúng/sai',
        'short_answer': 'Phần III — Trắc nghiệm trả lời ngắn',
      };
      const instructions = {
        'multiple_choice': 'Chọn một đáp án đúng.',
        'true_false': 'Chọn Đúng hoặc Sai cho từng mệnh đề.',
        'short_answer': 'Nhập đáp án ngắn.',
      };
      for (final type in const [
        'multiple_choice',
        'true_false',
        'short_answer',
      ]) {
        final group = questions
            .where((question) => question.questionType == type)
            .toList();
        if (group.isNotEmpty) {
          sections.add(ExamSection(
            title: labels[type]!,
            instructions: instructions[type]!,
            questionIds: group.map((question) => question.id).toList(),
          ));
        }
      }
    } else {
      final grouped = <String, List<QuestionModel>>{};
      for (final question in questions) {
        final sectionName = switch (question.difficulty) {
          1 => 'Phần I — Nhận biết',
          2 => 'Phần II — Thông hiểu',
          _ => 'Phần III — Vận dụng',
        };
        grouped.putIfAbsent(sectionName, () => []).add(question);
      }
      for (final entry in grouped.entries) {
        sections.add(ExamSection(
          title: entry.key,
          instructions: 'Chọn một đáp án đúng cho mỗi câu hỏi.',
          questionIds: entry.value.map((question) => question.id).toList(),
        ));
      }
    }
    return ComposedExam(
      title: title,
      assignmentType: assignmentType,
      durationMinutes: durationMinutes,
      sections: sections,
      questions: questions,
    );
  }
}
