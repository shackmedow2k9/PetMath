import 'package:flutter/material.dart';

/// Khung hình pet (ic_profile_blob.png) — dùng ở Hồ sơ, Nhà pet và các nơi
/// hiển thị ảnh đại diện pet. Ảnh pet nằm trong ô thân của khung, phần "mặt
/// mũ" của khung lộ phía trên giống ảnh minh họa.
class PetBlobFrame extends StatelessWidget {
  /// Chiều rộng khung; chiều cao tự theo tỉ lệ của ảnh khung.
  final double width;
  final String petAsset;

  const PetBlobFrame({super.key, required this.width, required this.petAsset});

  /// Tỉ lệ ảnh ic_profile_blob.png (294 × 272).
  static const double _aspect = 294 / 272;

  @override
  Widget build(BuildContext context) {
    final height = width / _aspect;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/ui/ic_profile_blob.png',
                fit: BoxFit.fill,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
          // Vùng "thân" của khung (đo trên ảnh gốc): trái 20%, phải 22%,
          // trên 40%, dưới 13%.
          Positioned(
            left: width * 0.20,
            right: width * 0.22,
            top: height * 0.40,
            bottom: height * 0.13,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(width * 0.07),
              child: Image.asset(
                petAsset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                // Thiếu ảnh pet: hiện biểu tượng thay vì crash.
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.pets_rounded, color: Colors.black26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
