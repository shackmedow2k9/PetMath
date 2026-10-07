import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'l10n/gen/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/pet_provider.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Đăng ký handler xử lý thông báo đẩy khi app ở nền/đã tắt — PHẢI đăng
  // ký ở top-level main(), trước runApp(), theo đúng yêu cầu của
  // firebase_messaging.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await NotificationService().init();
  final localeProvider = LocaleProvider();
  await localeProvider.loadSavedLocale();
  runApp(EduPetApp(localeProvider: localeProvider));
}

class EduPetApp extends StatelessWidget {
  final LocaleProvider localeProvider;
  const EduPetApp({super.key, required this.localeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PetProvider()),
        ChangeNotifierProvider.value(value: localeProvider),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, locale, _) => MaterialApp(
          title: 'PetMath',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: locale.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Đổi ngôn ngữ → dựng lại TOÀN BỘ cây widget một lần để cả những chỗ
          // dịch bằng tr() (hint, nhãn...) cũng cập nhật ngay, không cần mở lại màn.
          builder: (context, child) => _RebuildOnLocaleChange(
              languageCode: locale.locale.languageCode,
              child: child ?? const SizedBox.shrink()),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}

/// Khi [languageCode] đổi, đánh dấu mọi Element trong cây là "cần dựng lại".
class _RebuildOnLocaleChange extends StatefulWidget {
  final String languageCode;
  final Widget child;
  const _RebuildOnLocaleChange(
      {required this.languageCode, required this.child});

  @override
  State<_RebuildOnLocaleChange> createState() => _RebuildOnLocaleChangeState();
}

class _RebuildOnLocaleChangeState extends State<_RebuildOnLocaleChange> {
  @override
  void didUpdateWidget(covariant _RebuildOnLocaleChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.languageCode != widget.languageCode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        void rebuild(Element el) {
          el.markNeedsBuild();
          el.visitChildren(rebuild);
        }

        (context as Element).visitChildren(rebuild);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
