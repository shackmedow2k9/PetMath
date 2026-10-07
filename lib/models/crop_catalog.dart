import 'package:flutter/material.dart';

/// Hoa — thu hoạch xong thì BÁN lấy Coin (đôi khi có thêm Gem), chỉ để
/// trang trí/kiếm tiền. Trái cây — thu hoạch xong dùng để CHO PET ĂN ngay
/// trong Nông trại (hồi No bụng + EXP), không bán được.
enum PlantType { flower, fruit }

/// 1 loại cây có thể trồng ở Nông trại — mua hạt bằng Coin ở mục "Hạt
/// giống" trong Cửa hàng Nông trại, cây lớn dần theo thời gian THỰC, cần
/// tưới nước đều đặn (không thì héo dần rồi chết) — xem thêm
/// [FarmPlotState] để biết chi tiết cơ chế sức khoẻ của cây.
class CropTemplate {
  final String id;
  final String name;
  final PlantType type;
  final String emoji; // hình cây khi đã lớn hoàn toàn, sẵn sàng thu hoạch
  final int growSeconds; // tổng thời gian lớn (khi cây luôn khoẻ mạnh)
  final int priceCoin; // giá 1 hạt giống

  // ---- Hoa: bán thu hoạch lấy Coin/Gem ----
  final int coinRewardMin;
  final int coinRewardMax;
  final double gemChance; // 0.0 - 1.0
  final int gemRewardMax;

  // ---- Trái cây: cho pet ăn, hồi No bụng + EXP giống 1 phần đồ ăn ----
  final int hungerRestore;
  final int expReward;

  final Color color;

  const CropTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.emoji,
    required this.growSeconds,
    required this.priceCoin,
    this.coinRewardMin = 0,
    this.coinRewardMax = 0,
    this.gemChance = 0,
    this.gemRewardMax = 0,
    this.hungerRestore = 0,
    this.expReward = 0,
    required this.color,
  });

  bool get isFruit => type == PlantType.fruit;

  /// Nhãn thời gian lớn hiển thị cho học sinh, vd "12 giờ", "1 ngày 6 giờ".
  String get growDurationLabel {
    final d = Duration(seconds: growSeconds);
    if (d.inDays > 0) {
      final hrs = d.inHours % 24;
      return hrs == 0 ? '${d.inDays} ngày' : '${d.inDays} ngày ${hrs} giờ';
    }
    if (d.inHours > 0) return '${d.inHours} giờ';
    return '${d.inMinutes} phút';
  }
}

