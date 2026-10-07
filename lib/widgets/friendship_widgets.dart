import 'package:flutter/material.dart' hide Text;
import 'tr_text.dart';
import 'package:provider/provider.dart';

import '../config/game_balance.dart';
import '../l10n/gen/app_localizations.dart';
import '../models/friendship_level.dart';
import '../models/pet_model.dart';
import '../providers/pet_provider.dart';
import '../screens/pet_library_screen.dart';
import '../screens/skin_box_screen.dart';
import '../theme/app_theme.dart';

/// Mô tả phần thưởng của 1 mức Thân thiết (cho bảng Thân thiết). Số liệu lấy
/// từ [GameBalance] nên đổi balance là chữ tự cập nhật.
String friendshipUnlockDescription(AppLocalizations l, int level) {
  final u = GameBalance.friendshipUnlocks[level];
  if (u == null) return '';
  switch (u.type) {
    case FriendshipUnlockType.aiTutor:
      return l.friendshipRewardAiTutor;
    case FriendshipUnlockType.petStage:
      final stage = u.petStage ?? 1;
      return l.friendshipRewardPetStage(
          stage, GameBalance.expBonusPercentByPetStage[stage] ?? 0);
    case FriendshipUnlockType.coinBonus:
      return l.friendshipRewardCoin(GameBalance.coinBonusPercentByLevel[level] ?? 0);
    case FriendshipUnlockType.rankingVisibility:
      return l.friendshipRewardRanking;
    case FriendshipUnlockType.coinGemBonus:
      return l.friendshipRewardCoinGem(
          GameBalance.coinBonusPercentByLevel[level] ?? 0,
          GameBalance.gemBonusPercentByLevel[level] ?? 0);
  }
}

/// Câu "đã mở khoá" (popup ăn mừng).
List<String> friendshipUnlockedMessages(AppLocalizations l, int level) {
  final u = GameBalance.friendshipUnlocks[level];
  if (u == null) return const [];
  switch (u.type) {
    case FriendshipUnlockType.aiTutor:
      return [l.unlockedAiTutor];
    case FriendshipUnlockType.petStage:
      final stage = u.petStage ?? 1;
      final exp = GameBalance.expBonusPercentByPetStage[stage] ?? 0;
      return [l.unlockedPetStage(stage), if (exp > 0) l.unlockedExpBonus(exp)];
    case FriendshipUnlockType.coinBonus:
      return [l.unlockedCoinBonus(GameBalance.coinBonusPercentByLevel[level] ?? 0)];
    case FriendshipUnlockType.rankingVisibility:
      return [l.unlockedRanking];
    case FriendshipUnlockType.coinGemBonus:
      return [
        l.unlockedCoinGemBonus(GameBalance.coinBonusPercentByLevel[level] ?? 0,
            GameBalance.gemBonusPercentByLevel[level] ?? 0)
      ];
  }
}

/// Bảng Thân thiết: điểm hiện tại, tiến độ, và 10 mức kèm phần thưởng.
/// Đọc pet từ [PetProvider] nên tự cập nhật khi điểm thay đổi.
class FriendshipSheet extends StatelessWidget {
  const FriendshipSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final pet = context.watch<PetProvider>().pet;
    if (pet == null) return const SizedBox.shrink();
    final f = pet.friendship;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF241B3A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite_rounded, color: Color(0xFFFF6B8A)),
                const SizedBox(width: 8),
                Text('${l.friendshipTitle} · ${f.romanLevel}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              f.isMax
                  ? l.friendshipMaxedOut
                  : l.friendshipProgress(f.points, f.nextThreshold ?? f.points),
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: f.progress,
                  minHeight: 8,
                  backgroundColor: Colors.white12,
                  color: const Color(0xFFFF6B8A),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                l.friendshipHowTo(GameBalance.friendshipPerInteraction),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 11.5),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38)),
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const PetLibraryScreen()));
                      },
                      icon: const Icon(Icons.collections_bookmark_outlined, size: 18),
                      label: Text(l.libraryTitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const SkinBoxScreen()));
                      },
                      icon: Image.asset('assets/ui/ic_mystery_box.png',
                          width: 20, height: 20),
                      label: Text(l.skinBoxTitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: FriendshipInfo.maxLevel,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final level = i + 1;
                  final reached = f.level >= level;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: reached
                          ? const Color(0xFFFF6B8A).withValues(alpha: 0.16)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: reached
                          ? Border.all(
                              color: const Color(0xFFFF6B8A).withValues(alpha: 0.6))
                          : null,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(FriendshipInfo.roman(level),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: reached ? Colors.white : Colors.white54,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(friendshipUnlockDescription(l, level),
                                  style: TextStyle(
                                      color: reached ? Colors.white : Colors.white70,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5)),
                              const SizedBox(height: 2),
                              Text(
                                  l.friendshipPointsTotal(
                                      GameBalance.friendshipThresholds[level]),
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 11.5)),
                            ],
                          ),
                        ),
                        Icon(reached ? Icons.check_circle : Icons.lock_outline,
                            color: reached
                                ? const Color(0xFF12B76A)
                                : Colors.white30,
                            size: 20),
                      ],
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

/// Widget "vô hình" lắng nghe pet: khi mức Thân thiết vượt mức đã ăn mừng thì
/// hiện popup mở khoá — ĐÚNG 1 LẦN cho mỗi mốc (claimCelebration dùng
/// transaction nên nhiều màn hình cùng gắn widget này cũng không hiện đôi).
class FriendshipCelebrationListener extends StatefulWidget {
  const FriendshipCelebrationListener({super.key});

  @override
  State<FriendshipCelebrationListener> createState() =>
      _FriendshipCelebrationListenerState();
}

class _FriendshipCelebrationListenerState
    extends State<FriendshipCelebrationListener> {
  bool _busy = false;

  void _maybeCelebrate(PetModel pet) {
    final level = pet.friendship.level;
    final from = pet.celebratedFriendshipLevel;
    if (level <= from || _busy) return;
    _busy = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<PetProvider>();
      final claimed = await provider.claimCelebration(level);
      if (!mounted) return;
      if (claimed) {
        await showDialog<void>(
          context: context,
          builder: (_) => _UnlockDialog(from: from, to: level),
        );
      }
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pet = context.watch<PetProvider>().pet;
    if (pet != null) _maybeCelebrate(pet);
    return const SizedBox.shrink();
  }
}

class _UnlockDialog extends StatelessWidget {
  final int from;
  final int to;
  const _UnlockDialog({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final messages = <String>[];
    for (final e in FriendshipInfo.unlocksBetween(from, to)) {
      messages.addAll(friendshipUnlockedMessages(l, e.key));
    }
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, v, child) => Transform.scale(scale: v, child: child),
            child: const Text('🎉', style: TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: 6),
          Text(l.friendshipLevelLabel(FriendshipInfo.roman(to)),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in messages)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(m,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, color: AppColors.textPrimary)),
            ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
            onPressed: () => Navigator.of(context).pop(), child: Text(l.awesome)),
      ],
    );
  }
}
