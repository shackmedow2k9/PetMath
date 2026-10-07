import 'package:flutter/material.dart' hide Text;
import '../widgets/tr_text.dart';

/// Quản lý Khối lớp (1-12) cho PetMath.
///
/// PetMath hiện chỉ còn duy nhất môn Toán (đã bỏ hẳn các môn khác khỏi mọi
/// giao diện), nên file này chỉ còn giữ phần liên quan Khối lớp — dùng để
/// lọc ngân hàng câu hỏi/bài tập theo đúng khối khi Giáo viên tạo câu hỏi,
/// nhập đề Word, tạo đề, giao bài...
class Curriculum {
  static const List<int> allGrades = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

  static String gradeLabel(int grade) => 'Lớp $grade';

  // ---------- KHỐI LỚP ĐANG MỞ (chọn được) ----------
  //
  // PetMath hiện chỉ phục vụ Toán THPT, nên trong mọi màn hình có chọn
  // "Khối lớp" (tạo câu hỏi, nhập đề Word, tạo đề, giao bài, tạo lớp,
  // đăng ký tài khoản...), các khối chưa hỗ trợ (1-9) vẫn hiển thị để
  // người dùng biết là sẽ có trong tương lai, nhưng bị khóa (chữ xám,
  // không bấm chọn được) và bị đẩy xuống cuối danh sách.

  /// Khối lớp chọn được (PetMath hiện chỉ phục vụ bậc THPT).
  static const List<int> enabledGrades = [10, 11, 12];

  static bool isGradeEnabled(int? grade) =>
      grade != null && enabledGrades.contains(grade);

  /// Đưa các khối CHỌN ĐƯỢC lên đầu danh sách.
  static List<int> sortGradesByEnabled(List<int> grades) => [
        ...grades.where(isGradeEnabled),
        ...grades.where((g) => !isGradeEnabled(g)),
      ];

  static TextStyle? _itemStyle(bool enabled) =>
      enabled ? null : const TextStyle(color: Colors.grey);

  /// Danh sách [DropdownMenuItem] cho "Khối lớp" (bắt buộc chọn, kiểu
  /// `int` không null) — khối chọn được lên đầu, còn lại bị khóa.
  static List<DropdownMenuItem<int>> gradeDropdownItems([
    List<int>? grades,
  ]) =>
      [
        for (final g in sortGradesByEnabled(grades ?? allGrades))
          DropdownMenuItem<int>(
            value: g,
            enabled: isGradeEnabled(g),
            child: Text(gradeLabel(g), style: _itemStyle(isGradeEnabled(g))),
          ),
      ];

  /// Giống [gradeDropdownItems] nhưng cho kiểu `int?` (khối không bắt
  /// buộc), có thêm lựa chọn [unassignedLabel] ứng với value null ở đầu.
  static List<DropdownMenuItem<int?>> gradeDropdownItemsNullable({
    List<int>? grades,
    String unassignedLabel = 'Chưa gán khối',
  }) =>
      [
        DropdownMenuItem<int?>(value: null, child: Text(unassignedLabel)),
        for (final g in sortGradesByEnabled(grades ?? allGrades))
          DropdownMenuItem<int?>(
            value: g,
            enabled: isGradeEnabled(g),
            child: Text(gradeLabel(g), style: _itemStyle(isGradeEnabled(g))),
          ),
      ];
}
