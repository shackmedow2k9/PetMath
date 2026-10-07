import 'package:cloud_firestore/cloud_firestore.dart';

/// Kết quả 1 học sinh đã làm 1 bài được giao (lưu trong
/// `AssignmentModel.results`, key = studentId).
class AssignmentResult {
  final int correctCount;
  final int totalQuestions;
  final DateTime submittedAt;

  /// Điểm theo cơ chế chấm điểm mới — xem giải thích chi tiết ở
  /// [ExamResultModel.score]/[ExamResultModel.maxScore]. Bài tập nộp
  /// TRƯỚC khi có trường này sẽ mặc định 0/0 (xem [fromMap]); nơi hiển
  /// thị cần tự kiểm tra `maxScore > 0` trước khi dùng, nếu không thì lùi
  /// về hiển thị [correctCount]/[totalQuestions] như cũ.
  final double score;
  final double maxScore;

  AssignmentResult({
    required this.correctCount,
    required this.totalQuestions,
    required this.submittedAt,
    this.score = 0,
    this.maxScore = 0,
  });

  double get accuracy =>
      totalQuestions == 0 ? 0 : correctCount / totalQuestions;

  factory AssignmentResult.fromMap(Map<String, dynamic> map) {
    return AssignmentResult(
      correctCount: map['correctCount'] ?? 0,
      totalQuestions: map['totalQuestions'] ?? 0,
      submittedAt:
          (map['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      score: (map['score'] as num?)?.toDouble() ?? 0,
      maxScore: (map['maxScore'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'correctCount': correctCount,
      'totalQuestions': totalQuestions,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'score': score,
      'maxScore': maxScore,
    };
  }
}

/// Bài tập giáo viên giao cho 1 lớp (collection `assignments`) — gồm 1 bộ
/// câu hỏi cố định (lấy từ Ngân hàng câu hỏi) để cả lớp cùng làm, khác với
/// luồng "Làm bài" thường ngày của học sinh (random theo môn).
class AssignmentModel {
  final String id;
  final String classId;
  final String teacherId;
  final String title;
  final String subject;
  final List<String> questionIds;
  final DateTime createdAt;
  final DateTime? dueDate;
  final String assignmentType;
  final int visibilityDays;
  final Map<String, int> matrix;
  final List<Map<String, dynamic>> sections;
  final Map<String, AssignmentResult> results;

  AssignmentModel({
    required this.id,
    required this.classId,
    required this.teacherId,
    required this.title,
    required this.subject,
    required this.questionIds,
    required this.createdAt,
    this.dueDate,
    this.assignmentType = 'Bài tập',
    this.visibilityDays = 7,
    this.matrix = const {},
    this.sections = const [],
    this.results = const {},
  });

  bool completedBy(String studentId) => results.containsKey(studentId);

  bool get isOverdue => dueDate != null && DateTime.now().isAfter(dueDate!);

  /// Học sinh chỉ thấy bài trong cửa sổ hiển thị; giáo viên vẫn thấy toàn bộ.
  bool get isVisibleToStudent =>
      DateTime.now().isBefore(createdAt.add(Duration(days: visibilityDays)));

  factory AssignmentModel.fromMap(String id, Map<String, dynamic> map) {
    final rawResults = Map<String, dynamic>.from(map['results'] ?? {});
    return AssignmentModel(
      id: id,
      classId: map['classId'] ?? '',
      teacherId: map['teacherId'] ?? '',
      title: map['title'] ?? '',
      subject: map['subject'] ?? '',
      questionIds: List<String>.from(map['questionIds'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (map['dueDate'] as Timestamp?)?.toDate(),
      assignmentType: map['assignmentType'] ?? 'Bài tập',
      visibilityDays: (map['visibilityDays'] as num?)?.toInt() ?? 7,
      matrix: Map<String, int>.from((map['matrix'] as Map?)?.map((key, value) =>
              MapEntry(key.toString(), (value as num).toInt())) ??
          {}),
      sections: (map['sections'] as List?)
              ?.map((section) => Map<String, dynamic>.from(section as Map))
              .toList() ??
          const [],
      results: rawResults.map((studentId, value) => MapEntry(studentId,
          AssignmentResult.fromMap(Map<String, dynamic>.from(value)))),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'classId': classId,
      'teacherId': teacherId,
      'title': title,
      'subject': subject,
      'questionIds': questionIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'assignmentType': assignmentType,
      'visibilityDays': visibilityDays,
      'matrix': matrix,
      'sections': sections,
      'results': results.map((k, v) => MapEntry(k, v.toMap())),
    };
  }
}