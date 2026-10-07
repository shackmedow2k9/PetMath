import 'package:cloud_firestore/cloud_firestore.dart';

/// Kết quả 1 lần làm bài — dùng để tính EXP, cập nhật Dashboard giáo viên,
/// và làm dữ liệu cho AI "phân tích điểm yếu" sau này.
class ExamResultModel {
  final String? id;
  final String studentId;
  final String subject;
  final int totalQuestions;
  final int correctCount;
  final DateTime submittedAt;
  final List<String> wrongQuestionIds; // để AI gợi ý ôn tập

  /// Điểm số theo cơ chế chấm điểm mới (trắc nghiệm 0,25đ/câu, đúng/sai
  /// tính theo số mệnh đề đúng: 0,1/0,25/0,5/1đ, trả lời ngắn 0,5đ/câu) —
  /// TÁCH RIÊNG khỏi [correctCount] (vẫn giữ nguyên, chỉ đếm số câu đúng
  /// HOÀN TOÀN, dùng để tính EXP/Coin/streak như cũ). [score] là điểm học
  /// sinh đạt được (có thể có điểm cộng dồn một phần cho câu đúng/sai chỉ
  /// đúng vài mệnh đề), [maxScore] là điểm tối đa có thể đạt của đề này.
  final double score;
  final double maxScore;

  ExamResultModel({
    this.id,
    required this.studentId,
    required this.subject,
    required this.totalQuestions,
    required this.correctCount,
    required this.submittedAt,
    this.wrongQuestionIds = const [],
    this.score = 0,
    this.maxScore = 0,
  });

  double get accuracy =>
      totalQuestions == 0 ? 0 : correctCount / totalQuestions;

  /// Điểm quy đổi về thang 10 — dùng để hiển thị và chọn thông điệp động
  /// viên phù hợp với mức điểm (xem [ExamResultScreen]).
  double get scoreOnTen => maxScore == 0 ? 0 : (score / maxScore) * 10;

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'subject': subject,
      'totalQuestions': totalQuestions,
      'correctCount': correctCount,
      'submittedAt': Timestamp.fromDate(submittedAt),
      'wrongQuestionIds': wrongQuestionIds,
      'score': score,
      'maxScore': maxScore,
    };
  }
}