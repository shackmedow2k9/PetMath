import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';

import '../config/game_balance.dart';
import '../l10n/gen/app_localizations.dart';
import '../models/pet_family_catalog.dart';
import '../models/pet_model.dart';
import '../providers/auth_provider.dart';
import '../providers/pet_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/skin_rarity_style.dart';

/// Hộp mù Skin: [GameBalance.skinBoxPriceGem] Kim cương / lần mở.
///
/// Animation lấy cảm hứng từ màn "mở hộp nhận pet" lúc mới đăng ký
/// (PetRevealScreen): hộp rung → giữ tối thiểu 1,5 giây cho hồi hộp → kết quả
/// phóng to bằng đường cong elasticOut. Người chơi KHÔNG chọn được skin hay
/// độ hiếm — kết quả được random trong transaction ở FirestoreService.
class SkinBoxScreen extends StatefulWidget {
  const SkinBoxScreen({super.key});

  @override
  State<SkinBoxScreen> createState() => _SkinBoxScreenState();
}

class _SkinBoxScreenState extends State<SkinBoxScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake;
  bool _opening = false;
  SkinBoxResult? _result;

  @override
  void initState() {
    super.initState();
    // Chỉ chạy lặp KHI đang mở hộp (dừng ngay sau đó) — không có animation
    // vô hạn lúc rảnh.
    _shake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _open() async {
    // Khoá chống bấm đúp: chỉ 1 lần mở / 1 lần trừ tiền.
    if (_opening) return;
    final l = AppLocalizations.of(context)!;
    final auth = context.read<AuthProvider>();
    final pets = context.read<PetProvider>();
    final student = auth.currentStudent;
    if (student == null || pets.pet == null) return;

    // Không đủ Kim cương: không animation, không trừ, không âm.
    if (!student.hasEnoughGem(GameBalance.skinBoxPriceGem)) {
      _snack(l.skinBoxNotEnoughGems(GameBalance.skinBoxPriceGem));
      return;
    }

    setState(() {
      _opening = true;
      _result = null;
    });
    _shake.repeat(reverse: true);

    try {
      final stopwatch = Stopwatch()..start();
      final result = await pets.openSkinBox(student.uid);
      final remaining = 1500 - stopwatch.elapsedMilliseconds;
      if (remaining > 0) {
        await Future.delayed(Duration(milliseconds: remaining));
      }
      await auth.refreshCurrentStudent(); // cập nhật số Kim cương/Coin hiển thị
      if (!mounted) return;
      _shake.stop();
      setState(() {
        _result = result;
        _opening = false;
      });
    } on SkinBoxException catch (e) {
      if (!mounted) return;
      _shake.stop();
      setState(() => _opening = false);
      _snack(e.error == SkinBoxError.notEnoughGems
          ? l.skinBoxNotEnoughGems(GameBalance.skinBoxPriceGem)
          : l.skinBoxError);
    } catch (_) {
      if (!mounted) return;
      _shake.stop();
      setState(() => _opening = false);
      _snack(l.skinBoxError);
    }
  }

  Future<void> _equip(PetSkin skin) async {
    final l = AppLocalizations.of(context)!;
    final ok = await context.read<PetProvider>().equipSkin(skin.id);
    if (!mounted) return;
    if (!ok) _snack(l.equipFailed);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final student = context.watch<AuthProvider>().currentStudent;
    final pet = context.watch<PetProvider>().pet;

    return ScreenScaffold(bg: BgKind.lavender, 
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l.skinBoxTitle)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: _result == null
                      ? _buildBox(l, student?.gemDisplay ?? '0')
                      : _buildResult(l, pet, _result!),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBox(AppLocalizations l, String gemText) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GemChip(text: l.gemBalance(gemText)),
        const SizedBox(height: 12),
        Text(l.skinBoxSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 28),
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(_opening ? (_shake.value * 16 - 8) : 0, 0),
            child: child,
          ),
          child: GestureDetector(
            onTap: _opening ? null : _open,
            child: SizedBox(
              width: 180,
              height: 180,
              child: Image.asset('assets/ui/ic_mystery_box.png',
                  fit: BoxFit.contain),
            ),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _opening ? null : _open,
            child: Text(_opening
                ? l.skinBoxOpening
                : '${l.skinBoxOpen} · ${l.skinBoxPrice(GameBalance.skinBoxPriceGem)}'),
          ),
        ),
        const SizedBox(height: 24),
        _OddsCard(l: l),
      ],
    );
  }

  Widget _buildResult(AppLocalizations l, PetModel? pet, SkinBoxResult r) {
    final color = skinRarityColor(r.skin.rarity);
    final rarityText = skinRarityLabel(l, r.skin.rarity);
    final isEquipped = pet?.equippedSkin == r.skin.id;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.skinBoxGot(rarityText),
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 20),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (context, value, child) =>
              Transform.scale(scale: value, child: child),
          child: Container(
            width: 200,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color, width: 3),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 18)
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(PetArt.skinList(r.skin), fit: BoxFit.contain),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          Localizations.localeOf(context).languageCode == 'en'
              ? r.skin.nameEn
              : r.skin.nameVi,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        SkinRarityBadge(rarity: r.skin.rarity),
        const SizedBox(height: 8),
        Text(
          r.isDuplicate ? l.skinBoxDuplicate(r.coinRefund) : l.skinBoxNewSkin,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        if (!r.isDuplicate)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isEquipped ? null : () => _equip(r.skin),
              child: Text(isEquipped ? l.equipped : l.equip),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => setState(() => _result = null),
            child: Text('${l.skinBoxOpen} · ${l.skinBoxPrice(GameBalance.skinBoxPriceGem)}'),
          ),
        ),
      ],
    );
  }
}

class _GemChip extends StatelessWidget {
  final String text;
  const _GemChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/ui/ic_gem.png', width: 22, height: 22),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Bảng tỷ lệ rơi — đọc trực tiếp từ [GameBalance.skinRatePercent] nên luôn
/// khớp với tỷ lệ thật đang dùng để random.
class _OddsCard extends StatelessWidget {
  final AppLocalizations l;
  const _OddsCard({required this.l});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.skinBoxOdds,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final r in SkinRarity.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: skinRarityColor(r), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(skinRarityLabel(l, r))),
                  Text('${GameBalance.skinRatePercent[r] ?? 0}%',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
