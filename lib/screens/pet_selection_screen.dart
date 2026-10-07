import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart' hide Text;
import '../l10n/tr.dart';
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';
import '../models/pet_model.dart';
import '../providers/auth_provider.dart';
import '../providers/pet_provider.dart';
import '../theme/app_theme.dart';

/// Màn hình "Bốc Túi Mù" — bước đầu tiên sau khi đăng ký.
/// KHÔNG cho học sinh tự chọn loài pet: hệ thống tự động bốc ngẫu nhiên
/// 1 trong 40 loài, giống cơ chế túi mù (blind box / gacha).
class PetSelectionScreen extends StatefulWidget {
  const PetSelectionScreen({super.key});

  @override
  State<PetSelectionScreen> createState() => _PetSelectionScreenState();
}

enum _Stage { intro, shaking, revealed }

class _PetSelectionScreenState extends State<PetSelectionScreen>
    with SingleTickerProviderStateMixin {
  _Stage _stage = _Stage.intro;
  PetSpecies? _rolled;
  final _nameController = TextEditingController();
  bool _isCreating = false;

  late final AnimationController _shakeController;
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 800));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _confettiController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _openBlindBox() async {
    final petProvider = context.read<PetProvider>();
    setState(() => _stage = _Stage.shaking);

    await _shakeController.repeat(reverse: true).timeout(
          const Duration(milliseconds: 1200),
          onTimeout: () {},
        );
    _shakeController.stop();

    final species = petProvider.rollRandomSpecies();
    if (!mounted) return;
    setState(() {
      _rolled = species;
      _stage = _Stage.revealed;
    });
    _confettiController.play();
  }

  Future<void> _confirmSelection() async {
    if (_rolled == null) return;
    final name = _nameController.text.trim().isEmpty
        ? _rolled!.displayName
        : _nameController.text.trim();

    setState(() => _isCreating = true);
    final auth = context.read<AuthProvider>();
    final petProvider = context.read<PetProvider>();

    try {
      await petProvider.createPet(
        ownerId: auth.currentStudent!.uid,
        species: _rolled!,
        name: name,
      );
      // AuthProvider sẽ tự refresh currentStudent ở lần đăng nhập tiếp theo;
      // cập nhật cục bộ ngay để điều hướng mượt mà.
      auth.currentStudent =
          auth.currentStudent?.copyWith(petId: petProvider.pet!.id);
      auth.notifyListeners();
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    _stage == _Stage.revealed
                        ? 'Chúc mừng bạn!'
                        : 'Bốc Túi Mù Thú Cưng',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _stage == _Stage.revealed
                        ? 'Đây là người bạn đồng hành mới của bạn!'
                        : 'Chạm vào túi mù để nhận thú cưng của bạn',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 40),
                  Expanded(
                    child: Center(
                      child: switch (_stage) {
                        _Stage.intro =>
                          _BlindBox(onTap: _openBlindBox, shaking: false),
                        _Stage.shaking => AnimatedBuilder(
                            animation: _shakeController,
                            builder: (context, child) {
                              final angle =
                                  sin(_shakeController.value * pi * 8) * 0.12;
                              return Transform.rotate(
                                  angle: angle, child: child);
                            },
                            child: const _BlindBox(onTap: null, shaking: true),
                          ),
                        _Stage.revealed => _RevealedPet(species: _rolled!),
                      },
                    ),
                  ),
                  if (_stage == _Stage.revealed) ...[
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText:
                            tr('Đặt tên cho ${_rolled!.displayName.toLowerCase()}'),
                        prefixIcon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isCreating ? null : _confirmSelection,
                      child: _isCreating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Xác nhận'),
                    ),
                  ],
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                numberOfParticles: 24,
                gravity: 0.3,
                colors: const [
                  AppColors.primary,
                  AppColors.secondary,
                  AppColors.gold,
                  AppColors.success,
                  AppColors.info,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlindBox extends StatelessWidget {
  final VoidCallback? onTap;
  final bool shaking;
  const _BlindBox({required this.onTap, required this.shaking});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎁', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 12),
            Text(
              shaking ? 'Đang mở...' : 'Chạm để mở',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevealedPet extends StatelessWidget {
  final PetSpecies species;
  const _RevealedPet({required this.species});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 180,
            height: 180,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 3),
            ),
            child: Image.asset(species.assetPath, fit: BoxFit.contain),
          ),
          const SizedBox(height: 16),
          Text(
            species.displayName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ],
      ),
    );
  }
}
