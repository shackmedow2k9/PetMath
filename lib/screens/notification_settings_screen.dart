import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Tuỳ chọn thông báo ĐẨY (push notification) thật, gửi qua Firebase
/// Cloud Messaging kể cả khi không mở app — xem [NotificationService].
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _firestoreService = FirestoreService();
  bool _saving = false;

  static const _labels = {
    'streak': (
      'Nhắc giữ streak 🔥',
      'Nhắc nếu sau 6 tiếng mỗi ngày vẫn chưa học (đã học thì không nhắc)'
    ),
    'levelUp': ('Pet lên cấp 🎉', 'Thông báo khi thú cưng tăng cấp độ'),
    'achievement': ('Thành tích 🏆', 'Thông báo khi mở khoá huy hiệu mới'),
    'update': ('Cập nhật app 📢', 'Tin tức, tính năng mới của PetMath'),
  };

  Future<void> _toggle(StudentModel student, String key, bool value) async {
    final newPrefs = Map<String, bool>.from(student.notificationPrefs);
    newPrefs[key] = value;
    setState(() => _saving = true);
    try {
      await _firestoreService.updateNotificationPrefs(student.uid, newPrefs);
      // "update" gửi qua topic chung (không theo từng token) nên cần
      // subscribe/unsubscribe riêng, khác với 3 loại còn lại (server tự
      // đọc notificationPrefs trước khi gửi theo token).
      if (key == 'update') {
        await NotificationService().setUpdateTopicEnabled(value);
      }
      if (mounted) {
        context.read<AuthProvider>().currentStudent =
            student.copyWith(notificationPrefs: newPrefs);
        context.read<AuthProvider>().notifyListeners();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Có lỗi xảy ra: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<AuthProvider>().currentStudent;

    return ScreenScaffold(bg: BgKind.cream, 
      appBar: AppBar(title: const Text('Thông báo')),
      body: student == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.info, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Đây là thông báo đẩy thật — vẫn nhận được kể cả '
                          'khi không mở app. Cần cho phép quyền thông báo '
                          'cho PetMath trong Cài đặt máy.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    children: [
                      for (final entry in _labels.entries) ...[
                        SwitchListTile(
                          title: Text(entry.value.$1),
                          subtitle: Text(entry.value.$2,
                              style: const TextStyle(fontSize: 12)),
                          value: student.notificationPrefs[entry.key] ?? true,
                          activeColor: AppColors.primary,
                          onChanged: _saving
                              ? null
                              : (v) => _toggle(student, entry.key, v),
                        ),
                        if (entry.key != _labels.keys.last)
                          const Divider(height: 1, indent: 16),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
