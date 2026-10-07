import 'dart:math' as math;

import '../config/game_balance.dart';

/// Ảnh chụp trạng thái Thân thiết tại một thời điểm — TẤT CẢ suy ra từ điểm
/// tích luỹ [points], nên không có cờ riêng nào có thể lệch với điểm
/// (reload app, đổi thiết bị đều ra kết quả y hệt).
class FriendshipInfo {
  /// Điểm Thân thiết tích luỹ (đã chặn không âm).
  final int points;

  /// Mức Thân thiết 0..10 (0 = khởi đầu, 1..10 = I..X).
  final int level;

  const FriendshipInfo._(this.points, this.level);

  factory FriendshipInfo.fromPoints(int rawPoints) {
    final p = rawPoints < 0 ? 0 : rawPoints; // dữ liệu lỗi → coi như 0
    return FriendshipInfo._(p, levelForPoints(p));
  }

  static const int maxLevel = 10;

  /// Mức cao nhất mà [points] đạt được theo bảng ngưỡng.
  static int levelForPoints(int points) {
    final t = GameBalance.friendshipThresholds;
    var lv = 0;
    for (var i = 1; i < t.length; i++) {
      if (points >= t[i]) lv = i;
    }
    return lv;
  }

  /// Số La Mã hiển thị: 0 → "0", 1 → "I", ... 10 → "X".
  static String roman(int level) {
    const names = ['0', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];
    if (level < 0) return names.first;
    if (level >= names.length) return names.last;
    return names[level];
  }

  String get romanLevel => roman(level);
  bool get isMax => level >= maxLevel;

  /// Điểm cần để lên mức kế tiếp (null nếu đã tối đa).
  int? get nextThreshold =>
      isMax ? null : GameBalance.friendshipThresholds[level + 1];

  /// Tiến độ 0..1 trong khoảng [mức hiện tại → mức kế tiếp].
  double get progress {
    if (isMax) return 1;
    final lo = GameBalance.friendshipThresholds[level];
    final hi = GameBalance.friendshipThresholds[level + 1];
    return ((points - lo) / (hi - lo)).clamp(0.0, 1.0).toDouble();
  }

  // ----- Mở khoá -----

  /// Gia sư AI: ẩn hẳn (không chỉ disable) cho tới khi đạt mức này.
  bool get aiTutorUnlocked => level >= _firstLevelOf(FriendshipUnlockType.aiTutor);

  /// Cho phép profile của bản thân xuất hiện trên bảng xếp hạng.
  bool get canShowOnLeaderboard =>
      level >= _firstLevelOf(FriendshipUnlockType.rankingVisibility);

  /// Cấp pet (1..5) đang đạt — mức 0 luôn là cấp 1.
  int get petStage => stageForLevel(level);

  static int stageForLevel(int level) {
    var stage = 1;
    GameBalance.friendshipUnlocks.forEach((lv, unlock) {
      if (unlock.type == FriendshipUnlockType.petStage &&
          level >= lv &&
          unlock.petStage != null) {
        stage = math.max(stage, unlock.petStage!);
      }
    });
    return stage;
  }

  /// Mức Thân thiết cần để mở cấp pet [stage] (cấp 1 → mức 0).
  static int levelForPetStage(int stage) {
    if (stage <= 1) return 0;
    var result = maxLevel;
    GameBalance.friendshipUnlocks.forEach((lv, unlock) {
      if (unlock.type == FriendshipUnlockType.petStage &&
          unlock.petStage == stage) {
        result = lv;
      }
    });
    return result;
  }

  // ----- Hệ số thưởng (TÍNH TỪ TRẠNG THÁI HIỆN TẠI, không bao giờ cộng dồn) -----

  /// Hệ số EXP theo cấp pet. HÀM TRUNG TÂM — mọi chỗ cộng EXP dùng chung.
  double get expMultiplier => 1 +
      _percentAtOrBelow(GameBalance.expBonusPercentByPetStage, petStage) / 100;

  double get coinMultiplier =>
      1 + _percentAtOrBelow(GameBalance.coinBonusPercentByLevel, level) / 100;

  double get gemMultiplier =>
      1 + _percentAtOrBelow(GameBalance.gemBonusPercentByLevel, level) / 100;

  /// Áp hệ số lên số gốc. Số gốc <= 0 giữ nguyên (không thưởng/phạt thêm);
  /// kết quả không bao giờ nhỏ hơn số gốc.
  static int applyMultiplier(int base, double multiplier) {
    if (base <= 0) return base;
    return math.max(base, (base * multiplier).round());
  }

  int boostExp(int base) => applyMultiplier(base, expMultiplier);
  int boostCoin(int base) => applyMultiplier(base, coinMultiplier);
  int boostGem(int base) => applyMultiplier(base, gemMultiplier);

  /// Các phần thưởng MỚI mở khoá khi đi từ mức [from] lên mức [to].
  static List<MapEntry<int, FriendshipUnlock>> unlocksBetween(int from, int to) {
    final out = <MapEntry<int, FriendshipUnlock>>[];
    for (var lv = from + 1; lv <= to; lv++) {
      final u = GameBalance.friendshipUnlocks[lv];
      if (u != null) out.add(MapEntry(lv, u));
    }
    return out;
  }

  /// Mức Thân thiết cần để hiện profile trên bảng xếp hạng (mặc định V = 5).
  static int get rankingUnlockLevel =>
      _firstLevelOf(FriendshipUnlockType.rankingVisibility);

  static int _firstLevelOf(FriendshipUnlockType type) {
    var best = maxLevel + 1;
    GameBalance.friendshipUnlocks.forEach((lv, u) {
      if (u.type == type && lv < best) best = lv;
    });
    return best;
  }

  /// Lấy % của mốc CAO NHẤT có key <= [value] (0 nếu chưa đạt mốc nào).
  static int _percentAtOrBelow(Map<int, int> table, int value) {
    var bestKey = -1;
    var percent = 0;
    table.forEach((k, v) {
      if (k <= value && k > bestKey) {
        bestKey = k;
        percent = v;
      }
    });
    return percent;
  }
}
