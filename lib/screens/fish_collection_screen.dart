import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';
import '../models/fish_data.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/fish_illustration.dart';

/// Bộ sưu tập cá — hiển thị toàn bộ loài cá có thể câu được. Loài đã câu
/// được (mở khóa vĩnh viễn, lưu trên Firestore) hiện đầy đủ; loài chưa câu
/// được hiện dạng bóng mờ "???" để tạo động lực quay lại câu tiếp.
class FishCollectionScreen extends StatelessWidget {
  const FishCollectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final unlockedFish =
        context.watch<AuthProvider>().currentStudent?.unlockedFish ?? [];
    final fishRecords =
        context.watch<AuthProvider>().currentStudent?.fishRecords ?? {};
    final unlockedCount =
        kFishPool.where((f) => unlockedFish.contains(f.id)).length;

    return ScreenScaffold(bg: BgKind.light, 
      appBar: AppBar(title: const Text('Bộ sưu tập cá')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              children: [
                Text('🐟 Đã khám phá $unlockedCount/${kFishPool.length} loài',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: kFishPool.isEmpty
                        ? 0
                        : unlockedCount / kFishPool.length,
                    minHeight: 8,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: kFishPool.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.92,
              ),
              itemBuilder: (context, index) {
                final fish = kFishPool[index];
                final isUnlocked = unlockedFish.contains(fish.id);
                return _FishCard(
                  fish: fish,
                  isUnlocked: isUnlocked,
                  recordKg: fishRecords[fish.id],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FishCard extends StatelessWidget {
  final FishSpecies fish;
  final bool isUnlocked;
  final double? recordKg;
  const _FishCard(
      {required this.fish, required this.isUnlocked, this.recordKg});

  @override
  Widget build(BuildContext context) {
    final rarityColor = rarityBackgroundColor(fish.rarity);
    return Container(
      decoration: BoxDecoration(
        // Màu nền theo ĐỘ HIẾM (không phải màu riêng từng loài) — giúp
        // nhận biết ngay độ hiếm bằng màu sắc: Rác=Trắng, Phổ biến=Xanh
        // lá, Không phổ biến=Xanh nước biển, Hiếm=Đỏ, Siêu hiếm=Tím,
        // Huyền thoại=Vàng (xem [rarityBackgroundColor]).
        color: isUnlocked
            ? rarityColor.withValues(alpha: 0.16)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnlocked
              ? rarityColor.withValues(alpha: 0.55)
              : Colors.grey.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          isUnlocked
              ? FishIllustration(shape: fish.shape, color: fish.color, size: 44)
              : const Text('❓', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 6),
          if (isUnlocked && !fish.isJunk)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: rarityColor.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(rarityLabel(fish.rarity),
                  style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              isUnlocked ? fish.name : '???',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isUnlocked
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (isUnlocked && !fish.isJunk)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                if (fish.coin > 0)
                  Text('🪙 ${fish.coin}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.success)),
                if (fish.gem > 0)
                  Text('💎 ${fish.gem}',
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.info)),
              ],
            )
          else if (!isUnlocked)
            const Text('Chưa câu được',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          if (isUnlocked && !fish.isJunk && recordKg != null) ...[
            const SizedBox(height: 4),
            Text('🏆 Kỷ lục: ${recordKg!.toStringAsFixed(2)} kg',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold)),
          ],
        ],
      ),
    );
  }
}
