import 'dart:math';
import 'package:flutter/material.dart' hide Text;
import 'pet_blob_frame.dart';
import 'tr_text.dart';
import 'package:provider/provider.dart';

import '../models/pet_model.dart';
import '../models/pet_family_catalog.dart';
import '../providers/pet_provider.dart';
import '../theme/app_theme.dart';

/// Những câu bâng quơ dễ thương pet "nói" khi được vuốt ve — random 1 câu
/// mỗi lần chạm, y hệt cảm giác Linh Bảo trong Liên Quân Mobile phản hồi
/// khi người chơi tương tác.
const List<String> _petCuteLines = [
  'Yêu bạn quá! 💕',
  'Hihi, thích ghê!',
  'Vuốt ve nữa đi~',
  'Học bài đi rồi quay lại chơi nè!',
  'Mừng quá mừng quá! 🎉',
  'Cảm ơn bạn nha!',
];

/// Avatar pet có animation "thở" liên tục (không đứng im như ảnh tĩnh) và
/// phản hồi khi chạm vào: pet nảy lên vui vẻ + tim/sao bay lên + 1 câu
/// thoại dễ thương ngẫu nhiên. Vuốt ve có giới hạn lượt cộng Vui vẻ/ngày
/// (xem FirestoreService.maxPetInteractionsPerDay) — chạm quá lượt vẫn
/// chạy animation vui mắt, chỉ không cộng thêm chỉ số.
class InteractivePetAvatar extends StatefulWidget {
  final PetModel pet;
  final double size;

  const InteractivePetAvatar({
    super.key,
    required this.pet,
    this.size = 88,
  });

  @override
  State<InteractivePetAvatar> createState() => _InteractivePetAvatarState();
}

class _InteractivePetAvatarState extends State<InteractivePetAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _idleController;
  late final AnimationController _tapController;
  late final Animation<double> _idleBob;
  late final Animation<double> _tapScale;

  final _random = Random();
  final List<_ActiveParticle> _particles = [];
  String? _bubbleText;
  int _particleSeq = 0;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _idleBob = Tween<double>(begin: 0, end: -5).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );

    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _tapScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.82)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 30),
      TweenSequenceItem(
          tween: Tween(begin: 0.82, end: 1.12)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 35),
      TweenSequenceItem(
          tween: Tween(begin: 1.12, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 35),
    ]).animate(_tapController);
  }

  @override
  void dispose() {
    _idleController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    _tapController.forward(from: 0);
    _spawnParticles();
    setState(() =>
        _bubbleText = _petCuteLines[_random.nextInt(_petCuteLines.length)]);
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _bubbleText = null);
    });
    // Cộng Vui vẻ ở nền — không chặn animation, vì phần "vui mắt" luôn
    // chạy ngay lập tức bất kể còn lượt hay không.
    context.read<PetProvider>().patPet();
  }

  void _spawnParticles() {
    const emojis = ['❤️', '✨', '💕', '⭐'];
    final count = 3 + _random.nextInt(2); // 3-4 hạt mỗi lần chạm
    setState(() {
      for (var i = 0; i < count; i++) {
        final id = _particleSeq++;
        _particles.add(_ActiveParticle(
          id: id,
          emoji: emojis[_random.nextInt(emojis.length)],
          dx: (_random.nextDouble() - 0.5) * widget.size * 0.8,
          delayMs: i * 90,
        ));
      }
    });
  }

  void _removeParticle(int id) {
    if (!mounted) return;
    setState(() => _particles.removeWhere((p) => p.id == id));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size + 40,
      height: widget.size + 56,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Hạt tim/sao bay lên — nằm dưới avatar trong Stack nhưng
          // Positioned tự tính từ tâm avatar nên vẫn hiện phía trên nó.
          for (final p in _particles)
            _FloatingEmoji(
              key: ValueKey(p.id),
              emoji: p.emoji,
              dx: p.dx,
              delayMs: p.delayMs,
              onDone: () => _removeParticle(p.id),
            ),
          // Bong bóng thoại dễ thương.
          if (_bubbleText != null)
            Positioned(
              top: 0,
              child: AnimatedOpacity(
                opacity: _bubbleText != null ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2)),
                    ],
                  ),
                  child: Text(_bubbleText!,
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
              ),
            ),
          // Avatar pet: thở liên tục (idle) + nảy khi chạm (tap).
          Positioned(
            bottom: 0,
            child: GestureDetector(
              onTap: _onTap,
              child: AnimatedBuilder(
                animation: Listenable.merge([_idleController, _tapController]),
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _idleBob.value),
                    child: Transform.scale(
                      scale: _tapScale.value,
                      child: child,
                    ),
                  );
                },
                child: PetBlobFrame(
                    width: widget.size * 1.15,
                    petAsset: widget.pet.idleAsset),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveParticle {
  final int id;
  final String emoji;
  final double dx;
  final int delayMs;
  _ActiveParticle(
      {required this.id,
      required this.emoji,
      required this.dx,
      required this.delayMs});
}

/// 1 hạt emoji bay lên rồi mờ dần, tự huỷ sau khi chạy xong animation.
class _FloatingEmoji extends StatefulWidget {
  final String emoji;
  final double dx;
  final int delayMs;
  final VoidCallback onDone;

  const _FloatingEmoji({
    super.key,
    required this.emoji,
    required this.dx,
    required this.delayMs,
    required this.onDone,
  });

  @override
  State<_FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<_FloatingEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rise;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _rise = Tween<double>(begin: 0, end: -70)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.5, 1.0, curve: Curves.easeIn)),
    );
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          bottom: 30 - _rise.value,
          child: Transform.translate(
            offset: Offset(widget.dx, 0),
            child: Opacity(
              opacity: _fade.value,
              child: Text(widget.emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
        );
      },
    );
  }
}
