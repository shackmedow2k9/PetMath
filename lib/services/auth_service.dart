import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';
import '../models/teacher_model.dart';

/// Xử lý 4 quyền đăng nhập: Admin, Nhà sản xuất, Giáo viên, Học sinh
/// Vai trò được lưu trong custom claims / field 'role' trên Firestore.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Đăng ký tài khoản học sinh mới. Sau khi đăng ký, học sinh sẽ
  /// được chuyển sang màn hình "Chọn thú cưng" (chưa gán petId).
  Future<StudentModel> registerStudent({
    required String email,
    required String password,
    required String fullName,
    int? provinceCode,
    String? provinceName,
    int? wardCode,
    String? wardName,
    String? schoolName,
    int? grade,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;
    final student = StudentModel(
      uid: uid,
      fullName: fullName,
      email: email,
      createdAt: DateTime.now(),
      provinceCode: provinceCode,
      provinceName: provinceName,
      wardCode: wardCode,
      wardName: wardName,
      schoolName: schoolName,
      grade: grade,
    );

    await _db.collection('students').doc(uid).set(student.toMap());
    await credential.user!.updateDisplayName(fullName);

    return student;
  }

  /// Đăng ký tài khoản giáo viên mới (lưu ở collection riêng 'teachers').
  Future<TeacherModel> registerTeacher({
    required String email,
    required String password,
    required String fullName,
    int? provinceCode,
    String? provinceName,
    int? wardCode,
    String? wardName,
    String? schoolName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;
    final teacher = TeacherModel(
      uid: uid,
      fullName: fullName,
      email: email,
      createdAt: DateTime.now(),
      provinceCode: provinceCode,
      provinceName: provinceName,
      wardCode: wardCode,
      wardName: wardName,
      schoolName: schoolName,
    );

    await _db.collection('teachers').doc(uid).set(teacher.toMap());
    await credential.user!.updateDisplayName(fullName);

    return teacher;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// Lấy vai trò của user hiện tại để điều hướng đúng cổng
  /// (Admin / Nhà sản xuất / Giáo viên / Học sinh).
  Future<String> getUserRole(String uid) async {
    // Chỉ Học sinh/Giáo viên đăng ký qua app này (Admin/Nhà sản xuất được
    // tạo riêng), và rule Firestore chỉ cho phép đọc 'admins'/'producers'
    // khi có custom claim role=admin. Vì vậy mỗi lần đọc phải tự bắt lỗi
    // permission-denied, nếu không sẽ ném exception ra ngoài stream
    // listener và làm kẹt màn hình đăng nhập/đăng ký mãi mãi.
    for (final collection in ['admins', 'producers', 'teachers', 'students']) {
      try {
        final doc = await _db.collection(collection).doc(uid).get();
        if (doc.exists) {
          return collection; // dùng luôn tên collection làm role
        }
      } catch (e) {
        // Không có quyền đọc collection này (ví dụ 'admins'/'producers')
        // -> coi như user không thuộc collection đó, thử collection tiếp theo.
        continue;
      }
    }
    return 'unknown';
  }

  Future<StudentModel?> getStudent(String uid) async {
    final doc = await _db.collection('students').doc(uid).get();
    if (!doc.exists) return null;
    return StudentModel.fromMap(uid, doc.data()!);
  }

  /// Đổi tên hiển thị — cập nhật cả Firestore (`students.fullName`, nguồn
  /// hiển thị chính trong app) lẫn Firebase Auth `displayName` (để đồng
  /// nhất nếu sau này có nơi khác đọc trực tiếp từ Auth).
  Future<void> updateFullName(String uid, String newName) async {
    await _db.collection('students').doc(uid).update({'fullName': newName});
    await _auth.currentUser?.updateDisplayName(newName);
  }

  /// Đổi mật khẩu. Firebase Auth yêu cầu phải xác thực lại gần đây
  /// (reauthenticate) trước khi cho đổi mật khẩu, nên cần nhập lại mật
  /// khẩu hiện tại — nếu không sẽ gặp lỗi `requires-recent-login`.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Không tìm thấy tài khoản đang đăng nhập.');
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  /// Bổ sung/cập nhật hồ sơ (khối lớp + địa chỉ + trường) cho các tài
  /// khoản học sinh được tạo TRƯỚC khi có các trường này — dùng ở
  /// CompleteProfileScreen, chỉ hiện 1 lần (xem [StudentModel.grade]).
  Future<void> completeStudentProfile({
    required String uid,
    required int grade,
    required int provinceCode,
    required String provinceName,
    required int wardCode,
    required String wardName,
    String? schoolName,
  }) async {
    await _db.collection('students').doc(uid).update({
      'grade': grade,
      'provinceCode': provinceCode,
      'provinceName': provinceName,
      'wardCode': wardCode,
      'wardName': wardName,
      'schoolName': schoolName,
    });
  }

  Future<TeacherModel?> getTeacher(String uid) async {
    final doc = await _db.collection('teachers').doc(uid).get();
    if (!doc.exists) return null;
    return TeacherModel.fromMap(uid, doc.data()!);
  }
}
