import 'package:cloud_firestore/cloud_firestore.dart';

/// Danh sách trường học KHÔNG có API công khai đầy đủ cho toàn bộ Việt Nam
/// (khác với Tỉnh/Xã ở [LocationService]), nên danh sách này được xây dựng
/// dần từ chính người dùng: ai đăng ký trước và gõ tên trường mình thì
/// trường đó sẽ tự xuất hiện làm gợi ý cho người đăng ký sau cùng xã/phường.
class SchoolService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Gợi ý các trường đã từng được nhập trong cùng 1 xã/phường (theo mã xã).
  static Future<List<String>> getSchoolSuggestions(int wardCode) async {
    final snap = await _db
        .collection('schools')
        .where('wardCode', isEqualTo: wardCode)
        .orderBy('name')
        .get();
    return snap.docs.map((d) => d['name'] as String).toList();
  }

  /// Lưu lại 1 trường mới (nếu chưa có) để những học sinh/giáo viên sau
  /// cùng xã/phường có thể thấy ngay trong gợi ý, không cần gõ lại từ đầu.
  static Future<void> ensureSchoolExists({
    required String name,
    required int provinceCode,
    required String provinceName,
    required int wardCode,
    required String wardName,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    // ID ổn định theo xã + tên trường để tránh trùng lặp. Dùng hash của
    // tên đã chuẩn hoá (giữ nguyên dấu tiếng Việt) thay vì loại bỏ dấu,
    // vì loại dấu dễ khiến 2 trường khác tên bị trùng ID.
    final normalized = trimmed.toLowerCase();
    final docId = '${wardCode}_${normalized.hashCode}';
    await _db.collection('schools').doc(docId).set({
      'name': trimmed,
      'provinceCode': provinceCode,
      'provinceName': provinceName,
      'wardCode': wardCode,
      'wardName': wardName,
    }, SetOptions(merge: true));
  }
}
