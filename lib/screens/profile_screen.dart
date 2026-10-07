import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../widgets/pet_blob_frame.dart';
import '../widgets/tr_text.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:provider/provider.dart';
import '../widgets/emoji_icon.dart';
import '../l10n/gen/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/pet_provider.dart';
import '../models/student_model.dart';
import '../models/class_model.dart';
import '../models/achievement_catalog.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/language_menu_button.dart';
import 'login_screen.dart';
import 'notification_settings_screen.dart';
import 'achievements_screen.dart';
import '../models/pet_model.dart';
import '../models/pet_family_catalog.dart';

/// Màn hình hồ sơ / menu người dùng — mở ra khi chạm vào avatar pet ở
/// màn hình chính. Hiển thị thông tin học sinh + các tùy chọn tài khoản.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final petProvider = context.watch<PetProvider>();
    final student = auth.currentStudent;
    final pet = petProvider.pet;
    final l10n = AppLocalizations.of(context)!;

    return ScreenScaffold(bg: BgKind.light, 
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: student == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header: avatar pet + tên học sinh + email
                  Center(
                    child: Column(
                      children: [
                        // Ảnh pet trong khung ic_profile_blob (giống ảnh minh họa).
                        pet == null
                            ? const Icon(Icons.pets,
                                size: 60, color: AppColors.primary)
                            : PetBlobFrame(width: 170, petAsset: pet.idleAsset),
                        const SizedBox(height: 12),
                        Text(student.fullName,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(student.email,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                        if (pet != null) ...[
                          const SizedBox(height: 4),
                          Text(
                              '${pet.name} · ${pet.species.displayName} · Lv.${pet.level}',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Thống kê nhanh: Coin / Gem / Streak / Level pet
                  Row(
                    children: [
                      Expanded(
                          child: _StatBox(
                              emoji: '🪙',
                              label: 'Coin',
                              value: student.coinDisplay)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _StatBox(
                              emoji: '💎',
                              label: 'Gem',
                              value: student.gemDisplay)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _StatBox(
                              emoji: '🔥',
                              label: 'Streak',
                              value: l10n.streakDays(student.displayStreak))),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(l10n.accountSection,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _MenuCard(
                    children: [
                      _MenuTile(
                        icon: Icons.edit_outlined,
                        label: l10n.changeDisplayName,
                        onTap: () => _showChangeNameDialog(context, student),
                      ),
                      _MenuTile(
                        icon: Icons.lock_outline,
                        label: l10n.changePassword,
                        onTap: () => _showChangePasswordDialog(context),
                      ),
                      _MenuTile(
                        icon: Icons.school_outlined,
                        label: l10n.myClass,
                        subtitle: student.classId != null
                            ? l10n.myClassJoined
                            : l10n.myClassNotJoined,
                        onTap: () => _showJoinClassDialog(context, student),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(l10n.otherSection,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _MenuCard(
                    children: [
                      _MenuTile(
                        icon: Icons.emoji_events_outlined,
                        label: l10n.achievements,
                        subtitle: l10n.achievementsUnlocked(
                            student.badgeIds.length,
                            AchievementCatalog.all.length),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const AchievementsScreen()),
                        ),
                      ),
                      _MenuTile(
                        icon: Icons.notifications_outlined,
                        label: l10n.notifications,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const NotificationSettingsScreen()),
                        ),
                      ),
                      const LanguageListTile(),
                      _MenuTile(
                        icon: Icons.info_outline,
                        label: l10n.aboutEdupet,
                        onTap: () => _showAboutDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  OutlinedButton.icon(
                    onPressed: () => _confirmLogout(context),
                    icon: const Icon(Icons.logout, color: AppColors.danger),
                    label: Text(l10n.logout,
                        style: const TextStyle(color: AppColors.danger)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      side: const BorderSide(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'PetMath',
      applicationVersion: '0.1.0',
      applicationLegalese: 'Learn · Play · Grow',
    );
  }

  void _showChangeNameDialog(BuildContext context, StudentModel student) {
    showDialog(
      context: context,
      builder: (_) => _ChangeNameDialog(currentName: student.fullName),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
  }

  void _showJoinClassDialog(BuildContext context, StudentModel student) {
    showDialog(
      context: context,
      builder: (_) => _JoinClassDialog(student: student),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.logout,
                style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final uid = context.read<AuthProvider>().currentStudent?.uid;
      if (uid != null) {
        await NotificationService().unregister(uid);
      }
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}

class _StatBox extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _StatBox(
      {required this.emoji, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          EmojiIcon(emoji, size: 32),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}

/// Dialog đổi tên hiển thị.
class _ChangeNameDialog extends StatefulWidget {
  final String currentName;
  const _ChangeNameDialog({required this.currentName});

  @override
  State<_ChangeNameDialog> createState() => _ChangeNameDialogState();
}

class _ChangeNameDialogState extends State<_ChangeNameDialog> {
  late final _controller = TextEditingController(text: widget.currentName);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newName = _controller.text.trim();
    final l10n = AppLocalizations.of(context)!;
    if (newName.isEmpty) {
      setState(() => _error = l10n.nameEmptyError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().updateFullName(newName);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = l10n.genericError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.changeNameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        decoration: InputDecoration(
          hintText: l10n.nameHint,
          errorText: _error,
        ),
        enabled: !_saving,
        onSubmitted: (_) => _saving ? null : _save(),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}

/// Dialog đổi mật khẩu — cần nhập mật khẩu hiện tại để xác thực lại
/// (Firebase yêu cầu đăng nhập gần đây trước khi cho đổi mật khẩu).
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final current = _currentController.text;
    final newPass = _newController.text;
    final confirm = _confirmController.text;
    final l10n = AppLocalizations.of(context)!;

    if (current.isEmpty) {
      setState(() => _error = l10n.currentPasswordEmptyError);
      return;
    }
    if (newPass.length < 6) {
      setState(() => _error = l10n.newPasswordTooShortError);
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = l10n.passwordMismatchError);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().changePassword(
            currentPassword: current,
            newPassword: newPass,
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.changePasswordSuccess)),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mapPasswordError(e, l10n));
    } catch (e) {
      setState(() => _error = l10n.genericError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _mapPasswordError(FirebaseAuthException e, AppLocalizations l10n) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return l10n.wrongCurrentPasswordError;
      case 'weak-password':
        return l10n.weakNewPasswordError;
      case 'requires-recent-login':
        return l10n.sessionExpiredError;
      case 'too-many-requests':
        return l10n.tooManyAttemptsError;
      default:
        return l10n.genericAuthError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.changePasswordTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _currentController,
            obscureText: true,
            enabled: !_saving,
            decoration: InputDecoration(labelText: l10n.currentPasswordLabel),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newController,
            obscureText: true,
            enabled: !_saving,
            decoration: InputDecoration(labelText: l10n.newPasswordLabel),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmController,
            obscureText: true,
            enabled: !_saving,
            decoration:
                InputDecoration(labelText: l10n.confirmNewPasswordLabel),
            onSubmitted: (_) => _saving ? null : _save(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.save),
        ),
      ],
    );
  }
}

/// Dialog tham gia/rời lớp học bằng mã lớp do giáo viên cung cấp.
class _JoinClassDialog extends StatefulWidget {
  final StudentModel student;
  const _JoinClassDialog({required this.student});

  @override
  State<_JoinClassDialog> createState() => _JoinClassDialogState();
}

class _JoinClassDialogState extends State<_JoinClassDialog> {
  final _controller = TextEditingController();
  final _firestoreService = FirestoreService();
  bool _saving = false;
  String? _error;
  ClassModel? _currentClass;
  bool _loadingCurrentClass = false;

  @override
  void initState() {
    super.initState();
    final classId = widget.student.classId;
    if (classId != null) {
      _loadingCurrentClass = true;
      _firestoreService.getClass(classId).then((klass) {
        if (mounted) {
          setState(() {
            _currentClass = klass;
            _loadingCurrentClass = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _controller.text.trim();
    final l10n = AppLocalizations.of(context)!;
    if (code.isEmpty) {
      setState(() => _error = l10n.classCodeEmptyError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final klass =
          await _firestoreService.joinClassByCode(widget.student.uid, code);
      if (mounted) {
        final auth = context.read<AuthProvider>();
        auth.currentStudent = widget.student.copyWith(classId: klass.id);
        auth.notifyListeners();
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = l10n.invalidClassCodeError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    setState(() => _saving = true);
    try {
      await _firestoreService.leaveClass(widget.student.uid);
      if (mounted) {
        final auth = context.read<AuthProvider>();
        auth.currentStudent = widget.student.copyWith(classId: null);
        auth.notifyListeners();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context)!.genericError(e));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasClass = widget.student.classId != null;
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.myClassTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasClass
                ? (_loadingCurrentClass
                    ? l10n.loadingClassInfo
                    : l10n.currentClassInfo(
                        _currentClass?.name ?? l10n.classNotFound))
                : l10n.joinClassPrompt,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            enabled: !_saving,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: hasClass ? l10n.changeClassLabel : l10n.classCodeLabel,
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        if (hasClass)
          TextButton(
            onPressed: _saving ? null : _leave,
            child: Text(l10n.leaveClass,
                style: const TextStyle(color: AppColors.danger)),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _join,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.joinClass),
        ),
      ],
    );
  }
}
