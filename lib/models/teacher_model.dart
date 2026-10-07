import 'package:cloud_firestore/cloud_firestore.dart';

/// Model giáo viên — thông tin đăng ký, dùng ở Cổng giáo viên (quản lý
/// lớp học, ngân hàng câu hỏi, giao bài...).
class TeacherModel {
  final String uid;
  final String fullName;
  final String email;
  final DateTime createdAt;

  final int? provinceCode;
  final String? provinceName;
  final int? wardCode;
  final String? wardName;
  final String? schoolName;

  TeacherModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.createdAt,
    this.provinceCode,
    this.provinceName,
    this.wardCode,
    this.wardName,
    this.schoolName,
  });

  factory TeacherModel.fromMap(String uid, Map<String, dynamic> map) {
    return TeacherModel(
      uid: uid,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      provinceCode: map['provinceCode'],
      provinceName: map['provinceName'],
      wardCode: map['wardCode'],
      wardName: map['wardName'],
      schoolName: map['schoolName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
      'role': 'teacher',
      'provinceCode': provinceCode,
      'provinceName': provinceName,
      'wardCode': wardCode,
      'wardName': wardName,
      'schoolName': schoolName,
    };
  }
}
