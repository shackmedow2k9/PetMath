import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';

import '../l10n/gen/app_localizations.dart';
import '../models/friendship_level.dart';
import '../models/pet_family_catalog.dart';
import '../models/pet_model.dart';
import '../providers/pet_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/skin_rarity_style.dart';
import '../widgets/skin_room_sheet.dart';
import 'skin_box_screen.dart';

/// Thư viện: tab Pet (5 cấp, dùng ảnh "5level list") và tab Skin (10 skin,
/// dùng ảnh "skin list"). Mục chưa mở hiện xám + khoá, KHÔNG giả làm đã sở hữu.
class PetLibraryScreen extends StatelessWidget {
  const PetLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final pet = context.watch<PetProvider>().pet;
    return DefaultTabController(
      length: 2,
      child: ScreenScaffold(bg: BgKind.light, 
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(l.libraryTitle),
          bottom: TabBar(tabs: [
            Tab(text: l.libraryPetTab),
            Tab(text: l.librarySkinTab),
          ]),
        ),
        body: pet == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [
                _PetStagesTab(pet: pet),
                _SkinsTab(pet: pet),
              ]),
      ),
    );
  }
}

const ColorFilter _grayscale = ColorFilter.matrix([
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

Widget _lockedImage(String asset) => Opacity(
      opacity: 0.4,
      child: ColorFiltered(
        colorFilter: _grayscale,
        child: Image.asset(asset, fit: BoxFit.contain),
      ),
    );

class _PetStagesTab extends StatelessWidget {
  final PetModel pet;
  const _PetStagesTab({required this.pet});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final family = PetFamilyCatalog.familyOf(pet.species);
    final currentStage = pet.friendship.petStage;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        childAspectRatio: 0.42,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 5,
      itemBuilder: (context, i) {
        final stage = i + 1;
        final unlocked = stage <= currentStage;
        final isCurrent = stage == currentStage;
        final asset = PetArt.stageList(family, stage);
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isCurrent ? AppColors.primary : AppColors.border,
                width: isCurrent ? 2.5 : 1),
          ),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      unlocked
                          ? Image.asset(asset, fit: BoxFit.contain)
                          : _lockedImage(asset),
                      if (!unlocked)
                        const Center(
                            child: Icon(Icons.lock_rounded,
                                size: 38, color: Colors.black54)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                unlocked
                    ? (isCurrent ? l.libraryCurrent : l.libraryStageName(stage))
                    : l.libraryStageLocked(FriendshipInfo.roman(
                        FriendshipInfo.levelForPetStage(stage))),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: unlocked ? AppColors.textPrimary : AppColors.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SkinsTab extends StatelessWidget {
  final PetModel pet;
  const _SkinsTab({required this.pet});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final family = PetFamilyCatalog.familyOf(pet.species);
    final skins = PetFamilyCatalog.skinsOf(family);
    final owned = skins.where((s) => pet.unlockedSkins.contains(s.id)).length;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(l.librarySkinsOwned(owned, skins.length),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SkinBoxScreen())),
                icon: Image.asset('assets/ui/ic_mystery_box.png', width: 20, height: 20),
                label: Text(l.libraryOpenSkinBox),
              ),
            ],
          ),
        ),
        if (pet.equippedSkin.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextButton(
                onPressed: () => context.read<PetProvider>().equipSkin(''),
                child: Text(l.unequipSkin),
              ),
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.66,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: skins.length,
            itemBuilder: (context, i) {
              final skin = skins[i];
              final unlocked = pet.unlockedSkins.contains(skin.id);
              final equipped = pet.equippedSkin == skin.id;
              final color = skinRarityColor(skin.rarity);
              final asset = PetArt.skinList(skin);
              return GestureDetector(
                onTap: unlocked
                    ? () async {
                        final ok = await context
                            .read<PetProvider>()
                            .equipSkin(equipped ? '' : skin.id);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l.equipFailed)));
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
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              SkinThumb(asset: asset, unlocked: unlocked),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(isEn ? skin.nameEn : skin.nameVi,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      SkinRarityBadge(rarity: skin.rarity),
                      const SizedBox(height: 2),
                      Text(
                        equipped
                            ? l.equipped
                            : (unlocked ? l.equip : l.libraryLocked),
                        style: TextStyle(
                            fontSize: 11,
                            color: equipped
                                ? AppColors.success
                                : AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
