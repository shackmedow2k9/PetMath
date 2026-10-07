import 'package:cloud_firestore/cloud_firestore.dart';
import 'crop_catalog.dart';

/// Trạng thái 1 ô đất ĐANG được trồng — lưu trong `students/{uid}.farmPlots`
/// dưới dạng Map với key là chỉ số ô đất (dạng String, do Firestore Map
/// key luôn là String). Ô đất trống (chưa trồng gì) thì KHÔNG xuất hiện
/// trong Map này — xem thêm [FirestoreService.plantCrop]/[harvestCrop].
///
/// Cơ chế sức khoẻ cây: xem thêm phần "SỨC KHOẺ CÂY TRỒNG" trong
/// crop_catalog.dart ([kWaterWiltHours], [kWaterDeathHours],
/// [kFertilizerFullHours], [kNutritionBonusThreshold],
/// [kNutritionBonusMultiplier]).
class FarmPlotState {
  final int plotIndex;
  final String cropId;
  final DateTime plantedAt;

  // Tổng số giây đã lớn được "chốt sổ" (checkpoint) tính tới thời điểm
  // [lastCareUpdateAt] — cộng dồn với phần thời gian trôi qua thực tế kể
  // từ đó để ra [liveGrowSeconds]. Chỉ được cập nhật lại (checkpoint) mỗi
  // khi tưới/bón/thu hoạch — xem [FirestoreService._checkpointPlot].
  final int growAccumSeconds;

  final DateTime lastWateredAt;
  final DateTime lastFertilizedAt;
  final DateTime lastCareUpdateAt;

  const FarmPlotState({
    required this.plotIndex,
    required this.cropId,
    required this.plantedAt,
    this.growAccumSeconds = 0,
    required this.lastWateredAt,
    required this.lastFertilizedAt,
    required this.lastCareUpdateAt,
  });

