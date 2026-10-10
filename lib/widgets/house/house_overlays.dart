import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart' hide Text;
import '../../models/food_catalog.dart';
import '../../models/pet_model.dart';
import '../../theme/app_theme.dart';
import '../tr_text.dart';
import 'house_pet_sprite.dart';

/// Khay đồ ăn trượt lên từ dưới: bấm 1 món để cho pet ăn.
class HouseFoodTray extends StatelessWidget {
  final List<FoodTemplate> foods;
  final Map<String, int> inventory;
  final ValueChanged<FoodTemplate> onFeed;
  final VoidCallback onShop;
  final VoidCallback onClose;

  const HouseFoodTray({
    super.key,
    required this.foods,
    required this.inventory,
    required this.onFeed,
    required this.onShop,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('🍽️', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Chọn món cho pet ăn',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (foods.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      const Text('Bạn chưa có món ăn nào. Ghé Cửa hàng nhé!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: onShop,
                        icon: const Icon(Icons.storefront_rounded),
                        label: const Text('Đến Cửa hàng'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  height: 132,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: foods.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final f = foods[i];
                      final owned = inventory[f.id] ?? 0;
                      return _FoodCard(
                        food: f,
                        owned: owned,
                        onTap: () => onFeed(f),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodCard extends StatelessWidget {
  final FoodTemplate food;
  final int owned;
  final VoidCallback onTap;

  const _FoodCard(
      {required this.food, required this.owned, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          width: 102,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(food.assetPath, fit: BoxFit.contain),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('x$owned',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(food.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                Text('🍗+${food.hungerRestore}  ✨+${food.expReward}',
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cảnh tắm: nền mờ, pet phóng to ở giữa. Học sinh dùng ngón tay XOA lên pet
/// để chà xà phòng (thanh tiến độ đầy dần, bọt nhiều dần); đủ bọt thì tự xả
/// nước rồi ghi nhận lượt tắm.
class HouseBathScene extends StatelessWidget {
  final PetModel pet;
  final Animation<double> bob;
  final Animation<double> loop;
  final Animation<double> jump;
  final Animation<double> squash;

  /// 0..1 — mức bọt xà phòng đã chà.
  final double progress;
  final bool rinsing;
  final ValueChanged<double> onScrub;
  final VoidCallback onClose;

  const HouseBathScene({
    super.key,
    required this.pet,
    required this.bob,
    required this.loop,
    required this.jump,
    required this.squash,
    required this.progress,
    required this.rinsing,
    required this.onScrub,
    required this.onClose,
  });

  static const List<Offset> _foam = [
    Offset(0.50, 0.30),
    Offset(0.30, 0.42),
    Offset(0.70, 0.42),
    Offset(0.40, 0.58),
    Offset(0.60, 0.58),
    Offset(0.50, 0.46),
    Offset(0.26, 0.60),
    Offset(0.74, 0.60),
    Offset(0.36, 0.30),
    Offset(0.64, 0.30),
    Offset(0.50, 0.70),
    Offset(0.32, 0.72),
    Offset(0.68, 0.72),
    Offset(0.50, 0.18),
  ];

  @override
  Widget build(BuildContext context) {
    final petSize = min(MediaQuery.of(context).size.width * 0.62, 250.0);
    final foamCount = (progress * _foam.length).round().clamp(0, _foam.length);
    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.32)),
          ),
        ),
        Positioned.fill(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (d) => onScrub(d.delta.distance),
                    child: SizedBox(
                      width: petSize,
                      height: petSize,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: HousePetSprite(
                              pet: pet.copyWith(hygiene: 100),
                              activity: HousePetActivity.bathing,
                              facingRight: false,
                              size: petSize,
                              bob: bob,
                              loop: loop,
                              jump: jump,
                              squash: squash,
                            ),
                          ),
                          for (var i = 0; i < foamCount; i++)
                            Positioned(
                              left: _foam[i].dx * petSize - 24,
                              top: _foam[i].dy * petSize - 24,
                              child: IgnorePointer(
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white
                                        .withValues(alpha: 0.88),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.white
                                              .withValues(alpha: 0.5),
                                          blurRadius: 8),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          if (rinsing)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: AnimatedBuilder(
                                  animation: loop,
                                  builder: (context, _) => Stack(
                                    children: [
                                      for (var i = 0; i < 6; i++)
                                        Positioned(
                                          left: petSize * (0.12 + i * 0.15),
                                          top: ((loop.value + i * 0.17) %
                                                  1.0) *
                                              petSize,
                                          child: const Text('💧',
                                              style:
                                                  TextStyle(fontSize: 22)),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text('🧼', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              rinsing
                                  ? 'Đang xả nước cho sạch bọt…'
                                  : progress >= 1
                                      ? 'Đủ bọt rồi!'
                                      : 'Xoa ngón tay lên pet để chà xà phòng',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            onPressed: rinsing ? null : onClose,
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Đóng',
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0).toDouble(),
                            minHeight: 10,
                            backgroundColor:
                                const Color(0xFF3FB6C9).withValues(alpha: 0.18),
                            valueColor: const AlwaysStoppedAnimation(
                                Color(0xFF3FB6C9)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Lớp phủ khi pet đang ngủ: màn tối nhẹ + thẻ tiến độ giấc ngủ, có nút
/// "Dậy thôi" để hủy (hủy giữa chừng thì không được hồi Năng lượng).
class HouseSleepOverlay extends StatelessWidget {
  final ValueListenable<double> progress;
  final VoidCallback onWake;

  const HouseSleepOverlay(
      {super.key, required this.progress, required this.onWake});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.42)),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 18,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2250),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('🌙', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Pet đang ngủ… Zzz',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600)),
                      ),
                      TextButton(
                        onPressed: onWake,
                        child: const Text('Dậy thôi',
                            style: TextStyle(color: Color(0xFFFFD93D))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ValueListenableBuilder<double>(
                    valueListenable: progress,
                    builder: (context, v, _) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: v.clamp(0.0, 1.0).toDouble(),
                          minHeight: 9,
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                          valueColor: const AlwaysStoppedAnimation(
                              Color(0xFF8A99F2)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}