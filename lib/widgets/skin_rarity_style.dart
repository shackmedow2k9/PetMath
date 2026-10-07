import 'package:flutter/material.dart' hide Text;
import 'tr_text.dart';

import '../config/game_balance.dart';
import '../l10n/gen/app_localizations.dart';

/// Màu + nhãn độ hiếm DÙNG CHUNG cho Thư viện, Hộp mù, popup kết quả và skin
/// đang trang bị — để rarity luôn nhất quán ở mọi nơi.
Color skinRarityColor(SkinRarity r) {
  switch (r) {
    case SkinRarity.common:
      return const Color(0xFF9CA3AF); // xám bạc
    case SkinRarity.rare:
      return const Color(0xFF4FACFE); // xanh dương
    case SkinRarity.epic:
      return const Color(0xFFB388FF); // tím
    case SkinRarity.legendary:
      return const Color(0xFFFFB347); // cam vàng
  }
}

String skinRarityLabel(AppLocalizations l, SkinRarity r) {
  switch (r) {
    case SkinRarity.common:
      return l.rarityCommon;
    case SkinRarity.rare:
      return l.rarityRare;
    case SkinRarity.epic:
      return l.rarityEpic;
    case SkinRarity.legendary:
      return l.rarityLegendary;
  }
}

/// Huy hiệu độ hiếm nhỏ (dùng trên thẻ skin).
class SkinRarityBadge extends StatelessWidget {
  final SkinRarity rarity;
  const SkinRarityBadge({super.key, required this.rarity});

  @override
  Widget build(BuildContext context) {
    final color = skinRarityColor(rarity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        skinRarityLabel(AppLocalizations.of(context)!, rarity),
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
