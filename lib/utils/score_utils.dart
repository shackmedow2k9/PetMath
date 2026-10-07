/// Tiện ích định dạng điểm số kiểu Việt Nam — dùng chung cho màn hình kết
/// quả bài làm ([ExamResultScreen]) và danh sách bài được giao
/// ([StudentAssignmentsScreen]) để hiển thị nhất quán ở mọi nơi cần show
/// điểm số dạng số thực (ví dụ 8, 8,5, 8,25) thay vì luôn cứng 2 chữ số
/// thập phân, và dùng dấu phẩy thay dấu chấm theo quy ước Việt Nam.
String formatVnScore(double value) {
  // Làm tròn 2 chữ số thập phân trước để tránh sai số dấu phẩy động (vd
  // 0.1 + 0.25 có thể ra 0.34999999999999998 thay vì 0.35).
  final rounded = double.parse(value.toStringAsFixed(2));
  var text = rounded.toStringAsFixed(2);
  // Bỏ số 0 thừa ở cuối: "8.00" -> "8", "8.50" -> "8.5", "8.25" giữ nguyên.
  text = text.replaceFirst(RegExp(r'0+$'), '');
  text = text.replaceFirst(RegExp(r'\.$'), '');
  return text.replaceAll('.', ',');
}