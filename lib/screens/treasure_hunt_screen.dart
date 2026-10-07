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

enum _TileType { bomb, coin, gem, energy, empty }

class _Tile {
  final _TileType type;
  final int value;
  bool revealed;
  _Tile(this.type, this.value, {this.revealed = false});
}

/// Mini game Đào kho báu — lật từng ô trên bản đồ, gom Coin/Gem vào "hũ của cải"
/// tạm thời. Có thể rút của cải bất cứ lúc nào (an toàn), nhưng nếu đào trúng
/// bom thì mất sạch số chưa rút — tạo cảm giác hồi hộp "được ăn cả, ngã về không"
/// nhẹ nhàng (không ảnh hưởng tiến độ học, chỉ mất phần chưa rút của lượt chơi này).
class TreasureHuntScreen extends StatefulWidget {
  const TreasureHuntScreen({super.key});

  @override
  State<TreasureHuntScreen> createState() => _TreasureHuntScreenState();
}

class _TreasureHuntScreenState extends State<TreasureHuntScreen> {
  static const int _roundEnergyCost = 15;
  static const int _gridSize = 16;

  List<_Tile> _tiles = [];
  bool _roundActive = false;
  bool _roundEnded = false;
  bool _hitBomb = false;
  int _potCoin = 0;
  int _potGem = 0;
  int _revealedBombIndex = -1;

  List<_Tile> _generateBoard() {
    final defs = <_Tile>[
      _Tile(_TileType.bomb, 0),
      _Tile(_TileType.bomb, 0),
      _Tile(_TileType.bomb, 0),
      _Tile(_TileType.gem, 2),
      _Tile(_TileType.gem, 3),
      _Tile(_TileType.energy, 15),
      _Tile(_TileType.coin, 10),
      _Tile(_TileType.coin, 15),
      _Tile(_TileType.coin, 20),
      _Tile(_TileType.coin, 20),
      _Tile(_TileType.coin, 25),
      _Tile(_TileType.coin, 30),
      _Tile(_TileType.coin, 40),
      _Tile(_TileType.coin, 50),
      _Tile(_TileType.empty, 0),
      _Tile(_TileType.empty, 0),
    ];
    defs.shuffle(Random());
    return defs;
  }

  Future<void> _startRound() async {
    final petProvider = context.read<PetProvider>();
    final pet = petProvider.pet;
    if (pet == null || pet.energy < _roundEnergyCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pet không đủ Năng lượng để đào kho báu (cần 15 ⚡)')),
      );
      return;
    }
    await FirestoreService().adjustPetEnergy(pet.id, -_roundEnergyCost);

