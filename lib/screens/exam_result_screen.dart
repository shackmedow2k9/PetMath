import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../widgets/tr_text.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import '../models/exam_result_model.dart';
import '../models/question_model.dart';
import '../models/achievement_catalog.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/score_utils.dart';

/// Một "khoảng điểm" (thang 10) ứng với 1 lời động viên/khen ngợi riêng —
/// để học sinh điểm thấp vẫn được động viên thay vì chỉ có 2 trạng thái
/// "tốt/chưa tốt" như trước, còn điểm rất cao (9-10) có lời khen đặc biệt
/// hơn mức "làm tốt lắm" thông thường.
class _ScoreBand {
  final double minScore; // ngưỡng tối thiểu (thang 10) để đạt mức này
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  const _ScoreBand(
      this.minScore, this.emoji, this.title, this.subtitle, this.color);
}

// Sắp xếp từ cao xuống thấp — hàm _bandForScore duyệt từ trên xuống và lấy
// mốc đầu tiên mà điểm đạt được vượt qua.
const _scoreBands = <_ScoreBand>[
  _ScoreBand(10, '🏆', 'Điểm tuyệt đối!',
      'Không sai câu nào — quá đỉnh luôn!', AppColors.gold),
  _ScoreBand(9, '🌟', 'Gần như hoàn hảo!',
      'Chỉ còn thiếu chút xíu nữa là trọn vẹn.', AppColors.success),
  _ScoreBand(8, '🎉', 'Làm tốt lắm!', 'Kết quả này rất đáng tự hào đó!',
      AppColors.success),
  _ScoreBand(6.5, '👍', 'Khá đấy!', 'Cố thêm chút nữa là lên giỏi ngay.',
      AppColors.info),
  _ScoreBand(5, '📚', 'Ổn rồi!', 'Xem lại câu sai để lần sau tốt hơn nhé.',
      AppColors.primary),
  _ScoreBand(3.5, '🌱', 'Cố lên nhé!',
      'Mỗi lần luyện tập đều giúp bạn tiến bộ hơn.', AppColors.secondary),
  _ScoreBand(0, '🤗', 'Đừng nản lòng nhé!',
      'Ai cũng có lúc khó khăn, cùng ôn lại nào.', AppColors.danger),
];

_ScoreBand _bandForScore(double scoreOnTen) {
  for (final band in _scoreBands) {
    // Trừ hao sai số dấu phẩy động (vd 8.9999999 vẫn phải tính là đạt mốc 9).
    if (scoreOnTen >= band.minScore - 0.001) return band;
  }
  return _scoreBands.last;
}

/// Màn hình điểm số sau khi nộp bài — hiển thị điểm số, EXP nhận được,
/// và hiệu ứng confetti nếu làm tốt để tạo cảm giác thành tựu.
class ExamResultScreen extends StatefulWidget {
  final ExamResultModel result;
  final List<QuestionModel> questions;
  final String? assignmentId;
  final bool isExamOrAssignment;

  const ExamResultScreen({
    super.key,
    required this.result,
    this.questions = const [],
    this.assignmentId,
    this.isExamOrAssignment = false,
  });

  @override
  State<ExamResultScreen> createState() => _ExamResultScreenState();
}

class _ExamResultScreenState extends State<ExamResultScreen>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    if (widget.result.scoreOnTen >= 7) {
      _confettiController.play();
    }
    // Thành tựu (nếu có) đã được AuthProvider.refreshCurrentStudent() phát
    // hiện ngay sau khi nộp bài (xem ExamScreen._submitExam) — ở đây chỉ
    // cần "tiêu thụ" (đọc rồi xoá) để hiện popup ăn mừng đúng 1 lần.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final unlocked = context.read<AuthProvider>().consumeNewlyUnlocked();
      if (unlocked.isNotEmpty && mounted) {
        _showAchievementDialog(unlocked);
      }
    });
  }

  Future<void> _showAchievementDialog(List<AchievementDef> unlocked) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thành tựu mới! 🏆'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final def in unlocked)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(def.emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(def.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(def.description,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tuyệt vời!'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final expGained = result.correctCount * FirestoreService.xpPerCorrectAnswer;
    final coinGained = result.correctCount * 5;
    final band = _bandForScore(result.scoreOnTen);

    return ScreenScaffold(bg: BgKind.light, 
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Bảng điểm — thay cho emoji đơn thuần trước đây, hiển
                  // thị luôn điểm số (thang điểm của chính đề này) để học
                  // sinh thấy ngay kết quả, ví dụ "8,5/10".
                  Container(
                    width: 148,
                    height: 148,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: band.color.withValues(alpha: 0.12),
                      border: Border.all(color: band.color, width: 3),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(band.emoji, style: const TextStyle(fontSize: 30)),
                        const SizedBox(height: 4),
                        Text(
                          '${formatVnScore(result.score)}/${formatVnScore(result.maxScore)}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: band.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    band.title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(band.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text(
                      '${result.correctCount}/${result.totalQuestions} câu đúng',
                      style: const TextStyle(
                          fontSize: 15, color: AppColors.textSecondary)),
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _RewardRow(
                              emoji: '⭐',
                              label: 'EXP nhận được',
                              value: '+$expGained'),
                          const Divider(height: 24),
                          _RewardRow(
                              emoji: '🪙',
                              label: 'Coin nhận được',
                              value: '+$coinGained'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                    child: const Text('Về nhà thú cưng'),
                  ),
                ],
              ),
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 24,
            maxBlastForce: 20,
            minBlastForce: 8,
            gravity: 0.3,
          ),
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _RewardRow(
      {required this.emoji, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.success)),
      ],
    );
  }
}