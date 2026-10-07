import 'package:flutter/material.dart' hide Text;
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';
import '../models/pet_catalog.dart';
import '../providers/auth_provider.dart';
import '../providers/pet_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_image.dart';

/// Màn hình "mở hộp" — thay cho việc tự chọn thú cưng, hệ thống random
/// 1 trong 40 mẫu ngay sau khi đăng ký, kèm hiệu ứng hồi hộp trước khi
/// tiết lộ kết quả, tạo cảm giác hào hứng như rút thẻ.
class PetRevealScreen extends StatefulWidget {
  const PetRevealScreen({super.key});

  @override
  State<PetRevealScreen> createState() => _PetRevealScreenState();
}

class _PetRevealScreenState extends State<PetRevealScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  bool _isCreating = false;
  bool _revealed = false;
  PetTemplate? _resultTemplate;
  String? _newPetId;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _openBox() async {
    setState(() => _isCreating = true);

    final auth = context.read<AuthProvider>();
    final petProvider = context.read<PetProvider>();

    try {
      // Giữ animation "rung hộp" tối thiểu 1.5s để tạo cảm giác hồi hộp,
      // dù Firestore có thể trả về nhanh hơn. Chưa gán petId vào Student
      // ở bước này — chỉ gán sau khi người dùng bấm "Bắt đầu hành trình",
      // để tránh SplashScreen tự chuyển màn trước khi xem hiệu ứng reveal.
      final stopwatch = Stopwatch()..start();
      final newPet = await petProvider.createRandomPet(auth.currentStudent!.uid);
      final remaining = 1500 - stopwatch.elapsedMilliseconds;
      if (remaining > 0) {
        await Future.delayed(Duration(milliseconds: remaining));
      }

      if (!mounted) return;
      setState(() {
        _resultTemplate = newPet.template;
        _newPetId = newPet.id;
        _revealed = true;
        _isCreating = false;
      });
    } catch (e) {
      debugPrint('Lỗi tạo thú cưng: $e');
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tạo được thú cưng: $e')),
      );
    }
  }

  void _startJourney() {
    final auth = context.read<AuthProvider>();
    auth.currentStudent = auth.currentStudent?.copyWith(petId: _newPetId);
    auth.notifyListeners(); // SplashScreen sẽ tự chuyển sang PetHomeScreen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_revealed) ...[
                Text('Chào mừng bạn đến với PetMath!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Mở hộp bí ẩn để nhận thú cưng đầu tiên của bạn nhé!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 48),
                AnimatedBuilder(
                  animation: _shakeController,
                  builder: (context, child) {
                    final offset = _isCreating
                        ? (_shakeController.value * 16 - 8)
                        : 0.0;
                    return Transform.translate(
                      offset: Offset(offset, 0),
                      child: child,
                    );
                  },
                  child: GestureDetector(
                    onTap: _isCreating ? null : _openBox,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: AppColors.primary, width: 3),
                      ),
                      child: const Center(child: Text('🎁', style: TextStyle(fontSize: 80))),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _isCreating ? null : _openBox,
                  child: Text(_isCreating ? 'Đang mở hộp...' : 'Mở hộp ngay'),
                ),
              ] else ...[
                const Text('🎉', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text('Chúc mừng!',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) => Transform.scale(scale: value, child: child),
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 3),
                    ),
                    child: Center(child: PetImage(imageUrl: _resultTemplate!.imageUrl, emoji: _resultTemplate!.emoji, size: 72)),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Bạn đã nhận được',
                    style: const TextStyle(color: AppColors.textSecondary)),
                Text(_resultTemplate!.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _startJourney,
                  child: const Text('Bắt đầu hành trình!'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
