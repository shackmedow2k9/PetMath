import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/pet_model.dart';
import '../models/pet_catalog.dart';
import '../services/firestore_service.dart';

class PetProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final Random _random = Random();
  StreamSubscription<PetModel?>? _subscription;

  PetModel? pet;
  bool isLoading = false;

  /// Bốc túi mù: chọn ngẫu nhiên 1 trong 10 loài pet
  PetSpecies rollRandomSpecies() {
    return PetSpecies.values[_random.nextInt(PetSpecies.values.length)];
  }

  void watchPet(String petId) {
    isLoading = true;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _firestoreService.watchPet(petId).listen((updatedPet) {
      pet = updatedPet;
      isLoading = false;
      notifyListeners();
    });
  }

  /// Đọc lại pet, áp dụng trừ hao theo thời gian và phát thông báo để UI
  /// cập nhật ngay; không tạo thêm StreamSubscription.
  Future<void> refreshPetNow() async {
    final current = pet;
    if (current == null) return;
    final updated = await _firestoreService.getPetWithDecay(current.id);
    if (updated != null) {
      pet = updated;
      notifyListeners();
    }
  }

  /// Gọi sau khi học sinh làm bài đúng — cộng EXP và cập nhật UI ngay lập tức.
  Future<void> rewardExpForCorrectAnswers(int correctCount) async {
    if (pet == null) return;
    // Mỗi câu đúng = xem FirestoreService.xpPerCorrectAnswer.
    final expGained = correctCount * FirestoreService.xpPerCorrectAnswer;
    await _firestoreService.rewardExp(pet!.id, expGained,
        energyGain: correctCount * 3);
  }

  Future<RandomPetCreationResult> createRandomPet(String ownerId) async {
    final species = rollRandomSpecies();
    final template = PetCatalog.forSpecies(species);
    final created = await createPet(
      ownerId: ownerId,
      species: species,
      name: template.name,
    );
    return RandomPetCreationResult(id: created.id, template: template);
  }

  Future<PetModel> createPet({
    required String ownerId,
    required PetSpecies species,
    required String name,
  }) async {
    final newPet = await _firestoreService.createPet(
      ownerId: ownerId,
      species: species,
      name: name,
    );
    pet = newPet;
    watchPet(newPet.id);
    return newPet;
  }

  /// Vuốt ve pet (chạm trực tiếp vào pet ở Nhà pet). Trả về false nếu đã
  /// hết lượt cộng Vui vẻ hôm nay — UI vẫn tự chạy animation vui mắt ở
  /// trường hợp này, chỉ khác là không cộng thêm chỉ số. Không cần tự
  /// notifyListeners() ở đây vì [watchPet] đang lắng nghe stream Firestore
  /// sẽ tự cập nhật [pet] ngay khi ghi xong.
  // Chống cộng Thân thiết nhiều lần cho 1 lần chạm: bỏ qua chạm khi lệnh
  // ghi trước còn đang chạy HOẶC chạm quá sát nhau (double-tap / rebuild).
  bool _patInFlight = false;
  DateTime _lastPatAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _minPatGap = Duration(milliseconds: 600);

  Future<bool> patPet() async {
    if (pet == null) return false;
    final now = DateTime.now();
    if (_patInFlight || now.difference(_lastPatAt) < _minPatGap) return false;
    _patInFlight = true;
    _lastPatAt = now;
    try {
      return await _firestoreService.patPet(pet!.id);
    } catch (_) {
      return false;
    } finally {
      _patInFlight = false;
    }
  }

  /// Hộp mù Skin / trang bị skin — UI gọi qua provider để dùng chung service.
  Future<SkinBoxResult> openSkinBox(String studentId) {
    final current = pet;
    if (current == null) {
      return Future.error(const SkinBoxException(SkinBoxError.missingData));
    }
    return _firestoreService.openSkinBox(studentId: studentId, petId: current.id);
  }

  Future<bool> equipSkin(String skinId) async {
    final current = pet;
    if (current == null) return false;
    return _firestoreService.equipSkin(current.id, skinId);
  }

  /// Trả true nếu popup mở khoá cho [level] chưa từng được hiện.
  Future<bool> claimCelebration(int level) async {
    final current = pet;
    if (current == null) return false;
    try {
      return await _firestoreService.markFriendshipCelebrated(current.id, level);
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class RandomPetCreationResult {
  final String id;
  final PetTemplate template;

  const RandomPetCreationResult({required this.id, required this.template});
}
