import 'dart:math';
import 'package:flutter/material.dart' hide Text;
import '../../models/pet_family_catalog.dart';
import '../../models/pet_model.dart';
import '../tr_text.dart';

/// Pet đang làm gì — quyết định animation nào chạy.
enum HousePetActivity {
  idle,
  dragging,
  walking,
  hopping,
  spinning,
  sleeping,
  eating,
  bathing,
  playing,
  toileting,
}

/// Sprite pet 2D có đủ chuyển động: thở nhẹ khi đứng yên, bước chân khi đi,
/// nhảy khi chạm, nảy bịch khi thả tay, nhai khi ăn, phồng xẹp khi ngủ,
/// xoay vòng, kèm biểu tượng tâm trạng và lớp bụi bẩn khi pet dơ.
///
/// Widget này chỉ VẼ trong ô [size] x [size] — việc đặt vị trí/đi dạo do màn
/// hình nhà đảm nhiệm.
class HousePetSprite extends StatelessWidget {
  final PetModel pet;
  final HousePetActivity activity;
  final bool facingRight;
  final double size;

  /// Thở/bập bênh nhẹ (lặp qua lại 0↔1).
  final Animation<double> bob;

  /// Nhịp hành động lặp 0→1 (đi, nhảy, xoay, nhai).
  final Animation<double> loop;

  /// Cú nhảy 1 lần khi chạm vào pet.
  final Animation<double> jump;

  /// Cú nảy bịch 1 lần khi thả tay sau lúc kéo.
  final Animation<double> squash;

  const HousePetSprite({
    super.key,
    required this.pet,
    required this.activity,
    required this.facingRight,
    required this.size,
    required this.bob,
    required this.loop,
    required this.jump,
    required this.squash,
  });

  bool get _isDirty => pet.hygiene <= 35;

  String? get _mood {
    switch (activity) {
      case HousePetActivity.playing:
        return '😍';
      case HousePetActivity.toileting:
        return '😌';
      case HousePetActivity.sleeping:
      case HousePetActivity.eating:
      case HousePetActivity.bathing:
        return null;
      default:
        break;
    }
    if (pet.toiletNeed >= 70) return '😣';
    if (pet.hunger <= 35 || pet.energy <= 30) return '😟';
    if (pet.hygiene <= 35) return '😵';
    if (pet.playfulness <= 35) return '🥺';
    if (pet.happiness >= 80) return '😊';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([bob, loop, jump, squash]),
      builder: (context, _) => SizedBox(
        width: size,
        height: size,
        child: _build(),
      ),
    );
  }

  Widget _build() {
    final b = bob.value; // 0..1
    final l = loop.value; // 0..1 lặp
    double lift = 0;
    double sx = 1, sy = 1;

    switch (activity) {
      case HousePetActivity.idle:
        lift = sin(b * pi) * 5;
        break;
      case HousePetActivity.walking:
        lift = sin(l * pi * 2).abs() * 8;
        break;
      case HousePetActivity.hopping:
      case HousePetActivity.playing:
        final hop = sin(l * pi);
        lift = hop * 18;
        sx = 1 - hop * 0.08;
        sy = 1 + hop * 0.1;
        break;
      case HousePetActivity.spinning:
        lift = sin(b * pi) * 5;
        break;
      case HousePetActivity.dragging:
        sx = 0.92;
        sy = 1.08;
        lift = 8;
        break;
      case HousePetActivity.sleeping:
        sx = 1.14;
        sy = 0.64 + sin(b * pi) * 0.05;
        break;
      case HousePetActivity.eating:
        final chew = sin(l * pi);
        sx = 1 + chew * 0.08;
        sy = 1 - chew * 0.08;
        break;
      case HousePetActivity.bathing:
      case HousePetActivity.toileting:
        break;
    }

    // Cú nhảy khi chạm.
    final jt = jump.value;
    if (jt > 0 && jt < 1) {
      final w = sin(jt * pi);
      lift += w * 26;
      sx *= 1 - w * 0.12;
      sy *= 1 + w * 0.18;
    }
    // Rơi bịch kiểu slime sau khi thả tay.
    final st = squash.value;
    if (st > 0 && st < 1) {
      final w = sin(st * pi);
      sx *= 1 + w * 0.4;
      sy *= 1 - w * 0.3;
    }

    // Ảnh gốc vẽ pet quay mặt sang TRÁI nên quay phải thì phải lật ảnh.
    final flip = facingRight ? -1.0 : 1.0;
    Widget sprite = Transform(
      alignment: Alignment.bottomCenter,
      transform: Matrix4.identity()..scale(sx * flip, sy),
      child: Image.asset(pet.idleAsset, fit: BoxFit.contain),
    );

    if (activity == HousePetActivity.spinning) {
      sprite = Transform.rotate(angle: l * 2 * pi, child: sprite);
    }

    if (_isDirty && activity != HousePetActivity.sleeping) {
      final severity = ((40 - pet.hygiene) / 40).clamp(0.0, 1.0);
      sprite = ColorFiltered(
        colorFilter: ColorFilter.mode(
          const Color(0xFF6B4A2A).withValues(alpha: 0.22 + severity * 0.22),
          BlendMode.srcATop,
        ),
        child: sprite,
      );
    }

    final badges = <Widget>[];
    String? topEmoji;
    switch (activity) {
      case HousePetActivity.sleeping:
        topEmoji = '💤';
        break;
      case HousePetActivity.eating:
        topEmoji = '🍗';
        break;
      case HousePetActivity.playing:
        topEmoji = '🎾';
        break;
      case HousePetActivity.toileting:
        topEmoji = '🚽';
        break;
      default:
        topEmoji = _mood;
    }
    if (topEmoji != null) {
      badges.add(Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Center(
          child: Text(topEmoji, style: const TextStyle(fontSize: 22)),
        ),
      ));
    }
    if (_isDirty &&
        activity != HousePetActivity.sleeping &&
        activity != HousePetActivity.bathing) {
      final a = b * pi * 2;
      badges.add(Positioned(
        left: size * 0.12 + cos(a) * 10,
        top: size * 0.4 + sin(a) * 8,
        child: const Text('🪰', style: TextStyle(fontSize: 15)),
      ));
      badges.add(Positioned(
        right: size * 0.1 + sin(a) * 8,
        top: size * 0.55 + cos(a) * 6,
        child: const Text('💨', style: TextStyle(fontSize: 14)),
      ));
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          top: 22 - lift,
          bottom: lift - 0,
          child: sprite,
        ),
        ...badges,
      ],
    );
  }
}
