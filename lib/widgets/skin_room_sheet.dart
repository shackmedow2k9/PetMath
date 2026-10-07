import 'package:flutter/material.dart' hide Text;
import 'tr_text.dart';
import 'package:provider/provider.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/friendship_level.dart';
import '../models/pet_family_catalog.dart';
import '../models/pet_model.dart';
import '../providers/pet_provider.dart';
import '../screens/skin_box_screen.dart';
import '../theme/app_theme.dart';
import 'skin_rarity_style.dart';

/// Ảnh skin: đã mở khoá → hiện bình thường; CHƯA mở khoá → đen hoàn toàn
/// (tô đen mọi pixel, giữ nguyên hình dạng/độ trong suốt của ảnh).
class SkinThumb extends StatelessWidget {
  final String asset;
  final bool unlocked;
  const SkinThumb({super.key, required this.asset, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      asset,
      fit: BoxFit.contain,
      // Thiếu ảnh không làm app crash: hiện ô trống.
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.pets_rounded, size: 40, color: Colors.black26),
    );
    if (unlocked) return img;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
      child: img,
    );
  }
}

/// Phòng đổi skin (thay cho Tủ đồ cũ): danh sách 10 skin của họ pet hiện tại,
/// chạm skin đã sở hữu để mặc/tháo. Đọc pet từ [PetProvider] nên tự cập nhật.
class SkinRoomSheet extends StatelessWidget {
  const SkinRoomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final pet = context.watch<PetProvider>().pet;
    if (pet == null) return const SizedBox.shrink();
    final family = PetFamilyCatalog.familyOf(pet.species);
    final skins = PetFamilyCatalog.skinsOf(family);
    final owned = skins.where((s) => pet.unlockedSkins.contains(s.id)).length;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final hasSkin = pet.equippedSkin.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(l.skinRoomTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 17)),
            ),
            Text(l.librarySkinsOwned(owned, skins.length),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12.5)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
              child: Text(l.skinRoomHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ),
            // Xem trước pet đang hiển thị (skin đang mặc hoặc theo cấp pet).
            SizedBox(
              height: 120,
              child: Image.asset(
                PetArt.idleFor(pet),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.pets_rounded, size: 48),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (hasSkin)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            context.read<PetProvider>().equipSkin(''),
                        child: Text(l.unequipSkin),
                      ),
                    ),
                  if (hasSkin) const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const SkinBoxScreen())),
                      icon: Image.asset('assets/ui/ic_mystery_box.png',
                          width: 20, height: 20),
                      label: Text(l.skinRoomGoBox,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 170,
                  childAspectRatio: 0.68,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: skins.length,
                itemBuilder: (context, i) =>
                    _SkinTile(pet: pet, skin: skins[i], isEn: isEn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkinTile extends StatelessWidget {
  final PetModel pet;
  final PetSkin skin;
  final bool isEn;
  const _SkinTile({required this.pet, required this.skin, required this.isEn});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final unlocked = pet.unlockedSkins.contains(skin.id);
    final equipped = pet.equippedSkin == skin.id;
    final color = skinRarityColor(skin.rarity);
    return GestureDetector(
      onTap: unlocked
          ? () async {
              final ok = await context
                  .read<PetProvider>()
                  .equipSkin(equipped ? '' : skin.id);
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l.equipFailed)));
              }
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: unlocked ? color : AppColors.border,
              width: equipped ? 3 : 1.5),
          boxShadow: equipped
              ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10)]
              : null,
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SkinThumb(
                    asset: PetArt.skinList(skin), unlocked: unlocked),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              unlocked ? (isEn ? skin.nameEn : skin.nameVi) : '???',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            SkinRarityBadge(rarity: skin.rarity),
            const SizedBox(height: 2),
            Text(
              equipped
                  ? l.equipped
                  : (unlocked ? l.equip : l.libraryLocked),
              style: TextStyle(
                  fontSize: 11,
                  color: equipped ? AppColors.success : AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
