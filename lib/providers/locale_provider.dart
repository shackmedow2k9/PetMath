import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/tr.dart';

/// Quản lý ngôn ngữ hiện tại của app (Tiếng Việt / English), lưu lựa chọn
/// của người dùng vào máy để lần mở app sau vẫn giữ đúng ngôn ngữ đã chọn.
/// null = theo ngôn ngữ máy nếu được hỗ trợ, mặc định về Tiếng Việt.
class LocaleProvider extends ChangeNotifier {
  static const _prefsKey = 'app_locale_code';

  Locale _locale = const Locale('vi');
  Locale get locale => _locale;

  Future<void> loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      if (code == 'en' || code == 'vi') {
        _locale = Locale(code!);
        Tr.lang = code;
        notifyListeners();
      }
    } catch (_) {
      // Không tải được lựa chọn cũ (VD: lần đầu mở app) — cứ giữ mặc định
      // Tiếng Việt, không chặn app khởi động.
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    Tr.lang = locale.languageCode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, locale.languageCode);
    } catch (_) {
      // Lưu thất bại thì lần sau mở app về lại mặc định — chấp nhận được,
      // không chặn việc đổi ngôn ngữ ngay trong phiên hiện tại.
    }
  }
}
