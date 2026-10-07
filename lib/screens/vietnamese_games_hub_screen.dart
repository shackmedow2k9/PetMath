import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../widgets/tr_text.dart';

import '../theme/app_theme.dart';
import 'guess_picture_screen.dart';
import 'vietnamese_word_games_screen.dart';
import 'word_chain_screen.dart';

/// Hub riêng của Vua Tiếng Việt.
/// Chỉ chứa các trò chơi ngôn ngữ; các mini game khác thuộc hub Mini Game.
class VietnameseGamesHubScreen extends StatelessWidget {
  const VietnameseGamesHubScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(bg: BgKind.cream, 
      appBar: AppBar(title: const Text('Vua Tiếng Việt')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const _HubHero(),
          const SizedBox(height: 22),
          const Text(
            'Đấu trường ngôn ngữ',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.98,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _GameCard(
                emoji: '🖼️',
                title: 'Đoán hình',
                subtitle: 'Ghép hình đoán từ khó',
                color: AppColors.info,
                onTap: () => _open(context, const GuessPictureScreen()),
              ),
              _GameCard(
                emoji: '🔗',
                title: 'Nối từ',
                subtitle: 'Nối âm tiết, không lặp từ',
                color: AppColors.primary,
                onTap: () => _open(context, const WordChainScreen()),
              ),
              _GameCard(
                emoji: '🧩',
                title: 'Sắp xếp từ',
                subtitle: 'Giải mã chữ cái bị trộn',
                color: AppColors.secondary,
                onTap: () => _open(context, const WordScrambleScreen()),
              ),
              _GameCard(
                emoji: '📖',
                title: 'Đoán thành ngữ',
                subtitle: 'Điền mảnh ghép còn thiếu',
                color: AppColors.success,
                onTap: () => _open(context, const ProverbGuessScreen()),
              ),
              _GameCard(
                emoji: '🔍',
                title: 'Từ đồng nghĩa',
                subtitle: 'Chọn từ gần nghĩa nhất',
                color: const Color(0xFF8E64C8),
                onTap: () => _open(context, const SynonymGameScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HubHero extends StatelessWidget {
  const _HubHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB84C), Color(0xFFFF7A59)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Row(
        children: [
          Text('👑', style: TextStyle(fontSize: 48)),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vua Tiếng Việt',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Chơi chữ • học từ • phá kỷ lục',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
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
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 5),
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
