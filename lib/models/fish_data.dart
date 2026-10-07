import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Độ hiếm của 1 loài cá — quyết định: (1) tỉ lệ câu được (xem
/// [kNormalRarityRates]/[kLuckyRarityRates]), (2) màu nền hiển thị (xem
/// [rarityBackgroundColor]) để học sinh nhận biết ngay từ xa mà không cần
/// đọc tên. Thứ tự khai báo từ thường -> hiếm nhất.
enum FishRarity { junk, common, uncommon, rare, superRare, legendary }

/// Nhãn tiếng Việt hiển thị cho từng độ hiếm.
String rarityLabel(FishRarity rarity) => switch (rarity) {
      FishRarity.junk => 'Rác',
      FishRarity.common => 'Phổ biến',
      FishRarity.uncommon => 'Không phổ biến',
      FishRarity.rare => 'Hiếm',
      FishRarity.superRare => 'Siêu hiếm',
      FishRarity.legendary => 'Huyền thoại',
    };

/// Màu NỀN theo độ hiếm — theo đúng yêu cầu: Rác=Trắng, Phổ biến=Xanh lá,
/// Không phổ biến=Xanh nước biển, Hiếm=Đỏ, Siêu hiếm=Tím, Huyền thoại=Vàng.
/// Dùng ở Bộ sưu tập cá và bảng kết quả câu để phân biệt độ hiếm bằng màu
/// sắc ngay lập tức, không cần đọc chữ.
Color rarityBackgroundColor(FishRarity rarity) => switch (rarity) {
      FishRarity.junk => const Color(0xFFF5F5F5), // trắng
      FishRarity.common => const Color(0xFF66BB6A), // xanh lá
      FishRarity.uncommon => const Color(0xFF42A5F5), // xanh nước biển
      FishRarity.rare => const Color(0xFFEF5350), // đỏ
      FishRarity.superRare => const Color(0xFFAB47BC), // tím
      FishRarity.legendary => const Color(0xFFFFC107), // vàng
    };

/// Màu HÀO QUANG (luồng ánh sáng xoay quanh cá) khi vừa câu được — dùng
/// riêng cho hiệu ứng "reveal" ở màn câu cá, KHÁC với [rarityBackgroundColor]
/// (dùng cho nhãn/badge) vì màu nhãn của Rác gần như trắng, cần đậm hơn 1
/// chút (bạc xám) mới nổi rõ trên nền biển xanh. Rác vẫn có hào quang riêng
/// theo đúng yêu cầu — không phải chỉ cá quý mới có hiệu ứng này.
Color rarityAuraColor(FishRarity rarity) => switch (rarity) {
      FishRarity.junk => const Color(0xFFB0BEC5), // bạc xám nhẹ
      FishRarity.common => const Color(0xFF66BB6A), // xanh lá
      FishRarity.uncommon => const Color(0xFF42A5F5), // xanh nước biển
      FishRarity.rare => const Color(0xFFEF5350), // đỏ
      FishRarity.superRare => const Color(0xFFAB47BC), // tím
      FishRarity.legendary => const Color(0xFFFFD54F), // vàng rực
    };

/// Hình dạng minh họa (vector, vẽ bằng CustomPainter — KHÔNG dùng ảnh cá
/// thật) cho từng loài — xem [FishIllustration] ở lib/widgets/. Mỗi giá
/// trị là 1 "khuôn" hình đúng với đặc điểm thật của loài (thân dài với cá
/// lóc, có ria với cá trê, xoắn ốc với ốc, hình sao với sao biển...) để
/// không còn dùng chung emoji lẫn lộn giữa các loài khác hẳn nhau. Vài loài
/// dùng chung 1 khuôn khi chúng đúng là CÙNG 1 loại động vật (chỉ khác cỡ/
/// độ hiếm, ví dụ rùa nhỏ và rùa khổng lồ) — màu riêng của từng loài
/// ([FishSpecies.color]) vẫn giúp phân biệt.
enum FishShape {
  genericFish,
  eelFish,
  catfish,
  pufferRound,
  goldfishFancy,
  koiFish,
  bettaFish,
  angelfish,
  clownfish,
  swordtailFish,
  flyingFish,
  rayFlat,
  seahorseCurve,
  sharkFin,
  dolphinCurve,
  whaleBig,
  shrimpCurl,
  prawnClaw,
  crabShell,
  snailShell,
  nautilusShell,
  abaloneShell,
  oysterPearl,
  starfishPoint,
  coralBranch,
  seaweedFresh,
  seaweedDried,
  squidGiant,
  octopusCute,
  turtleShell,
  sealCute,
  penguinCute,
  jellyfishGlow,
  mermaidTreasure,
  dragonSea,
  crownRoyal,
  treasureChest,
  bootShoe,
  canRusty,
  bottleGlass,
  sandalFlip,
  plasticBag,
}

/// Một loài cá có thể câu được — dùng chung giữa màn hình Câu cá và màn
/// hình Bộ sưu tập cá, để cả 2 nơi luôn khớp dữ liệu với nhau.
class FishSpecies {
  final String id;
  final String name;
  final String emoji;
  final FishShape shape;
  final int coin;
  final int gem;
  final int
      weight; // trọng số random NỘI BỘ trong cùng 1 độ hiếm (xem bên dưới)
  final FishRarity rarity;
  final Color color;
  final bool isJunk;

  const FishSpecies({
    required this.id,
    required this.name,
    required this.emoji,
    required this.shape,
    required this.coin,
    this.gem = 0,
    required this.weight,
    required this.rarity,
    required this.color,
    this.isJunk = false,
  });
}

/// Trọng số lớn nhất trong bể, dùng để chuẩn hóa độ khó giật cần (cá càng
/// hiếm — trọng số càng nhỏ — thì ô "giật cần" trong mini QTE càng hẹp).
/// Phải luôn bằng trọng số lớn nhất thực tế trong [kFishPool] bên dưới.
const int kMaxFishWeight = 30;

/// ---------- TỈ LỆ CÂU CÁ THEO ĐỘ HIẾM ----------
///
/// Trước đây tỉ lệ câu cá hiếm được tính hoàn toàn qua cơ chế "reroll"
/// (random nhiều lần, giữ lại con hiếm nhất) — khó kiểm soát chính xác
/// % thực tế và dễ khiến cá hiếm ra nhiều hơn cảm giác "hiếm" đúng nghĩa.
/// Giờ chia làm 2 bước rõ ràng:
///   1. Random ra ĐỘ HIẾM trước, theo đúng % cố định ở 2 bảng dưới đây
///      (khác nhau tùy có dùng Mồi câu may mắn hay không).
///   2. Trong độ hiếm đã chọn, mới random tiếp 1 loài cá CỤ THỂ theo
///      [FishSpecies.weight] (loài phổ biến hơn TRONG CÙNG độ hiếm dễ gặp
///      hơn) — cần câu xịn / quăng cần Perfect vẫn có tác dụng ở bước này
///      (thiên vị loài "xịn" hơn trong đúng độ hiếm đã random ra), không
///      làm lệch % tổng theo độ hiếm.
///
/// Câu bình thường (không dùng mồi may mắn): cá thường (Phổ biến +
/// Không phổ biến) 90%, Rác 5%, còn lại 5% chia cho 3 mức hiếm — càng
/// hiếm tỉ lệ càng thấp (Hiếm 3% > Siêu hiếm 1.3% > Huyền thoại 0.7%).
const Map<FishRarity, double> kNormalRarityRates = {
  FishRarity.common: 0.60,
  FishRarity.uncommon: 0.30,
  FishRarity.junk: 0.05,
  FishRarity.rare: 0.030,
  FishRarity.superRare: 0.013,
  FishRarity.legendary: 0.007,
};

/// Câu dùng Mồi câu may mắn: cá thường giảm còn 70%, Rác tăng lên 12%
/// (mồi "khuấy động" nước nên cũng dễ vướng rác hơn), phần còn lại 18%
/// chia cho cá hiếm — tăng so với câu thường nhưng vẫn giữ đúng thứ tự
/// càng hiếm càng khó gặp (Hiếm 10% > Siêu hiếm 5% > Huyền thoại 3%).
const Map<FishRarity, double> kLuckyRarityRates = {
  FishRarity.common: 0.45,
  FishRarity.uncommon: 0.25,
  FishRarity.junk: 0.12,
  FishRarity.rare: 0.10,
  FishRarity.superRare: 0.05,
  FishRarity.legendary: 0.03,
};

/// Random ra 1 loài cá theo ĐÚNG 2 bước: (1) random ĐỘ HIẾM theo [rates]
/// (tổng phải = 1.0 — xem [kNormalRarityRates]/[kLuckyRarityRates]), rồi
/// (2) trong đúng độ hiếm vừa random được, random tiếp 1 loài CỤ THỂ theo
/// [FishSpecies.weight]. Nếu [extraRerolls] > 0 (quăng cần mạnh/cần câu
/// xịn) thì random thêm vài lần TRONG CÙNG độ hiếm và giữ lại loài có giá
/// trị (coin quy đổi) cao nhất — nhờ vậy cần câu xịn/quăng cần Perfect vẫn
/// có ý nghĩa (ra loài "xịn" hơn) mà KHÔNG làm lệch % tổng theo độ hiếm đã
/// cam kết với người chơi.
FishSpecies pickFishByRarity(
  Random random,
  Map<FishRarity, double> rates, {
  int extraRerolls = 0,
}) {
  final roll = random.nextDouble();
  var cumulative = 0.0;
  var chosenRarity = rates.keys.last;
  for (final entry in rates.entries) {
    cumulative += entry.value;
    if (roll < cumulative) {
      chosenRarity = entry.key;
      break;
    }
  }

  final pool = kFishPool.where((f) => f.rarity == chosenRarity).toList();
  if (pool.isEmpty) return kFishPool.first;

  FishSpecies pickOneInPool() {
    final total = pool.fold<int>(0, (sum, f) => sum + f.weight);
    var r = random.nextInt(total);
    for (final fish in pool) {
      if (r < fish.weight) return fish;
      r -= fish.weight;
    }
    return pool.first;
  }

  var best = pickOneInPool();
  for (var i = 0; i < extraRerolls; i++) {
    final candidate = pickOneInPool();
    final candidateValue = candidate.coin + candidate.gem * 10;
    final bestValue = best.coin + best.gem * 10;
    if (candidateValue > bestValue) best = candidate;
  }
  return best;
}

/// Khoảng cân nặng (kg) hợp lý cho 1 loài cá, dựa theo độ hiếm của nó
/// (không lưu cứng cho từng loài để đỡ phải khai báo tay 40+ dòng — suy ra
/// từ [FishSpecies.weight] là đủ chân thực: cá phổ biến thì nhỏ nhắn, cá
/// huyền thoại thì to đùng, cỡ hàng chục cân).
(double min, double max) fishWeightRangeKg(FishSpecies fish) {
  if (fish.isJunk) return (0.05, 0.6); // đồ linh tinh, không phải cá thật
  final rarityRatio = fish.weight / kMaxFishWeight; // 1.0 = phổ biến nhất
  final minKg = 0.05 + (1 - rarityRatio) * 3.2;
  final maxKg = minKg + 0.35 + (1 - rarityRatio) * 14.0;
  return (minKg, maxKg);
}

/// 1 cấp cần câu — mua ở Cửa hàng câu cá bằng Coin. Cần cao cấp hơn giúp:
/// - [extraRerolls]: thêm lượt random loài CỤ THỂ trong đúng độ hiếm đã ra
///   (xem [pickFishByRarity]) — không làm tăng % ra cá hiếm nói chung, chỉ
///   giúp ra loài "xịn" hơn (giá trị coin/gem cao hơn) trong đúng độ hiếm.
/// - [markerSizeBonus]: cộng thêm vào độ rộng thanh trắng khi giật cần
///   (dễ bắt kịp cá hơn).
/// - [energyCost]: Năng lượng tốn mỗi lượt thả cần (giảm dần theo cấp).
class RodTier {
  final String name;
  final String emoji;
  final int priceCoin;
  final int extraRerolls;
  final double markerSizeBonus;
  final int energyCost;

  const RodTier({
    required this.name,
    required this.emoji,
    required this.priceCoin,
    required this.extraRerolls,
    required this.markerSizeBonus,
    required this.energyCost,
  });
}

const List<RodTier> kRodTiers = [
  RodTier(
      name: 'Cần tre',
      emoji: '🎣',
      priceCoin: 0,
      extraRerolls: 0,
      markerSizeBonus: 0,
      energyCost: 10),
  RodTier(
      name: 'Cần gỗ chắc',
      emoji: '🪵',
      priceCoin: 300,
      extraRerolls: 1,
      markerSizeBonus: 0.02,
      energyCost: 9),
  RodTier(
      name: 'Cần bạc',
      emoji: '🥈',
      priceCoin: 900,
      extraRerolls: 2,
      markerSizeBonus: 0.035,
      energyCost: 8),
  RodTier(
      name: 'Cần vàng huyền thoại',
      emoji: '🏆',
      priceCoin: 2500,
      extraRerolls: 3,
      markerSizeBonus: 0.055,
      energyCost: 6),
];

/// Giá 1 lượt "Mồi câu may mắn" (Gem) — mỗi lượt tự động dùng 1 mồi (nếu
/// có) để cộng thêm rerolls may mắn CHỈ cho lượt câu đó.
const int kBaitGemPrice = 3;
const int kBaitExtraRerolls = 2;

/// Bể cá — chia theo 6 nhóm độ hiếm: Phổ biến, Không phổ biến, Hiếm,
/// Siêu hiếm, Huyền thoại và Rác (câu hụt, không tính vào bộ sưu tập).
/// 7 loài đầu tiên (id: ca_ro -> ung_rach) GIỮ NGUYÊN id/chỉ số như bản
/// gốc để không làm mất dữ liệu "đã mở khóa" của học sinh đang chơi.
const List<FishSpecies> kFishPool = [
  // ================= PHỔ BIẾN (giữ nguyên từ bản gốc) =================
  FishSpecies(
      id: 'ca_ro',
      shape: FishShape.genericFish,
      name: 'Cá rô nhỏ',
      emoji: '🐟',
      coin: 10,
      weight: 28,
      rarity: FishRarity.common,
      color: AppColors.info),
  FishSpecies(
      id: 'ca_diec',
      shape: FishShape.genericFish,
      name: 'Cá diếc',
      emoji: '🐟',
      coin: 15,
      weight: 24,
      rarity: FishRarity.common,
      color: AppColors.info),

  // ================= PHỔ BIẾN (thêm mới) =================
  FishSpecies(
      id: 'ca_me',
      shape: FishShape.genericFish,
      name: 'Cá mè',
      emoji: '🐟',
      coin: 10,
      weight: 30,
      rarity: FishRarity.common,
      color: Color(0xFF64B5F6)),
  FishSpecies(
      id: 'ca_tram',
      shape: FishShape.genericFish,
      name: 'Cá trắm',
      emoji: '🐟',
      coin: 12,
      weight: 29,
      rarity: FishRarity.common,
      color: Color(0xFF4FC3F7)),
  FishSpecies(
      id: 'ca_chuoi',
      shape: FishShape.eelFish,
      name: 'Cá chuối',
      emoji: '🐟',
      coin: 13,
      weight: 27,
      rarity: FishRarity.common,
      color: Color(0xFF26A69A)),
  FishSpecies(
      id: 'ca_loc',
      shape: FishShape.eelFish,
      name: 'Cá lóc',
      emoji: '🐟',
      coin: 14,
      weight: 26,
      rarity: FishRarity.common,
      color: Color(0xFF00897B)),
  FishSpecies(
      id: 'ca_tre',
      shape: FishShape.catfish,
      name: 'Cá trê',
      emoji: '🐟',
      coin: 12,
      weight: 27,
      rarity: FishRarity.common,
      color: Color(0xFF6D4C41)),
  FishSpecies(
      id: 'ca_chot',
      shape: FishShape.catfish,
      name: 'Cá chốt',
      emoji: '🐟',
      coin: 11,
      weight: 28,
      rarity: FishRarity.common,
      color: Color(0xFF8D6E63)),
  FishSpecies(
      id: 'ca_bong',
      shape: FishShape.genericFish,
      name: 'Cá bống',
      emoji: '🐟',
      coin: 10,
      weight: 29,
      rarity: FishRarity.common,
      color: Color(0xFF90A4AE)),
  FishSpecies(
      id: 'tep_dong',
      shape: FishShape.shrimpCurl,
      name: 'Tép đồng',
      emoji: '🦐',
      coin: 8,
      weight: 30,
      rarity: FishRarity.common,
      color: Color(0xFFFF8A65)),
  FishSpecies(
      id: 'oc_buou',
      shape: FishShape.snailShell,
      name: 'Ốc bươu',
      emoji: '🐌',
      coin: 9,
      weight: 28,
      rarity: FishRarity.common,
      color: Color(0xFFBCAAA4)),
  FishSpecies(
      id: 'ca_linh',
      shape: FishShape.genericFish,
      name: 'Cá linh',
      emoji: '🐟',
      coin: 11,
      weight: 27,
      rarity: FishRarity.common,
      color: Color(0xFF4DB6AC)),

  // ================= KHÔNG PHỔ BIẾN =================
  FishSpecies(
      id: 'ca_chep_vang',
      shape: FishShape.goldfishFancy,
      name: 'Cá chép vàng',
      emoji: '🐠',
      coin: 35,
      weight: 18,
      rarity: FishRarity.uncommon,
      color: AppColors.secondary),
  FishSpecies(
      id: 'ca_koi',
      shape: FishShape.koiFish,
      name: 'Cá Koi',
      emoji: '🐠',
      coin: 38,
      weight: 17,
      rarity: FishRarity.uncommon,
      color: Color(0xFFFF7043)),
  FishSpecies(
      id: 'ca_betta',
      shape: FishShape.bettaFish,
      name: 'Cá betta rực rỡ',
      emoji: '🐠',
      coin: 32,
      weight: 18,
      rarity: FishRarity.uncommon,
      color: Color(0xFFEC407A)),
  FishSpecies(
      id: 'ca_than_tien',
      shape: FishShape.angelfish,
      name: 'Cá thần tiên',
      emoji: '🐠',
      coin: 34,
      weight: 17,
      rarity: FishRarity.uncommon,
      color: Color(0xFF7E57C2)),
  FishSpecies(
      id: 'ca_he',
      shape: FishShape.clownfish,
      name: 'Cá hề (Nemo)',
      emoji: '🐠',
      coin: 36,
      weight: 16,
      rarity: FishRarity.uncommon,
      color: Color(0xFFFF7043)),
  FishSpecies(
      id: 'ca_duoi_kiem',
      shape: FishShape.swordtailFish,
      name: 'Cá đuôi kiếm',
      emoji: '🐠',
      coin: 30,
      weight: 19,
      rarity: FishRarity.uncommon,
      color: Color(0xFF29B6F6)),
  FishSpecies(
      id: 'tom_cang',
      shape: FishShape.prawnClaw,
      name: 'Tôm càng xanh',
      emoji: '🦞',
      coin: 40,
      weight: 15,
      rarity: FishRarity.uncommon,
      color: Color(0xFF26C6DA)),
  FishSpecies(
      id: 'cua_bien',
      shape: FishShape.crabShell,
      name: 'Cua biển',
      emoji: '🦀',
      coin: 42,
      weight: 14,
      rarity: FishRarity.uncommon,
      color: Color(0xFFEF5350)),
  FishSpecies(
      id: 'sao_bien',
      shape: FishShape.starfishPoint,
      name: 'Sao biển',
      emoji: '⭐',
      coin: 28,
      weight: 19,
      rarity: FishRarity.uncommon,
      color: Color(0xFFFFCA28)),
  FishSpecies(
      id: 'suong_rong',
      shape: FishShape.seaweedFresh,
      name: 'Rong biển tốt tươi',
      emoji: '🌿',
      coin: 20,
      weight: 20,
      rarity: FishRarity.uncommon,
      color: Color(0xFF66BB6A)),
  FishSpecies(
      id: 'san_ho',
      shape: FishShape.coralBranch,
      name: 'San hô nhỏ',
      emoji: '🪸',
      coin: 33,
      weight: 16,
      rarity: FishRarity.uncommon,
      color: Color(0xFFFF8A80)),
  FishSpecies(
      id: 'oc_anh_vu',
      shape: FishShape.nautilusShell,
      name: 'Ốc anh vũ',
      emoji: '🐚',
      coin: 45,
      gem: 1,
      weight: 13,
      rarity: FishRarity.uncommon,
      color: Color(0xFFD7CCC8)),

  // ================= HIẾM =================
  FishSpecies(
      id: 'rua_bien',
      shape: FishShape.turtleShell,
      name: 'Rùa biển bé',
      emoji: '🐢',
      coin: 55,
      gem: 1,
      weight: 12,
      rarity: FishRarity.rare,
      color: AppColors.success),
  FishSpecies(
      id: 'ca_ngua',
      shape: FishShape.seahorseCurve,
      name: 'Cá ngựa',
      emoji: '🐠',
      coin: 60,
      gem: 1,
      weight: 10,
      rarity: FishRarity.rare,
      color: Color(0xFFAB47BC)),
  FishSpecies(
      id: 'ca_nuoc_no',
      shape: FishShape.pufferRound,
      name: 'Cá nóc phồng',
      emoji: '🐡',
      coin: 58,
      gem: 1,
      weight: 10,
      rarity: FishRarity.rare,
      color: Color(0xFFFFB300)),
  FishSpecies(
      id: 'suua_phat_sang',
      shape: FishShape.jellyfishGlow,
      name: 'Sứa phát sáng',
      emoji: '🪼',
      coin: 62,
      gem: 1,
      weight: 9,
      rarity: FishRarity.rare,
      color: Color(0xFF80DEEA)),
  FishSpecies(
      id: 'ca_bay',
      shape: FishShape.flyingFish,
      name: 'Cá chuồn bay',
      emoji: '🐟',
      coin: 65,
      gem: 1,
      weight: 9,
      rarity: FishRarity.rare,
      color: Color(0xFF42A5F5)),
  FishSpecies(
      id: 'ca_duoi',
      shape: FishShape.rayFlat,
      name: 'Cá đuối nhỏ',
      emoji: '🐟',
      coin: 68,
      gem: 1,
      weight: 8,
      rarity: FishRarity.rare,
      color: Color(0xFF5C6BC0)),
  FishSpecies(
      id: 'hai_cau_con',
      shape: FishShape.sealCute,
      name: 'Hải cẩu con',
      emoji: '🦭',
      coin: 75,
      gem: 2,
      weight: 7,
      rarity: FishRarity.rare,
      color: Color(0xFF78909C)),
  FishSpecies(
      id: 'chim_canh_cut',
      shape: FishShape.penguinCute,
      name: 'Chim cánh cụt lạc',
      emoji: '🐧',
      coin: 72,
      gem: 2,
      weight: 7,
      rarity: FishRarity.rare,
      color: Color(0xFF37474F)),
  FishSpecies(
      id: 'ca_map_con',
      shape: FishShape.sharkFin,
      name: 'Cá mập con hiền lành',
      emoji: '🦈',
      coin: 80,
      gem: 2,
      weight: 6,
      rarity: FishRarity.rare,
      color: Color(0xFF546E7A)),
  FishSpecies(
      id: 'oc_xa_cu',
      shape: FishShape.abaloneShell,
      name: 'Ốc xà cừ ánh cầu vồng',
      emoji: '🐚',
      coin: 78,
      gem: 2,
      weight: 6,
      rarity: FishRarity.rare,
      color: Color(0xFFB39DDB)),

  // ================= SIÊU HIẾM =================
  FishSpecies(
      id: 'bach_tuoc',
      shape: FishShape.octopusCute,
      name: 'Bạch tuộc tí hon',
      emoji: '🐙',
      coin: 70,
      gem: 2,
      weight: 8,
      rarity: FishRarity.superRare,
      color: AppColors.primary),
  FishSpecies(
      id: 'ca_heo',
      shape: FishShape.dolphinCurve,
      name: 'Cá heo nhí',
      emoji: '🐬',
      coin: 95,
      gem: 3,
      weight: 5,
      rarity: FishRarity.superRare,
      color: Color(0xFF29B6F6)),
  FishSpecies(
      id: 'rua_khong_lo',
      shape: FishShape.turtleShell,
      name: 'Rùa biển khổng lồ',
      emoji: '🐢',
      coin: 100,
      gem: 3,
      weight: 4,
      rarity: FishRarity.superRare,
      color: Color(0xFF2E7D32)),
  FishSpecies(
      id: 'ca_nhac_gai',
      shape: FishShape.whaleBig,
      name: 'Cá nhà táng nhí',
      emoji: '🐳',
      coin: 110,
      gem: 3,
      weight: 4,
      rarity: FishRarity.superRare,
      color: Color(0xFF3949AB)),
  FishSpecies(
      id: 'trai_ngoc',
      shape: FishShape.oysterPearl,
      name: 'Trai ngọc quý',
      emoji: '🦪',
      coin: 120,
      gem: 4,
      weight: 3,
      rarity: FishRarity.superRare,
      color: Color(0xFFF8BBD0)),
  FishSpecies(
      id: 'bach_tuoc_khong_lo',
      shape: FishShape.octopusCute,
      name: 'Bạch tuộc khổng lồ',
      emoji: '🐙',
      coin: 130,
      gem: 4,
      weight: 3,
      rarity: FishRarity.superRare,
      color: Color(0xFF6A1B9A)),
  FishSpecies(
      id: 'muc_khong_lo',
      shape: FishShape.squidGiant,
      name: 'Mực khổng lồ bí ẩn',
      emoji: '🦑',
      coin: 135,
      gem: 4,
      weight: 3,
      rarity: FishRarity.superRare,
      color: Color(0xFFAD1457)),
  FishSpecies(
      id: 'san_ho_hoang_gia',
      shape: FishShape.coralBranch,
      name: 'San hô hoàng gia',
      emoji: '🪸',
      coin: 115,
      gem: 3,
      weight: 4,
      rarity: FishRarity.superRare,
      color: Color(0xFFFF5252)),

  // ================= HUYỀN THOẠI =================
  FishSpecies(
      id: 'kho_bau_dai_duong',
      shape: FishShape.mermaidTreasure,
      name: 'Kho báu đại dương',
      emoji: '🧜‍♀️',
      coin: 150,
      gem: 5,
      weight: 3,
      rarity: FishRarity.legendary,
      color: AppColors.gold),
  FishSpecies(
      id: 'ca_voi_xanh',
      shape: FishShape.whaleBig,
      name: 'Cá voi xanh huyền thoại',
      emoji: '🐋',
      coin: 220,
      gem: 7,
      weight: 2,
      rarity: FishRarity.legendary,
      color: Color(0xFF1565C0)),
  FishSpecies(
      id: 'rong_bien',
      shape: FishShape.dragonSea,
      name: 'Rồng biển cổ đại',
      emoji: '🐉',
      coin: 260,
      gem: 8,
      weight: 1,
      rarity: FishRarity.legendary,
      color: Color(0xFF00695C)),
  FishSpecies(
      id: 'vua_hai_vuong',
      shape: FishShape.crownRoyal,
      name: 'Vương miện Hải Vương',
      emoji: '👑',
      coin: 300,
      gem: 10,
      weight: 1,
      rarity: FishRarity.legendary,
      color: AppColors.gold),
  FishSpecies(
      id: 'xac_tau_co',
      shape: FishShape.treasureChest,
      name: 'Rương báu tàu đắm cổ',
      emoji: '💰',
      coin: 350,
      gem: 12,
      weight: 1,
      rarity: FishRarity.legendary,
      color: Color(0xFFFFB300)),

  // ================= RÁC (câu hụt, không tính vào bộ sưu tập) =================
  FishSpecies(
      id: 'ung_rach',
      shape: FishShape.bootShoe,
      name: 'Một chiếc ủng rách',
      emoji: '👢',
      coin: 0,
      weight: 7,
      rarity: FishRarity.junk,
      color: Colors.grey,
      isJunk: true),
  FishSpecies(
      id: 'lon_nuoc',
      shape: FishShape.canRusty,
      name: 'Lon nước rỉ sét',
      emoji: '🥫',
      coin: 0,
      weight: 8,
      rarity: FishRarity.junk,
      color: Colors.blueGrey,
      isJunk: true),
  FishSpecies(
      id: 'chai_thuy_tinh',
      shape: FishShape.bottleGlass,
      name: 'Chai thủy tinh vỡ',
      emoji: '🍾',
      coin: 0,
      weight: 6,
      rarity: FishRarity.junk,
      color: Colors.brown,
      isJunk: true),
  FishSpecies(
      id: 'dep_to_ong',
      shape: FishShape.sandalFlip,
      name: 'Một chiếc dép tổ ong',
      emoji: '🩴',
      coin: 0,
      weight: 7,
      rarity: FishRarity.junk,
      color: Colors.grey,
      isJunk: true),
  FishSpecies(
      id: 'tui_nilon',
      shape: FishShape.plasticBag,
      name: 'Túi nilon trôi dạt',
      emoji: '🛍️',
      coin: 0,
      weight: 8,
      rarity: FishRarity.junk,
      color: Colors.blueGrey,
      isJunk: true),
  FishSpecies(
      id: 'tao_bien_kho',
      shape: FishShape.seaweedDried,
      name: 'Rong biển khô héo',
      emoji: '🌾',
      coin: 0,
      weight: 6,
      rarity: FishRarity.junk,
      color: Colors.brown,
      isJunk: true),
];