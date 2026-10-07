import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';

/// Thông báo ĐẨY THẬT (push notification) qua Firebase Cloud Messaging
/// (FCM) — thay thế hoàn toàn kiểu banner-chỉ-hiện-khi-đang-mở-app cũ
/// (xem lịch sử ở NotificationSettingsScreen). 4 loại được server (Cloud
/// Functions, thư mục `functions/`) gửi tới:
///  - "streak": nhắc giữ streak nếu quá 6 tiếng mỗi ngày vẫn chưa học
///    (không gửi nếu hôm đó đã học rồi).
///  - "levelUp": khi pet lên cấp độ mới.
///  - "achievement": khi mở khoá huy hiệu/thành tích mới (badgeIds).
///  - "update": tin tức/cập nhật chung của app, gửi qua topic
///    'app_updates' (không gắn riêng theo học sinh).
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'edupet_default',
    'PetMath — Thông báo',
    description:
        'Nhắc giữ streak, pet lên cấp, thành tích mới, cập nhật app',
    importance: Importance.high,
  );

  /// Gọi 1 LẦN lúc app khởi động (trong main(), TRƯỚC runApp) — chỉ dựng
  /// kênh thông báo cục bộ + lắng nghe thông báo tới khi app đang mở.
  /// CHƯA xin quyền/lấy token ở đây vì lúc này có thể chưa biết học sinh
  /// nào đăng nhập (xem [registerForStudent]).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Thông báo tới khi app đang MỞ (foreground) KHÔNG tự hiện banner hệ
    // thống như lúc app ở nền/đã tắt — phải tự hiển thị bằng
    // flutter_local_notifications.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'edupet_default',
          'PetMath — Thông báo',
          channelDescription:
              'Nhắc giữ streak, pet lên cấp, thành tích mới, cập nhật app',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Gọi sau khi biết [studentId] (ngay sau đăng nhập/đăng ký thành công,
  /// xem StudentHomeScreen) — xin quyền thông báo, lấy FCM token của máy
  /// và lưu vào `students/{studentId}.fcmToken` để Cloud Functions gửi
  /// đúng máy, đồng thời đăng ký topic 'app_updates' cho thông báo cập
  /// nhật chung của app.
  Future<void> registerForStudent(String studentId) async {
    try {
      final settings = await _messaging.requestPermission(
          alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return; // học sinh/phụ huynh từ chối quyền — tôn trọng, không ép.
      }

      final token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('students')
            .doc(studentId)
            .update({'fcmToken': token});
      }
      await _messaging.subscribeToTopic('app_updates');

      // Token có thể đổi (gỡ cài lại app, đổi máy, xoá dữ liệu app...) —
      // lắng nghe để cập nhật lại, tránh gửi vào token cũ đã hết hạn.
      _messaging.onTokenRefresh.listen((newToken) {
        FirebaseFirestore.instance
            .collection('students')
            .doc(studentId)
            .update({'fcmToken': newToken}).catchError((_) {});
      });
    } catch (e) {
      debugPrint('Lỗi đăng ký push notification: $e');
    }
  }

  /// Bật/tắt nhận thông báo "update" (tin tức chung của app) — tách riêng
  /// khỏi 3 loại còn lại (streak/levelUp/achievement) vì gửi qua TOPIC
  /// chung chứ không theo từng token, nên cần subscribe/unsubscribe thay
  /// vì chỉ lưu cờ bật/tắt trong Firestore.
  Future<void> setUpdateTopicEnabled(bool enabled) async {
    if (enabled) {
      await _messaging.subscribeToTopic('app_updates');
    } else {
      await _messaging.unsubscribeFromTopic('app_updates');
    }
  }

  /// Gọi khi đăng xuất — bỏ token khỏi hồ sơ (tránh gửi nhầm cho tài
  /// khoản đã đăng xuất, vd máy dùng chung nhiều học sinh) và huỷ topic.
  Future<void> unregister(String studentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .update({'fcmToken': FieldValue.delete()});
      await _messaging.unsubscribeFromTopic('app_updates');
      await _messaging.deleteToken();
    } catch (_) {
      // Bỏ qua lỗi mạng lúc đăng xuất — không chặn luồng đăng xuất chính.
    }
  }
}

/// Xử lý thông báo đến khi app đang ở NỀN hoặc đã TẮT HẲN. Bắt buộc là
/// hàm TOP-LEVEL (không phải method trong class) + đánh dấu
/// @pragma('vm:entry-point') để Flutter engine gọi được dù app chưa
/// khởi động (chạy trong 1 background isolate riêng, phải tự
/// Firebase.initializeApp() lại vì không dùng chung isolate với main()).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);
  // Không cần xử lý gì thêm — hệ điều hành tự hiển thị thông báo hệ
  // thống dựa theo field "notification" trong payload khi app ở nền/đã
  // tắt, miễn Cloud Functions gửi kèm field đó (xem functions/index.js).
}
