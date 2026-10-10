import 'package:flutter/material.dart' hide Text;
import '../../l10n/tr.dart';
import '../../models/pet_model.dart';
import '../../models/room_data.dart';
import '../../theme/app_theme.dart';
import '../pet_care_dock.dart' show CareButton, roomTabIcon;
import '../tr_text.dart';

/// Nút tròn nền kính trắng nổi trên khung cảnh, có huy hiệu số (ví dụ số
/// nhiệm vụ chờ nhận).
class HouseGlassButton extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final String tooltip;
  final VoidCallback onTap;
  final int badge;
  final Color? color;

  const HouseGlassButton({
    super.key,
    this.icon,
    this.emoji,
    required this.tooltip,
    required this.onTap,
    this.badge = 0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.9),
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.25),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: emoji != null
                      ? Text(emoji!, style: const TextStyle(fontSize: 22))
                      : Icon(icon,
                          size: 22, color: color ?? AppColors.primaryDeep),
                ),
              ),
            ),
          ),
          if (badge > 0)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text('$badge',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Viên thuốc ở giữa thanh trên: tên nhà + thời tiết + giờ game.
class HouseTitleChip extends StatelessWidget {
  final String title;
  final String subtitle;

  const HouseTitleChip({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold)),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

/// Viên thuốc hiển thị số Coin.
class HouseCoinPill extends StatelessWidget {
  final String text;

  const HouseCoinPill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

/// Thẻ trạng thái pet: tên + cấp + thanh EXP, và 5 nhu cầu trên 1 hàng
/// (chuyển đỏ khi pet cần được chăm).
class HouseNeedsCard extends StatelessWidget {
  final PetModel pet;
  final Widget? trailing;

  const HouseNeedsCard({super.key, required this.pet, this.trailing});

  @override
  Widget build(BuildContext context) {
    final expRatio = pet.expToNextLevel <= 0
        ? 0.0
        : (pet.exp / pet.expToNextLevel).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(pet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Lv.${pet.level}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDeep)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: expRatio,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceMuted,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primaryLight),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _NeedBar(emoji: '🍗', value: pet.hunger)),
              const SizedBox(width: 8),
              Expanded(child: _NeedBar(emoji: '⚡', value: pet.energy)),
              const SizedBox(width: 8),
              Expanded(child: _NeedBar(emoji: '😊', value: pet.happiness)),
              const SizedBox(width: 8),
              Expanded(child: _NeedBar(emoji: '🫧', value: pet.hygiene)),
              const SizedBox(width: 8),
              Expanded(
                  child: _NeedBar(emoji: '🚽', value: 100 - pet.toiletNeed)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NeedBar extends StatelessWidget {
  final String emoji;
  final int value;

  const _NeedBar({required this.emoji, required this.value});

  Color get _color {
    if (value < 35) return AppColors.danger;
    if (value < 60) return AppColors.secondary;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final v = (value / 100).clamp(0.0, 1.0).toDouble();
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 3),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 7,
              backgroundColor: _color.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation(_color),
            ),
          ),
        ),
      ],
    );
  }
}

/// Banner "Chăm sóc nhanh": gợi ý việc nên làm NGAY (nhu cầu cấp bách nhất,
/// hoặc nhận thưởng nhiệm vụ), bấm là pet đi tới đúng phòng và làm luôn.
class HouseQuickBanner extends StatefulWidget {
  final String emoji;
  final String title;
  final String actionLabel;
  final bool urgent;
  final VoidCallback onTap;

  const HouseQuickBanner({
    super.key,
    required this.emoji,
    required this.title,
    required this.actionLabel,
    required this.urgent,
    required this.onTap,
  });

  @override
  State<HouseQuickBanner> createState() => _HouseQuickBannerState();
}

class _HouseQuickBannerState extends State<HouseQuickBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.urgent ? AppColors.danger : AppColors.success;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Transform.scale(
        scale: 1 + _pulse.value * 0.035,
        child: child,
      ),
      child: Material(
        color: Colors.white,
        elevation: 4,
        shadowColor: accent.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(widget.actionLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bảng điều khiển phía dưới: chọn phòng + 6 nút chăm sóc (Ăn, Tắm, Ngủ,
/// Vệ sinh, Chơi, Hoạt động) có vòng tiến độ hiển thị chỉ số liên quan.
class HouseDock extends StatelessWidget {
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

  const HouseDock({
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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _RoomTabs(index: roomIndex, onTap: onRoom),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: CareButton(
                          icon: Icons.restaurant_rounded,
                          label: tr('Ăn'),
                          value: pet.hunger / 100,
                          color: const Color(0xFFE59A3E),
                          enabled: !busy,
                          onTap: onFeed,
                        ),
                      ),
                      Expanded(
                        child: CareButton(
                          icon: Icons.bathtub_rounded,
                          label: tr('Tắm'),
                          value: pet.hygiene / 100,
                          color: const Color(0xFF3FB6C9),
                          enabled: !busy,
                          onTap: onBathe,
                        ),
                      ),
                      Expanded(
                        child: CareButton(
                          icon: Icons.bedtime_rounded,
                          label: tr('Ngủ'),
                          value: pet.energy / 100,
                          color: const Color(0xFF5A6BD6),
                          enabled: !busy,
                          onTap: onSleep,
                        ),
                      ),
                      Expanded(
                        child: CareButton(
                          icon: Icons.wc_rounded,
                          label: tr('Vệ sinh'),
                          value: (100 - pet.toiletNeed) / 100,
                          color: const Color(0xFF9B7BE8),
                          enabled: !busy,
                          onTap: onToilet,
                        ),
                      ),
                      Expanded(
                        child: CareButton(
                          assetEmoji: '🎾',
                          label: tr('Chơi'),
                          value: pet.playfulness / 100,
                          color: const Color(0xFF1FA463),
                          enabled: !busy,
                          onTap: onPlay,
                        ),
                      ),
                      Expanded(
                        child: CareButton(
                          icon: Icons.auto_awesome_rounded,
                          label: tr('Hoạt động'),
                          value: 1,
                          color: AppColors.primary,
                          enabled: !busy,
                          onTap: onActivities,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const _RoomTabs({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (var i = 0; i < kRooms.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(roomTabIcon(kRooms[i].type),
                          size: 17,
                          color: i == index
                              ? Colors.white
                              : AppColors.textSecondary),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(kRooms[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: i == index
                                    ? Colors.white
                                    : AppColors.textSecondary)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
