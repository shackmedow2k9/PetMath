import 'package:flutter/material.dart';

/// Toạ độ các mốc trên ảnh nền `assets/images/farm/garden_bg.jpg`
/// (kích thước gốc 1537x1023) — tất cả lưu dưới dạng TỈ LỆ (0.0-1.0) theo
/// chiều rộng/cao ảnh, để khi ảnh co giãn theo màn hình thì các điểm vẫn
/// khớp đúng vị trí (dùng cùng với Positioned trong 1 Stack có kích thước
/// = kích thước ảnh đã co giãn).
///
/// Được xác định bằng cách dò màu pixel (đất nâu / viền đá xám) trên ảnh
/// gốc học sinh cung cấp — nếu học sinh đổi ảnh nền khác, các toạ độ này
/// cần dò lại cho khớp.
class FarmLayout {
  /// Tỉ lệ khung ảnh gốc (width / height) — dùng để khoá AspectRatio khi
  /// hiển thị, tránh bị méo hình.
  static const double imageAspectRatio = 1537 / 1023;

  /// Vị trí tâm 19 ô đất trồng cây, dò chính xác từ ảnh nền gốc bằng phân
  /// tích màu (khối đất nâu), sắp theo thứ tự từ TRÊN xuống DƯỚI, TRÁI qua
  /// PHẢI — dùng chung thứ tự này để mở khoá ô đất dần dần. Đơn vị: tỉ lệ
  /// (dx, dy) theo kích thước ảnh gốc.
  static const List<Offset> plotCenters = [
    Offset(0.8373, 0.3539), // 0
    Offset(0.7619, 0.4242), // 1
    Offset(0.6845, 0.4946), // 2
    Offset(0.6070, 0.5660), // 3
    Offset(0.7625, 0.5621), // 4
    Offset(0.5309, 0.6364), // 5
    Offset(0.6864, 0.6334), // 6
    Offset(0.8399, 0.6325), // 7
    Offset(0.6096, 0.7058), // 8
    Offset(0.7645, 0.7038), // 9
    Offset(0.9187, 0.7028), // 10
    Offset(0.5329, 0.7781), // 11
    Offset(0.6877, 0.7771), // 12
    Offset(0.8412, 0.7752), // 13
    Offset(0.6103, 0.8485), // 14
    Offset(0.7651, 0.8465), // 15
    Offset(0.9206, 0.8456), // 16
    Offset(0.6884, 0.9169), // 17
    Offset(0.8426, 0.9169), // 18
  ];

  /// Kích thước ô đất (đo trực tiếp từ ảnh gốc bằng dò màu, ~178x112px
  /// trên ảnh 1537x1023) — dùng để vẽ ô vuông trồng cây vừa khít viên
  /// gạch đất trên ảnh nền. Chiều rộng/cao tách riêng vì ảnh không vuông.
  static const double plotWidth = 0.098;
  static const double plotHeight = 0.092;

  /// Tâm khu đất vuông lớn (viền đá xám) để đặt NHÀ hiện tại của học
  /// sinh — dò trực tiếp 4 đỉnh viền đá trên ảnh nền gốc (1537x1023):
  /// trên (807,57) trái (604,172) phải (1010,172) dưới (807,287). Tâm neo
  /// đặt CAO hơn tâm hình học của viền đá khá nhiều (0.131 thay vì ~0.168)
  /// vì ảnh nhà là một khối cao (tháp vươn lên) chứ không dàn phẳng như
  /// viền đá — đẩy lên hết mức để chân nhà không tràn qua mũi nhọn phía
  /// trước, tận dụng luôn khoảng trống ~34px giữa cụm chỉ số (xu/kim
  /// cương/lá) và mép trên khu vườn để đỉnh tháp có thể lấn nhẹ vào đó
  /// (vẫn còn cách cụm chỉ số một đoạn, không đè lên).
  static const Offset housePosition = Offset(0.525, 0.131);

  /// Kích thước khu đặt nhà (tỉ lệ theo chiều rộng/cao ảnh). Ảnh nhà có
  /// viền trong suốt quanh nội dung + là ảnh vuông 1:1 nên bị BoxFit.contain
  /// co theo cạnh nhỏ hơn (chiều cao) — houseHeight lấy gần mức tối đa mà
  /// khoảng trống phía trên (xem housePosition) + mũi nhọn phía trước cho
  /// phép, để nhà to nhất có thể mà vẫn không tràn ra 2 đầu. houseWidth
  /// chỉ cần đủ lớn để không phải là cạnh giới hạn (chiều cao mới là cạnh
  /// quyết định kích thước cuối cùng, vì ảnh vuông 1:1 hẹp hơn viền đá).
  static const double houseWidth = 0.29;
  static const double houseHeight = 0.36;

  /// Vùng bãi cỏ khoảng trống bên trái (không có viền) — nơi có thể đặt đồ
  /// trang trí mua ở mục "Nội thất". Trả toạ độ TÂM vùng, dùng làm điểm
  /// neo mặc định khi đặt món đồ trang trí đầu tiên.
  static const Offset decorAreaCenter = Offset(0.24, 0.30);

  /// Vùng bãi cỏ trống phía dưới bên trái (khoảng sân rộng) — vùng thứ 2
  /// để đặt đồ trang trí.
  static const Offset decorAreaCenter2 = Offset(0.20, 0.62);

  /// Các điểm mốc pet có thể "đi dạo" tới (toạ độ tỉ lệ) — chọn rải rác
  /// trên bãi cỏ trống, tránh đè lên ô đất trồng cây hoặc khu đặt nhà, để
  /// pet lượn qua lượn lại trông tự nhiên.
  static const List<Offset> petWanderSpots = [
    Offset(0.24, 0.34),
    Offset(0.16, 0.46),
    Offset(0.30, 0.52),
    Offset(0.20, 0.62),
    Offset(0.34, 0.66),
    Offset(0.42, 0.42),
    Offset(0.55, 0.30),
  ];
}
