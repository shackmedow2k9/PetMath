import 'package:cloud_firestore/cloud_firestore.dart';

/// Model lớp học do Giáo viên tạo (collection `classes`). Học sinh tham
/// gia lớp bằng [joinCode] (mã 6 ký tự, giáo viên đọc cho học sinh nhập ở
/// màn hình Hồ sơ) — khi tham gia thành công, `StudentModel.classId` sẽ
/// được gán bằng [id] của document lớp này (KHÔNG phải joinCode).
class ClassModel {
  final String id;
  final String name;
  final String teacherId;
  final String joinCode;
  final DateTime createdAt;
  // Khối lớp (1-12) — dùng để lọc môn học/ngân hàng câu hỏi phù hợp trình
  // độ khi giáo viên Giao bài cho lớp này. Null = lớp được tạo TRƯỚC khi
  // có tính năng khối lớp (lớp cũ) — giáo viên có thể bổ sung sau trong
  // Dashboard của lớp.
  final int? grade;

  ClassModel({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.joinCode,
    required this.createdAt,
    this.grade,
  });

  factory ClassModel.fromMap(String id, Map<String, dynamic> map) {
    return ClassModel(
      id: id,
      name: map['name'] ?? '',
      teacherId: map['teacherId'] ?? '',
      joinCode: map['joinCode'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      grade: map['grade'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'teacherId': teacherId,
      'joinCode': joinCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'grade': grade,
    };
  }
}
