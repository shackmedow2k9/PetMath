import 'dart:math';

import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

/// Mini game Đoán hình — ghép nhiều emoji để đoán từ/cụm từ tiếng Việt.
class GuessPictureScreen extends StatefulWidget {
  const GuessPictureScreen({super.key});

  @override
  State<GuessPictureScreen> createState() => _GuessPictureScreenState();
}

class _GuessPictureScreenState extends State<GuessPictureScreen> {
  static const _questionBank = <_PicturePuzzle>[
    _PicturePuzzle(
        '🐝🍯',
        'mật ong',
        ['mật ong', 'mật khẩu', 'ong bướm', 'ngọt ngào'],
        'Ghép “mật” và “ong”'),
    _PicturePuzzle(
        '🌙⭐🛏️',
        'đi ngủ',
        ['đi ngủ', 'ngủ đông', 'đêm hội', 'sao băng'],
        'Một hoạt động thường làm ban đêm'),
    _PicturePuzzle(
        '🔥🚒👨‍🚒',
        'cứu hỏa',
        ['cứu hỏa', 'cháy nhà', 'xe cứu thương', 'báo động'],
        'Nghề nghiệp/phương tiện xử lý đám cháy'),
    _PicturePuzzle(
        '📚🎓🎉',
        'tốt nghiệp',
        ['tốt nghiệp', 'học sinh', 'lễ hội', 'khai giảng'],
        'Sự kiện sau khi hoàn thành một bậc học'),
    _PicturePuzzle(
        '🌧️☂️👢',
        'trời mưa',
        ['trời mưa', 'cầu vồng', 'mưa đá', 'áo mưa'],
        'Thời tiết khiến ta cần chiếc ô'),
    _PicturePuzzle(
        '🐟🍜',
        'bún cá',
        ['bún cá', 'cá kho', 'mì tôm', 'canh chua'],
        'Món ăn gồm sợi bún và cá'),
    _PicturePuzzle(
        '🦷🪥😁',
        'đánh răng',
        ['đánh răng', 'răng sữa', 'nụ cười', 'sạch sẽ'],
        'Việc cần làm để chăm sóc răng'),
    _PicturePuzzle(
        '🌊⚡🏭',
        'thủy điện',
        ['thủy điện', 'điện thoại', 'sóng biển', 'nhà máy'],
        'Điện được tạo ra nhờ sức nước'),
    _PicturePuzzle(
        '🌱💧☀️',
        'cây xanh',
        ['cây xanh', 'trồng cây', 'ánh sáng', 'nông trại'],
        'Một vật thể sống cần nước và ánh sáng'),
    _PicturePuzzle(
        '🐢🏁🐇',
        'rùa và thỏ',
        ['rùa và thỏ', 'chậm mà chắc', 'đua xe', 'truyện cổ'],
        'Hai nhân vật trong một truyện ngụ ngôn'),
    _PicturePuzzle(
        '🧠💡📖',
        'ý tưởng',
        ['ý tưởng', 'trí nhớ', 'bài học', 'sáng tạo'],
        'Điều lóe lên khi ta suy nghĩ'),
    _PicturePuzzle(
        '❤️🤝🌍',
        'yêu thương',
        ['yêu thương', 'tình bạn', 'đoàn kết', 'trái tim'],
        'Tình cảm được thể hiện bằng trái tim và sự gắn kết'),
    _PicturePuzzle(
        '⏰🏃‍♀️🚌',
        'trễ giờ',
        ['trễ giờ', 'đúng giờ', 'chạy bộ', 'xe buýt'],
        'Tình huống khi đồng hồ đã quá thời gian'),
    _PicturePuzzle('🔑🚪🏠', 'chìa khóa',
        ['chìa khóa', 'mở cửa', 'nhà cửa', 'khóa học'], 'Vật dùng để mở cửa'),
    _PicturePuzzle(
        '👂🎵🎧',
        'âm nhạc',
        ['âm nhạc', 'nghe nhạc', 'tai nghe', 'giai điệu'],
        'Nghệ thuật của âm thanh và giai điệu'),
    _PicturePuzzle(
        '🌋🔥🌍',
        'núi lửa',
        ['núi lửa', 'núi đá', 'lửa trại', 'động đất'],
        'Ngọn núi có thể phun dung nham'),
    _PicturePuzzle(
        '🧊🍦❄️',
        'kem lạnh',
        ['kem lạnh', 'băng tuyết', 'mùa đông', 'đá viên'],
        'Món ăn ngọt thường được giữ lạnh'),
    _PicturePuzzle(
        '📝✅🏆',
        'bài thi',
        ['bài thi', 'bài tập', 'đáp án', 'chiến thắng'],
        'Bài làm được chấm để đánh giá kiến thức'),
  ];

