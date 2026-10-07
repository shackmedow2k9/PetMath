import 'package:cloud_firestore/cloud_firestore.dart';

/// Ma trận sinh đề do giáo viên thiết lập.
/// difficultyCounts dùng khóa 1/2/3 tương ứng Dễ/Trung bình/Khó.
class ExamMatrix {
  final Map<String, int> topicCounts;
  final Map<int, int> difficultyCounts;

  /// multiple_choice, true_false, short_answer.
  final Map<String, int> questionTypeCounts;

  const ExamMatrix({
    this.topicCounts = const {},
    this.difficultyCounts = const {},
    this.questionTypeCounts = const {},
  });

  int get totalQuestions => questionTypeCounts.isNotEmpty
      ? questionTypeCounts.values.fold(0, (sum, value) => sum + value)
      : topicCounts.isNotEmpty
          ? topicCounts.values.fold(0, (sum, value) => sum + value)
          : difficultyCounts.values.fold(0, (sum, value) => sum + value);

  Map<String, dynamic> toMap() => {
        'topicCounts': topicCounts,
        'difficultyCounts': difficultyCounts.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
        'questionTypeCounts': questionTypeCounts,
      };

  factory ExamMatrix.fromMap(Map<String, dynamic> map) {
    final rawTopics = Map<String, dynamic>.from(map['topicCounts'] ?? {});
    final rawDifficulty =
        Map<String, dynamic>.from(map['difficultyCounts'] ?? {});
    final rawTypes = Map<String, dynamic>.from(map['questionTypeCounts'] ?? {});
    return ExamMatrix(
      topicCounts: rawTopics.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
      difficultyCounts: rawDifficulty.map(
        (key, value) =>
            MapEntry(int.tryParse(key) ?? 1, (value as num).toInt()),
      ),
      questionTypeCounts: rawTypes.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
    );
  }
}

/// Cấu hình đầy đủ cho một lần tạo bài/đề.
class ExamTemplate {
  final String id;
  final String title;
  final String subject;
  final int? grade;
  final String assignmentType;
  final int durationMinutes;
  final DateTime? dueDate;
  final ExamMatrix matrix;

  const ExamTemplate({
    required this.id,
    required this.title,
    required this.subject,
    this.grade,
    this.assignmentType = 'Đề kiểm tra',
    this.durationMinutes = 45,
    this.dueDate,
    this.matrix = const ExamMatrix(),
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'subject': subject,
        'grade': grade,
        'assignmentType': assignmentType,
        'durationMinutes': durationMinutes,
        'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
        'matrix': matrix.toMap(),
      };
}
