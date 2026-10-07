import 'package:flutter/material.dart' hide Text;
import 'tr_text.dart';

/// Widget hiển thị ảnh thú cưng — dùng ảnh thật nếu `imageUrl` không rỗng,
/// nếu không (hoặc ảnh lỗi/đang tải) thì hiện emoji thay thế.
class PetImage extends StatelessWidget {
  final String imageUrl;
  final String emoji;
  final double size;

  const PetImage({
    super.key,
    required this.imageUrl,
    required this.emoji,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return Text(emoji, style: TextStyle(fontSize: size));
    }

    return Image.network(
      imageUrl,
      width: size * 1.5,
      height: size * 1.5,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          width: size, height: size,
          child: const CircularProgressIndicator(strokeWidth: 2),
        );
      },
      errorBuilder: (context, error, stackTrace) =>
          Text(emoji, style: TextStyle(fontSize: size)),
    );
  }
}
