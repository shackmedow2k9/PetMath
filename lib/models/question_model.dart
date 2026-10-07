import 'package:cloud_firestore/cloud_firestore.dart';

/// Model câu hỏi trắc nghiệm theo môn học.
///
/// Câu hỏi Toán THPT phải được nhập vào Firestore kèm metadata nguồn. App
/// không còn tạo câu hỏi mẫu trong mã nguồn; [sourceUrl] chỉ trỏ về nguồn
/// tham khảo, còn nội dung câu hỏi cần được sử dụng theo quyền/giấy phép phù hợp.
class QuestionModel {
  final String id;
  final String subject;
  final String content;
  final List<String> options;
  final int correctOptionIndex;
  final String? explanation;
  final int difficulty; // 1 (dễ) - 3 (khó)
  final String? createdBy;
  final DateTime? createdAt;
  final int? grade;
  final String? topic;

  /// Học kỳ 1 hoặc 2 — null nghĩa là "cả năm/chưa xác định". Dùng để lọc
  /// khi giáo viên tạo đề tự động, tránh random nhầm câu hỏi của học kỳ
  /// học sinh chưa học tới.
  final int? semester;
  final String? bookSeries;
  final String? sourceId;
  final String? sourceName;
  final String? sourceUrl;
  final Map<String, dynamic>? visual3d;

  /// multiple_choice, true_false hoặc short_answer.
  final String questionType;

  /// Dùng cho câu đúng/sai: mỗi phần tử tương ứng một mệnh đề.
  final List<bool>? trueFalseAnswers;

  /// Dùng cho câu trả lời ngắn.
  final String? shortAnswer;

  /// URL/path ảnh, bảng, đồ thị hoặc tài liệu minh họa.
  final List<String> mediaUrls;

  /// Câu hỏi công khai (true) sẽ xuất hiện trong "Kho công khai" của Ngân
  /// hàng câu hỏi để MỌI giáo viên khác cũng thấy và dùng được — không chỉ
  /// riêng người tạo ra nó. Mặc định là false (chỉ chủ sở hữu dùng được
  /// trong Ngân hàng câu hỏi của chính họ).
  final bool isPublic;

  QuestionModel({
    required this.id,
    required this.subject,
    required this.content,
    required this.options,
    required this.correctOptionIndex,
    this.explanation,
    this.difficulty = 1,
    this.createdBy,
    this.createdAt,
    this.grade,
    this.topic,
    this.semester,
    this.bookSeries,
    this.sourceId,
    this.sourceName,
    this.sourceUrl,
    this.visual3d,
    this.questionType = 'multiple_choice',
    this.trueFalseAnswers,
    this.shortAnswer,
    this.mediaUrls = const [],
    this.isPublic = false,
  });

  factory QuestionModel.fromMap(String id, Map<String, dynamic> map) {
    return QuestionModel(
      id: id,
      subject: map['subject'] ?? '',
      content: map['content'] ?? '',
      options: List<String>.from(map['options'] ?? []),
      correctOptionIndex: map['correctOptionIndex'] ?? 0,
      explanation: map['explanation'],
      difficulty: map['difficulty'] ?? 1,
      createdBy: map['createdBy'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      grade: (map['grade'] as num?)?.toInt(),
      topic: map['topic'],
      semester: (map['semester'] as num?)?.toInt(),
      bookSeries: map['bookSeries'],
      sourceId: map['sourceId'],
      sourceName: map['sourceName'],
      sourceUrl: map['sourceUrl'],
      visual3d: map['visual3d'] == null
          ? null
          : Map<String, dynamic>.from(map['visual3d'] as Map),
      questionType:
          (map['questionType'] ?? map['type'] ?? 'multiple_choice').toString(),
      trueFalseAnswers: (map['trueFalseAnswers'] as List?)
          ?.map((value) => value == true)
          .toList(),
      shortAnswer: map['shortAnswer']?.toString(),
      mediaUrls: List<String>.from(map['mediaUrls'] ?? const []),
      isPublic: map['isPublic'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'subject': subject,
      'content': content,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'explanation': explanation,
      'difficulty': difficulty,
      'createdBy': createdBy,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'grade': grade,
      'topic': topic,
      'semester': semester,
      'bookSeries': bookSeries,
      'sourceId': sourceId,
      'sourceName': sourceName,
      'sourceUrl': sourceUrl,
      'visual3d': visual3d,
      'questionType': questionType,
      'trueFalseAnswers': trueFalseAnswers,
      'shortAnswer': shortAnswer,
      'mediaUrls': mediaUrls,
      'isPublic': isPublic,
    };
  }

  bool get isMultipleChoice => questionType == 'multiple_choice';
  bool get isTrueFalse => questionType == 'true_false';
  bool get isShortAnswer => questionType == 'short_answer';

  QuestionModel copyWith({
    String? id,
    String? subject,
    String? content,
    List<String>? options,
    int? correctOptionIndex,
    String? explanation,
    int? difficulty,
    String? createdBy,
    DateTime? createdAt,
    int? grade,
    String? topic,
    int? semester,
    String? bookSeries,
    String? sourceId,
    String? sourceName,
    String? sourceUrl,
    Map<String, dynamic>? visual3d,
    String? questionType,
    List<bool>? trueFalseAnswers,
    String? shortAnswer,
    List<String>? mediaUrls,
    bool? isPublic,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      content: content ?? this.content,
      options: options ?? this.options,
      correctOptionIndex: correctOptionIndex ?? this.correctOptionIndex,
      explanation: explanation ?? this.explanation,
      difficulty: difficulty ?? this.difficulty,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      grade: grade ?? this.grade,
      topic: topic ?? this.topic,
      semester: semester ?? this.semester,
      bookSeries: bookSeries ?? this.bookSeries,
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      visual3d: visual3d ?? this.visual3d,
      questionType: questionType ?? this.questionType,
      trueFalseAnswers: trueFalseAnswers ?? this.trueFalseAnswers,
      shortAnswer: shortAnswer ?? this.shortAnswer,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      isPublic: isPublic ?? this.isPublic,
    );
  }
}
