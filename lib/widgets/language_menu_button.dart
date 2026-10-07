import 'package:flutter/material.dart' hide Text;
import 'tr_text.dart';
import 'package:provider/provider.dart';

import '../l10n/gen/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';

/// Mở dialog cho chọn Tiếng Việt / English, áp dụng ngay lập tức toàn app
/// (không cần khởi động lại). Dùng chung cho cả [LanguageMenuButton] và
/// [LanguageListTile] để 2 kiểu hiển thị khác nhau (nút / ô danh sách)
/// không lặp lại logic.
Future<void> showLanguagePicker(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final localeProvider = context.read<LocaleProvider>();
  final current = localeProvider.locale.languageCode;

  await showDialog(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(l10n.chooseLanguageTitle),
      children: [
        _LanguageOption(
          label: l10n.vietnamese,
          selected: current == 'vi',
          onTap: () {
            localeProvider.setLocale(const Locale('vi'));
            Navigator.of(dialogContext).pop();
          },
        ),
        _LanguageOption(
          label: l10n.english,
          selected: current == 'en',
          onTap: () {
            localeProvider.setLocale(const Locale('en'));
            Navigator.of(dialogContext).pop();
          },
        ),
      ],
    ),
  );
}

String _currentLanguageLabel(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final code = context.watch<LocaleProvider>().locale.languageCode;
  return code == 'en' ? l10n.english : l10n.vietnamese;
}

/// Nút chọn ngôn ngữ dạng OutlinedButton — dùng ở Tài khoản (Giáo viên),
/// nơi các mục cài đặt hiển thị dạng nút full-width thay vì danh sách.
class LanguageMenuButton extends StatelessWidget {
  const LanguageMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return OutlinedButton.icon(
      onPressed: () => showLanguagePicker(context),
      icon: const Icon(Icons.language, color: AppColors.primary),
      label: Text('${l10n.language}: ${_currentLanguageLabel(context)}'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

/// Ô chọn ngôn ngữ dạng ListTile — dùng ở Hồ sơ (Học sinh), khớp phong
/// cách các [_MenuTile] khác trong menu "Khác".
class LanguageListTile extends StatelessWidget {
  const LanguageListTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: const Icon(Icons.language, color: AppColors.primary),
      title: Text(l10n.language),
      subtitle: Text(_currentLanguageLabel(context)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: () => showLanguagePicker(context),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleDialogOption(
      onPressed: onTap,
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? AppColors.primary : AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
