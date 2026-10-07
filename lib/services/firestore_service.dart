import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import '../config/game_balance.dart';
import '../models/friendship_level.dart';
import '../models/pet_family_catalog.dart';
import '../models/pet_model.dart';
import 'skin_box_roller.dart';
import '../models/student_model.dart';
import '../models/achievement_catalog.dart';
import '../models/teacher_model.dart';
import '../models/question_model.dart';
import '../models/exam_result_model.dart';
import '../models/math_progress_model.dart';
import '../models/class_model.dart';
import '../models/assignment_model.dart';
import '../models/exam_template_model.dart';
import '../models/exam_composition_model.dart';
import '../models/crop_catalog.dart';
import '../models/farm_plot_model.dart';

/// Xử lý toàn bộ logic dữ liệu: pet, streak, coin, thành tích.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------- PET ----------

  /// Tạo (nếu chưa có) 1 "hồ sơ pet" cho Giáo viên, dùng CHUNG cấu trúc dữ
  /// liệu với `students/{uid}` (coin, gem, petId, foodInventory...) — nhờ
  /// vậy tái dùng được NGUYÊN VẸN toàn bộ Nhà pet/Cửa hàng/Minigame/BXH đã
  /// xây cho học sinh mà không phải viết lại 1 hệ thống song song.
  ///
  /// AN TOÀN: document id trùng UID của giáo viên nhưng nằm ở collection
  /// `students` (khác hẳn `teachers/{uid}` chứa tài khoản thật) — không
  /// làm giáo viên bị nhận nhầm thành học sinh, vì [AuthService.getUserRole]
  /// luôn kiểm tra collection 'teachers' TRƯỚC 'students'.
  Future<StudentModel> ensureTeacherPetProfile(TeacherModel teacher) async {
    final ref = _db.collection('students').doc(teacher.uid);
    final doc = await ref.get();
    if (doc.exists) {
      return StudentModel.fromMap(teacher.uid, doc.data()!);
    }
    final profile = StudentModel(
      uid: teacher.uid,
      fullName: teacher.fullName,
      email: teacher.email,
      createdAt: DateTime.now(),
      provinceCode: teacher.provinceCode,
      provinceName: teacher.provinceName,
      wardCode: teacher.wardCode,
      wardName: teacher.wardName,
      schoolName: teacher.schoolName,
    );
    await ref.set(profile.toMap());
    return profile;
  }

  Future<PetModel> createPet({
    required String ownerId,
    required PetSpecies species,
    required String name,
  }) async {
    final docRef = _db.collection('pets').doc();
    final pet = PetModel(
      id: docRef.id,
      ownerId: ownerId,
      species: species,
      name: name,
      lastFedAt: DateTime.now(),
    );
    await docRef.set(pet.toMap());
    await _db.collection('students').doc(ownerId).update({
      'petId': docRef.id,
      // Mọi pet mới đều bắt đầu ở cấp 1 — ghi mốc thời gian này để tie-break
      // BXH (ai lên cấp 1, tức tạo pet, trước thì hạng cao hơn nếu hoà cấp).
      'petLevel': pet.level,
      'petLevelUpAt': Timestamp.now(),
    });
    return pet;
  }

  // ---------- TRỪ HAO THEO THỜI GIAN THỰC (offline decay) ----------
  //
  // Trước đây No bụng/Sạch sẽ/Năng lượng CHỈ giảm khi có 1 hành động cụ
  // thể xảy ra (làm bài, hoặc Timer 18s chạy trong màn Nhà pet) — nghĩa
  // là pet coi như "đóng băng" hoàn toàn khi học sinh không mở app. Giờ
  // mọi pet đều có mốc [PetModel.lastDecayAt]; mỗi khi đọc lại pet (qua
  // [watchPet] hoặc trước khi ghi 1 thay đổi khác), ta tính xem đã trôi
  // qua bao nhiêu thời gian THỰC kể từ mốc đó rồi trừ hao tương ứng —
  // nhờ vậy dù học sinh đóng app cả ngày, lần mở lại tiếp theo (ở BẤT KỲ
  // màn hình nào, không riêng Nhà pet) vẫn thấy đúng pet đói/dơ/mệt như
  // thể thời gian vẫn trôi liên tục.
  // Các mốc tính theo thời gian thực để đồng bộ với chu kỳ 1 ngày game = 15 phút.
  // Như vậy chỉ số thay đổi ngay trong một ngày game, không cần chờ hàng giờ.
  static const int hungerDecaySeconds = 90; // -1 No bụng / 90 giây thực
  static const int hygieneDecaySeconds = 120; // -1 Sạch sẽ / 120 giây thực
  static const int energyDecaySeconds = 150; // -1 Năng lượng / 150 giây thực
  static const int playfulnessDecaySeconds = 90; // -1 hứng thú / 90 giây thực
  static const int toiletNeedIncreaseSeconds = 75; // +1 nhu cầu / 75 giây thực

  /// Hàm THUẦN (không ghi Firestore) — tính lại pet sau khi trừ hao theo
  /// thời gian thực đã trôi qua kể từ [PetModel.lastDecayAt]. Trả về
  /// nguyên [pet] nếu chưa đủ 1 phút hoặc chưa đủ 1 "nấc" trừ nào, để nơi
  /// gọi biết có cần ghi lại Firestore hay không (so sánh giá trị trả về
  /// với [pet] gốc).
  PetModel applyTimeDecay(PetModel pet, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final elapsedSeconds = current.difference(pet.lastDecayAt).inSeconds;
    if (elapsedSeconds < 1) return pet;

    final hungerLoss = elapsedSeconds ~/ hungerDecaySeconds;
    final hygieneLoss = elapsedSeconds ~/ hygieneDecaySeconds;
    final energyLoss = elapsedSeconds ~/ energyDecaySeconds;
    final playfulnessLoss = elapsedSeconds ~/ playfulnessDecaySeconds;
    final toiletIncrease = elapsedSeconds ~/ toiletNeedIncreaseSeconds;
    if (hungerLoss == 0 &&
        hygieneLoss == 0 &&
        energyLoss == 0 &&
        playfulnessLoss == 0 &&
        toiletIncrease == 0) return pet;

    final newHygiene = pet.hygiene - hygieneLoss;
    final newPlayfulness = pet.playfulness - playfulnessLoss;
    final conditionPenalty =
        (newHygiene < 55 ? 1 : 0) + (newPlayfulness < 55 ? 1 : 0);
    final naturalHappinessLoss = elapsedSeconds ~/ 180;
    return pet.copyWith(
      hunger: pet.hunger - hungerLoss,
      hygiene: newHygiene,
      energy: pet.energy - energyLoss,
      playfulness: newPlayfulness,
      toiletNeed: pet.toiletNeed + toiletIncrease,
      // Vui vẻ giảm chậm tự nhiên, và giảm thêm khi pet bẩn/không muốn chơi.
      happiness: pet.happiness - naturalHappinessLoss - conditionPenalty,
      lastDecayAt: current,
    );
  }

  /// true nếu [applyTimeDecay] đã thực sự làm thay đổi ít nhất 1 chỉ số
  /// (dùng để quyết định có cần ghi lại Firestore hay không).
  bool _decayChanged(PetModel original, PetModel decayed) =>
      decayed.hunger != original.hunger ||
      decayed.hygiene != original.hygiene ||
      decayed.energy != original.energy ||
      decayed.playfulness != original.playfulness ||
      decayed.toiletNeed != original.toiletNeed ||
      decayed.happiness != original.happiness;

  Future<PetModel?> getPetWithDecay(String petId) async {
    final doc = await _db.collection('pets').doc(petId).get();
    if (!doc.exists || doc.data() == null) return null;
    final original = PetModel.fromMap(doc.id, doc.data()!);
    final decayed = applyTimeDecay(original);
    if (_decayChanged(original, decayed)) {
      await _db.collection('pets').doc(petId).update({
        'hunger': decayed.hunger,
        'hygiene': decayed.hygiene,
        'energy': decayed.energy,
        'playfulness': decayed.playfulness,
        'toiletNeed': decayed.toiletNeed,
        'happiness': decayed.happiness,
        'lastDecayAt': Timestamp.fromDate(decayed.lastDecayAt),
      });
    }
    return decayed;
  }

  Stream<PetModel?> watchPet(String petId) {
    return _db.collection('pets').doc(petId).snapshots().map((doc) {
      if (!doc.exists) return null;
      final pet = PetModel.fromMap(doc.id, doc.data()!);
      final decayed = applyTimeDecay(pet);
      if (_decayChanged(pet, decayed)) {
        // Ghi nền, không await — không được chặn Stream vì UI đang chờ
        // dữ liệu hiển thị ngay; lần snapshot kế tiếp (do chính lệnh ghi
        // này kích hoạt) sẽ có lastDecayAt mới nên không lặp vô hạn.
        _db.collection('pets').doc(petId).update({
          'hunger': decayed.hunger,
          'hygiene': decayed.hygiene,
          'energy': decayed.energy,
          'playfulness': decayed.playfulness,
          'toiletNeed': decayed.toiletNeed,
          'happiness': decayed.happiness,
          'lastDecayAt': Timestamp.fromDate(decayed.lastDecayAt),
        }).catchError((_) {});
      }
      return decayed;
    });
  }

  /// Ghi lại petLevel/petLevelUpAt lên document student mỗi khi pet lên cấp
  /// — dùng chung cho mọi chỗ có thể làm pet lên cấp (ăn/ngủ/làm bài đúng...)
  /// để bảng xếp hạng theo cấp độ pet luôn khớp dữ liệu thật.
  Future<void> _syncPetLevelToOwner(PetModel oldPet, PetModel updatedPet) {
    if (updatedPet.level == oldPet.level) return Future.value();
    return _db.collection('students').doc(updatedPet.ownerId).update({
      'petLevel': updatedPet.level,
      'petLevelUpAt': Timestamp.now(),
    });
  }

  /// Gọi khi học sinh làm đúng bài tập.
  /// [energyGain]: Năng lượng hồi thêm cho pet — TÁCH RIÊNG khỏi [expAmount]
  /// (không suy ra theo tỷ lệ cố định từ EXP nữa) vì lượng EXP mỗi câu đúng
  /// có thể thay đổi theo thời gian (hiện tại: 1000 EXP/câu — xem
  /// [FirestoreService.xpPerCorrectAnswer]) trong khi Năng lượng vẫn nên
  /// tăng theo ĐÚNG SỐ CÂU đã làm, không theo số EXP tuyệt đối. Nếu không
  /// truyền, mặc định hồi 3 Năng lượng (tương đương lối tính cũ khi 1 câu
  /// đúng = 10 EXP).
  Future<PetModel> rewardExp(String petId, int expAmount,
      {int energyGain = 3}) async {
    final doc = await _db.collection('pets').doc(petId).get();
    final pet = applyTimeDecay(PetModel.fromMap(petId, doc.data()!));
    final updated = pet.addExp(pet.friendship.boostExp(expAmount)).copyWith(
          happiness: pet.happiness + 5,
          hunger: pet.hunger - 5,
          energy: pet.energy + energyGain,
        );
    await _db.collection('pets').doc(petId).update(updated.toMap());
    await _syncPetLevelToOwner(pet, updated);
    return updated;
  }

  /// Cho pet ăn — tốn Coin mua đồ ăn, hồi No bụng & Vui vẻ, cộng EXP.
  /// LƯU Ý: EXP được cộng NGAY TRONG transaction này (không gọi [rewardExp]
  /// riêng sau đó) để tránh race-condition: nếu gọi 2 lệnh ghi Firestore
  /// tách rời, lệnh thứ 2 (rewardExp) có thể đọc phải dữ liệu pet CŨ (do
  /// đọc lệch nhịp với transaction feedPet) rồi ghi đè lại đúng lúc,
  /// làm mất luôn phần "No bụng" vừa được cộng — đây chính là lý do
  /// trước đây độ no có vẻ "không tăng" sau khi cho ăn.
  static const int feedCostCoin = 15;
  static const int feedExpReward = 15;

  Future<void> feedPet(
      {required String studentId, required String petId}) async {
    await _db.runTransaction((tx) async {
      final studentRef = _db.collection('students').doc(studentId);
      final petRef = _db.collection('pets').doc(petId);
      final studentDoc = await tx.get(studentRef);
      final petDoc = await tx.get(petRef);

      final currentCoin = studentDoc.data()?['coin'] ?? 0;
      final coinInfinite = studentDoc.data()?['coinInfinite'] ?? false;
      if (!coinInfinite && currentCoin < feedCostCoin) {
        throw Exception('Không đủ Coin để mua đồ ăn cho pet');
      }

      final pet = applyTimeDecay(PetModel.fromMap(petId, petDoc.data()!));
      final updated = pet.addExp(pet.friendship.boostExp(feedExpReward)).copyWith(
            hunger: pet.hunger + 25,
            happiness: pet.happiness + 5,
          );

      tx.update(studentRef, {
        if (!coinInfinite) 'coin': currentCoin - feedCostCoin,
        if (updated.level != pet.level) 'petLevel': updated.level,
        if (updated.level != pet.level) 'petLevelUpAt': Timestamp.now(),
      });
      tx.update(petRef, updated.toMap());
    });
  }

  /// Mua 1 phần đồ ăn ở Cửa hàng — cộng vào foodInventory (kho đồ ăn) của
  /// học sinh, dùng transaction để tránh mua vượt quá số Coin đang có.
  Future<void> buyFood(String studentId, String foodId, int priceCoin) async {
    await _db.runTransaction((tx) async {
      final ref = _db.collection('students').doc(studentId);
      final doc = await tx.get(ref);
      final currentCoin = (doc.data()?['coin'] ?? 0) as int;
      final coinInfinite = doc.data()?['coinInfinite'] ?? false;
      if (!coinInfinite && currentCoin < priceCoin) {
        throw Exception('Không đủ Coin để mua món này (cần $priceCoin Coin)');
      }
      tx.update(ref, {
        if (!coinInfinite) 'coin': currentCoin - priceCoin,
        'foodInventory.$foodId': FieldValue.increment(1),
      });
    });
  }

  /// Cho pet ăn 1 món cụ thể đã mua (kéo thả trong Phòng ăn) — tiêu 1 phần
  /// trong kho đồ ăn, hồi No bụng theo đúng giá trị của món đó, cộng EXP.
  /// Trả về false nếu học sinh không còn món này trong kho (VD: bấm 2 lần
  /// liên tiếp trước khi UI kịp cập nhật).
  Future<bool> feedPetWithFood({
    required String studentId,
    required String petId,
    required String foodId,
    required int hungerRestore,
    required int expReward,
  }) async {
    return _db.runTransaction<bool>((tx) async {
      final studentRef = _db.collection('students').doc(studentId);
      final petRef = _db.collection('pets').doc(petId);
      final studentDoc = await tx.get(studentRef);
      final petDoc = await tx.get(petRef);

      final foodInventory =
          Map<String, dynamic>.from(studentDoc.data()?['foodInventory'] ?? {});
      final owned = (foodInventory[foodId] ?? 0) as int;
      if (owned < 1) return false;

      final pet = applyTimeDecay(PetModel.fromMap(petId, petDoc.data()!));
      final updated = pet.addExp(pet.friendship.boostExp(expReward)).copyWith(
            hunger: pet.hunger + hungerRestore,
            happiness: pet.happiness + 5,
          );

      tx.update(
          studentRef, {'foodInventory.$foodId': FieldValue.increment(-1)});
      tx.update(petRef, updated.toMap());
      return true;
    });
  }

  /// Chơi với pet — hồi hứng thú chơi và Vui vẻ, đồng thời tiêu hao nhẹ
  /// Năng lượng để hành động có cảm giác thật hơn.
  Future<void> playWithPet(String petId) async {
    final doc = await _db.collection('pets').doc(petId).get();
    final pet = applyTimeDecay(PetModel.fromMap(petId, doc.data()!));
    final updated = pet.copyWith(
      playfulness: pet.playfulness + 30,
      happiness: pet.happiness + 18,
      energy: pet.energy - 5,
      hp: pet.hp + 2,
    );
    await _db.collection('pets').doc(petId).update(updated.toMap());
  }

  /// Hoạt động cùng pet (học, nhảy, tập thể dục, hát, chụp ảnh, thư giãn — xem
  /// PetActivityCatalog): cộng/trừ chỉ số theo định nghĩa hoạt động; EXP đi qua
  /// hệ số bonus theo cấp pet như mọi nguồn EXP khác.
  Future<void> petActivity(
    String petId, {
    int hunger = 0,
    int energy = 0,
    int happiness = 0,
    int hp = 0,
    int exp = 0,
  }) async {
    final doc = await _db.collection('pets').doc(petId).get();
    final data = doc.data();
    if (data == null) return;
    final pet = applyTimeDecay(PetModel.fromMap(petId, data));
    var updated = pet.copyWith(
      hunger: pet.hunger + hunger,
      energy: pet.energy + energy,
      happiness: pet.happiness + happiness,
      hp: pet.hp + hp,
    );
    if (exp > 0) updated = updated.addExp(updated.friendship.boostExp(exp));
    await _db.collection('pets').doc(petId).update(updated.toMap());
  }

  /// Đi vệ sinh — đưa nhu cầu về 0 và hồi một chút Vui vẻ.
  Future<void> useToilet(String petId) async {
    final doc = await _db.collection('pets').doc(petId).get();
    final pet = applyTimeDecay(PetModel.fromMap(petId, doc.data()!));
    final updated = pet.copyWith(
      toiletNeed: 0,
      happiness: pet.happiness + 6,
      energy: pet.energy - 2,
    );
    await _db.collection('pets').doc(petId).update(updated.toMap());
  }

  /// Tắm rửa cho pet — miễn phí, hồi Vui vẻ & HP, tốn một ít Năng lượng.
  Future<void> bathePet(String petId) async {
    final doc = await _db.collection('pets').doc(petId).get();
    final pet = applyTimeDecay(PetModel.fromMap(petId, doc.data()!));
    final updated = pet.copyWith(
      happiness: pet.happiness + 20,
      hp: pet.hp + 10,
      energy: pet.energy - 10,
      hygiene: 100, // tắm xong sạch hoàn toàn
    );
    await _db.collection('pets').doc(petId).update(updated.toMap());
  }

  /// Độ sạch giảm dần theo thời gian (gọi định kỳ khi đang ở trong Nhà
  /// pet) — khi pet dơ (hygiene thấp), Vui vẻ cũng giảm theo.
  Future<int> adjustPetHygiene(String petId, int delta) async {
    final doc = await _db.collection('pets').doc(petId).get();
    final pet = applyTimeDecay(PetModel.fromMap(petId, doc.data()!));
    final updated = pet.copyWith(hygiene: pet.hygiene + delta);
    await _db.collection('pets').doc(petId).update({
      'hygiene': updated.hygiene,
      'hunger': updated.hunger,
      'energy': updated.energy,
      'playfulness': updated.playfulness,
      'toiletNeed': updated.toiletNeed,
      'happiness': updated.happiness,
      'lastDecayAt': Timestamp.fromDate(updated.lastDecayAt),
    });
    return updated.hygiene;
  }

  Future<void> adjustPetHappiness(String petId, int delta) async {
    final doc = await _db.collection('pets').doc(petId).get();
    final pet = PetModel.fromMap(petId, doc.data()!);
    final updated = pet.copyWith(happiness: pet.happiness + delta);
    await _db
        .collection('pets')
        .doc(petId)
        .update({'happiness': updated.happiness});
  }

  /// Số lượt vuốt ve tối đa/ngày được cộng Vui vẻ — giống giới hạn "điểm
  /// thân thiết" mỗi ngày của Linh Bảo trong Liên Quân Mobile: chạm thêm
  /// vẫn có hiệu ứng vui mắt ở UI, chỉ không cộng thêm chỉ số nữa.
  static const int maxPetInteractionsPerDay = GameBalance.maxPetTapsPerDay;
  static const int petInteractionHappinessGain = 2;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Vuốt ve pet (chạm trực tiếp vào pet ở Nhà pet). Trả về true nếu vẫn
  /// còn lượt trong ngày (đã cộng Vui vẻ), false nếu đã dùng hết lượt hôm
  /// nay — UI vẫn có thể chạy animation vui mắt ở trường hợp false, chỉ
  /// là không cộng thêm chỉ số.
  Future<bool> patPet(String petId) async {
    final doc = await _db.collection('pets').doc(petId).get();
    final pet = applyTimeDecay(PetModel.fromMap(petId, doc.data()!));
    final now = DateTime.now();
    final isNewDay = pet.lastPetInteractionAt == null ||
        !_isSameDay(pet.lastPetInteractionAt!, now);
    final countToday = isNewDay ? 0 : pet.petInteractionsToday;

    if (countToday >= maxPetInteractionsPerDay) {
      // Vẫn lưu lại kết quả trừ hao theo thời gian (applyTimeDecay) để
      // không mất đồng bộ, nhưng không cộng thêm Vui vẻ/lượt nữa.
      await _db.collection('pets').doc(petId).update(pet.toMap());
      return false;
    }

    final updated = pet.copyWith(
      happiness: pet.happiness + petInteractionHappinessGain,
      petInteractionsToday: countToday + 1,
      lastPetInteractionAt: now,
    );
    await _db.collection('pets').doc(petId).update(updated.toMap());
    // 1 lần vuốt ve hợp lệ = đúng 1 lần cộng Thân thiết (xem addPetAffection).
    await addPetAffection(petId, petInteractionAffectionGain);
    return true;
  }

  // Điểm Thân thiết cộng mỗi lần hoàn thành 1 hành động chăm sóc — hành
  // động càng tốn công (tắm phải chà xà phòng + xịt nước) thì cộng càng
  // nhiều, giống cách Linh Bảo Liên Quân thưởng điểm thân thiết.
  // PetMath: MỌI tương tác hợp lệ đều cộng cùng 1 mức
  // ([GameBalance.friendshipPerInteraction] = 2000) — chỉnh trong config.
  static const int petInteractionAffectionGain =
      GameBalance.friendshipPerInteraction;
  static const int feedAffectionGain = GameBalance.friendshipPerInteraction;
  static const int batheAffectionGain = GameBalance.friendshipPerInteraction;
  static const int playAffectionGain = GameBalance.friendshipPerInteraction;
  static const int sleepAffectionGain = GameBalance.friendshipPerInteraction;

  /// Cộng điểm Thân thiết cho pet — gọi sau khi 1 hành động chăm sóc
  /// (cho ăn/tắm/chơi/ngủ) hoàn tất thành công. Điểm Thân thiết KHÔNG bị
  /// giới hạn theo ngày (khác Vui vẻ từ vuốt ve) — tích luỹ mãi để mở
  /// khoá các mốc trong [kSpeciesSkins].
  Future<void> addPetAffection(String petId, int points) async {
    if (points <= 0) return;
    await _db.runTransaction((tx) async {
      final petRef = _db.collection('pets').doc(petId);
      final petDoc = await tx.get(petRef);
      final data = petDoc.data();
      if (data == null) return;
      final before = FriendshipInfo.fromPoints(
          ((data['affectionPoints'] ?? 0) as num).toInt());
      final after = FriendshipInfo.fromPoints(before.points + points);
      tx.update(petRef, {'affectionPoints': after.points});
      // Mức V trở lên: cho phép profile hiện trên bảng xếp hạng. Ghi lại mỗi
      // lần (idempotent) để tự sửa nếu cờ bị lệch.
      final ownerId = data['ownerId'] as String?;
      if (after.canShowOnLeaderboard && ownerId != null && ownerId.isNotEmpty) {
        tx.update(_db.collection('students').doc(ownerId),
            {'showOnLeaderboard': true});
      }
    });
  }

  /// Đánh dấu đã ăn mừng (popup mở khoá) tới mức [level]. Transaction + chỉ
  /// tăng, nên dù nhiều màn hình cùng gọi thì mỗi mốc chỉ ăn mừng 1 lần.
  /// Trả về true nếu LẦN GỌI NÀY là lần đầu ghi nhận (được phép hiện popup).
  Future<bool> markFriendshipCelebrated(String petId, int level) {
    return _db.runTransaction<bool>((tx) async {
      final ref = _db.collection('pets').doc(petId);
      final doc = await tx.get(ref);
      final current =
          ((doc.data()?['celebratedFriendshipLevel'] ?? 0) as num).toInt();
      if (level <= current) return false;
      tx.update(ref, {'celebratedFriendshipLevel': level});
      return true;
    });
  }

  // ---------- HỘP MÙ SKIN ----------

  final SkinBoxRoller _skinBoxRoller = SkinBoxRoller();

  /// Mở 1 Hộp mù Skin. TOÀN BỘ trong 1 transaction: kiểm tra đủ Kim cương →
  /// trừ đúng [GameBalance.skinBoxPriceGem] → random có trọng số → lưu skin
  /// (hoặc đền Coin nếu trùng). Không đủ Kim cương thì ném [SkinBoxException]
  /// TRƯỚC khi đổi bất kỳ dữ liệu nào (không trừ, không âm). Người chơi
  /// không có cách nào chọn/can thiệp kết quả.
  Future<SkinBoxResult> openSkinBox({
    required String studentId,
    required String petId,
  }) {
    return _db.runTransaction<SkinBoxResult>((tx) async {
      final studentRef = _db.collection('students').doc(studentId);
      final petRef = _db.collection('pets').doc(petId);
      final studentDoc = await tx.get(studentRef);
      final petDoc = await tx.get(petRef);
      final sData = studentDoc.data();
      final pData = petDoc.data();
      if (sData == null || pData == null) {
        throw const SkinBoxException(SkinBoxError.missingData);
      }
      final gem = ((sData['gem'] ?? 0) as num).toInt();
      final gemInfinite = (sData['gemInfinite'] ?? false) as bool;
      const price = GameBalance.skinBoxPriceGem;
      if (!gemInfinite && gem < price) {
        throw const SkinBoxException(SkinBoxError.notEnoughGems);
      }

      final pet = PetModel.fromMap(petId, pData);
      final family = PetFamilyCatalog.familyOf(pet.species);
      final skin = _skinBoxRoller.rollSkin(family);
      final isDuplicate = pet.unlockedSkins.contains(skin.id);
      final refund = isDuplicate
          ? (GameBalance.duplicateSkinCoinReward[skin.rarity] ?? 0)
          : 0;

      tx.update(studentRef, {
        if (!gemInfinite) 'gem': gem - price,
        if (refund > 0) 'coin': FieldValue.increment(refund),
      });
      if (!isDuplicate) {
        tx.update(petRef, {
          'unlockedSkins': FieldValue.arrayUnion([skin.id]),
        });
      }
      return SkinBoxResult(
          skin: skin, isDuplicate: isDuplicate, coinRefund: refund);
    });
  }

  /// Trang bị skin ([skinId] rỗng = tháo skin). Chỉ cho phép skin ĐÃ SỞ HỮU
  /// và đúng họ pet; id lỗi bị từ chối (trả false), không crash.
  Future<bool> equipSkin(String petId, String skinId) {
    return _db.runTransaction<bool>((tx) async {
      final ref = _db.collection('pets').doc(petId);
      final doc = await tx.get(ref);
      if (!doc.exists) return false;
      if (skinId.isEmpty) {
        tx.update(ref, {'equippedSkin': ''});
        return true;
      }
      final pet = PetModel.fromMap(petId, doc.data()!);
      final skin = PetFamilyCatalog.skinById(skinId);
      if (skin == null ||
          skin.family != PetFamilyCatalog.familyOf(pet.species) ||
          !pet.unlockedSkins.contains(skinId)) {
        return false;
      }
      tx.update(ref, {'equippedSkin': skinId});
      return true;
    });
  }

  /// Hệ số thưởng hiện tại của học sinh (đọc từ pet) cho Coin/Kim cương.
  /// Lỗi đọc → hệ số 1 (không thưởng thêm), không chặn việc nhận thưởng.
  Future<FriendshipInfo> _friendshipOfStudent(String studentId) async {
    try {
      final s = await _db.collection('students').doc(studentId).get();
      final petId = s.data()?['petId'] as String?;
      if (petId == null) return FriendshipInfo.fromPoints(0);
      final p = await _db.collection('pets').doc(petId).get();
      return FriendshipInfo.fromPoints(
          ((p.data()?['affectionPoints'] ?? 0) as num).toInt());
    } catch (_) {
      return FriendshipInfo.fromPoints(0);
    }
  }

  /// Trừ (hoặc cộng, nếu [delta] dương) HP của pet — dùng khi làm bài SAI
  /// (mỗi câu sai trừ 5 HP, xem [submitExam]) hoặc bất kỳ chỗ nào khác cần
  /// chỉnh HP trực tiếp. HP có sàn tối thiểu 10 (xem [PetModel.clampStat]),
  /// không bao giờ về 0 để tránh gây áp lực "pet chết" cho học sinh.
  Future<int> adjustPetHp(String petId, int delta) async {
    final doc = await _db.collection('pets').doc(petId).get();
    final pet = applyTimeDecay(PetModel.fromMap(petId, doc.data()!));
    final updated = pet.copyWith(hp: pet.hp + delta);
    await _db.collection('pets').doc(petId).update({
      'hp': updated.hp,
      'hunger': updated.hunger,
      'hygiene': updated.hygiene,
      'energy': updated.energy,
      'playfulness': updated.playfulness,
      'toiletNeed': updated.toiletNeed,
      'happiness': updated.happiness,
      'lastDecayAt': Timestamp.fromDate(updated.lastDecayAt),
    });
    return updated.hp;
  }

  /// Mua một căn nhà mới cho pet — trừ Coin của học sinh, thêm nhà vào
  /// danh sách sở hữu và chuyển pet vào ở nhà mới luôn.
  Future<void> purchaseHouse({
    required String studentId,
    required String petId,
    required String houseId,
    required int priceCoin,
  }) async {
    await _db.runTransaction((tx) async {
      final studentRef = _db.collection('students').doc(studentId);
      final petRef = _db.collection('pets').doc(petId);
      final studentDoc = await tx.get(studentRef);
      final petDoc = await tx.get(petRef);

      final currentCoin = studentDoc.data()?['coin'] ?? 0;
      final coinInfinite = studentDoc.data()?['coinInfinite'] ?? false;
      if (!coinInfinite && currentCoin < priceCoin) {
        throw Exception('Không đủ Coin để mua căn nhà này');
      }

      tx.update(
          studentRef, {if (!coinInfinite) 'coin': currentCoin - priceCoin});
      tx.update(petRef, {
        'ownedHouseIds': FieldValue.arrayUnion([houseId]),
        'currentHouseId': houseId,
      });
    });
  }

  /// Chuyển pet sang ở một căn nhà đã sở hữu (miễn phí, không cần mua lại).
  Future<void> setCurrentHouse(String petId, String houseId) async {
    await _db.collection('pets').doc(petId).update({'currentHouseId': houseId});
  }

  // ---------- STREAK & COIN ----------

  /// Cập nhật streak học mỗi ngày.
  /// Mốc thưởng theo đặc tả: 3 ngày -> 100 Coin, 7 ngày -> 500 Coin,
  /// 30 ngày -> mở khóa pet hiếm.
  Future<int> updateStreakAndReward(StudentModel student) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = student.lastStudyDate;
    final lastDateOnly =
        last != null ? DateTime(last.year, last.month, last.day) : null;
    final gap =
        lastDateOnly != null ? today.difference(lastDateOnly).inDays : null;

    if (gap == 0) return student.streakDays; // đã học hôm nay rồi

    // gap == 1 -> học liên tục ngày kế tiếp -> +1. Mọi trường hợp khác
    // (chưa từng học, hoặc gap >= 2 tức bỏ lỡ từ 1 ngày trở lên mà KHÔNG
    // dùng Kim cương giữ kịp — xem [useStreakFreeze]) -> streak reset về 1.
    final newStreak = gap == 1 ? student.streakDays + 1 : 1;
    int bonusCoin = 0;
    if (newStreak == 3) bonusCoin = 100;
    if (newStreak == 7) bonusCoin = 500;
    // streak == 30 -> mở khóa pet hiếm, xử lý riêng ở lớp gọi hàm này

    await _db.collection('students').doc(student.uid).update({
      'streakDays': newStreak,
      'lastStudyDate': Timestamp.fromDate(now),
      'coin': FieldValue.increment(bonusCoin),
    });

    return newStreak;
  }

  // ---------- THÀNH TỰU / HUY HIỆU ----------

  /// So khớp trạng thái hiện tại của [student] với toàn bộ điều kiện ở
  /// [AchievementCatalog], mở khoá (ghi vào `badgeIds`) những thành tựu
  /// MỚI đạt được mà trước đó chưa có. Dùng `arrayUnion` nên gọi lại
  /// nhiều lần/nhiều nơi với cùng dữ liệu không bao giờ bị trùng lặp —
  /// gọi càng nhiều chỗ (sau khi nộp bài, cho ăn, tắm, ngủ...) thì thành
  /// tựu càng được phát hiện nhanh, không cần 1 Cloud Function riêng quét
  /// định kỳ. Trả về danh sách thành tựu VỪA mở khoá (rỗng nếu không có
  /// gì mới) để nơi gọi tự quyết định có hiện popup ăn mừng hay không —
  /// Cloud Function `onAchievementUnlocked` (xem functions/index.js) sẽ
  /// tự phát hiện `badgeIds` thay đổi và gửi kèm push notification.
  Future<List<AchievementDef>> checkAndAwardAchievements(
      StudentModel student) async {
    final owned = student.badgeIds.toSet();
    final newlyUnlocked = AchievementCatalog.all
        .where((def) => !owned.contains(def.id) && def.isUnlocked(student))
        .toList();
    if (newlyUnlocked.isEmpty) return const [];

    await _db.collection('students').doc(student.uid).update({
      'badgeIds':
          FieldValue.arrayUnion(newlyUnlocked.map((d) => d.id).toList()),
    });
    return newlyUnlocked;
  }

  /// Chi phí Kim cương để "đóng băng" 1 ngày đã bỏ lỡ, giữ nguyên streak.
  static const int streakFreezeGemCost = 20;

  /// Dùng Kim cương để giữ streak khi vừa bỏ lỡ ĐÚNG 1 ngày
  /// ([StudentModel.streakAtRisk] == true). Cơ chế: coi như học sinh đã
  /// học "hôm qua" (lùi lastStudyDate lại 1 ngày) để lần học tiếp theo
  /// trong hôm nay được tính là liên tục, không bị mất streak.
  /// Nếu đã bỏ lỡ từ 2 ngày trở lên thì KHÔNG thể cứu được nữa (ném lỗi).
  Future<void> useStreakFreeze(StudentModel student) async {
    if (student.daysSinceLastStudy != 2) {
      throw Exception(
          'Chỉ có thể dùng Kim cương giữ streak khi vừa bỏ lỡ đúng 1 ngày.');
    }
    if (!student.hasEnoughGem(streakFreezeGemCost)) {
      throw Exception('Không đủ Kim cương để giữ streak.');
    }
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    await _db.collection('students').doc(student.uid).update({
      'gem': FieldValue.increment(-streakFreezeGemCost),
      'lastStudyDate': Timestamp.fromDate(yesterday),
      'lastStreakCheckDate': Timestamp.fromDate(now),
    });
  }

  /// Ghi nhận đã hỏi/khước từ cảnh báo mất streak hôm nay — để không hỏi
  /// lại nhiều lần trong cùng 1 ngày (xem [StudentModel.streakAtRisk]).
  /// Không cần chủ động ghi streakDays = 0 ở đây: [StudentModel.displayStreak]
  /// đã tự hiển thị 0 khi bỏ lỡ >= 1 ngày mà chưa cứu kịp, và lần học tiếp
  /// theo [updateStreakAndReward] sẽ tự reset về 1 vì gap != 1.
  Future<void> acknowledgeStreakLoss(String studentId) async {
    await _db.collection('students').doc(studentId).update({
      'lastStreakCheckDate': Timestamp.fromDate(DateTime.now()),
    });
  }

  // ---------- LỚP HỌC (GIÁO VIÊN) & TUỲ CHỌN THÔNG BÁO ----------

  static const _joinCodeChars =
      'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // bỏ ký tự dễ nhầm: 0/O, 1/I

  String _generateJoinCode() {
    final random = Random();
    return List.generate(
        6, (_) => _joinCodeChars[random.nextInt(_joinCodeChars.length)]).join();
  }

  /// Giáo viên tạo lớp học mới, sinh sẵn 1 mã mời 6 ký tự (duy nhất) để
  /// đọc cho học sinh nhập ở màn hình Hồ sơ.
  Future<ClassModel> createClass(
      {required String teacherId, required String name, int? grade}) async {
    // Thử tối đa vài lần để tránh trùng mã mời (xác suất trùng rất thấp
    // với 6 ký tự trong bộ 32 ký tự, nhưng vẫn kiểm tra cho chắc).
    String code = _generateJoinCode();
    for (var attempt = 0; attempt < 5; attempt++) {
      final existing = await findClassByJoinCode(code);
      if (existing == null) break;
      code = _generateJoinCode();
    }

    final docRef = _db.collection('classes').doc();
    final classModel = ClassModel(
      id: docRef.id,
      name: name,
      teacherId: teacherId,
      joinCode: code,
      createdAt: DateTime.now(),
      grade: grade,
    );
    await docRef.set(classModel.toMap());
    return classModel;
  }

  Future<void> renameClass(String classId, String newName) async {
    await _db.collection('classes').doc(classId).update({'name': newName});
  }

  /// Đặt/sửa khối lớp cho 1 lớp đã có sẵn — chủ yếu dùng để bổ sung khối
  /// lớp cho các lớp được tạo TRƯỚC khi có tính năng này (ClassModel.grade
  /// null), qua 1 banner nhỏ ở Dashboard của lớp.
  Future<void> setClassGrade(String classId, int grade) async {
    await _db.collection('classes').doc(classId).update({'grade': grade});
  }

  /// Xoá lớp học. LƯU Ý: không tự động gỡ `classId` khỏi các học sinh đang
  /// ở lớp này (Firestore không hỗ trợ xoá theo điều kiện trong 1 lệnh) —
  /// các học sinh đó sẽ không còn thấy lớp trong danh sách của mình nhưng
  /// vẫn cần tự "Rời lớp" ở Hồ sơ nếu muốn tham gia lớp khác.
  Future<void> deleteClass(String classId) async {
    await _db.collection('classes').doc(classId).delete();
  }

  /// Chỉ where theo teacherId (một field, bằng nhau) rồi sắp xếp ở phía
  /// Dart — không dùng `.orderBy('createdAt', ...)` kèm theo, vì where-bằng
  /// -nhau kết hợp orderBy trên field KHÁC cũng bắt buộc composite index,
  /// giống lý do đã sửa ở [watchStudentAssignments].
  Stream<List<ClassModel>> watchTeacherClasses(String teacherId) {
    return _db
        .collection('classes')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ClassModel.fromMap(d.id, d.data())).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  Future<ClassModel?> getClass(String classId) async {
    final doc = await _db.collection('classes').doc(classId).get();
    if (!doc.exists) return null;
    return ClassModel.fromMap(doc.id, doc.data()!);
  }

  Future<ClassModel?> findClassByJoinCode(String code) async {
    final snap = await _db
        .collection('classes')
        .where('joinCode', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return ClassModel.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  /// Số học sinh hiện có trong lớp (aggregate count — không cần tải hết
  /// document học sinh, phù hợp để hiển thị nhanh ở danh sách lớp).
  Future<int> countClassStudents(String classId) async {
    final agg = await _db
        .collection('students')
        .where('classId', isEqualTo: classId)
        .count()
        .get();
    return agg.count ?? 0;
  }

  Stream<List<StudentModel>> watchClassStudents(String classId) {
    return _db
        .collection('students')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => StudentModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Học sinh nhập mã lớp giáo viên cung cấp để tham gia. Trả về tên lớp
  /// nếu thành công; ném lỗi nếu mã không tồn tại.
  Future<ClassModel> joinClassByCode(String studentId, String code) async {
    final klass = await findClassByJoinCode(code);
    if (klass == null) {
      throw Exception('Mã lớp không đúng, vui lòng kiểm tra lại.');
    }
    await _db.collection('students').doc(studentId).update({
      'classId': klass.id,
    });
    return klass;
  }

  /// Rời khỏi lớp hiện tại (xoá classId) — giáo viên cũng dùng hàm này để
  /// gỡ 1 học sinh khỏi lớp mình quản lý.
  Future<void> leaveClass(String studentId) async {
    await _db.collection('students').doc(studentId).update({
      'classId': null,
    });
  }

  /// Số ngày tối thiểu giữa 2 lần thưởng/phạt liên tiếp của CÙNG 1 học
  /// sinh (bất kể giáo viên nào thực hiện) — chống spam thưởng/phạt liên
  /// tục trong ngày.
  static const int rewardCooldownDays = 3;

  /// Lấy thời điểm thưởng/phạt (hoặc dùng mã ẩn vô hạn/reset) gần nhất
  /// của 1 học sinh, dựa vào dòng mới nhất trong `rewardLogs`. Trả về
  /// null nếu học sinh chưa từng bị/được thưởng phạt lần nào.
  Future<DateTime?> getLastRewardTime(String studentId) async {
    final snap = await _db
        .collection('students')
        .doc(studentId)
        .collection('rewardLogs')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final ts = snap.docs.first.data()['createdAt'];
    return ts is Timestamp ? ts.toDate() : null;
  }

  /// Giáo viên thưởng (delta dương) hoặc phạt (delta âm) Coin/Kim cương
  /// cho 1 học sinh — vd thưởng vì tích cực phát biểu, phạt vì gian lận.
  /// Ghi kèm 1 dòng lịch sử vào `students/{id}/rewardLogs` để giáo viên
  /// (và học sinh) xem lại được ai đã thưởng/phạt, khi nào, vì sao.
  Future<void> adjustStudentReward({
    required String studentId,
    required String teacherId,
    int coinDelta = 0,
    int gemDelta = 0,
    String? note,
  }) async {
    final studentRef = _db.collection('students').doc(studentId);
    await studentRef.update({
      if (coinDelta != 0) 'coin': FieldValue.increment(coinDelta),
      if (gemDelta != 0) 'gem': FieldValue.increment(gemDelta),
    });
    await studentRef.collection('rewardLogs').add({
      'teacherId': teacherId,
      'coinDelta': coinDelta,
      'gemDelta': gemDelta,
      'note': note,
      'createdAt': Timestamp.now(),
    });
  }

  /// Ghi đè TUYỆT ĐỐI (không cộng dồn) trạng thái Coin hoặc Gem của 1 học
  /// sinh — dùng cho 2 mã ẩn trong hộp thoại Thưởng/Phạt của giáo viên:
  /// đặt về VÔ HẠN ([infinite] = true) hoặc reset sạch về 0 ([infinite] =
  /// false). Tách riêng khỏi [adjustStudentReward] vì đây không phải cộng
  /// dồn delta như thưởng/phạt thông thường.
  Future<void> setStudentCurrencyOverride({
    required String studentId,
    required String teacherId,
    required bool isCoin, // true = Coin, false = Gem
    required bool infinite, // true = đặt vô hạn, false = reset về 0
    String? note,
  }) async {
    final studentRef = _db.collection('students').doc(studentId);
    final amountField = isCoin ? 'coin' : 'gem';
    final infiniteField = isCoin ? 'coinInfinite' : 'gemInfinite';
    await studentRef.update({
      infiniteField: infinite,
      if (!infinite) amountField: 0,
    });
    await studentRef.collection('rewardLogs').add({
      'teacherId': teacherId,
      'coinDelta': 0,
      'gemDelta': 0,
      'note': note ??
          (infinite
              ? 'Đặt $amountField vô hạn (mã quản trị)'
              : 'Reset $amountField về 0 (mã quản trị)'),
      'createdAt': Timestamp.now(),
    });
  }

  /// Lưu tuỳ chọn thông báo TRONG APP (nhắc streak, lên cấp, thành tích).
  /// Đây là tuỳ chọn hiển thị banner/nhắc nhở NGAY TRONG APP, không phải
  /// push notification hệ thống (chưa tích hợp Firebase Cloud Messaging).
  Future<void> updateNotificationPrefs(
      String studentId, Map<String, bool> prefs) async {
    await _db.collection('students').doc(studentId).update({
      'notificationPrefs': prefs,
    });
  }

  // ---------- BÀI HỌC / LÀM BÀI ----------

  // PetMath hiện chỉ còn duy nhất môn Toán — xem Curriculum.enabledSubjects.
  static const _subjects = ['Toán'];

  List<String> get subjects => _subjects;

  /// Lấy ngẫu nhiên câu hỏi đã được nạp trong Firestore.
  ///
  /// App không còn gọi ngân hàng mẫu trong mã nguồn và không còn bổ sung
  /// câu chưa gán khối. Với Toán, chỉ câu hỏi THPT có sourceId/sourceUrl
  /// mới được phép đi vào luồng luyện tập và đề kiểm tra.
  Future<List<QuestionModel>> fetchQuestions(
    String subject, {
    int? grade,
    String? topic,
    String? bookSeries,
    String? sourceId,
    int limit = 10,
  }) async {
    final random = Random();
    final snap = await _db
        .collection('questions')
        .where('subject', isEqualTo: subject)
        .get();

    var questions = snap.docs
        .map((d) => QuestionModel.fromMap(d.id, d.data()))
        .where((q) => subject != 'Toán' || _isSourceBackedThptMath(q))
        .where((q) => grade == null || q.grade == grade)
        .where((q) => topic == null || q.topic == topic)
        .where((q) => bookSeries == null || q.bookSeries == bookSeries)
        .where((q) => sourceId == null || q.sourceId == sourceId)
        .toList()
      ..shuffle(random);

    // Không đủ câu thì trả về đúng số câu đang có. Không trộn câu từ
    // khối khác, câu mẫu cũ hoặc câu chưa gắn nguồn.
    if (questions.length > limit) {
      questions = questions.take(limit).toList();
    }

    return questions.map((q) => _shuffleOptions(q, random)).toList();
  }

  bool _isSourceBackedThptMath(QuestionModel question) {
    final validGrade = question.grade != null &&
        question.grade! >= 10 &&
        question.grade! <= 12;
    final hasSourceId = question.sourceId?.trim().isNotEmpty == true;
    final hasSourceUrl = question.sourceUrl?.trim().isNotEmpty == true;
    return validGrade && hasSourceId && hasSourceUrl;
  }

  QuestionModel _shuffleOptions(QuestionModel question, Random random) {
    final order = List<int>.generate(question.options.length, (i) => i)
      ..shuffle(random);
    final shuffledOptions = order.map((i) => question.options[i]).toList();
    final newCorrectIndex = order.indexOf(question.correctOptionIndex);
    return QuestionModel(
      id: question.id,
      subject: question.subject,
      content: question.content,
      options: shuffledOptions,
      correctOptionIndex: newCorrectIndex,
      explanation: question.explanation,
      difficulty: question.difficulty,
      grade: question.grade,
      topic: question.topic,
      bookSeries: question.bookSeries,
      sourceId: question.sourceId,
      sourceName: question.sourceName,
      sourceUrl: question.sourceUrl,
      visual3d: question.visual3d,
      questionType: question.questionType,
      trueFalseAnswers: question.trueFalseAnswers,
      shortAnswer: question.shortAnswer,
      mediaUrls: question.mediaUrls,
    );
  }

  // ---------- NGÂN HÀNG CÂU HỎI (GIÁO VIÊN TỰ TẠO) ----------

  /// Danh sách câu hỏi cho Ngân hàng câu hỏi của Giáo viên — lọc theo môn
  /// (tuỳ chọn) và chỉ lấy câu do CHÍNH giáo viên này tạo (createdBy ==
  /// teacherId). Không dùng `orderBy` kèm `where` khác field để tránh bắt
  /// buộc phải tạo composite index.
  Stream<List<QuestionModel>> watchTeacherQuestions({
    required String teacherId,
    String? subject,
    int? grade,
  }) {
    Query<Map<String, dynamic>> query =
        _db.collection('questions').where('createdBy', isEqualTo: teacherId);
    if (subject != null) {
      query = query.where('subject', isEqualTo: subject);
    }
    if (grade != null) {
      query = query.where('grade', isEqualTo: grade);
    }
    return query.snapshots().map((snap) =>
        snap.docs.map((d) => QuestionModel.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(2000))
              .compareTo(a.createdAt ?? DateTime(2000))));
  }

  Future<List<QuestionModel>> fetchTeacherQuestions({
    required String teacherId,
    String? subject,
    int? grade,
  }) async {
    Query<Map<String, dynamic>> query =
        _db.collection('questions').where('createdBy', isEqualTo: teacherId);
    if (subject != null) query = query.where('subject', isEqualTo: subject);
    if (grade != null) query = query.where('grade', isEqualTo: grade);
    final snap = await query.get();
    return snap.docs.map((d) => QuestionModel.fromMap(d.id, d.data())).toList();
  }

  /// "Kho công khai" — câu hỏi do CÁC giáo viên khác chia sẻ (isPublic ==
  /// true), để mọi giáo viên có thêm nguồn câu hỏi ngoài ngân hàng của
  /// riêng mình. [excludeTeacherId] dùng để không lặp lại câu hỏi công khai
  /// của chính người xem (họ đã thấy nó ở tab "Của tôi" rồi). Cũng chỉ
  /// dùng where bằng nhau (không orderBy khác field) để tránh phải tạo
  /// composite index, giống các hàm truy vấn khác trong file này.
  Stream<List<QuestionModel>> watchPublicQuestions({
    String? subject,
    int? grade,
    String? excludeTeacherId,
  }) {
    Query<Map<String, dynamic>> query =
        _db.collection('questions').where('isPublic', isEqualTo: true);
    if (subject != null) {
      query = query.where('subject', isEqualTo: subject);
    }
    if (grade != null) {
      query = query.where('grade', isEqualTo: grade);
    }
    return query.snapshots().map((snap) => snap.docs
        .map((d) => QuestionModel.fromMap(d.id, d.data()))
        .where(
            (q) => excludeTeacherId == null || q.createdBy != excludeTeacherId)
        .toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000))));
  }

  Future<List<QuestionModel>> fetchPublicQuestions({
    String? subject,
    int? grade,
    String? excludeTeacherId,
  }) async {
    Query<Map<String, dynamic>> query =
        _db.collection('questions').where('isPublic', isEqualTo: true);
    if (subject != null) query = query.where('subject', isEqualTo: subject);
    if (grade != null) query = query.where('grade', isEqualTo: grade);
    final snap = await query.get();
    return snap.docs
        .map((d) => QuestionModel.fromMap(d.id, d.data()))
        .where(
            (q) => excludeTeacherId == null || q.createdBy != excludeTeacherId)
        .toList();
  }

  /// Tạo đề từ ma trận mà không cần AI: chỉ chọn lại câu đã có trong ngân
  /// hàng giáo viên, vì vậy không phát sinh chi phí API và vẫn giữ nguồn câu.
  Future<AssignmentModel> generateExamFromMatrix({
    required String teacherId,
    required String classId,
    required ExamTemplate template,
    int? semester,
    List<String>? topics,
  }) async {
    final pool = await fetchTeacherQuestions(
      teacherId: teacherId,
      subject: template.subject,
      grade: template.grade,
    );
    // Ngân hàng riêng của giáo viên có thể chưa đủ câu — bổ sung thêm câu
    // công khai do các giáo viên khác chia sẻ để có nhiều "vốn" câu hỏi
    // hơn khi trộn đề theo ma trận. Câu của chính mình luôn được ưu tiên
    // trước (đứng đầu danh sách `pool`), câu công khai chỉ lấp chỗ trống.
    final publicPool = await fetchPublicQuestions(
      subject: template.subject,
      grade: template.grade,
      excludeTeacherId: teacherId,
    );
    final poolIds = pool.map((q) => q.id).toSet();
    pool.addAll(publicPool.where((q) => !poolIds.contains(q.id)));

    // Lọc theo Học kỳ + Chuyên đề/Bài do giáo viên chọn — tránh random
    // nhầm câu của học kỳ/bài học sinh chưa học tới. Câu chưa gắn học kỳ
    // (semester == null, tức "cả năm/chưa xác định") vẫn được coi là phù
    // hợp với mọi học kỳ, để không loại bỏ oan các câu cũ chưa gắn nhãn.
    if (semester != null) {
      pool.retainWhere((q) => q.semester == null || q.semester == semester);
    }
    if (topics != null && topics.isNotEmpty) {
      final topicSet = topics.map((t) => t.trim()).toSet();
      pool.retainWhere((q) => topicSet.contains((q.topic ?? '').trim()));
    }

    if (pool.isEmpty) {
      throw Exception(
          'Ngân hàng câu hỏi chưa có câu phù hợp (kiểm tra lại bộ lọc Học kỳ/Chuyên đề đã chọn, hoặc thêm câu hỏi mới).');
    }

    final random = Random();
    final remaining = [...pool]..shuffle(random);
    final selected = <QuestionModel>[];

    void takeFrom(List<QuestionModel> candidates, int count, {int? limit}) {
      final maxSelected = limit ?? template.matrix.totalQuestions;
      for (final question in candidates) {
        if (selected.length >= maxSelected) break;
        if (count <= 0) break;
        if (!selected.any((item) => item.id == question.id)) {
          selected.add(question);
          count--;
        }
      }
    }

    if (template.matrix.questionTypeCounts.isNotEmpty) {
      for (final entry in template.matrix.questionTypeCounts.entries) {
        final typePool = remaining
            .where((question) => question.questionType == entry.key)
            .toList()
          ..shuffle(random);
        final before = selected.length;
        takeFrom(typePool, entry.value);
        if (selected.length - before < entry.value) {
          throw Exception(
              'Ngân hàng chưa đủ câu dạng ${entry.key} (${selected.length - before}/${entry.value}).');
        }
      }
    } else {
      // Ưu tiên đúng từng chuyên đề; trong mỗi chuyên đề ưu tiên mức độ theo
      // ma trận, sau đó lấp phần thiếu bằng câu cùng chuyên đề.
      if (template.matrix.topicCounts.isNotEmpty) {
        for (final entry in template.matrix.topicCounts.entries) {
          final topicPool = remaining
              .where((q) => (q.topic ?? '').trim() == entry.key.trim())
              .toList()
            ..shuffle(random);
          final before = selected.length;
          final topicLimit = before + entry.value;
          for (final difficultyEntry
              in template.matrix.difficultyCounts.entries) {
            final remainingTopicQuota = topicLimit - selected.length;
            if (remainingTopicQuota <= 0) break;
            takeFrom(
              topicPool
                  .where((q) => q.difficulty == difficultyEntry.key)
                  .toList(),
              min(difficultyEntry.value, remainingTopicQuota),
              limit: topicLimit,
            );
          }
          takeFrom(
            topicPool,
            topicLimit - selected.length,
            limit: topicLimit,
          );
          if (selected.length - before < entry.value) {
            throw Exception(
                'Chuyên đề "${entry.key}" không đủ ${entry.value} câu trong ngân hàng.');
          }
        }
      }

      // Nếu ma trận không chỉ rõ chuyên đề, dùng quota độ khó.
      if (template.matrix.topicCounts.isEmpty) {
        for (final entry in template.matrix.difficultyCounts.entries) {
          takeFrom(
            remaining.where((q) => q.difficulty == entry.key).toList(),
            entry.value,
          );
        }
      }
    }

    final target = template.matrix.totalQuestions;
    takeFrom(remaining, target - selected.length);
    if (selected.length < target) {
      throw Exception(
          'Không đủ câu hỏi trong ngân hàng để tạo đề (${selected.length}/$target).');
    }

    final selectedQuestions = selected.take(target).toList();
    final sections = <ExamSection>[];
    if (template.matrix.questionTypeCounts.isNotEmpty) {
      const typeLabels = {
        'multiple_choice': 'Phần I — Trắc nghiệm nhiều lựa chọn',
        'true_false': 'Phần II — Trắc nghiệm đúng/sai',
        'short_answer': 'Phần III — Trắc nghiệm trả lời ngắn',
      };
      const instructions = {
        'multiple_choice': 'Chọn một đáp án đúng.',
        'true_false': 'Chọn Đúng hoặc Sai cho từng mệnh đề.',
        'short_answer': 'Nhập đáp án ngắn của câu hỏi.',
      };
      for (final type in template.matrix.questionTypeCounts.keys) {
        final sectionQuestions = selectedQuestions
            .where((question) => question.questionType == type)
            .toList();
        if (sectionQuestions.isNotEmpty) {
          sections.add(ExamSection(
            title: typeLabels[type] ?? type,
            instructions: instructions[type] ?? '',
            questionIds:
                sectionQuestions.map((question) => question.id).toList(),
          ));
        }
      }
    } else {
      for (final entry in <int, String>{
        1: 'Phần I — Nhận biết',
        2: 'Phần II — Thông hiểu',
        3: 'Phần III — Vận dụng',
      }.entries) {
        final sectionQuestions = selectedQuestions
            .where((question) => question.difficulty == entry.key)
            .toList();
        if (sectionQuestions.isNotEmpty) {
          sections.add(ExamSection(
            title: entry.value,
            instructions: 'Chọn một đáp án đúng cho mỗi câu hỏi.',
            questionIds:
                sectionQuestions.map((question) => question.id).toList(),
          ));
        }
      }
    }

    return createAssignment(
      classId: classId,
      teacherId: teacherId,
      title: template.title,
      subject: template.subject,
      questionIds: selectedQuestions.map((q) => q.id).toList(),
      dueDate: template.dueDate,
      assignmentType: template.assignmentType,
      matrix: {
        ...template.matrix.topicCounts.map((k, v) => MapEntry('topic:$k', v)),
        ...template.matrix.difficultyCounts
            .map((k, v) => MapEntry('difficulty:$k', v)),
        ...template.matrix.questionTypeCounts
            .map((k, v) => MapEntry('type:$k', v)),
      },
      sections: sections.map((section) => section.toMap()).toList(),
    );
  }

  Future<String> uploadQuestionMedia({
    required Uint8List bytes,
    required String fileName,
    required String teacherId,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final ref = FirebaseStorage.instance.ref(
        'question_media/$teacherId/${DateTime.now().microsecondsSinceEpoch}_$safeName');
    final metadata = SettableMetadata(contentType: _mediaContentType(fileName));
    final snapshot = await ref.putData(bytes, metadata);
    return snapshot.ref.getDownloadURL();
  }

  String _mediaContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<String> createQuestion(QuestionModel question) async {
    final docRef = await _db.collection('questions').add(question.toMap());
    return docRef.id;
  }

  Future<AssignmentModel> createAssignmentFromComposedExam({
    required String classId,
    required String teacherId,
    required String title,
    required String subject,
    required String assignmentType,
    required List<String> questionIds,
    required List<ExamSection> sections,
    DateTime? dueDate,
  }) async {
    final matrix = <String, int>{
      for (final section in sections)
        'section:${section.title}': section.questionIds.length,
    };
    return createAssignment(
      classId: classId,
      teacherId: teacherId,
      title: title,
      subject: subject,
      questionIds: questionIds,
      dueDate: dueDate,
      assignmentType: assignmentType,
      matrix: matrix,
      sections: sections.map((section) => section.toMap()).toList(),
    );
  }

  Future<void> updateQuestion(String id, QuestionModel question) async {
    await _db.collection('questions').doc(id).update(question.toMap());
  }

  Future<void> deleteQuestion(String id) async {
    await _db.collection('questions').doc(id).delete();
  }

  /// Lấy đúng bộ câu hỏi theo id (giữ nguyên thứ tự trong [ids]) — dùng
  /// khi học sinh làm 1 bài tập được giao (không random như [fetchQuestions]).
  Future<List<QuestionModel>> fetchQuestionsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    // whereIn giới hạn 30 phần tử/lần — bài tập giao thường không vượt quá
    // số này (tương đương 1 đề kiểm tra), nhưng vẫn chia theo lô cho an toàn.
    final result = <String, QuestionModel>{};
    for (var i = 0; i < ids.length; i += 30) {
      final batch = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap = await _db
          .collection('questions')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final d in snap.docs) {
        final question = QuestionModel.fromMap(d.id, d.data());
        if (question.subject != 'Toán' || _isSourceBackedThptMath(question)) {
          result[d.id] = question;
        }
      }
    }
    // Giữ đúng thứ tự đã lưu trong bài tập, bỏ qua id nào lỡ bị xoá khỏi
    // ngân hàng câu hỏi sau khi đã giao bài.
    return ids.where(result.containsKey).map((id) => result[id]!).toList();
  }

  // ---------- BÀI TẬP ĐƯỢC GIAO (GIÁO VIÊN GIAO BÀI CHO LỚP) ----------

  Future<AssignmentModel> createAssignment({
    required String classId,
    required String teacherId,
    required String title,
    required String subject,
    required List<String> questionIds,
    DateTime? dueDate,
    String assignmentType = 'Bài tập',
    int visibilityDays = 7,
    Map<String, int> matrix = const {},
    List<Map<String, dynamic>> sections = const [],
  }) async {
    final docRef = _db.collection('assignments').doc();
    final assignment = AssignmentModel(
      id: docRef.id,
      classId: classId,
      teacherId: teacherId,
      title: title,
      subject: subject,
      questionIds: questionIds,
      createdAt: DateTime.now(),
      dueDate: dueDate,
      assignmentType: assignmentType,
      visibilityDays: visibilityDays,
      matrix: matrix,
      sections: sections,
    );
    await docRef.set(assignment.toMap());
    return assignment;
  }

  Future<void> deleteAssignment(String assignmentId) async {
    await _db.collection('assignments').doc(assignmentId).delete();
  }

  /// Dùng chung cho cả màn hình Giáo viên (xem tiến độ cả lớp) và Học sinh
  /// (xem bài được giao cho lớp mình) — cùng 1 truy vấn theo classId.
  Stream<List<AssignmentModel>> watchClassAssignments(String classId) {
    return _db
        .collection('assignments')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AssignmentModel.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  /// Stream dành riêng cho học sinh: chỉ trả bài còn trong cửa sổ hiển thị.
  /// Giáo viên vẫn dùng [watchClassAssignments] để giữ toàn bộ lịch sử.
  ///
  /// CHÚ Ý: chỉ where theo classId (một field, bằng nhau) rồi lọc
  /// createdAt/isVisibleToStudent ở phía Dart — KHÔNG được thêm
  /// `.where('createdAt', isGreaterThanOrEqualTo: ...)` vào cùng query,
  /// vì kết hợp where-bằng-nhau với where-khoảng trên 2 field khác nhau
  /// bắt buộc phải có composite index. Dự án chưa tạo index đó thì query
  /// sẽ ném lỗi ngay khi chạy — StreamBuilder phía học sinh lại không bắt
  /// lỗi nên chỉ âm thầm hiện "chưa có bài tập" dù giáo viên đã giao thành
  /// công. Lọc ở Dart tránh hẳn vấn đề này, giống các hàm khác trong file.
  Stream<List<AssignmentModel>> watchStudentAssignments(String classId) {
    return _db
        .collection('assignments')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AssignmentModel.fromMap(d.id, d.data()))
            .where((assignment) => assignment.isVisibleToStudent)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  /// Học sinh nộp kết quả 1 bài được giao — ghi vào field động
  /// `results.<studentId>` (không ghi đè kết quả của học sinh khác trong
  /// cùng document nhờ Firestore hỗ trợ cập nhật field lồng theo đường dẫn).
  Future<void> submitAssignmentResult({
    required String assignmentId,
    required String studentId,
    required int correctCount,
    required int totalQuestions,
    double score = 0,
    double maxScore = 0,
  }) async {
    final result = AssignmentResult(
      correctCount: correctCount,
      totalQuestions: totalQuestions,
      submittedAt: DateTime.now(),
      score: score,
      maxScore: maxScore,
    );
    await _db.collection('assignments').doc(assignmentId).update({
      'results.$studentId': result.toMap(),
    });
  }

  /// EXP thưởng cho mỗi câu làm đúng trong bài tập (mini game câu cá/thu
  /// thập... có công thức thưởng riêng, không dùng hằng số này).
  static const int xpPerCorrectAnswer = 5;

  /// Theo dõi tiến độ Toán THPT theo học sinh và khối lớp.
  Stream<MathProgressModel> watchMathProgress({
    required String studentId,
    required int grade,
  }) {
    final docId = '${studentId}_$grade';
    return _db.collection('mathProgress').doc(docId).snapshots().map((snap) {
      return snap.exists
          ? MathProgressModel.fromMap(studentId, grade, snap.data() ?? {})
          : MathProgressModel.empty(studentId, grade);
    });
  }

  /// Ghi nhận một phiên học đã hoàn thành. Chỉ gọi sau khi học sinh đã đi
  /// hết câu hỏi và nộp bài, không gọi khi mới mở bài học.
  Future<void> recordMathStudyProgress({
    required String studentId,
    required int grade,
    String? topic,
    required int totalQuestions,
    required int correctCount,
  }) async {
    if (totalQuestions <= 0) return;

    final docId = '${studentId}_$grade';
    final ref = _db.collection('mathProgress').doc(docId);
    final accuracy = correctCount / totalQuestions;

    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      final current = snap.data() ?? <String, dynamic>{};
      final rawTopics = Map<String, dynamic>.from(current['topics'] ?? {});
      final now = FieldValue.serverTimestamp();

      if (topic != null && topic.trim().isNotEmpty) {
        final topicKey = topic.trim();
        final rawTopic = Map<String, dynamic>.from(rawTopics[topicKey] ?? {});
        final sessions = (rawTopic['sessions'] as num?)?.toInt() ?? 0;
        final previousQuestions =
            (rawTopic['totalQuestions'] as num?)?.toInt() ?? 0;
        final previousCorrect =
            (rawTopic['totalCorrect'] as num?)?.toInt() ?? 0;
        final previousBest =
            (rawTopic['bestAccuracy'] as num?)?.toDouble() ?? 0;

        rawTopics[topicKey] = {
          'sessions': sessions + 1,
          'totalQuestions': previousQuestions + totalQuestions,
          'totalCorrect': previousCorrect + correctCount,
          'bestAccuracy': accuracy > previousBest ? accuracy : previousBest,
          'lastStudiedAt': now,
        };
      }

      final totalSessions =
          (current['completedSessions'] as num?)?.toInt() ?? 0;
      final allQuestions = (current['totalQuestions'] as num?)?.toInt() ?? 0;
      final allCorrect = (current['totalCorrect'] as num?)?.toInt() ?? 0;

      transaction.set(
        ref,
        {
          'studentId': studentId,
          'grade': grade,
          'completedSessions': totalSessions + 1,
          'totalQuestions': allQuestions + totalQuestions,
          'totalCorrect': allCorrect + correctCount,
          if (topic != null && topic.trim().isNotEmpty)
            'lastTopic': topic.trim(),
          'lastStudiedAt': now,
          'topics': rawTopics,
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Nộp bài: lưu kết quả, cộng EXP cho pet (5 EXP/câu đúng — EXP dư sau
  /// khi đầy 1 cấp sẽ tự động cộng dồn sang cấp kế tiếp, xem
  /// [PetModel.addExp]), cập nhật streak, và trả về kết quả để hiển thị
  /// màn hình điểm số.
  Future<ExamResultModel> submitExam({
    required StudentModel student,
    required String petId,
    required String subject,
    required int correctCount,
    required int totalQuestions,
    required List<String> wrongQuestionIds,
    int? grade,
    String? topic,
    double score = 0,
    double maxScore = 0,
  }) async {
    final resultRef = _db.collection('examResults').doc();
    final result = ExamResultModel(
      id: resultRef.id,
      studentId: student.uid,
      subject: subject,
      totalQuestions: totalQuestions,
      correctCount: correctCount,
      submittedAt: DateTime.now(),
      wrongQuestionIds: wrongQuestionIds,
      score: score,
      maxScore: maxScore,
    );

    await resultRef.set(result.toMap());
    await rewardExp(petId, correctCount * xpPerCorrectAnswer,
        energyGain: correctCount * 3);
    // Mỗi câu SAI trừ 5 HP — tạo hậu quả nhẹ cho việc làm sai, khuyến
    // khích học kỹ hơn, nhưng vẫn không thể khiến pet "chết" vì HP luôn
    // có sàn tối thiểu 10 (xem [PetModel.clampStat]).
    if (wrongQuestionIds.isNotEmpty) {
      await adjustPetHp(petId, -5 * wrongQuestionIds.length);
    }
    await updateStreakAndReward(student);
    final examFriendship = await _friendshipOfStudent(student.uid);
    await _db.collection('students').doc(student.uid).update({
      'coin': FieldValue.increment(
          examFriendship.boostCoin(correctCount * 5)), // Coin nhỏ mỗi câu đúng
      'totalExp': FieldValue.increment(correctCount * xpPerCorrectAnswer),
      'totalCorrectAnswers': FieldValue.increment(correctCount),
    });

    if (subject == 'Toán' && grade != null && grade >= 10 && grade <= 12) {
      await recordMathStudyProgress(
        studentId: student.uid,
        grade: grade,
        topic: topic,
        totalQuestions: totalQuestions,
        correctCount: correctCount,
      );
    }
    return result;
  }

  // ---------- MINI GAME ----------

  /// Vé Giải mật mã — mua ở Cửa hàng, 10 Coin/vé. Dùng transaction để tránh
  /// bấm liên tục làm trừ Coin nhiều hơn số vé cộng được, và để đảm bảo
  /// không mua được khi không đủ Coin.
  static const int cipherTicketPriceCoin = 10;

  Future<void> buyCipherTicket(String studentId) async {
    await _db.runTransaction((tx) async {
      final ref = _db.collection('students').doc(studentId);
      final doc = await tx.get(ref);
      final currentCoin = (doc.data()?['coin'] ?? 0) as int;
      final coinInfinite = doc.data()?['coinInfinite'] ?? false;
      if (!coinInfinite && currentCoin < cipherTicketPriceCoin) {
        throw Exception(
            'Không đủ Coin để mua vé (cần $cipherTicketPriceCoin Coin)');
      }
      final currentTickets = (doc.data()?['cipherTickets'] ?? 0) as int;
      tx.update(ref, {
        if (!coinInfinite) 'coin': currentCoin - cipherTicketPriceCoin,
        'cipherTickets': currentTickets + 1,
      });
    });
  }

  /// Tiêu 1 vé để bắt đầu 1 lượt chơi Giải mật mã. Trả về false nếu hết vé.
  Future<bool> consumeCipherTicket(String studentId) async {
    return _db.runTransaction<bool>((tx) async {
      final ref = _db.collection('students').doc(studentId);
      final doc = await tx.get(ref);
      final currentTickets = (doc.data()?['cipherTickets'] ?? 0) as int;
      if (currentTickets < 1) return false;
      tx.update(ref, {'cipherTickets': currentTickets - 1});
      return true;
    });
  }

  /// Lucky Spin: thưởng Coin ngẫu nhiên, dùng năng lượng của pet (đặc tả:
  /// mini game để kiếm Coin, không ảnh hưởng học tập).
  Future<int> claimMiniGameReward(String studentId, int coinAmount) async {
    coinAmount = (await _friendshipOfStudent(studentId)).boostCoin(coinAmount);
    await _db.collection('students').doc(studentId).update({
      'coin': FieldValue.increment(coinAmount),
    });
    return coinAmount;
  }

  /// URL Worker Cloudflare (free, không cần thẻ) thay cho Cloud Function
  /// askMathTutor. Đổi thành URL Worker thật của bạn sau khi deploy
  /// (`wrangler deploy` trong thư mục worker/), dạng:
  /// https://edupet-ai-tutor.<subdomain-cua-ban>.workers.dev
  static const String _aiTutorWorkerUrl =
      'https://edupet-ai-tutor.edupet.workers.dev';
  static const int _tutorAnswerCostGem = 10;

  /// Gọi gia sư AI. Khác với bản Cloud Function cũ: TOÀN BỘ logic kiểm tra
  /// đã nộp bài, tải câu hỏi theo questionId và trừ Gem chạy ngay trong
  /// app (Firestore transaction) — y hệt cách [spendGemForHint] bên dưới
  /// đang làm. Worker Cloudflare chỉ giữ Groq API key và xác thực idToken,
  /// không đụng tới Firestore, nên không cần Cloud Functions/Blaze nữa.
  Future<Map<String, dynamic>> askMathTutor({
    required String mode,
    required String questionText,
    required List<String> options,
    String? questionId,
    String? assignmentId,
    String? submissionId,
    bool isExamOrAssignment = false,
  }) async {
    final user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Bạn cần đăng nhập để dùng gia sư AI.');
    }
    final uid = user.uid;

    if (isExamOrAssignment) {
      await _assertTutorSubmitted(
        uid: uid,
        assignmentId: assignmentId,
        submissionId: submissionId,
      );
    }

    final context = questionId != null
        ? await _loadTutorQuestionContext(questionId, options)
        : null;

    bool charged = false;
    if (mode == 'answer') {
      charged = await _spendTutorAnswerGem(uid);
    }

    try {
      final systemInstruction = mode == 'hint'
          ? 'Bạn là gia sư Toán THPT. Chỉ hướng dẫn từng bước, đặt câu hỏi '
              'gợi mở, tuyệt đối không nêu chữ cái đáp án hoặc kết quả cuối '
              'cùng. Trả lời tiếng Việt, NGẮN GỌN: tối đa 3-4 câu hoặc '
              '2-3 gạch đầu dòng, đi thẳng vào ý, không lan man không '
              'nhắc lại đề bài, không mở đầu bằng lời chào hay giải thích '
              'dài dòng.'
          : 'Bạn là gia sư Toán THPT. Giải ngắn gọn, súc tích: chỉ nêu các '
              'bước biến đổi chính (không giải thích lý thuyết dài dòng, '
              'không nhắc lại đề bài), rồi kết luận đáp án cuối cùng rõ '
              'ràng. Trả lời bằng tiếng Việt. Không bịa dữ kiện.';

      final privateContext = (context != null && mode == 'answer')
          ? '\nDạng câu: ${context['questionType']}\n'
              'Lựa chọn/mệnh đề chuẩn: ${jsonEncode(context['options'])}\n'
              'Đáp án trắc nghiệm: ${context['correctOptionIndex']}\n'
              'Đáp án đúng/sai: ${jsonEncode(context['trueFalseAnswers'])}\n'
              'Đáp án ngắn chuẩn: ${context['shortAnswer'] ?? ''}\n'
              'Lời giải tham khảo: ${context['explanation'] ?? ''}'
          : '';
      final prompt = 'Đề bài và câu hỏi học sinh:\n$questionText\n'
          'Các lựa chọn: ${jsonEncode(options)}$privateContext';

      final idToken = await user.getIdToken();

      final response = await http
          .post(
            Uri.parse(_aiTutorWorkerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'idToken': idToken,
              'mode': mode,
              'systemInstruction': systemInstruction,
              'prompt': prompt,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception(
            'Gia sư AI lỗi ${response.statusCode}: ${response.body}');
      }
      final data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      final text = data['text']?.toString();
      if (text == null || text.isEmpty) {
        throw Exception('Không nhận được phản hồi từ gia sư AI.');
      }
      return {'text': text, 'gemCharged': charged};
    } catch (e) {
      if (charged) {
        await _db.collection('students').doc(uid).update({
          'gem': FieldValue.increment(_tutorAnswerCostGem),
        });
      }
      rethrow;
    }
  }

  /// Kiểm tra học sinh đã nộp bài giáo viên giao/bài kiểm tra chưa, trước
  /// khi cho mở gia sư AI (giữ nguyên logic từ Cloud Function cũ).
  Future<void> _assertTutorSubmitted({
    required String uid,
    String? assignmentId,
    String? submissionId,
  }) async {
    if (assignmentId != null) {
      final doc = await _db.collection('assignments').doc(assignmentId).get();
      final results = Map<String, dynamic>.from(doc.data()?['results'] ?? {});
      if (!doc.exists || !results.containsKey(uid)) {
        throw Exception('Hãy nộp bài giáo viên giao trước khi hỏi gia sư AI.');
      }
      return;
    }
    if (submissionId != null) {
      final doc = await _db.collection('examResults').doc(submissionId).get();
      if (!doc.exists || doc.data()?['studentId'] != uid) {
        throw Exception('Hãy nộp bài kiểm tra trước khi hỏi gia sư AI.');
      }
      return;
    }
    throw Exception('Thiếu thông tin bài đã nộp để mở gia sư AI.');
  }

  /// Tải đáp án chuẩn theo questionId để đưa vào ngữ cảnh cho AI (chỉ dùng
  /// ở chế độ "answer" — chế độ "hint" không cần và không nên biết đáp án).
  Future<Map<String, dynamic>?> _loadTutorQuestionContext(
    String questionId,
    List<String> fallbackOptions,
  ) async {
    final doc = await _db.collection('questions').doc(questionId).get();
    if (!doc.exists) return null;
    final data = doc.data() ?? {};
    return {
      'options':
          (data['options'] as List?)?.map((e) => e.toString()).toList() ??
              fallbackOptions,
      'questionType': (data['questionType'] ?? 'multiple_choice').toString(),
      'correctOptionIndex':
          data['correctOptionIndex'] is int ? data['correctOptionIndex'] : null,
      'trueFalseAnswers':
          (data['trueFalseAnswers'] as List?)?.map((e) => e == true).toList(),
      'shortAnswer': data['shortAnswer']?.toString(),
      'explanation': data['explanation']?.toString() ?? '',
    };
  }

  /// Trừ Gem để mở đáp án đầy đủ, dùng transaction để tránh trừ 2 lần khi
  /// bấm liên tục. Trả về false khi học sinh có Gem vô hạn (không cần
  /// trừ); throw khi không đủ Gem — y hệt hành vi Cloud Function cũ.
  Future<bool> _spendTutorAnswerGem(String uid) {
    final studentRef = _db.collection('students').doc(uid);
    return _db.runTransaction<bool>((tx) async {
      final doc = await tx.get(studentRef);
      final data = doc.data() ?? {};
      if (data['gemInfinite'] == true) return false;
      final gem = (data['gem'] ?? 0) as int;
      if (gem < _tutorAnswerCostGem) {
        throw Exception(
            'Không đủ Gem để mở đáp án (cần $_tutorAnswerCostGem Gem).');
      }
      tx.update(studentRef, {'gem': gem - _tutorAnswerCostGem});
      return true;
    });
  }

  /// Dùng Gem để mua gợi ý trong minigame (ví dụ: màn Giải mã).
  /// Trả về true nếu trừ Gem thành công, false nếu không đủ Gem — dùng
  /// transaction để tránh trường hợp Gem đổi đồng thời từ nơi khác, dù
  /// màn hình gọi hàm này đã tự kiểm tra đủ Gem trước đó.
  Future<bool> spendGemForHint(String studentId, int cost) async {
    final studentRef = _db.collection('students').doc(studentId);
    return _db.runTransaction<bool>((tx) async {
      final doc = await tx.get(studentRef);
      final gemInfinite = doc.data()?['gemInfinite'] ?? false;
      if (gemInfinite) return true;
      final currentGem = doc.data()?['gem'] ?? 0;
      if (currentGem < cost) return false;
      tx.update(studentRef, {'gem': currentGem - cost});
      return true;
    });
  }

  /// Thưởng cả Coin lẫn Gem cho các mini game có phần thưởng hiếm (Câu cá,
  /// Đào kho báu, ô Gem của Lucky Spin).
  Future<void> claimMiniGameRewardWithGem(
    String studentId, {
    int coinAmount = 0,
    int gemAmount = 0,
  }) async {
    final f = await _friendshipOfStudent(studentId);
    coinAmount = f.boostCoin(coinAmount);
    gemAmount = f.boostGem(gemAmount);
    await _db.collection('students').doc(studentId).update({
      if (coinAmount != 0) 'coin': FieldValue.increment(coinAmount),
      if (gemAmount != 0) 'gem': FieldValue.increment(gemAmount),
    });
  }

  /// Lucky Spin giới hạn 1 lượt/ngày: cộng thưởng và đồng thời ghi nhận
  /// ngày quay để khóa lượt quay tiếp theo tới ngày hôm sau.
  Future<void> claimSpinReward(
    String studentId, {
    int coinAmount = 0,
    int gemAmount = 0,
  }) async {
    final now = DateTime.now();
    final f = await _friendshipOfStudent(studentId);
    coinAmount = f.boostCoin(coinAmount);
    gemAmount = f.boostGem(gemAmount);
    await _db.collection('students').doc(studentId).update({
      if (coinAmount != 0) 'coin': FieldValue.increment(coinAmount),
      if (gemAmount != 0) 'gem': FieldValue.increment(gemAmount),
      'lastSpinDate': Timestamp.fromDate(now),
    });
  }

  /// Ghi nhận vĩnh viễn 1 loài cá đã câu được vào Bộ sưu tập cá của học
  /// sinh (hiển thị ở màn hình riêng), dùng arrayUnion nên gọi lại nhiều
  /// lần với cùng 1 fishId cũng không bị trùng lặp.
  Future<void> unlockFish(String studentId, String fishId) async {
    await _db.collection('students').doc(studentId).update({
      'unlockedFish': FieldValue.arrayUnion([fishId]),
    });
  }

  /// Nâng cấp cần câu lên [newTier] (xem [kRodTiers]), trừ Coin tương ứng.
  Future<void> upgradeFishingRod(
      String studentId, int newTier, int costCoin) async {
    await _db.collection('students').doc(studentId).update({
      'coin': FieldValue.increment(-costCoin),
      'fishingRodTier': newTier,
    });
  }

  /// Mua thêm [quantity] lượt Mồi câu may mắn, trừ Gem tương ứng.
  Future<void> buyFishingBait(
      String studentId, int quantity, int costGem) async {
    await _db.collection('students').doc(studentId).update({
      'gem': FieldValue.increment(-costGem),
      'baitCharges': FieldValue.increment(quantity),
    });
  }

  /// Dùng 1 lượt Mồi câu may mắn cho lượt thả cần hiện tại.
  Future<void> consumeFishingBait(String studentId) async {
    await _db.collection('students').doc(studentId).update({
      'baitCharges': FieldValue.increment(-1),
    });
  }

  /// Cập nhật kỷ lục cân nặng cho 1 loài cá — CHỈ gọi khi phía client đã tự
  /// xác nhận [weightKg] lớn hơn kỷ lục cũ (tránh phải dùng transaction cho
  /// 1 thao tác không mang tính tranh chấp/đồng thời).
  Future<void> updateFishRecord(
      String studentId, String fishId, double weightKg) async {
    await _db.collection('students').doc(studentId).update({
      'fishRecords.$fishId': weightKg,
    });
  }

  /// Câu cá / Đào kho báu tốn Năng lượng của pet để chơi mỗi lượt — dùng
  /// năng lượng làm "vé chơi" thay vì giới hạn cứng theo ngày, để học sinh
  /// vẫn có thể chơi nhiều nếu chăm cho pet ăn/nghỉ. Năng lượng có sàn 10
  /// (xem PetModel.clampStat) nên pet không bao giờ bị "kiệt sức" hẳn.
  Future<int> adjustPetEnergy(String petId, int delta) async {
    final doc = await _db.collection('pets').doc(petId).get();
    final pet = applyTimeDecay(PetModel.fromMap(petId, doc.data()!));
    final updated = pet.copyWith(energy: pet.energy + delta);
    await _db.collection('pets').doc(petId).update({
      'energy': updated.energy,
      'hunger': updated.hunger,
      'hygiene': updated.hygiene,
      'playfulness': updated.playfulness,
      'toiletNeed': updated.toiletNeed,
      'happiness': updated.happiness,
      'lastDecayAt': Timestamp.fromDate(updated.lastDecayAt),
    });
    return updated.energy;
  }

  /// Cho pet ngủ để hồi Năng lượng, cộng EXP.
  /// Cộng EXP NGAY TRONG cùng 1 lần đọc/ghi (giống cách đã sửa ở [feedPet])
  /// để tránh race-condition: nếu gọi [adjustPetEnergy] rồi gọi [rewardExp]
  /// tách rời, [rewardExp] có thể đọc phải dữ liệu pet CŨ rồi ghi đè lại,
  /// làm mất luôn phần Năng lượng vừa hồi được.
  // Sau một giấc ngủ hoàn chỉnh, pet thức dậy với thanh năng lượng đầy.
  static const int sleepEnergyGain = 100;
  static const int sleepExpReward = 10;

  Future<void> sleepPet(String petId) async {
    final doc = await _db.collection('pets').doc(petId).get();
    final pet = applyTimeDecay(PetModel.fromMap(petId, doc.data()!));
    final updated = pet.addExp(pet.friendship.boostExp(sleepExpReward)).copyWith(
          // Đặt tuyệt đối 100, không cộng dồn, để luôn đầy năng lượng sau khi
          // pet thức dậy.
          energy: sleepEnergyGain,
        );
    await _db.collection('pets').doc(petId).update(updated.toMap());
    await _syncPetLevelToOwner(pet, updated);
  }

  // ---------- NÔNG TRẠI (mini game trồng Hoa & Trái cây kiểu Hay Day) ----------

  /// "Chốt sổ" tiến độ lớn thực tế của 1 ô đất tính tới [now] — dùng
  /// CHUNG công thức với [FarmPlotState.liveGrowSeconds] (đọc lại từ đúng
  /// model đó) để đảm bảo số hiển thị trên UI và số lưu server khớp nhau
  /// tuyệt đối. Gọi trước MỌI thay đổi mốc thời gian tưới/bón/thu hoạch,
  /// để không bị mất phần đã lớn trong khoảng thời gian vừa qua.
  Map<String, dynamic> _checkpointPlot(
      Map<String, dynamic> plotMap, int plotIndex, DateTime now) {
    final state = FarmPlotState.fromMap(plotIndex, plotMap);
    final updated = Map<String, dynamic>.from(plotMap);
    updated['growAccumSeconds'] = state.liveGrowSeconds(now: now);
    updated['lastCareUpdateAt'] = Timestamp.fromDate(now);
    return updated;
  }

  /// Trồng 1 hạt giống [cropId] vào ô đất [plotIndex] — trừ Coin ngay lúc
  /// trồng. Dùng transaction để tránh trồng "chùa" nếu bấm liên tiếp hoặc
  /// ô đất/Coin vừa đổi cùng lúc ở nơi khác. Trả về false nếu ô đất chưa
  /// mở khoá, đang có cây (kể cả cây đã chết chưa dọn), hoặc không đủ Coin.
  Future<bool> plantCrop(
    String studentId, {
    required int plotIndex,
    required String cropId,
    required int costCoin,
  }) async {
    final ref = _db.collection('students').doc(studentId);
    return _db.runTransaction<bool>((tx) async {
      final doc = await tx.get(ref);
      final data = doc.data() ?? {};
      final unlocked = (data['farmPlotsUnlocked'] ?? kFarmFreePlots) as int;
      if (plotIndex >= unlocked) return false;
      final farmPlots = Map<String, dynamic>.from(data['farmPlots'] ?? {});
      final key = '$plotIndex';
      if (farmPlots.containsKey(key)) return false; // ô đất đã có cây
      final coinInfinite = data['coinInfinite'] ?? false;
      final currentCoin = (data['coin'] ?? 0) as int;
      if (!coinInfinite && currentCoin < costCoin) return false;
      final now = Timestamp.now();
      tx.update(ref, {
        if (!coinInfinite) 'coin': currentCoin - costCoin,
        'farmPlots.$key': {
          'cropId': cropId,
          'plantedAt': now,
          'growAccumSeconds': 0,
          'lastWateredAt': now,
          'lastFertilizedAt': now,
          'lastCareUpdateAt': now,
        },
      });
      return true;
    });
  }

  /// Tưới nước cho ô đất [plotIndex] — "chốt sổ" tiến độ lớn tới hiện tại
  /// rồi làm ĐẦY LẠI Nước (đặt [lastWateredAt] = bây giờ), giúp cây hết
  /// héo và tiếp tục lớn. Miễn phí, không giới hạn số lần/ngày. Trả về
  /// false nếu ô đất trống hoặc cây đã chết (phải dọn bỏ trước).
  Future<bool> waterCrop(String studentId, int plotIndex) async {
    final ref = _db.collection('students').doc(studentId);
    return _db.runTransaction<bool>((tx) async {
      final doc = await tx.get(ref);
      final farmPlots =
          Map<String, dynamic>.from(doc.data()?['farmPlots'] ?? {});
      final key = '$plotIndex';
      if (!farmPlots.containsKey(key)) return false;
      final now = DateTime.now();
      final plot = Map<String, dynamic>.from(farmPlots[key]);
      if (FarmPlotState.fromMap(plotIndex, plot).isDead(now: now)) {
        return false;
      }
      final checkpointed = _checkpointPlot(plot, plotIndex, now);
      checkpointed['lastWateredAt'] = Timestamp.fromDate(now);
      tx.update(ref, {'farmPlots.$key': checkpointed});
      return true;
    });
  }

  /// Bón phân cho ô đất [plotIndex] — tốn [kFertilizeCostCoin] Coin, làm
  /// đầy lại Dinh dưỡng (đặt [lastFertilizedAt] = bây giờ) để cây lớn
  /// nhanh hơn 1 chút. Trả về false nếu ô đất trống, cây đã chết, hoặc
  /// không đủ Coin.
  Future<bool> fertilizeCrop(String studentId, int plotIndex) async {
    final ref = _db.collection('students').doc(studentId);
    return _db.runTransaction<bool>((tx) async {
      final doc = await tx.get(ref);
      final data = doc.data() ?? {};
      final farmPlots = Map<String, dynamic>.from(data['farmPlots'] ?? {});
      final key = '$plotIndex';
      if (!farmPlots.containsKey(key)) return false;
      final now = DateTime.now();
      final plot = Map<String, dynamic>.from(farmPlots[key]);
      if (FarmPlotState.fromMap(plotIndex, plot).isDead(now: now)) {
        return false;
      }
      final coinInfinite = data['coinInfinite'] ?? false;
      final currentCoin = (data['coin'] ?? 0) as int;
      if (!coinInfinite && currentCoin < kFertilizeCostCoin) return false;
      final checkpointed = _checkpointPlot(plot, plotIndex, now);
      checkpointed['lastFertilizedAt'] = Timestamp.fromDate(now);
      tx.update(ref, {
        if (!coinInfinite) 'coin': currentCoin - kFertilizeCostCoin,
        'farmPlots.$key': checkpointed,
      });
      return true;
    });
  }

  /// Thu hoạch ô đất [plotIndex] đã lớn hoàn toàn — xoá cây khỏi ô. Nếu
  /// là Hoa thì cộng Coin/Gem; nếu là Trái cây thì cộng vào `foodInventory`
  /// (dùng chung kho đồ ăn với FoodCatalog, id = [cropId]) để cho pet ăn
  /// sau — luôn cộng đủ dù đang bật vô hạn, giống [claimMiniGameReward].
  /// Trả về false nếu ô đất trống, cây chưa chín, hoặc đã chết.
  Future<bool> harvestCrop(
    String studentId,
    int plotIndex, {
    int coinReward = 0,
    int gemReward = 0,
    bool isFruit = false,
  }) async {
    final ref = _db.collection('students').doc(studentId);
    final friendship = await _friendshipOfStudent(studentId);
    coinReward = friendship.boostCoin(coinReward);
    gemReward = friendship.boostGem(gemReward);
    return _db.runTransaction<bool>((tx) async {
      final doc = await tx.get(ref);
      final data = doc.data() ?? {};
      final farmPlots = Map<String, dynamic>.from(data['farmPlots'] ?? {});
      final key = '$plotIndex';
      if (!farmPlots.containsKey(key)) return false;
      final plot = FarmPlotState.fromMap(
          plotIndex, Map<String, dynamic>.from(farmPlots[key]));
      if (!plot.isReady()) return false;
      final currentCoin = (data['coin'] ?? 0) as int;
      final currentGem = (data['gem'] ?? 0) as int;
      tx.update(ref, {
        'farmPlots.$key': FieldValue.delete(),
        if (isFruit) 'foodInventory.${plot.cropId}': FieldValue.increment(1),
        if (!isFruit) 'coin': currentCoin + coinReward,
        if (!isFruit && gemReward != 0) 'gem': currentGem + gemReward,
      });
      return true;
    });
  }

  /// Dọn bỏ 1 ô đất có cây ĐÃ CHẾT (do quên tưới quá lâu) để trồng lại từ
  /// đầu — không có thưởng gì. Trả về false nếu ô đất trống hoặc cây vẫn
  /// còn sống (chưa tới lúc chết).
  Future<bool> clearDeadPlot(String studentId, int plotIndex) async {
    final ref = _db.collection('students').doc(studentId);
    return _db.runTransaction<bool>((tx) async {
      final doc = await tx.get(ref);
      final farmPlots =
          Map<String, dynamic>.from(doc.data()?['farmPlots'] ?? {});
      final key = '$plotIndex';
      if (!farmPlots.containsKey(key)) return false;
      final plot = FarmPlotState.fromMap(
          plotIndex, Map<String, dynamic>.from(farmPlots[key]));
      if (!plot.isDead()) return false;
      tx.update(ref, {'farmPlots.$key': FieldValue.delete()});
      return true;
    });
  }

  /// Mở khoá thêm 1 ô đất nông trại theo đúng thứ tự — trừ Coin theo giá
  /// tương ứng trong [kFarmUnlockCosts]. Trả về false nếu không đủ Coin
  /// hoặc đã mở hết [kFarmMaxPlots] ô.
  Future<bool> unlockFarmPlot(String studentId, int costCoin) async {
    final ref = _db.collection('students').doc(studentId);
    return _db.runTransaction<bool>((tx) async {
      final doc = await tx.get(ref);
      final data = doc.data() ?? {};
      final unlocked = (data['farmPlotsUnlocked'] ?? kFarmFreePlots) as int;
      if (unlocked >= kFarmMaxPlots) return false;
      final coinInfinite = data['coinInfinite'] ?? false;
      final currentCoin = (data['coin'] ?? 0) as int;
      if (!coinInfinite && currentCoin < costCoin) return false;
      tx.update(ref, {
        if (!coinInfinite) 'coin': currentCoin - costCoin,
        'farmPlotsUnlocked': unlocked + 1,
      });
      return true;
    });
  }

  // ---------- THỐNG KÊ LỚP HỌC (DASHBOARD GIÁO VIÊN) ----------

  /// Điểm trung bình (%) của cả lớp, tính từ TOÀN BỘ lượt làm bài
  /// (`examResults`) của các học sinh trong lớp — dùng cho ô "Điểm TB" ở
  /// Dashboard giáo viên. Trả về null nếu lớp chưa có học sinh nào làm bài.
  /// Đây là Future (gọi 1 lần), không phải Stream, vì phải quét nhiều lượt
  /// làm bài — nên gọi lại thủ công (vd nút làm mới) thay vì theo dõi realtime.
  Future<double?> computeClassAverageAccuracy(List<String> studentIds) async {
    if (studentIds.isEmpty) return null;
    var totalCorrect = 0;
    var totalQuestions = 0;
    for (var i = 0; i < studentIds.length; i += 30) {
      final batch = studentIds.sublist(
          i, i + 30 > studentIds.length ? studentIds.length : i + 30);
      final snap = await _db
          .collection('examResults')
          .where('studentId', whereIn: batch)
          .get();
      for (final d in snap.docs) {
        totalCorrect += (d.data()['correctCount'] as num?)?.toInt() ?? 0;
        totalQuestions += (d.data()['totalQuestions'] as num?)?.toInt() ?? 0;
      }
    }
    if (totalQuestions == 0) return null;
    return totalCorrect / totalQuestions * 100;
  }

  // ---------- BẢNG XẾP HẠNG ----------

  /// 3 chỉ số có thể xếp hạng — khớp tên field trên document `students`.
  /// 'petLevel' xếp kèm tie-break theo petLevelUpAt (ai lên cấp đó trước
  /// thắng); 'coin'/'gem' xếp giảm dần đơn thuần theo số dư hiện có.
  static const List<String> leaderboardMetrics = ['petLevel', 'coin', 'gem'];

  /// 4 phạm vi BXH: lớp (theo classId) / trường (theo schoolName — hệ
  /// thống KHÔNG có schoolId thật vì trường chỉ là text tự nhập, xem
  /// [SchoolService]) / tỉnh (theo provinceCode) / toàn quốc (không lọc).
  ///
  /// LƯU Ý: cần tạo composite index trên Firestore cho collection
  /// `students` ứng với mỗi tổ hợp (scopeField asc, metric desc[, `+
  /// petLevelUpAt asc` nếu metric là petLevel]) — Firestore sẽ tự báo lỗi
  /// kèm link để tạo index khi chạy lần đầu, chỉ cần bấm vào.
  Stream<List<StudentModel>> watchLeaderboard({
    String metric = 'petLevel',
    String? scopeField,
    Object? scopeValue,
    int limit = 20,
  }) {
    assert(leaderboardMetrics.contains(metric));
    Query<Map<String, dynamic>> query = _db.collection('students');
    if (scopeField != null && scopeValue != null) {
      query = query.where(scopeField, isEqualTo: scopeValue);
    }
    query = query.orderBy(metric, descending: true);
    if (metric == 'petLevel') {
      query = query.orderBy('petLevelUpAt', descending: false);
    }
    // Chỉ hiện học sinh đã đạt mức Thân thiết V (showOnLeaderboard). Lọc phía
    // client để KHÔNG đổi yêu cầu composite index của Firestore → lấy dư
    // bản ghi rồi cắt còn [limit].
    query = query.limit((limit * 5).clamp(limit, 200).toInt());

    return query.snapshots().map(
          (snap) => snap.docs
              .map((d) => StudentModel.fromMap(d.id, d.data()))
              .where((s) => s.showOnLeaderboard)
              .take(limit)
              .toList(),
        );
  }

  /// CHẠY 1 LẦN (migration) cho các tài khoản được tạo TRƯỚC khi có
  /// petLevel/petLevelUpAt trên document student — nếu không chạy, những
  /// tài khoản này sẽ không hiện trong BXH vì Firestore loại bỏ hẳn các
  /// document thiếu field đang orderBy.
  ///
  /// Quét toàn bộ collection `students`, với mỗi học sinh có `petId` thì
  /// đọc cấp độ pet hiện tại và ghi lại lên student (chỉ ghi nếu đang
  /// thiếu/lệch). Trả về số tài khoản đã được cập nhật.
  ///
  /// Cách dùng: gọi 1 lần (ví dụ từ 1 nút bấm tạm thời trong lúc dev), sau
  /// đó có thể bỏ nút đi — các lần lên cấp tiếp theo sẽ tự đồng bộ như
  /// bình thường, không cần chạy lại hàm này nữa.
  Future<int> backfillPetLevelsForAllStudents() async {
    final studentsSnap = await _db.collection('students').get();
    var updatedCount = 0;

    for (final studentDoc in studentsSnap.docs) {
      final data = studentDoc.data();
      final petId = data['petId'] as String?;
      if (petId == null) continue;

      final hasLevel = data['petLevel'] != null;
      final hasLevelUpAt = data['petLevelUpAt'] != null;
      if (hasLevel && hasLevelUpAt) continue; // đã đồng bộ rồi, bỏ qua

      final petDoc = await _db.collection('pets').doc(petId).get();
      if (!petDoc.exists) continue;
      final pet = PetModel.fromMap(petId, petDoc.data()!);

      await studentDoc.reference.update({
        'petLevel': pet.level,
        // Không có mốc thời gian lên cấp thật của các tài khoản cũ này,
        // nên tạm dùng thời điểm chạy migration làm mốc tie-break.
        'petLevelUpAt': data['petLevelUpAt'] ?? Timestamp.now(),
      });
      updatedCount++;
    }

    return updatedCount;
  }

  // ---------- SHOP ----------

  Stream<StudentModel?> watchStudent(String studentId) {
    return _db.collection('students').doc(studentId).snapshots().map(
          (doc) =>
              doc.exists ? StudentModel.fromMap(doc.id, doc.data()!) : null,
        );
  }

  Stream<List<Map<String, dynamic>>> watchShopItems() {
    return _db.collection('items').snapshots().map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }

  Future<void> purchaseItem({
    required String studentId,
    required String itemId,
    required int priceCoin,
  }) async {
    await _db.runTransaction((tx) async {
      final studentRef = _db.collection('students').doc(studentId);
      final studentDoc = await tx.get(studentRef);
      final currentCoin = studentDoc.data()?['coin'] ?? 0;
      final coinInfinite = studentDoc.data()?['coinInfinite'] ?? false;

      if (!coinInfinite && currentCoin < priceCoin) {
        throw Exception('Không đủ Coin để mua vật phẩm này');
      }

      tx.update(studentRef, {
        if (!coinInfinite) 'coin': currentCoin - priceCoin,
        'inventory': FieldValue.arrayUnion([itemId]),
      });
    });
  }

  /// Mặc/tháo vật phẩm cho pet — item phải nằm trong inventory (đã mua) trước đó.
  Future<void> toggleEquipItem(String petId, String itemId, bool equip) async {
    await _db.collection('pets').doc(petId).update({
      'equippedItemIds': equip
          ? FieldValue.arrayUnion([itemId])
          : FieldValue.arrayRemove([itemId]),
    });
  }
}
enum SkinBoxError { notEnoughGems, missingData }

class SkinBoxException implements Exception {
  final SkinBoxError error;
  const SkinBoxException(this.error);
  @override
  String toString() => 'SkinBoxException($error)';
}

/// Kết quả 1 lần mở Hộp mù Skin.
class SkinBoxResult {
  final PetSkin skin;
  final bool isDuplicate;

  /// Coin đền bù khi trùng skin (0 nếu skin mới).
  final int coinRefund;

  const SkinBoxResult({
    required this.skin,
    required this.isDuplicate,
    required this.coinRefund,
  });
}