/// Danh mục hạt giống bán ở mục "Hạt giống" trong Cửa hàng Nông trại.
class CropCatalog {
  static const List<CropTemplate> all = [
    // ---------- HOA (bán lấy Coin/Gem) ----------
    CropTemplate(
      id: 'hoa_cuc',
      name: 'Hoa cúc',
      type: PlantType.flower,
      emoji: '🌼',
      growSeconds: 18 * 3600,
      priceCoin: 30,
      coinRewardMin: 60,
      coinRewardMax: 90,
      color: Color(0xFFFFD93D),
    ),
    CropTemplate(
      id: 'hoa_tulip',
      name: 'Hoa tulip',
      type: PlantType.flower,
      emoji: '🌷',
      growSeconds: 24 * 3600,
      priceCoin: 50,
      coinRewardMin: 110,
      coinRewardMax: 150,
      gemChance: 0.10,
      gemRewardMax: 1,
      color: Color(0xFFFF6B9D),
    ),
    CropTemplate(
      id: 'hoa_hong',
      name: 'Hoa hồng',
      type: PlantType.flower,
      emoji: '🌹',
      growSeconds: 30 * 3600,
      priceCoin: 80,
      coinRewardMin: 170,
      coinRewardMax: 220,
      gemChance: 0.20,
      gemRewardMax: 2,
      color: Color(0xFFEE5A52),
    ),
    CropTemplate(
      id: 'hoa_huong_duong',
      name: 'Hoa hướng dương',
      type: PlantType.flower,
      emoji: '🌻',
      growSeconds: 36 * 3600,
      priceCoin: 120,
      coinRewardMin: 260,
      coinRewardMax: 330,
      gemChance: 0.30,
      gemRewardMax: 3,
      color: Color(0xFFFFC048),
    ),

    // ---------- TRÁI CÂY (cho pet ăn) ----------
    CropTemplate(
      id: 'dau_tay',
      name: 'Dâu tây',
      type: PlantType.fruit,
      emoji: '🍓',
      growSeconds: 12 * 3600,
      priceCoin: 25,
      hungerRestore: 18,
      expReward: 8,
      color: Color(0xFFFF6B9D),
    ),
    CropTemplate(
      id: 'ca_chua',
      name: 'Cà chua',
      type: PlantType.fruit,
      emoji: '🍅',
      growSeconds: 18 * 3600,
      priceCoin: 35,
      hungerRestore: 22,
      expReward: 10,
      color: Color(0xFFEE5A52),
    ),
    CropTemplate(
      id: 'tao',
      name: 'Táo',
      type: PlantType.fruit,
      emoji: '🍎',
      growSeconds: 24 * 3600,
      priceCoin: 55,
      hungerRestore: 28,
      expReward: 13,
      color: Color(0xFFE84C3D),
    ),
    CropTemplate(
      id: 'dua_hau',
      name: 'Dưa hấu',
      type: PlantType.fruit,
      emoji: '🍉',
      growSeconds: 36 * 3600,
      priceCoin: 90,
      hungerRestore: 38,
      expReward: 18,
      color: Color(0xFF2ECC71),
    ),
  ];

  static CropTemplate byId(String id) => all.firstWhere(
        (c) => c.id == id,
        orElse: () => all.first,
      );

  static List<CropTemplate> get flowers =>
      all.where((c) => c.type == PlantType.flower).toList();

  static List<CropTemplate> get fruits =>
      all.where((c) => c.type == PlantType.fruit).toList();
}

/// Tổng số ô đất trồng cây trên khu vườn (khớp đúng số ô đất "đế" hiển thị
/// trên hình nền Nông trại — xem [kFarmPlotPositions] trong
/// farm_layout.dart).
const int kFarmMaxPlots = 19;

/// Số ô đất được mở sẵn miễn phí ngay từ đầu.
const int kFarmFreePlots = 6;

/// Giá Coin để mở khoá TỪNG ô đất tiếp theo, theo đúng thứ tự.
const List<int> kFarmUnlockCosts = [
  120, 160, 220, 280, 340, 400,
  480, 560, 650, 750, 900, 1100,
  1300,
];

// ---------- SỨC KHOẺ CÂY TRỒNG ----------

/// Nếu quá số giờ này KHÔNG tưới nước, cây sẽ CHẾT (phải dọn bỏ, không thu
/// hoạch được nữa).
const int kWaterDeathHours = 12;

/// Nếu quá số giờ này không tưới, cây bắt đầu HÉO (ngừng lớn, đổi màu cảnh
/// báo) cho tới khi được tưới lại — có khoảng thời gian đệm trước khi chết
/// hẳn ở [kWaterDeathHours] để học sinh kịp quay lại chăm sóc.
const int kWaterWiltHours = 8;

/// Bón phân đầy Dinh dưỡng, giảm dần hết trong khoảng thời gian này.
const int kFertilizerFullHours = 24;

/// Dinh dưỡng trên mức % này thì cây lớn nhanh hơn (xem [kNutritionBonusMultiplier]).
const int kNutritionBonusThreshold = 50;

/// Hệ số lớn nhanh hơn khi Dinh dưỡng còn cao.
const double kNutritionBonusMultiplier = 1.15;

/// Giá Coin cho 1 lần bón phân.
const int kFertilizeCostCoin = 8;