    setState(() {
      _tiles = _generateBoard();
      _roundActive = true;
      _roundEnded = false;
      _hitBomb = false;
      _potCoin = 0;
      _potGem = 0;
      _revealedBombIndex = -1;
    });
  }

  void _digTile(int index) {
    if (!_roundActive || _tiles[index].revealed) return;
    final tile = _tiles[index];

    setState(() => tile.revealed = true);

    switch (tile.type) {
      case _TileType.bomb:
        HapticFeedback.heavyImpact();
        setState(() {
          _hitBomb = true;
          _roundActive = false;
          _roundEnded = true;
          _revealedBombIndex = index;
          _potCoin = 0;
          _potGem = 0;
        });
        break;
      case _TileType.coin:
        HapticFeedback.selectionClick();
        setState(() => _potCoin += tile.value);
        break;
      case _TileType.gem:
        HapticFeedback.mediumImpact();
        setState(() => _potGem += tile.value);
        break;
      case _TileType.energy:
        HapticFeedback.lightImpact();
        final pet = context.read<PetProvider>().pet;
        if (pet != null) {
          FirestoreService().adjustPetEnergy(pet.id, tile.value);
        }
        break;
      case _TileType.empty:
        break;
    }

    if (!_hitBomb && _tiles.every((t) => t.revealed || t.type == _TileType.bomb)) {
      // Đã đào hết mọi ô an toàn — tự động kết thúc và rút của cải.
      _cashOut();
    }
  }

  Future<void> _cashOut() async {
    if (!_roundActive && !_roundEnded) return;
    final auth = context.read<AuthProvider>();
    final student = auth.currentStudent;
    if (student != null && (_potCoin > 0 || _potGem > 0)) {
      await FirestoreService().claimMiniGameRewardWithGem(
        student.uid,
        coinAmount: _potCoin,
        gemAmount: _potGem,
      );
      auth.currentStudent = student.copyWith(
        coin: student.coin + _potCoin,
        gem: student.gem + _potGem,
      );
      auth.notifyListeners();
    }
    setState(() {
      _roundActive = false;
      _roundEnded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pet = context.watch<PetProvider>().pet;

    return ScreenScaffold(bg: BgKind.lavender, 
      appBar: AppBar(title: const Text('Đào kho báu')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatPill(emoji: '⚡', label: '${pet?.energy ?? 0}/100'),
                _StatPill(emoji: '🪙', label: '$_potCoin', color: AppColors.secondary),
                _StatPill(emoji: '💎', label: '$_potGem', color: AppColors.info),
              ],
            ),
            const SizedBox(height: 16),
            if (!_roundActive && !_roundEnded)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('⛏️', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 12),
                      const Text('Đào kho báu ẩn dưới các ô đất!',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 6),
                      const Text(
                        'Coi chừng bom 💣 — trúng bom sẽ mất số của cải\nchưa rút trong lượt này. Rút bất cứ lúc nào để an toàn!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _startRound,
                        child: const Text('Bắt đầu đào (tốn 15 ⚡)'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: GridView.builder(
                  itemCount: _gridSize,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) => _TileWidget(
                    tile: _tiles[index],
                    isBombReveal: index == _revealedBombIndex,
                    onTap: () => _digTile(index),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (_roundActive)
              ElevatedButton(
                onPressed: _cashOut,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                child: Text('Rút của cải về túi (🪙$_potCoin 💎$_potGem)'),
              )
            else if (_roundEnded)
              Column(
                children: [
                  Text(
                    _hitBomb
                        ? '💥 Trúng bom! Bạn mất số của cải chưa rút.'
                        : '🎉 Đã rút thành công 🪙$_potCoin 💎$_potGem về túi!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _hitBomb ? AppColors.danger : AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Thoát'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _startRound,
                          child: const Text('Đào tiếp'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TileWidget extends StatelessWidget {
  final _Tile tile;
  final bool isBombReveal;
  final VoidCallback onTap;

  const _TileWidget({required this.tile, required this.isBombReveal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final revealed = tile.revealed;
    Color bg;
    Widget content;

    if (!revealed) {
      bg = AppColors.primary.withValues(alpha: 0.85);
      content = const Icon(Icons.landscape_rounded, color: Colors.white70, size: 26);
    } else {
      switch (tile.type) {
        case _TileType.bomb:
          bg = isBombReveal ? AppColors.danger : AppColors.danger.withValues(alpha: 0.5);
          content = const Text('💣', style: TextStyle(fontSize: 26));
          break;
        case _TileType.coin:
          bg = AppColors.secondary.withValues(alpha: 0.25);
          content = Text('🪙\n${tile.value}',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold));
          break;
        case _TileType.gem:
          bg = AppColors.info.withValues(alpha: 0.25);
          content = Text('💎\n${tile.value}',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold));
          break;
        case _TileType.energy:
          bg = AppColors.success.withValues(alpha: 0.25);
          content = const Text('⚡', style: TextStyle(fontSize: 24));
          break;
        case _TileType.empty:
          bg = Colors.grey.withValues(alpha: 0.15);
          content = const Text('🪨', style: TextStyle(fontSize: 20));
          break;
      }
    }

    return AnimatedScale(
      scale: revealed ? 1.0 : 0.96,
      duration: const Duration(milliseconds: 200),
      child: InkWell(
        onTap: revealed ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String emoji;
  final String label;
  final Color? color;
  const _StatPill({required this.emoji, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (color ?? AppColors.primary).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color ?? AppColors.textPrimary)),
      ]),
    );
  }
}
