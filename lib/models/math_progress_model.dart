import 'package:cloud_firestore/cloud_firestore.dart';

/// Tiến độ học Toán THPT của một học sinh trong một khối.
///
/// Mỗi document được lưu ở `mathProgress/{studentId}_{grade}`. Các chuyên đề
/// đã học được lưu trong map `topics`; chuyên đề chưa từng học không xuất hiện
/// trong map và luôn có tiến độ 0.
class MathProgressModel {
  final String studentId;
  final int grade;
  final int completedSessions;
  final int totalQuestions;
  final int totalCorrect;
  final String? lastTopic;
  final DateTime? lastStudiedAt;
  final Map<String, MathTopicProgress> topics;

  const MathProgressModel({
    required this.studentId,
    required this.grade,
    this.completedSessions = 0,
    this.totalQuestions = 0,
    this.totalCorrect = 0,
    this.lastTopic,
    this.lastStudiedAt,
    this.topics = const {},
  });

  factory MathProgressModel.empty(String studentId, int grade) {
    return MathProgressModel(studentId: studentId, grade: grade);
  }

  factory MathProgressModel.fromMap(
      String studentId, int grade, Map<String, dynamic> map) {
    final rawTopics = Map<String, dynamic>.from(map['topics'] ?? {});
    final topics = <String, MathTopicProgress>{};
    for (final entry in rawTopics.entries) {
      final data = Map<String, dynamic>.from(entry.value as Map);
      topics[entry.key] = MathTopicProgress.fromMap(data);
    }

    return MathProgressModel(
      studentId: studentId,
      grade: grade,
      completedSessions: (map['completedSessions'] as num?)?.toInt() ?? 0,
      totalQuestions: (map['totalQuestions'] as num?)?.toInt() ?? 0,
      totalCorrect: (map['totalCorrect'] as num?)?.toInt() ?? 0,
      lastTopic: map['lastTopic'],
      lastStudiedAt: (map['lastStudiedAt'] as Timestamp?)?.toDate(),
      topics: topics,
    );
  }

  double get accuracy =>
      totalQuestions == 0 ? 0 : totalCorrect / totalQuestions;

  /// Số chuyên đề đã có ít nhất một phiên hoàn thành.
  int get completedTopics =>
      topics.values.where((topic) => topic.sessions > 0).length;

  /// Tiến độ tổng quan theo số chuyên đề trong lộ trình hiện tại.
  double progressForTopicCount(int topicCount) {
    if (topicCount <= 0) return 0;
    return (completedTopics / topicCount).clamp(0.0, 1.0).toDouble();
  }
}

class MathTopicProgress {
  final int sessions;
  final int totalQuestions;
  final int totalCorrect;
  final double bestAccuracy;
  final DateTime? lastStudiedAt;

  const MathTopicProgress({
    this.sessions = 0,
    this.totalQuestions = 0,
    this.totalCorrect = 0,
    this.bestAccuracy = 0,
    this.lastStudiedAt,
  });

  factory MathTopicProgress.fromMap(Map<String, dynamic> map) {
    return MathTopicProgress(
      sessions: (map['sessions'] as num?)?.toInt() ?? 0,
      totalQuestions: (map['totalQuestions'] as num?)?.toInt() ?? 0,
      totalCorrect: (map['totalCorrect'] as num?)?.toInt() ?? 0,
      bestAccuracy: (map['bestAccuracy'] as num?)?.toDouble() ?? 0,
      lastStudiedAt: (map['lastStudiedAt'] as Timestamp?)?.toDate(),
    );
  }

  double get accuracy =>
      totalQuestions == 0 ? 0 : totalCorrect / totalQuestions;
}
