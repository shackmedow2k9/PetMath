import 'room_data.dart';

/// Món nội thất để trang trí nhà pet — mua bằng Coin ngay trong chế độ
/// "Trang trí". Mỗi món chỉ mua 1 lần, đặt được ở 1 phòng (kéo để đổi chỗ,
/// bấm ✕ để cất lại vào kho).
class DecorTemplate {
  final String id;
  final String name;
  final String emoji;
  final int priceCoin;

  /// Kích thước vẽ (px) của món đồ trong phòng.
  final double size;

  /// null = đặt được ở mọi phòng; khác null = chỉ hợp với 1 phòng.
  final RoomType? room;

  const DecorTemplate({
    required this.id,
    required this.name,
    required this.emoji,
    required this.priceCoin,
    this.size = 54,
    this.room,
  });

  bool fitsRoom(RoomType type) => room == null || room == type;
}

class DecorCatalog {
  DecorCatalog._();

  /// Số món tối đa trong 1 phòng để phòng không bị rối.
  static const int maxPerRoom = 6;

  static const List<DecorTemplate> all = [
    // Dùng chung mọi phòng
    DecorTemplate(id: 'plant', name: 'Chậu cây', emoji: '🪴', priceCoin: 30),
    DecorTemplate(id: 'flowers', name: 'Bình hoa', emoji: '💐', priceCoin: 45),
    DecorTemplate(id: 'teddy', name: 'Gấu bông', emoji: '🧸', priceCoin: 40),
    DecorTemplate(
        id: 'lamp', name: 'Nến thơm', emoji: '🕯️', priceCoin: 50, size: 46),
    DecorTemplate(
        id: 'painting', name: 'Tranh treo', emoji: '🖼️', priceCoin: 60, size: 62),
    DecorTemplate(id: 'books', name: 'Chồng sách', emoji: '📚', priceCoin: 70),
    DecorTemplate(
        id: 'clock', name: 'Đồng hồ', emoji: '🕰️', priceCoin: 80, size: 60),
    DecorTemplate(
        id: 'globe', name: 'Quả địa cầu', emoji: '🌍', priceCoin: 90, size: 58),
    DecorTemplate(
        id: 'sofa', name: 'Ghế sofa', emoji: '🛋️', priceCoin: 120, size: 86),
    // Phòng ngủ
    DecorTemplate(
        id: 'moon_light',
        name: 'Đèn ngủ',
        emoji: '🌙',
        priceCoin: 60,
        room: RoomType.bedroom),
    DecorTemplate(
        id: 'mirror',
        name: 'Gương soi',
        emoji: '🪞',
        priceCoin: 100,
        size: 66,
        room: RoomType.bedroom),
    // Nhà tắm
    DecorTemplate(
        id: 'duck',
        name: 'Vịt cao su',
        emoji: '🦆',
        priceCoin: 40,
        size: 48,
        room: RoomType.bathroom),
    DecorTemplate(
        id: 'soap',
        name: 'Xà phòng thơm',
        emoji: '🧴',
        priceCoin: 35,
        size: 46,
        room: RoomType.bathroom),
    DecorTemplate(
        id: 'toothbrush',
        name: 'Bàn chải',
        emoji: '🪥',
        priceCoin: 25,
        size: 44,
        room: RoomType.bathroom),
    // Phòng ăn
    DecorTemplate(
        id: 'fruit',
        name: 'Rổ trái cây',
        emoji: '🍎',
        priceCoin: 30,
        room: RoomType.dining),
    DecorTemplate(
        id: 'cake',
        name: 'Bánh kem',
        emoji: '🍰',
        priceCoin: 50,
        room: RoomType.dining),
    DecorTemplate(
        id: 'tea',
        name: 'Ấm trà',
        emoji: '🫖',
        priceCoin: 55,
        size: 50,
        room: RoomType.dining),
  ];

  static DecorTemplate? byId(String id) {
    for (final d in all) {
      if (d.id == id) return d;
    }
    return null;
  }
}

/// 1 món nội thất đã đặt trong 1 phòng; [x], [y] là tỉ lệ 0..1 trong sân khấu
/// của phòng (cùng hệ toạ độ với vị trí pet).
class PlacedDecor {
  final String id;
  final double x;
  final double y;

  const PlacedDecor({required this.id, required this.x, required this.y});

  PlacedDecor moved(double nx, double ny) =>
      PlacedDecor(id: id, x: nx, y: ny);

  Map<String, dynamic> toMap() => {'id': id, 'x': x, 'y': y};

  static PlacedDecor? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final x = raw['x'];
    final y = raw['y'];
    if (id is! String || x is! num || y is! num) return null;
    if (DecorCatalog.byId(id) == null) return null;
    return PlacedDecor(
      id: id,
      x: x.toDouble().clamp(0.05, 0.95).toDouble(),
      y: y.toDouble().clamp(0.1, 0.95).toDouble(),
    );
  }
}