  late List<_PicturePuzzle> _rounds;
  int _currentIndex = 0;
  int _score = 0;
  int _streak = 0;
  int? _selectedIndex;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final shuffled = [..._questionBank]..shuffle(Random());
    _rounds = shuffled.take(10).toList();
  }

  void _select(int index) {
    if (_selectedIndex != null) return;
    final puzzle = _rounds[_currentIndex];
    final correct = index == puzzle.correctIndex;
    setState(() {
      _selectedIndex = index;
      if (correct) {
        _streak++;
        _score += 10 + (_streak - 1) * 2;
      } else {
        _streak = 0;
      }
    });
  }

  Future<void> _next() async {
    if (_currentIndex < _rounds.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedIndex = null;
      });
      return;
    }
    final auth = context.read<AuthProvider>();
    final coinReward = _score ~/ 5;
    if (coinReward > 0 && auth.currentStudent != null) {
      await FirestoreService()
          .claimMiniGameReward(auth.currentStudent!.uid, coinReward);
      auth.currentStudent = auth.currentStudent?.copyWith(
        coin: auth.currentStudent!.coin + coinReward,
      );
      auth.notifyListeners();
    }
    if (mounted) setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return _buildResult();
    final puzzle = _rounds[_currentIndex];
    return ScreenScaffold(bg: BgKind.cream, 
      appBar: AppBar(
          title: Text('Đoán hình ${_currentIndex + 1}/${_rounds.length}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF4FACFE), Color(0xFF6C5CE7)]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(children: [
                const Text('🖼️', style: TextStyle(fontSize: 34)),
                const SizedBox(width: 12),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Đoán hình cấp độ khó',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20)),
                      SizedBox(height: 4),
                      Text('Ghép nhiều hình để tìm từ khóa',
                          style: TextStyle(color: Colors.white70))
                    ])),
                Text('$_score điểm',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
                child: Column(children: [
                  Text(puzzle.category,
                      style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 18),
                  FittedBox(
                      child: Text(puzzle.emoji,
                          style: const TextStyle(fontSize: 62))),
                  const SizedBox(height: 16),
                  Text(puzzle.hint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.info, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            ...List.generate(puzzle.choices.length, (index) {
              final isSelected = _selectedIndex == index;
              final isCorrect = index == puzzle.correctIndex;
              Color color = Colors.white;
              if (_selectedIndex != null && isCorrect)
                color = AppColors.success.withValues(alpha: 0.18);
              if (_selectedIndex == index && !isCorrect)
                color = AppColors.danger.withValues(alpha: 0.18);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => _select(index),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 16),
                    decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 2)),
                    child: Text(puzzle.choices[index],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }),
            if (_selectedIndex != null)
              ElevatedButton(
                  onPressed: _next,
                  child: Text(_currentIndex < _rounds.length - 1
                      ? 'Câu tiếp theo'
                      : 'Xem kết quả')),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final coinReward = _score ~/ 5;
    return ScreenScaffold(bg: BgKind.cream, 
      appBar: AppBar(title: const Text('Kết quả Đoán hình')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🏆', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 14),
              Text(
                '$_score điểm',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Thưởng $coinReward Coin',
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Về Vua Tiếng Việt'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PicturePuzzle {
  final String emoji;
  final String answer;
  final List<String> choices;
  final String hint;

  const _PicturePuzzle(this.emoji, this.answer, this.choices, this.hint);

  String get category => 'Câu đố ghép hình';
  int get correctIndex => choices.indexOf(answer);
}
