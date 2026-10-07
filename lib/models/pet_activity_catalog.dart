import 'package:flutter/material.dart';

/// Hoạt động vui chơi/học cùng pet trong Nhà pet (ngoài Ăn / Tắm / Ngủ / Vệ
/// sinh / Chơi). Mọi con số (hồi/tốn chỉ số, EXP) nằm ở đây để chỉnh cân bằng
/// dễ dàng; mỗi lần làm hoạt động còn được cộng Thân thiết như các tương tác
/// khác ([GameBalance.friendshipPerInteraction]).
class PetActivityDef {
  final String id;
  final IconData icon;
  final Color color;
  final String name;
  final String description;

  /// Hiệu ứng lên chỉ số (dương = hồi, âm = tốn).
  final int hunger;
  final int energy;
  final int happiness;
  final int hp;
  final int exp;

  /// Năng lượng tối thiểu để làm (pet quá mệt thì từ chối).
  final int minEnergy;

  /// Đồ ăn tối thiểu (hoạt động tốn sức cần pet không quá đói).
  final int minHunger;

  /// Kiểu animation: 'hop' (nhún nhảy), 'spin' (xoay tròn), 'pose' (tạo dáng).
  final String anim;
  final int seconds;
  final String startThought;
  final String doneThought;

  const PetActivityDef({
    required this.id,
    required this.icon,
    required this.color,
    required this.name,
    required this.description,
    this.hunger = 0,
    this.energy = 0,
    this.happiness = 0,
    this.hp = 0,
    this.exp = 0,
    this.minEnergy = 15,
    this.minHunger = 0,
    required this.anim,
    required this.seconds,
    required this.startThought,
    required this.doneThought,
  });
}

class PetActivityCatalog {
  PetActivityCatalog._();

  static const List<PetActivityDef> all = [
    PetActivityDef(
      id: 'study',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF5A6BD6),
      name: 'Học cùng pet',
      description: 'Đọc sách chung — nhận thêm EXP',
      energy: -10,
      happiness: 5,
      exp: 20,
      minEnergy: 20,
      anim: 'pose',
      seconds: 3,
      startThought: 'Mình cùng học bài nào! 📚',
      doneThought: 'Học xong rồi, mình thông minh hơn! 🧠',
    ),
    PetActivityDef(
      id: 'dance',
      icon: Icons.music_note_rounded,
      color: Color(0xFFE5589B),
      name: 'Nhảy múa',
      description: 'Vui vẻ tăng mạnh, tốn năng lượng',
      energy: -15,
      happiness: 22,
      anim: 'spin',
      seconds: 3,
      startThought: 'Nhảy nào nhảy nào! 🎵',
      doneThought: 'Vui quá đi mất! 💃',
    ),
    PetActivityDef(
      id: 'exercise',
      icon: Icons.fitness_center_rounded,
      color: Color(0xFFE59A3E),
      name: 'Tập thể dục',
      description: 'Hồi HP, nhận EXP, tốn năng lượng và đói',
      energy: -20,
      hunger: -10,
      hp: 8,
      happiness: 8,
      exp: 10,
      minEnergy: 30,
      minHunger: 30,
      anim: 'hop',
      seconds: 3,
      startThought: 'Một, hai, một, hai! 💪',
      doneThought: 'Khoẻ re luôn! 🏋️',
    ),
    PetActivityDef(
      id: 'sing',
      icon: Icons.mic_rounded,
      color: Color(0xFF1FA463),
      name: 'Hát karaoke',
      description: 'Hát vui, tăng Vui vẻ',
      energy: -5,
      happiness: 14,
      minEnergy: 10,
      anim: 'pose',
      seconds: 3,
      startThought: 'La la la~ 🎤',
      doneThought: 'Mình hát hay không nè? 🎶',
    ),
    PetActivityDef(
      id: 'selfie',
      icon: Icons.photo_camera_rounded,
      color: Color(0xFF59C3E3),
      name: 'Chụp ảnh',
      description: 'Tạo dáng selfie, không tốn năng lượng',
      happiness: 10,
      minEnergy: 0,
      anim: 'pose',
      seconds: 2,
      startThought: 'Cười lên nào! 📸',
      doneThought: 'Ảnh đẹp quá! ✨',
    ),
    PetActivityDef(
      id: 'relax',
      icon: Icons.spa_rounded,
      color: Color(0xFF9B7BE8),
      name: 'Thư giãn',
      description: 'Massage nhẹ, hồi HP và Vui vẻ',
      energy: 5,
      hp: 10,
      happiness: 10,
      minEnergy: 0,
      anim: 'pose',
      seconds: 3,
      startThought: 'Ahh… thoải mái quá… 😌',
      doneThought: 'Cảm giác như mới hoàn toàn! 🌿',
    ),
  ];
}
