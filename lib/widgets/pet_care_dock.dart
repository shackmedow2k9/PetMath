import 'package:flutter/material.dart' hide Text;
import '../l10n/tr.dart';
import 'tr_text.dart';

import '../models/pet_activity_catalog.dart';
import '../models/pet_model.dart';
import '../models/room_data.dart';
import '../theme/app_theme.dart';
import 'emoji_icon.dart';

/// Icon thanh chọn phòng (Material icons — icon.zip không có giường/bồn tắm/
/// bàn ăn).
IconData roomTabIcon(RoomType type) {
  switch (type) {
    case RoomType.bedroom:
      return Icons.bed_rounded;
    case RoomType.bathroom:
      return Icons.bathtub_rounded;
    case RoomType.dining:
      return Icons.restaurant_rounded;
  }
}

/// Bảng điều khiển chăm sóc pet ở cuối Nhà pet: chọn phòng, 5 nút chăm sóc có
/// vòng tiến độ (hiện mức chỉ số liên quan, đỏ khi pet cần), và 2 nút mở rộng
/// "Hoạt động" / "Menu". Thay cho cụm nút xếp chồng cũ.
class PetCareDock extends StatelessWidget {
  final PetModel pet;
  final int roomIndex;
  final bool busy;
  final ValueChanged<int> onRoom;
  final VoidCallback onFeed;
  final VoidCallback onBathe;
  final VoidCallback onSleep;
  final VoidCallback onToilet;
  final VoidCallback onPlay;
  final VoidCallback onActivities;
  final VoidCallback onMenu;

  const PetCareDock({
    super.key,
    required this.pet,
    required this.roomIndex,
    required this.busy,
    required this.onRoom,
    required this.onFeed,
    required this.onBathe,
    required this.onSleep,
    required this.onToilet,
    required this.onPlay,
    required this.onActivities,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 16,
              offset: const Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < kRooms.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _RoomChip(
                          icon: roomTabIcon(kRooms[i].type),
                          label: kRooms[i].label,
                          selected: i == roomIndex,
                          onTap: () => onRoom(i),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CareButton(
                        icon: Icons.restaurant_rounded,
                        label: 'Ăn',
                        value: pet.hunger / 100,
                        color: const Color(0xFFE59A3E),
                        enabled: !busy,
                        onTap: onFeed,
                      ),
                    ),
                    Expanded(
                      child: CareButton(
                        icon: Icons.bathtub_rounded,
                        label: 'Tắm',
                        value: pet.hygiene / 100,
                        color: const Color(0xFF3FB6C9),
                        enabled: !busy,
                        onTap: onBathe,
                      ),
                    ),
                    Expanded(
                      child: CareButton(
                        icon: Icons.bedtime_rounded,
                        label: 'Ngủ',
                        value: pet.energy / 100,
                        color: const Color(0xFF5A6BD6),
                        enabled: !busy,
                        onTap: onSleep,
                      ),
                    ),
                    Expanded(
                      child: CareButton(
                        icon: Icons.wc_rounded,
                        label: 'Vệ sinh',
                        // Vòng đầy = thoải mái (ít buồn vệ sinh).
                        value: (100 - pet.toiletNeed) / 100,
                        color: const Color(0xFF9B7BE8),
                        enabled: !busy,
                        onTap: onToilet,
                      ),
                    ),
                    Expanded(
                      child: CareButton(
                        assetEmoji: '🎾',
                        label: 'Chơi',
                        value: pet.playfulness / 100,
                        color: const Color(0xFF1FA463),
                        enabled: !busy,
                        onTap: onPlay,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: busy ? null : onActivities,
                        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                        label: const Text('Hoạt động',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onMenu,
                        icon: const Icon(Icons.apps_rounded, size: 20),
                        label: const Text('Menu',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RoomChip(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 17, color: selected ? Colors.white : AppColors.primary),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? Colors.white : AppColors.textPrimary)),
        ]),
      ),
    );
  }
}

/// Nút tròn chăm sóc có vòng tiến độ quanh icon: vòng đầy = chỉ số tốt, đỏ khi
/// dưới 35% (pet đang cần).
class CareButton extends StatelessWidget {
  final IconData? icon;
  final String? assetEmoji;
  final String label;
  final double value;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const CareButton({
    super.key,
    this.icon,
    this.assetEmoji,
    required this.label,
    required this.value,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0).toDouble();
    final urgent = v < 0.35;
    final ring = urgent ? AppColors.danger : color;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      value: v,
                      strokeWidth: 4,
                      backgroundColor: ring.withValues(alpha: 0.16),
                      valueColor: AlwaysStoppedAnimation(ring),
                    ),
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: assetEmoji != null
                          ? EmojiIcon(assetEmoji!, size: 26)
                          : Icon(icon, color: color, size: 24),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Bảng chọn hoạt động cùng pet. Gọi [onPick] khi bấm một hoạt động hợp lệ.
class PetActivitiesSheet extends StatelessWidget {
  final PetModel pet;
  final ValueChanged<PetActivityDef> onPick;
  const PetActivitiesSheet({super.key, required this.pet, required this.onPick});

  String? _blockReason(PetActivityDef a) {
    if (pet.energy < a.minEnergy) return tr('Pet quá mệt');
    if (pet.hunger < a.minHunger) return tr('Pet đang đói');
    return null;
  }

  String _effects(PetActivityDef a) {
    final parts = <String>[];
    String sign(int v) => v > 0 ? '+$v' : '$v';
    if (a.exp != 0) parts.add('EXP ${sign(a.exp)}');
    if (a.happiness != 0) parts.add('😊 ${sign(a.happiness)}');
    if (a.energy != 0) parts.add('⚡ ${sign(a.energy)}');
    if (a.hunger != 0) parts.add('🍗 ${sign(a.hunger)}');
    if (a.hp != 0) parts.add('❤ ${sign(a.hp)}');
    return parts.join('  ');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 12),
            const Text('Hoạt động cùng pet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Mỗi hoạt động đều tăng Thân thiết',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 12),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisExtent: 128,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: PetActivityCatalog.all.length,
                itemBuilder: (context, i) {
                  final a = PetActivityCatalog.all[i];
                  final block = _blockReason(a);
                  return Material(
                    color: a.color.withValues(alpha: block == null ? 0.12 : 0.05),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: block == null
                          ? () {
                              Navigator.of(context).pop();
                              onPick(a);
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Opacity(
                          opacity: block == null ? 1 : 0.5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                      color: a.color, shape: BoxShape.circle),
                                  child: Icon(a.icon,
                                      color: Colors.white, size: 18),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(a.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14)),
                                ),
                              ]),
                              const SizedBox(height: 6),
                              Text(a.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11.5)),
                              const Spacer(),
                              Text(block ?? _effects(a),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: block == null
                                          ? AppColors.textPrimary
                                          : AppColors.danger)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Một ô trong Menu nhanh.
class MenuTile extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;
  const MenuTile(
      {super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 44, height: 44, child: Center(child: icon)),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
