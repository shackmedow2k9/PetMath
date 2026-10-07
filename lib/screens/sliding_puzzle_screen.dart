import 'dart:math';
import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../widgets/tr_text.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/pet_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../models/pet_model.dart';

/// Mini game Ghép hình — trò chơi xếp hình trượt (sliding puzzle) 3x3 kinh
/// điển, dùng chính ảnh pet của học sinh làm hình ảnh cần ghép lại, để tạo
/// sự gắn kết với pet thay vì hình ảnh chung chung.
class SlidingPuzzleScreen extends StatefulWidget {
  const SlidingPuzzleScreen({super.key});

  @override
  State<SlidingPuzzleScreen> createState() => _SlidingPuzzleScreenState();
}

class _SlidingPuzzleScreenState extends State<SlidingPuzzleScreen> {
  static const int _gridSize = 3; // 3x3 = 8 ô + 1 ô trống
  static const double _boardSize = 288;

  List<int> _tiles = List<int>.generate(_gridSize * _gridSize, (i) => i);
  int _moves = 0;
  bool _solved = false;
  bool _started = false;

  int get _blankIndex => _tiles.indexOf(_gridSize * _gridSize - 1);

  void _startGame() {
    final random = Random();
    final tiles = List<int>.generate(_gridSize * _gridSize, (i) => i);
    // Xáo bằng cách thực hiện nhiều nước đi hợp lệ từ trạng thái đã giải —
    // đảm bảo bàn cờ luôn giải được (khác với hoán vị ngẫu nhiên thuần túy,
    // vốn có 50% khả năng ra một cấu hình KHÔNG THỂ giải được).
    int blank = tiles.indexOf(_gridSize * _gridSize - 1);
    for (int i = 0; i < 150; i++) {
      final neighbors = _neighborsOf(blank);
      final swapWith = neighbors[random.nextInt(neighbors.length)];
      final temp = tiles[blank];
      tiles[blank] = tiles[swapWith];
      tiles[swapWith] = temp;
      blank = swapWith;
    }

    setState(() {
      _tiles = tiles;
      _moves = 0;
      _solved = false;
      _started = true;
    });
  }

  List<int> _neighborsOf(int index) {
    final row = index ~/ _gridSize;
    final col = index % _gridSize;
    final result = <int>[];
    if (row > 0) result.add(index - _gridSize);
    if (row < _gridSize - 1) result.add(index + _gridSize);
    if (col > 0) result.add(index - 1);
    if (col < _gridSize - 1) result.add(index + 1);
    return result;
  }

  Future<void> _tapTile(int index) async {
    if (_solved) return;
    final blank = _blankIndex;
    if (!_neighborsOf(blank).contains(index)) return;

    HapticFeedback.selectionClick();
    setState(() {
      final temp = _tiles[blank];
      _tiles[blank] = _tiles[index];
      _tiles[index] = temp;
      _moves++;
    });

    final isSolved = List.generate(_gridSize * _gridSize, (i) => i)
        .every((i) => _tiles[i] == i);
    if (isSolved) {
      HapticFeedback.heavyImpact();
      final reward = (140 - _moves * 2).clamp(30, 140);
      final auth = context.read<AuthProvider>();
      final student = auth.currentStudent;
      if (student != null) {
        await FirestoreService().claimMiniGameReward(student.uid, reward);
        auth.currentStudent = student.copyWith(coin: student.coin + reward);
        auth.notifyListeners();
      }
      setState(() => _solved = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = context.watch<PetProvider>().pet;

    return ScreenScaffold(bg: BgKind.lavender, 
      appBar: AppBar(title: const Text('Ghép hình')),
      body: Center(
        child: pet == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_started)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(pet.species.assetPath,
                              width: 160, height: 160, fit: BoxFit.cover),
                        ),
                        const SizedBox(height: 16),
                        const Text('Ghép lại hình ảnh của chính pet bạn!',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        const Text(
                            'Càng ít bước di chuyển, phần thưởng càng cao.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 20),
                        ElevatedButton(
                            onPressed: _startGame,
                            child: const Text('Bắt đầu ghép hình')),
                      ],
                    )
                  else ...[
                    Text('Số bước: $_moves',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: _boardSize,
                      height: _boardSize,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.primary, width: 3),
                            ),
                          ),
                          GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _gridSize * _gridSize,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _gridSize,
                              mainAxisSpacing: 3,
                              crossAxisSpacing: 3,
                            ),
                            itemBuilder: (context, index) {
                              final tileValue = _tiles[index];
                              final isBlank =
                                  tileValue == _gridSize * _gridSize - 1;
                              if (isBlank && !_solved) {
                                return const SizedBox.shrink();
                              }
                              return _PuzzleTile(
                                assetPath: pet.species.assetPath,
                                tileValue: tileValue,
                                gridSize: _gridSize,
                                boardSize: _boardSize,
                                onTap: () => _tapTile(index),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_solved) ...[
                      Text('🎉 Hoàn thành trong $_moves bước!',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.success)),
                      const SizedBox(height: 6),
                      Text(
                          'Nhận được 🪙 ${(140 - _moves * 2).clamp(30, 140)} Coin',
                          style: const TextStyle(color: AppColors.success)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _startGame, child: const Text('Chơi lại')),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

class _PuzzleTile extends StatelessWidget {
  final String assetPath;
  final int tileValue; // vị trí gốc (0..n²-1) của mảnh ảnh này
  final int gridSize;
  final double boardSize;
  final VoidCallback onTap;

  const _PuzzleTile({
    required this.assetPath,
    required this.tileValue,
    required this.gridSize,
    required this.boardSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = tileValue ~/ gridSize;
    final col = tileValue % gridSize;
    // Alignment(-1..1) tương ứng vị trí mảnh ảnh gốc cần hiển thị trong ô này.
    final alignX = gridSize == 1 ? 0.0 : -1 + col * (2 / (gridSize - 1));
    final alignY = gridSize == 1 ? 0.0 : -1 + row * (2 / (gridSize - 1));

    return InkWell(
      onTap: onTap,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: boardSize,
          maxHeight: boardSize,
          alignment: Alignment(alignX, alignY),
          child: SizedBox(
            width: boardSize,
            height: boardSize,
            child: Image.asset(assetPath, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}
