import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';
import '../models/achievement_catalog.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';

/// Màn hình liệt kê TOÀN BỘ thành tựu trong app — đã mở khoá thì hiện màu,
/// chưa mở khoá thì hiện xám kèm điều kiện cần đạt, để học sinh biết mục
/// tiêu tiếp theo nên nhắm tới.
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final student = context.watch<AuthProvider>().currentStudent;
    final owned = student?.badgeIds.toSet() ?? <String>{};
    final unlockedCount =
        AchievementCatalog.all.where((d) => owned.contains(d.id)).length;
    final total = AchievementCatalog.all.length;

    return ScreenScaffold(bg: BgKind.cream, 
      appBar: AppBar(title: const Text('Thành tựu')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text('Đã mở khoá $unlockedCount/$total',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                const Spacer(),
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : unlockedCount / total,
                      minHeight: 8,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.12),
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: AchievementCatalog.all.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final def = AchievementCatalog.all[index];
                final unlocked = owned.contains(def.id);
                return _AchievementTile(def: def, unlocked: unlocked);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final AchievementDef def;
  final bool unlocked;
  const _AchievementTile({required this.def, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unlocked ? AppColors.gold.withValues(alpha: 0.10) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked
              ? AppColors.gold.withValues(alpha: 0.5)
              : Colors.black.withValues(alpha: 0.08),
          width: unlocked ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked
                  ? AppColors.gold.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            child: Text(
              unlocked ? def.emoji : '🔒',
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: unlocked
                            ? AppColors.textPrimary
                            : AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(def.description,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (unlocked)
            const Icon(Icons.check_circle, color: AppColors.success, size: 22),
        ],
      ),
    );
  }
}
