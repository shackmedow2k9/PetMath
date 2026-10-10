import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart' hide Text;
import '../../models/house_decor_catalog.dart';
import '../../models/house_quest_catalog.dart';
import '../../models/room_data.dart';
import '../../services/house_extras_service.dart';
import '../../theme/app_theme.dart';
import '../tr_text.dart';
import 'house_hud.dart';

/// Bảng "Nhiệm vụ hôm nay": tiến độ từng nhiệm vụ, nút nhận thưởng Coin và
/// Rương thưởng cuối ngày khi đã nhận đủ.
class HouseQuestSheet extends StatelessWidget {
  final ValueListenable<HouseExtras> extras;
  final Future<void> Function(String questId) onClaim;
  final Future<void> Function() onClaimBonus;

  const HouseQuestSheet({
    super.key,
    required this.extras,
    required this.onClaim,
    required this.onClaimBonus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: ValueListenableBuilder<HouseExtras>(
            valueListenable: extras,
            builder: (context, ex, _) {
              final doneCount =
                  HouseQuestCatalog.all.where(ex.isClaimed).length;
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('📋', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Nhiệm vụ hôm nay',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        Text('$doneCount/${HouseQuestCatalog.all.length}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDeep)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Làm mới mỗi ngày. Xong việc nhớ bấm nhận thưởng nhé!',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ),
                    const SizedBox(height: 12),
                    for (final q in HouseQuestCatalog.all)
                      _QuestRow(
                        quest: q,
                        progress: ex.progressOf(q.id),
                        claimed: ex.isClaimed(q),
                        onClaim: () => onClaim(q.id),
                      ),
                    const SizedBox(height: 6),
                    _BonusRow(
                      ready: ex.bonusReady,
                      claimed: ex.bonusClaimed,
                      onClaim: onClaimBonus,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  final HouseQuestDef quest;
  final int progress;
  final bool claimed;
  final VoidCallback onClaim;

  const _QuestRow({
    required this.quest,
    required this.progress,
    required this.claimed,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final done = progress >= quest.target;
    final ratio = (progress / quest.target).clamp(0.0, 1.0).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: claimed
            ? AppColors.success.withValues(alpha: 0.08)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Text(quest.emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quest.title,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 7,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation(
                              done ? AppColors.success : AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${progress.clamp(0, quest.target)}/${quest.target}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (claimed)
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 28)
          else if (done)
            ElevatedButton(
              onPressed: onClaim,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Nhận 🪙${quest.rewardCoin}',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.bold)),
            )
          else
            Text('🪙${quest.rewardCoin}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _BonusRow extends StatelessWidget {
  final bool ready;
  final bool claimed;
  final Future<void> Function() onClaim;

  const _BonusRow(
      {required this.ready, required this.claimed, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.secondary.withValues(alpha: ready ? 0.35 : 0.14),
          AppColors.gold.withValues(alpha: ready ? 0.35 : 0.14),
        ]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Text(claimed ? '🎉' : '🎁', style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rương thưởng cuối ngày',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text(
                  claimed
                      ? 'Hôm nay bạn đã mở rương rồi. Hẹn ngày mai nhé!'
                      : 'Nhận đủ thưởng 5 nhiệm vụ để mở · +${HouseQuestCatalog.bonusCoin} 🪙',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (!claimed)
            ElevatedButton(
              onPressed: ready ? onClaim : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Mở',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

/// Khay Trang trí thay cho dock khi bật chế độ trang trí: tab "Kho" (đồ đã
/// mua, chưa đặt) và tab "Cửa hàng" (mua thêm bằng Coin). Kéo món đồ trong
/// phòng để đổi chỗ, bấm ✕ trên món để cất lại vào kho.
class HouseDecorPanel extends StatefulWidget {
  final RoomInfo room;
  final HouseExtras extras;
  final int placedInRoom;
  final String coinText;
  final bool Function(int price) canAfford;
  final ValueChanged<DecorTemplate> onPlace;
  final ValueChanged<DecorTemplate> onBuy;
  final VoidCallback onDone;

  const HouseDecorPanel({
    super.key,
    required this.room,
    required this.extras,
    required this.placedInRoom,
    required this.coinText,
    required this.canAfford,
    required this.onPlace,
    required this.onBuy,
    required this.onDone,
  });

  @override
  State<HouseDecorPanel> createState() => _HouseDecorPanelState();
}

class _HouseDecorPanelState extends State<HouseDecorPanel> {
  int _tab = 0; // 0 = Kho, 1 = Cửa hàng

  @override
  Widget build(BuildContext context) {
    final ex = widget.extras;
    final type = widget.room.type;
    final placedIds = ex.placedIds;
    final fit = DecorCatalog.all.where((d) => d.fitsRoom(type)).toList();
    final bag = fit
        .where((d) => ex.ownedDecor.contains(d.id) && !placedIds.contains(d.id))
        .toList();
    final shop = fit;
    final full = widget.placedInRoom >= DecorCatalog.maxPerRoom;

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
                  const Text('🪑', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Trang trí · ${widget.room.label}',
                            style: const TextStyle(
                                fontSize: 15.5, fontWeight: FontWeight.bold)),
                        Text(
                            '${widget.placedInRoom}/${DecorCatalog.maxPerRoom} món trong phòng',
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  HouseCoinPill(text: widget.coinText),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: widget.onDone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Xong',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _TabButton(
                        label: 'Kho (${bag.length})',
                        selected: _tab == 0,
                        onTap: () => setState(() => _tab = 0)),
                    _TabButton(
                        label: 'Cửa hàng',
                        selected: _tab == 1,
                        onTap: () => setState(() => _tab = 1)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 112,
                child: _tab == 0
                    ? _buildBag(bag, full)
                    : _buildShop(shop, ex, placedIds),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBag(List<DecorTemplate> bag, bool full) {
    if (bag.isEmpty) {
      return const Center(
        child: Text(
          'Kho trống — sang tab Cửa hàng để mua đồ mới nhé!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: bag.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (context, i) {
        final d = bag[i];
        return _DecorCard(
          decor: d,
          footer: full ? 'Phòng đầy' : 'Đặt vào phòng',
          footerColor: full ? AppColors.textSecondary : AppColors.primaryDeep,
          dimmed: full,
          onTap: full ? null : () => widget.onPlace(d),
        );
      },
    );
  }

  Widget _buildShop(
      List<DecorTemplate> shop, HouseExtras ex, Set<String> placedIds) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: shop.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (context, i) {
        final d = shop[i];
        final owned = ex.ownedDecor.contains(d.id);
        if (owned) {
          return _DecorCard(
            decor: d,
            footer: placedIds.contains(d.id) ? 'Đã đặt' : 'Trong kho',
            footerColor: AppColors.success,
            dimmed: true,
            onTap: null,
          );
        }
        final ok = widget.canAfford(d.priceCoin);
        return _DecorCard(
          decor: d,
          footer: '🪙 ${d.priceCoin}',
          footerColor: ok ? AppColors.secondary : AppColors.danger,
          dimmed: !ok,
          onTap: () => widget.onBuy(d),
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary)),
        ),
      ),
    );
  }
}

class _DecorCard extends StatelessWidget {
  final DecorTemplate decor;
  final String footer;
  final Color footerColor;
  final bool dimmed;
  final VoidCallback? onTap;

  const _DecorCard({
    required this.decor,
    required this.footer,
    required this.footerColor,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.62 : 1,
      child: Material(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: SizedBox(
            width: 94,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(decor.emoji, style: const TextStyle(fontSize: 34)),
                const SizedBox(height: 4),
                Text(decor.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(footer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: footerColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}