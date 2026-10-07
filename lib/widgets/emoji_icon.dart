import 'package:flutter/material.dart' hide Text;
import 'tr_text.dart';

/// Biểu tượng trong app: dùng icon thật từ icon.zip (assets/ui) cho các emoji
/// quen thuộc; emoji nào chưa có icon tương ứng thì vẫn hiện như cũ.
/// Mọi nơi trước đây vẽ `Text('🪙')`, `Text('💎')`, icon mini game... đều dùng
/// widget này để giao diện đồng nhất.
class EmojiIcon extends StatelessWidget {
  final String emoji;
  final double size;
  const EmojiIcon(this.emoji, {super.key, this.size = 24});

  /// emoji → file icon trong assets/ui
  static const Map<String, String> _assets = {
    '🪙': 'assets/ui/ic_coin_book.png',
    '💎': 'assets/ui/ic_gem.png',
    '🎡': 'assets/ui/ic_lucky_wheel.png',
    '👑': 'assets/ui/ic_crown.png',
    '⛏️': 'assets/ui/ic_treasure_map.png',
    '🎣': 'assets/ui/ic_fishing.png',
    '🕵️‍♂️': 'assets/ui/ic_cipher.png',
    '🧩': 'assets/ui/ic_puzzle_owl.png',
    '🚜': 'assets/ui/ic_farm.png',
    '🧠': 'assets/ui/ic_memory_cards.png',
    '🎭': 'assets/ui/ic_mystery_box.png',
    '🛒': 'assets/ui/ic_coin_book.png',
    '🎮': 'assets/ui/ic_gamepad.png',
    '🏆': 'assets/ui/ic_crown.png',
    '👕': 'assets/ui/ic_mystery_box.png',
    '🏠': 'assets/ui/ic_home.png',
    '🎾': 'assets/ui/ic_gamepad.png',
  };

  @override
  Widget build(BuildContext context) {
    final asset = _assets[emoji];
    if (asset == null) {
      return Text(emoji, style: TextStyle(fontSize: size * 0.8));
    }
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Thiếu ảnh: rơi về emoji gốc, không crash.
      errorBuilder: (_, __, ___) =>
          Text(emoji, style: TextStyle(fontSize: size * 0.8)),
    );
  }
}

/// Icon thanh điều hướng dưới: ảnh từ icon.zip, mờ đi khi chưa được chọn.
class NavAssetIcon extends StatelessWidget {
  final String asset;
  final bool selected;
  const NavAssetIcon(this.asset, {super.key, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: selected ? 1 : 0.55,
      child: SizedBox(
        width: 32,
        height: 32,
        child: Image.asset(asset, fit: BoxFit.contain),
      ),
    );
  }
}
