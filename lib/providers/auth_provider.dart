import 'package:flutter/foundation.dart';
import '../models/student_model.dart';
import '../models/teacher_model.dart';
import '../models/achievement_catalog.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Vai trò chọn lúc đăng ký. Admin / Nhà sản xuất không đăng ký qua app này.
enum RegisterRole { student, teacher }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  AuthStatus status = AuthStatus.unknown;
  StudentModel? currentStudent;
  TeacherModel? currentTeacher;
  String? errorMessage;
  bool isLoading = false;

  // Thành tựu VỪA được mở khoá ở lần [refreshCurrentStudent] gần nhất —
  // UI (vd ExamResultScreen) đọc rồi tự xoá (xem [consumeNewlyUnlocked])
  // để hiện popup ăn mừng đúng 1 lần, không hiện lặp lại ở màn hình khác.
  List<AchievementDef> newlyUnlockedAchievements = [];

  List<AchievementDef> consumeNewlyUnlocked() {
    final result = newlyUnlockedAchievements;
    newlyUnlockedAchievements = [];
    return result;
  }

  AuthProvider() {
    _authService.authStateChanges.listen((user) async {
      try {
        if (user == null) {
          status = AuthStatus.unauthenticated;
          currentStudent = null;
          currentTeacher = null;
        } else {
          final role = await _authService.getUserRole(user.uid);
          if (role == 'teachers') {
            currentTeacher = await _authService.getTeacher(user.uid);
            currentStudent = null;
          } else {
            currentStudent = await _authService.getStudent(user.uid);
            currentTeacher = null;
          }
          status = AuthStatus.authenticated;
        }
      } catch (e) {
        // Nếu có lỗi bất ngờ (vd. mất mạng, Firestore permission-denied),
        // vẫn phải gọi notifyListeners() ở dưới — nếu không, status sẽ
        // không bao giờ cập nhật và app bị kẹt mãi ở màn hình đăng nhập.
        // QUAN TRỌNG: trước đây lỗi này chỉ debugPrint (chỉ thấy trong
        // console F12/terminal) — người dùng KHÔNG thấy gì cả, giống hệt
        // hiện tượng "bấm đăng nhập xong không có phản ứng gì" dù thật ra
        // email/mật khẩu đã đúng, chỉ là bước tải hồ sơ sau đó bị lỗi. Nay
        // lưu vào [errorMessage] để LoginScreen hiển thị được cho người
        // dùng thấy rõ nguyên nhân thay vì chỉ im lặng quay lại màn đăng nhập.
        debugPrint('Lỗi khi xác định trạng thái đăng nhập: $e');
        errorMessage =
            'Đăng nhập thành công nhưng không tải được hồ sơ tài khoản.\n'
            'Chi tiết lỗi: $e';
        status = AuthStatus.unauthenticated;
        currentStudent = null;
        currentTeacher = null;
      }
      notifyListeners();
    });
  }

  Future<bool> login(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _authService.signIn(email: email, password: password);
      return true;
    } catch (e) {
      debugPrint('Lỗi đăng nhập: $e');
      errorMessage = _mapError(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    required RegisterRole role,
    int? provinceCode,
    String? provinceName,
    int? wardCode,
    String? wardName,
    String? schoolName,
    int? grade,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      if (role == RegisterRole.teacher) {
        currentTeacher = await _authService.registerTeacher(
          email: email,
          password: password,
          fullName: fullName,
          provinceCode: provinceCode,
          provinceName: provinceName,
          wardCode: wardCode,
          wardName: wardName,
          schoolName: schoolName,
        );
        currentStudent = null;
      } else {
        currentStudent = await _authService.registerStudent(
          email: email,
          password: password,
          fullName: fullName,
          provinceCode: provinceCode,
          provinceName: provinceName,
          wardCode: wardCode,
          wardName: wardName,
          schoolName: schoolName,
          grade: grade,
        );
        currentTeacher = null;
      }
      return true;
    } catch (e) {
      // In lỗi thật ra console để debug (xem bằng F12 > Console trên web,
      // hoặc terminal `flutter run` trên mobile/desktop).
      debugPrint('Lỗi đăng ký: $e');
      errorMessage = _mapError(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() => _authService.signOut();

  /// Nạp lại dữ liệu học sinh MỚI NHẤT từ Firestore và cập nhật vào
  /// [currentStudent]. Cần gọi sau bất kỳ thao tác nào làm thay đổi dữ liệu
  /// học sinh ở phía server (nộp bài, cho ăn, đổi streak...) mà không đi
  /// qua [currentStudent] trực tiếp — vì [currentStudent] chỉ được nạp 1
  /// lần lúc đăng nhập (không phải stream), nên sẽ bị "cũ" nếu không gọi
  /// lại hàm này, khiến giao diện hiển thị sai (vd. streak/coin không tăng
  /// dù đã cộng thành công ở Firestore).
  Future<void> refreshCurrentStudent() async {
    final uid = currentStudent?.uid;
    if (uid == null) return;
    final fresh = await _authService.getStudent(uid);
    if (fresh != null) {
      // Kiểm tra thành tựu mới NGAY khi có dữ liệu mới nhất — trung tâm
      // hoá ở đây (thay vì rải rác ở từng màn hình) vì hàm này vốn đã
      // được gọi sau MỌI hành động có thể làm thay đổi số liệu học sinh
      // (nộp bài, streak, cho ăn/tắm/ngủ pet...).
      final unlocked = await _firestoreService.checkAndAwardAchievements(fresh);
      currentStudent = unlocked.isEmpty
          ? fresh
          : fresh.copyWith(
              badgeIds: [...fresh.badgeIds, ...unlocked.map((d) => d.id)]);
      if (unlocked.isNotEmpty) {
        newlyUnlockedAchievements = [
          ...newlyUnlockedAchievements,
          ...unlocked,
        ];
      }
      notifyListeners();
    }
  }

  /// Dùng ở CompleteProfileScreen — bổ sung khối lớp/địa chỉ/trường 1 LẦN
  /// cho các tài khoản học sinh cũ (tạo trước khi có các trường này), rồi
  /// nạp lại [currentStudent] để SplashScreen không hiện lại màn đó nữa.
  Future<bool> completeStudentProfile({
    required int grade,
    required int provinceCode,
    required String provinceName,
    required int wardCode,
    required String wardName,
    String? schoolName,
  }) async {
    final uid = currentStudent?.uid;
    if (uid == null) return false;
    isLoading = true;
    notifyListeners();
    try {
      await _authService.completeStudentProfile(
        uid: uid,
        grade: grade,
        provinceCode: provinceCode,
        provinceName: provinceName,
        wardCode: wardCode,
        wardName: wardName,
        schoolName: schoolName,
      );
      await refreshCurrentStudent();
      return true;
    } catch (e) {
      debugPrint('Lỗi bổ sung hồ sơ: $e');
      errorMessage = _mapError(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Đổi tên hiển thị — cập nhật cả Firestore/Auth và [currentStudent].
  Future<void> updateFullName(String newName) async {
    final uid = currentStudent?.uid;
    if (uid == null) return;
    await _authService.updateFullName(uid, newName);
    currentStudent = currentStudent?.copyWith(fullName: newName);
    notifyListeners();
  }

  /// Đổi mật khẩu — ném lỗi (FirebaseAuthException) nếu mật khẩu hiện tại
  /// sai hoặc mật khẩu mới quá yếu, để UI tự bắt và hiển thị thông báo.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _authService.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// Nạp (và tự tạo nếu chưa có) hồ sơ pet của CHÍNH giáo viên đang đăng
  /// nhập, lưu tạm vào [currentStudent] để tái dùng nguyên vẹn PetHomeScreen/
  /// ShopScreen/MinigameHubScreen/LeaderboardScreen vốn được viết cho học
  /// sinh — xem [FirestoreService.ensureTeacherPetProfile].
  Future<void> loadTeacherPetProfile() async {
    final teacher = currentTeacher;
    if (teacher == null) return;
    final profile = await FirestoreService().ensureTeacherPetProfile(teacher);
    currentStudent = profile;
    notifyListeners();
  }

  String _mapError(Object e) {
    final msg = e.toString();
    if (msg.contains('email-already-in-use'))
      return 'Email này đã được sử dụng';
    if (msg.contains('weak-password'))
      return 'Mật khẩu quá yếu (tối thiểu 6 ký tự)';
    if (msg.contains('user-not-found') || msg.contains('wrong-password')) {
      return 'Email hoặc mật khẩu không đúng';
    }
    if (msg.contains('invalid-email')) return 'Email không hợp lệ';
    return 'Đã có lỗi xảy ra, vui lòng thử lại';
  }
}
