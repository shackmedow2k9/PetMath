/// 3 phòng cố định trong mỗi căn nhà — mỗi phòng có 1 chức năng chăm sóc
/// pet đặc trưng riêng, giống các phòng trong nhà của Talking Tom.
enum RoomType { bedroom, bathroom, dining }

class RoomInfo {
  final RoomType type;
  final String label;
  final String emoji;
  final String actionLabel;
  final String actionEmoji;

  const RoomInfo({
    required this.type,
    required this.label,
    required this.emoji,
    required this.actionLabel,
    required this.actionEmoji,
  });
}

/// Thứ tự trong danh sách này = thứ tự tab phòng hiển thị trong nhà.
/// Phòng đầu tiên (Phòng ngủ) là phòng mở ra ngay khi bước vào nhà.
const List<RoomInfo> kRooms = [
  RoomInfo(
    type: RoomType.bedroom,
    label: 'Phòng ngủ',
    emoji: '🛏️',
    actionLabel: 'Ngủ nghỉ',
    actionEmoji: '💤',
  ),
  RoomInfo(
    type: RoomType.bathroom,
    label: 'Nhà tắm',
    emoji: '🛁',
    actionLabel: 'Tắm rửa',
    actionEmoji: '🧼',
  ),
  RoomInfo(
    type: RoomType.dining,
    label: 'Phòng ăn',
    emoji: '🍽️',
    actionLabel: 'Cho ăn',
    actionEmoji: '🍗',
  ),
];

/// Tên file ảnh nền theo từng phòng (khớp thư mục assets/images/houses/rooms/<houseId>/).
String _roomFileName(RoomType type) => switch (type) {
      RoomType.bedroom => 'bedroom',
      RoomType.bathroom => 'bathroom',
      RoomType.dining => 'dining',
    };

/// Đường dẫn ảnh nền của 1 phòng, riêng theo từng loại nhà [houseId]
/// (id trong [HouseCatalog], ví dụ 'wood', 'tree', 'castle'...).
String roomBackgroundAsset(String houseId, RoomType type) =>
    'assets/images/houses/rooms/$houseId/${_roomFileName(type)}.png';
