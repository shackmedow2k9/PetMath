import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../widgets/tr_text.dart';
import '../widgets/emoji_icon.dart';

import '../theme/app_theme.dart';
import 'cipher_screen.dart';
import 'fishing_screen.dart';
import 'lucky_spin_screen.dart';
import 'memory_match_screen.dart';
import 'plant_growing_screen.dart';
import 'sliding_puzzle_screen.dart';
import 'treasure_hunt_screen.dart';
import 'vietnamese_games_hub_screen.dart';

/// Trung tâm Mini Game — giữ nguyên bố cục cũ và mở Vua Tiếng Việt
/// từ vị trí thẻ Đoán hình.
class MiniGameHubScreen extends StatelessWidget {
  const MiniGameHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(bg: BgKind.lavender, 
      appBar: AppBar(title: const Text('Mini Game')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.95,
          children: [
            _GameCard(
              emoji: '🎡',
              title: 'Lucky Spin',
              subtitle: 'Quay để nhận Coin & Gem',
              color: AppColors.secondary,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LuckySpinScreen()),
              ),
            ),
            _GameCard(
              emoji: '👑',
              title: 'Vua Tiếng Việt',
              subtitle: 'Đoán hình, nối từ và chơi chữ',
              color: AppColors.info,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const VietnameseGamesHubScreen()),
              ),
            ),
            _GameCard(
              emoji: '⛏️',
              title: 'Đào kho báu',
              subtitle: 'Đào ô, né bom, rút của cải',
              color: AppColors.primary,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TreasureHuntScreen()),
              ),
            ),
            _GameCard(
              emoji: '🎣',
              title: 'Câu cá',
              subtitle: 'Giật cần đúng lúc để câu cá',
              color: AppColors.success,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FishingScreen()),
              ),
            ),
            _GameCard(
              emoji: '🕵️‍♂️',
              title: 'Giải mật mã',
              subtitle: 'Dịch mật mã Caesar, đoán từ',
              color: AppColors.textPrimary,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CipherScreen()),
              ),
            ),
            _GameCard(
              emoji: '🧩',
              title: 'Ghép hình',
              subtitle: 'Ghép lại ảnh pet của bạn',
              color: AppColors.secondary,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SlidingPuzzleScreen()),
              ),
            ),
            _GameCard(
              emoji: '🚜',
              title: 'Nông trại',
              subtitle: 'Trồng hoa & trái cây, chăm pet đi dạo',
              color: AppColors.info,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlantGrowingScreen()),
              ),
            ),
            _GameCard(
              emoji: '🧠',
              title: 'Lật thẻ trí nhớ',
              subtitle: 'Ghép cặp thẻ giống nhau',
              color: AppColors.danger,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MemoryMatchScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _GameCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        decoration: BoxDecoration(
          // Nền ĐẶC (không trong suốt): pha màu mini game lên nền trắng.
          color: Color.alphaBlend(color.withValues(alpha: 0.16), Colors.white),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Icon chiếm phần lớn thẻ (to như ảnh minh họa), co theo kích cỡ ô.
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => Center(
                  child: EmojiIcon(emoji,
                      size: (c.biggest.shortestSide).clamp(64.0, 150.0)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
