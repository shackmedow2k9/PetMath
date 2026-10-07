import 'dart:math';

import '../config/game_balance.dart';
import '../models/pet_family_catalog.dart';

/// Bộ random Hộp mù Skin — THUẦN Dart (không phụ thuộc Firebase) để test được.
///
/// Quy trình 2 bước, đúng yêu cầu:
///  1. Random ĐỘ HIẾM theo trọng số [GameBalance.skinRatePercent]
///     (65/20/10/5 — KHÔNG random đều 10 skin).
///  2. Random ĐỀU 1 skin thuộc độ hiếm đó trong họ pet của người chơi.
/// Người chơi không có bất kỳ cách nào chọn/can thiệp kết quả.
class SkinBoxRoller {
  final Random _rng;

  /// Mặc định dùng [Random.secure] để kết quả không đoán trước được.
  SkinBoxRoller([Random? rng]) : _rng = rng ?? Random.secure();

  SkinRarity rollRarity() {
    final rates = GameBalance.skinRatePercent;
    var total = 0;
    for (final r in SkinRarity.values) {
      total += (rates[r] ?? 0).clamp(0, 1 << 30).toInt();
    }
    if (total <= 0) return SkinRarity.common; // cấu hình hỏng → an toàn
    var pick = _rng.nextInt(total);
    for (final r in SkinRarity.values) {
      pick -= (rates[r] ?? 0).clamp(0, 1 << 30).toInt();
      if (pick < 0) return r;
    }
    return SkinRarity.common;
  }

  PetSkin rollSkin(PetFamily family) {
    final all = PetFamilyCatalog.skinsOf(family);
    final rarity = rollRarity();
    var pool = all.where((s) => s.rarity == rarity).toList();
    if (pool.isEmpty) pool = all; // họ thiếu skin ở độ hiếm này → không crash
    return pool[_rng.nextInt(pool.length)];
  }
}