  factory FarmPlotState.fromMap(int plotIndex, Map<String, dynamic> map) {
    final plantedAt =
        (map['plantedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return FarmPlotState(
      plotIndex: plotIndex,
      cropId: map['cropId'] ?? '',
      plantedAt: plantedAt,
      growAccumSeconds: map['growAccumSeconds'] ?? 0,
      // Dữ liệu cũ (trước khi có cơ chế tưới/bón) có thể chưa có các mốc
      // này — dùng [plantedAt] làm mốc khởi điểm thay thế hợp lý.
      lastWateredAt:
          (map['lastWateredAt'] as Timestamp?)?.toDate() ?? plantedAt,
      lastFertilizedAt:
          (map['lastFertilizedAt'] as Timestamp?)?.toDate() ?? plantedAt,
      lastCareUpdateAt:
          (map['lastCareUpdateAt'] as Timestamp?)?.toDate() ?? plantedAt,
    );
  }

  CropTemplate get crop => CropCatalog.byId(cropId);

  /// Số giờ đã trôi qua kể từ lần tưới nước gần nhất.
  double _hoursSinceWatered(DateTime now) =>
      now.difference(lastWateredAt).inSeconds / 3600.0;

  /// Số giờ đã trôi qua kể từ lần bón phân gần nhất.
  double _hoursSinceFertilized(DateTime now) =>
      now.difference(lastFertilizedAt).inSeconds / 3600.0;

  /// Cây ĐÃ CHẾT — quên tưới quá [kWaterDeathHours] giờ, phải dọn bỏ, không
  /// thu hoạch/tưới/bón được nữa. NGOẠI LỆ: cây đã lớn đủ 100% (chín hẳn)
  /// TRƯỚC KHI hết nước thì không bao giờ chết nữa — cứ để đó chờ thu
  /// hoạch bao lâu cũng được, kể cả để sang năm sau (xem
  /// [_reachedFullGrowthBeforeWilting]).
  bool isDead({DateTime? now}) {
    final t = now ?? DateTime.now();
    if (_reachedFullGrowthBeforeWilting) return false;
    return _hoursSinceWatered(t) >= kWaterDeathHours;
  }

  /// Cây đang HÉO — quên tưới quá [kWaterWiltHours] giờ (nhưng chưa tới lúc
  /// chết) — ngừng lớn cho tới khi được tưới lại.
  bool isWilted({DateTime? now}) =>
      _hoursSinceWatered(now ?? DateTime.now()) >= kWaterWiltHours;

  /// Mức Nước còn lại, 0-100 — về 0 đúng lúc cây bắt đầu héo.
  double waterLevel({DateTime? now}) {
    final hours = _hoursSinceWatered(now ?? DateTime.now());
    return (100 - hours / kWaterWiltHours * 100).clamp(0.0, 100.0);
  }

  /// Mức Dinh dưỡng còn lại, 0-100 — về 0 sau [kFertilizerFullHours] giờ
  /// kể từ lần bón phân gần nhất.
  double nutritionLevel({DateTime? now}) {
    final hours = _hoursSinceFertilized(now ?? DateTime.now());
    return (100 - hours / kFertilizerFullHours * 100).clamp(0.0, 100.0);
  }

  /// Số giây đã lớn cộng dồn tính tới [t]: [growAccumSeconds] (đã chốt sổ)
  /// cộng thêm phần thời gian lớn thêm kể từ [lastCareUpdateAt], NHƯNG chỉ
  /// tính tới mốc bắt đầu héo ([kWaterWiltHours] sau lần tưới gần nhất) —
  /// cây ngừng lớn hoàn toàn kể từ lúc đó (dù [t] có xa tới đâu) cho tới khi
  /// được tưới lại. Đây là phần lõi dùng chung cho cả [liveGrowSeconds] lẫn
  /// [_reachedFullGrowthBeforeWilting]; KHÔNG tự kiểm tra [isDead] (để
  /// tránh vòng lặp phụ thuộc lẫn nhau giữa 2 hàm đó).
  int _frozenGrowSeconds(DateTime t) {
    final wiltAt = lastWateredAt.add(Duration(hours: kWaterWiltHours));
    final growUntil = wiltAt.isBefore(t) ? wiltAt : t;
    var elapsed = growUntil.difference(lastCareUpdateAt).inSeconds;
    if (elapsed <= 0) return growAccumSeconds;

    final multiplier = nutritionLevel(now: t) > kNutritionBonusThreshold
        ? kNutritionBonusMultiplier
        : 1.0;
    return growAccumSeconds + (elapsed * multiplier).round();
  }

  /// TRUE nếu cây đã lớn đủ 100% ngay TRƯỚC KHI (hoặc đúng lúc) hết nước và
  /// bắt đầu héo — tức là chín hẳn trong lúc còn sống, không phải chín do
  /// "gian lận" sau khi đã chết. Vì lớn lên bị đóng băng đúng ở mốc hết
  /// nước, giá trị lớn lên tối đa mà cây có thể đạt được (nếu không tưới
  /// thêm nữa) chính là [_frozenGrowSeconds] tính tại mốc đó — không phụ
  /// thuộc thời điểm hiện tại xa mốc đó bao lâu.
  bool get _reachedFullGrowthBeforeWilting {
    if (crop.growSeconds <= 0) return true;
    final wiltAt = lastWateredAt.add(Duration(hours: kWaterWiltHours));
    return _frozenGrowSeconds(wiltAt) >= crop.growSeconds;
  }

  /// Số giây đã lớn cộng dồn tính tới [now]: [growAccumSeconds] (đã chốt
  /// sổ) cộng thêm phần thời gian lớn thêm kể từ [lastCareUpdateAt]. Cây
  /// NGỪNG lớn hoàn toàn kể từ lúc bắt đầu héo (chưa chết hẳn nhưng không
  /// lớn thêm) cho tới khi được tưới lại (khi đó server sẽ chốt sổ và đặt
  /// lại mốc). Nếu Dinh dưỡng còn trên [kNutritionBonusThreshold]% thì lớn
  /// nhanh hơn theo [kNutritionBonusMultiplier].
  int liveGrowSeconds({DateTime? now}) {
    final t = now ?? DateTime.now();
    if (isDead(now: t)) return growAccumSeconds;
    return _frozenGrowSeconds(t);
  }

  /// Tiến độ lớn lên: 0.0 (vừa trồng) -> 1.0 (đã chín, sẵn sàng thu hoạch).
  double progress({DateTime? now}) {
    if (crop.growSeconds <= 0) return 1.0;
    final elapsed = liveGrowSeconds(now: now);
    return (elapsed / crop.growSeconds).clamp(0.0, 1.0);
  }

  bool isReady({DateTime? now}) =>
      !isDead(now: now) && progress(now: now) >= 1.0;

  /// Thời gian còn lại tới khi chín — 0 nếu đã sẵn sàng thu hoạch.
  Duration remaining({DateTime? now}) {
    final elapsed = liveGrowSeconds(now: now);
    final left = crop.growSeconds - elapsed;
    return Duration(seconds: left < 0 ? 0 : left);
  }

  /// Giai đoạn hiển thị: 0=hạt giống, 1=mầm non, 2=cây lớn dần, 3=đã chín
  /// (hiện đúng hình quả/hoa riêng của từng loại cây, xem [CropTemplate.emoji]).
  int stageIndex({DateTime? now}) {
    final p = progress(now: now);
    if (p >= 1.0) return 3;
    if (p >= 0.6) return 2;
    if (p >= 0.25) return 1;
    return 0;
  }

  static const List<String> _growingStageEmojis = ['🌰', '🌱', '🌿'];
  static const List<String> _stageNames = [
    'Hạt giống',
    'Mầm non',
    'Đang lớn',
    'Đã chín',
  ];

  String stageEmoji({DateTime? now}) {
    final stage = stageIndex(now: now);
    return stage == 3 ? crop.emoji : _growingStageEmojis[stage];
  }

  /// Nhãn giai đoạn hiển thị cho học sinh, vd "Mầm non", "Đã chín".
  String get stageName => _stageNames[stageIndex()];

  /// Nhãn đếm ngược hiển thị cho học sinh, vd "2:30" hoặc "1:05:20".
  String remainingLabel({DateTime? now}) {
    final d = remaining(now: now);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
  }
}

/// Parse toàn bộ `farmPlots` (dạng Map thô từ Firestore) thành danh sách
/// [FarmPlotState], bỏ qua entry lỗi định dạng (an toàn khi dữ liệu cũ).
List<FarmPlotState> parseFarmPlots(Map<String, dynamic> rawFarmPlots) {
  final result = <FarmPlotState>[];
  for (final entry in rawFarmPlots.entries) {
    final index = int.tryParse(entry.key);
    if (index == null || entry.value is! Map) continue;
    result.add(
      FarmPlotState.fromMap(index, Map<String, dynamic>.from(entry.value)),
    );
  }
  result.sort((a, b) => a.plotIndex.compareTo(b.plotIndex));
  return result;
}
