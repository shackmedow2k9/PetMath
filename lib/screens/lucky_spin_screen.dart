import 'dart:math';
import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../widgets/tr_text.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

/// Một ô phần thưởng trên vòng quay — có độ hiếm riêng để tạo cảm giác hồi hộp
/// (Thường / Khá / Hiếm / Cực hiếm), thay vì random đều như bản cũ.
class _SpinSlice {
  final String label;
  final int coin;
  final int gem;
  final int weight; // trọng số random: số càng lớn càng dễ trúng
  final Color color;
  final bool isJackpot;

  const _SpinSlice({
    required this.label,
    required this.coin,
    this.gem = 0,
    required this.weight,
    required this.color,
    this.isJackpot = false,
  });
}

/// Lucky Spin — quay ngẫu nhiên (có trọng số theo độ hiếm) để nhận Coin/Gem.
/// Giới hạn thật sự 1 lượt/ngày (khóa bằng [StudentModel.lastSpinDate]) để
/// tránh học sinh chỉ chơi mà không học — Coin chính vẫn đến từ làm bài.
class LuckySpinScreen extends StatefulWidget {
  const LuckySpinScreen({super.key});

  @override
  State<LuckySpinScreen> createState() => _LuckySpinScreenState();
}

class _LuckySpinScreenState extends State<LuckySpinScreen>
    with SingleTickerProviderStateMixin {
  static const _slices = [
    _SpinSlice(label: '15', coin: 15, weight: 20, color: Color(0xFF6C5CE7)),
    _SpinSlice(label: '30', coin: 30, weight: 16, color: Color(0xFFFFB84C)),
    _SpinSlice(label: '10', coin: 10, weight: 22, color: Color(0xFF4FACFE)),
    _SpinSlice(
        label: '💎 x2', coin: 0, gem: 2, weight: 9, color: Color(0xFF00B894)),
    _SpinSlice(label: '50', coin: 50, weight: 13, color: Color(0xFFFF6B6B)),
    _SpinSlice(label: '20', coin: 20, weight: 20, color: Color(0xFF6C5CE7)),
    _SpinSlice(label: '100', coin: 100, weight: 7, color: Color(0xFFFFB84C)),
    _SpinSlice(
      label: 'JACKPOT',
      coin: 200,
      gem: 5,
      weight: 3,
      color: Color(0xFFFFD93D),
      isJackpot: true,
    ),
  ];

  late final AnimationController _controller;
  late Animation<double> _animation;
  bool _isSpinning = false;
  _SpinSlice? _result;
  int _lastTickSlice = -1;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _animation = Tween<double>(begin: 0, end: 0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _spunToday(DateTime? lastSpinDate) {
    if (lastSpinDate == null) return false;
    final now = DateTime.now();
    return now.year == lastSpinDate.year &&
        now.month == lastSpinDate.month &&
        now.day == lastSpinDate.day;
  }

  _SpinSlice _pickWeightedSlice(Random random) {
    final totalWeight = _slices.fold<int>(0, (sum, s) => sum + s.weight);
    var roll = random.nextInt(totalWeight);
    for (final slice in _slices) {
      if (roll < slice.weight) return slice;
      roll -= slice.weight;
    }
    return _slices.first;
  }

  Future<void> _spin() async {
    if (_isSpinning) return;
    final auth = context.read<AuthProvider>();
    final student = auth.currentStudent;
    if (student == null) return;

    if (_spunToday(student.lastSpinDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Bạn đã quay hôm nay rồi, quay lại vào ngày mai nhé! 🌙')),
      );
      return;
    }

    final random = Random();
    final chosen = _pickWeightedSlice(random);
    final rewardIndex = _slices.indexOf(chosen);

    // Quay nhiều vòng (6-8 vòng ngẫu nhiên cho đỡ nhàm) rồi dừng đúng vào
    // giữa ô đã chọn trước (fair random, không "lừa" học sinh).
    //
    // Lưu ý về hệ góc: CustomPaint.drawArc coi góc 0 là vị trí "3 giờ" và
    // tăng dần theo chiều kim đồng hồ. Mũi tên cố định cũng đặt tại đúng
    // vị trí "3 giờ" nên mốc pointerAngle = 0, khớp thẳng với hệ góc vẽ —
    // không cần quy đổi thêm. Muốn ô rewardIndex dừng đúng dưới mũi tên,
    // ta quay tới đúng góc lệch giữa tâm ô đó và mốc 0 này.
    final sliceAngle = 2 * pi / _slices.length;
    const pointerAngle = 0.0; // vị trí "3 giờ" — trùng mốc 0 của drawArc
    final sliceCenterAngle = rewardIndex * sliceAngle + sliceAngle / 2;
    // Góc quay cần thiết (phần dư trong 1 vòng) để tâm ô rewardIndex khớp
    // đúng vị trí mũi tên, giữ nguyên trong khoảng [0, 2π).
    final requiredRotationMod =
        ((pointerAngle - sliceCenterAngle) % (2 * pi) + (2 * pi)) % (2 * pi);
    // Jitter nhỏ để không phải lúc nào cũng dừng chính giữa ô, nhưng vẫn
    // phải nằm an toàn trong nửa ô (tránh lệch sang ô bên cạnh).
    final jitter = (random.nextDouble() - 0.5) * sliceAngle * 0.7;

    final extraSpins = 6 + random.nextInt(3);
    final currentAngle = _animation.value;
    final baseFullTurns = currentAngle - (currentAngle % (2 * pi));
    final targetAngle =
        baseFullTurns + (2 * pi * extraSpins) + requiredRotationMod + jitter;

    _animation = Tween<double>(begin: currentAngle, end: targetAngle).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuint),
    );
    _lastTickSlice = -1;

    setState(() {
      _isSpinning = true;
      _result = null;
    });

    HapticFeedback.mediumImpact();
    _controller.reset();
    await _controller.forward();

    final firestoreService = FirestoreService();
    await firestoreService.claimSpinReward(
      student.uid,
      coinAmount: chosen.coin,
      gemAmount: chosen.gem,
    );
    auth.currentStudent = student.copyWith(
      coin: student.coin + chosen.coin,
      gem: student.gem + chosen.gem,
      lastSpinDate: DateTime.now(),
    );
    auth.notifyListeners();

    if (chosen.isJackpot) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    setState(() {
      _isSpinning = false;
      _result = chosen;
    });

    if (mounted) _showResultDialog(chosen);
  }

  void _onTick() {
    // Rung nhẹ mỗi khi mũi tên vượt qua ranh giới 1 ô — tạo cảm giác "lách cách"
    // giống vòng quay thật, không cần file âm thanh.
    final sliceAngle = 2 * pi / _slices.length;
    final currentSlice = (_animation.value / sliceAngle).floor();
    if (currentSlice != _lastTickSlice) {
      _lastTickSlice = currentSlice;
      if (_controller.isAnimating) HapticFeedback.selectionClick();
    }
  }

  void _showResultDialog(_SpinSlice slice) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'result',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (dialogContext, anim, __, ___) {
        final scale = CurvedAnimation(parent: anim, curve: Curves.elasticOut);
        return Opacity(
          opacity: anim.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale.value,
            child: _ResultCard(
                slice: slice, onClose: () => Navigator.of(dialogContext).pop()),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<AuthProvider>().currentStudent;
    final alreadySpun = _spunToday(student?.lastSpinDate);

    return ScreenScaffold(bg: BgKind.lavender, 
      appBar: AppBar(title: const Text('Lucky Spin')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
                'Quay để nhận Coin — có cơ hội trúng Gem hoặc JACKPOT! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            SizedBox(
              width: 290,
              height: 290,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Vòng phát sáng phía sau bánh xe.
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.gold.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      _onTick();
                      return Transform.rotate(
                          angle: _animation.value, child: child);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        border: Border.all(color: Colors.white, width: 6),
                      ),
                      child: CustomPaint(
                        size: const Size(260, 260),
                        painter: _WheelPainter(_slices),
                      ),
                    ),
                  ),
                  // Tâm bánh xe.
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 6)
                      ],
                    ),
                    child: const Icon(Icons.star_rounded,
                        color: AppColors.gold, size: 26),
                  ),
                  // Kim chỉ hướng cố định ở vị trí "3 giờ" (bên phải), trỏ vào tâm.
                  const Positioned(
                    right: -6,
                    child: Icon(Icons.arrow_left,
                        size: 54, color: AppColors.danger),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (alreadySpun && !_isSpinning)
              Column(
                children: const [
                  Text('🌙 Hẹn gặp lại vào ngày mai nhé!',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary)),
                  SizedBox(height: 4),
                  Text(
                      'Mỗi ngày chỉ được quay 1 lượt để bạn tập trung học nữa nha.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              child: ElevatedButton(
                onPressed: (_isSpinning || alreadySpun) ? null : _spin,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      alreadySpun ? Colors.grey : AppColors.primary,
                ),
                child: Text(
                  _isSpinning
                      ? 'Đang quay...'
                      : (alreadySpun ? 'Đã quay hôm nay' : 'Quay ngay 🎡'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final _SpinSlice slice;
  final VoidCallback onClose;
  const _ResultCard({required this.slice, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(slice.isJackpot ? '🎉🏆🎉' : '✨🪙✨',
                  style: const TextStyle(fontSize: 42)),
              const SizedBox(height: 12),
              Text(
                slice.isJackpot ? 'JACKPOT!!!' : 'Chúc mừng!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color:
                      slice.isJackpot ? AppColors.gold : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: [
                  if (slice.coin > 0)
                    Text('🪙 +${slice.coin} Coin',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.success)),
                  if (slice.gem > 0)
                    Text('💎 +${slice.gem} Gem',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.info)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: onClose, child: const Text('Tuyệt vời!')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<_SpinSlice> slices;
  _WheelPainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sliceAngle = 2 * pi / slices.length;

    for (int i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final startAngle = i * sliceAngle;

      final paint = Paint()
        ..shader = LinearGradient(
          colors: [slice.color, slice.color.withValues(alpha: 0.72)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sliceAngle,
        true,
        paint,
      );

      // Viền phân cách giữa các ô cho rõ ràng.
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sliceAngle,
        true,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      final textAngle = startAngle + sliceAngle / 2;
      final textOffset = Offset(
        center.dx + radius * 0.62 * cos(textAngle),
        center.dy + radius * 0.62 * sin(textAngle),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: slice.isJackpot ? '👑\n${slice.label}' : slice.label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: slice.isJackpot ? 11 : 15,
            shadows: const [Shadow(color: Colors.black38, blurRadius: 3)],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas,
          textOffset - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
