import 'dart:math';
import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../widgets/tr_text.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class _MemoryCard {
  final String emoji;
  bool isFlipped;
  bool isMatched;
  _MemoryCard(this.emoji, {this.isFlipped = false, this.isMatched = false});
}

/// Mini game Lật thẻ trí nhớ — lật 2 thẻ mỗi lượt để tìm cặp giống nhau.
/// Càng ít lượt lật, phần thưởng càng cao — rèn khả năng ghi nhớ, tập trung.
class MemoryMatchScreen extends StatefulWidget {
  const MemoryMatchScreen({super.key});

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  static const _emojiSet = ['🍎', '🚗', '🎈', '🌟', '🐶', '🐱', '⚽', '🎨'];

  late List<_MemoryCard> _cards;
  int? _firstIndex;
  int? _secondIndex;
  bool _busy = false;
  int _moves = 0;
  int _matchedPairs = 0;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
    final deck = [..._emojiSet, ..._emojiSet];
    deck.shuffle(Random());
    setState(() {
      _cards = deck.map((e) => _MemoryCard(e)).toList();
      _firstIndex = null;
      _secondIndex = null;
      _busy = false;
      _moves = 0;
      _matchedPairs = 0;
    });
  }

  Future<void> _tapCard(int index) async {
    if (_busy || _cards[index].isFlipped || _cards[index].isMatched) return;

    setState(() => _cards[index].isFlipped = true);

    if (_firstIndex == null) {
      _firstIndex = index;
      return;
    }

    _secondIndex = index;
    _moves++;
    _busy = true;

    final first = _cards[_firstIndex!];
    final second = _cards[_secondIndex!];

    if (first.emoji == second.emoji) {
      HapticFeedback.mediumImpact();
      setState(() {
        first.isMatched = true;
        second.isMatched = true;
        _matchedPairs++;
        _firstIndex = null;
        _secondIndex = null;
        _busy = false;
      });
      if (_matchedPairs == _emojiSet.length) {
        await _onWin();
      }
    } else {
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      setState(() {
        first.isFlipped = false;
        second.isFlipped = false;
        _firstIndex = null;
        _secondIndex = null;
        _busy = false;
      });
    }
  }

  Future<void> _onWin() async {
    final reward = (200 - _moves * 5).clamp(30, 150);
    final auth = context.read<AuthProvider>();
    final student = auth.currentStudent;
    if (student != null) {
      await FirestoreService().claimMiniGameReward(student.uid, reward);
      auth.currentStudent = student.copyWith(coin: student.coin + reward);
      auth.notifyListeners();
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('🎉 Hoàn thành!'),
        content: Text('Bạn đã lật đúng tất cả cặp thẻ trong $_moves lượt.\nNhận được 🪙 $reward Coin.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _newGame();
            },
            child: const Text('Chơi lại'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Thoát'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(bg: BgKind.lavender, 
      appBar: AppBar(title: const Text('Lật thẻ trí nhớ')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Lượt lật: $_moves', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Đã ghép: $_matchedPairs/${_emojiSet.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                itemCount: _cards.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final card = _cards[index];
                  final revealed = card.isFlipped || card.isMatched;
                  return InkWell(
                    onTap: () => _tapCard(index),
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                      child: Container(
                        key: ValueKey(revealed),
                        decoration: BoxDecoration(
                          color: card.isMatched
                              ? AppColors.success.withValues(alpha: 0.25)
                              : (revealed ? Colors.white : AppColors.primary.withValues(alpha: 0.85)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: card.isMatched ? AppColors.success : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          revealed ? card.emoji : '❓',
                          style: TextStyle(fontSize: 26, color: revealed ? null : Colors.white70),
                        ),
                      ),
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
