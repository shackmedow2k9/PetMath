import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi')
  ];

  /// No description provided for @cancel.
  ///
  /// In vi, this message translates to:
  /// **'Hủy'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get save;

  /// No description provided for @retry.
  ///
  /// In vi, this message translates to:
  /// **'Thử tải lại'**
  String get retry;

  /// No description provided for @loginWelcomeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chào mừng trở lại!'**
  String get loginWelcomeTitle;

  /// No description provided for @loginWelcomeSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập để tiếp tục nuôi thú cưng nhé'**
  String get loginWelcomeSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In vi, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailInvalid.
  ///
  /// In vi, this message translates to:
  /// **'Email không hợp lệ'**
  String get emailInvalid;

  /// No description provided for @passwordLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu'**
  String get passwordLabel;

  /// No description provided for @passwordTooShort.
  ///
  /// In vi, this message translates to:
  /// **'Tối thiểu 6 ký tự'**
  String get passwordTooShort;

  /// No description provided for @loginButton.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập'**
  String get loginButton;

  /// No description provided for @noAccountRegister.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tài khoản? Đăng ký ngay'**
  String get noAccountRegister;

  /// No description provided for @navPet.
  ///
  /// In vi, this message translates to:
  /// **'Nhà pet'**
  String get navPet;

  /// No description provided for @navLearn.
  ///
  /// In vi, this message translates to:
  /// **'Học tập'**
  String get navLearn;

  /// No description provided for @navShop.
  ///
  /// In vi, this message translates to:
  /// **'Cửa hàng'**
  String get navShop;

  /// No description provided for @navMinigame.
  ///
  /// In vi, this message translates to:
  /// **'Minigame'**
  String get navMinigame;

  /// No description provided for @navProfile.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ'**
  String get navProfile;

  /// No description provided for @navClasses.
  ///
  /// In vi, this message translates to:
  /// **'Lớp học'**
  String get navClasses;

  /// No description provided for @navQuestions.
  ///
  /// In vi, this message translates to:
  /// **'Câu hỏi'**
  String get navQuestions;

  /// No description provided for @navAccount.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản'**
  String get navAccount;

  /// No description provided for @profileTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hồ sơ của tôi'**
  String get profileTitle;

  /// No description provided for @accountSection.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản'**
  String get accountSection;

  /// No description provided for @changeDisplayName.
  ///
  /// In vi, this message translates to:
  /// **'Đổi tên hiển thị'**
  String get changeDisplayName;

  /// No description provided for @changePassword.
  ///
  /// In vi, this message translates to:
  /// **'Đổi mật khẩu'**
  String get changePassword;

  /// No description provided for @myClass.
  ///
  /// In vi, this message translates to:
  /// **'Lớp học của tôi'**
  String get myClass;

  /// No description provided for @myClassJoined.
  ///
  /// In vi, this message translates to:
  /// **'Đã tham gia lớp — chạm để xem'**
  String get myClassJoined;

  /// No description provided for @myClassNotJoined.
  ///
  /// In vi, this message translates to:
  /// **'Chưa được thêm vào lớp nào'**
  String get myClassNotJoined;

  /// No description provided for @otherSection.
  ///
  /// In vi, this message translates to:
  /// **'Khác'**
  String get otherSection;

  /// No description provided for @achievements.
  ///
  /// In vi, this message translates to:
  /// **'Thành tựu'**
  String get achievements;

  /// No description provided for @achievementsUnlocked.
  ///
  /// In vi, this message translates to:
  /// **'{unlocked}/{total} đã mở khoá'**
  String achievementsUnlocked(int unlocked, int total);

  /// No description provided for @notifications.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo'**
  String get notifications;

  /// No description provided for @aboutEdupet.
  ///
  /// In vi, this message translates to:
  /// **'Về PetMath'**
  String get aboutEdupet;

  /// No description provided for @logout.
  ///
  /// In vi, this message translates to:
  /// **'Đăng xuất'**
  String get logout;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đăng xuất'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có chắc muốn đăng xuất không?'**
  String get logoutConfirmMessage;

  /// No description provided for @streakDays.
  ///
  /// In vi, this message translates to:
  /// **'{count} ngày'**
  String streakDays(int count);

  /// No description provided for @changeNameTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đổi tên hiển thị'**
  String get changeNameTitle;

  /// No description provided for @nameHint.
  ///
  /// In vi, this message translates to:
  /// **'Tên hiển thị'**
  String get nameHint;

  /// No description provided for @nameEmptyError.
  ///
  /// In vi, this message translates to:
  /// **'Tên không được để trống'**
  String get nameEmptyError;

  /// No description provided for @genericError.
  ///
  /// In vi, this message translates to:
  /// **'Có lỗi xảy ra: {error}'**
  String genericError(Object error);

  /// No description provided for @changePasswordTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đổi mật khẩu'**
  String get changePasswordTitle;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu hiện tại'**
  String get currentPasswordLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu mới'**
  String get newPasswordLabel;

  /// No description provided for @confirmNewPasswordLabel.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận mật khẩu mới'**
  String get confirmNewPasswordLabel;

  /// No description provided for @currentPasswordEmptyError.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập mật khẩu hiện tại'**
  String get currentPasswordEmptyError;

  /// No description provided for @newPasswordTooShortError.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu mới phải có ít nhất 6 ký tự'**
  String get newPasswordTooShortError;

  /// No description provided for @passwordMismatchError.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu xác nhận không khớp'**
  String get passwordMismatchError;

  /// No description provided for @changePasswordSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đổi mật khẩu thành công!'**
  String get changePasswordSuccess;

  /// No description provided for @wrongCurrentPasswordError.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu hiện tại không đúng'**
  String get wrongCurrentPasswordError;

  /// No description provided for @weakNewPasswordError.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu mới quá yếu'**
  String get weakNewPasswordError;

  /// No description provided for @sessionExpiredError.
  ///
  /// In vi, this message translates to:
  /// **'Phiên đăng nhập đã cũ, vui lòng đăng xuất rồi đăng nhập lại'**
  String get sessionExpiredError;

  /// No description provided for @tooManyAttemptsError.
  ///
  /// In vi, this message translates to:
  /// **'Bạn thử quá nhiều lần, vui lòng thử lại sau'**
  String get tooManyAttemptsError;

  /// No description provided for @genericAuthError.
  ///
  /// In vi, this message translates to:
  /// **'Đã có lỗi xảy ra, vui lòng thử lại'**
  String get genericAuthError;

  /// No description provided for @myClassTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lớp học của tôi'**
  String get myClassTitle;

  /// No description provided for @loadingClassInfo.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải thông tin lớp…'**
  String get loadingClassInfo;

  /// No description provided for @currentClassInfo.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang ở lớp: {className}'**
  String currentClassInfo(String className);

  /// No description provided for @classNotFound.
  ///
  /// In vi, this message translates to:
  /// **'(không tìm thấy lớp)'**
  String get classNotFound;

  /// No description provided for @joinClassPrompt.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mã lớp giáo viên cung cấp để tham gia lớp học.'**
  String get joinClassPrompt;

  /// No description provided for @classCodeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mã lớp'**
  String get classCodeLabel;

  /// No description provided for @changeClassLabel.
  ///
  /// In vi, this message translates to:
  /// **'Nhập mã để chuyển lớp khác'**
  String get changeClassLabel;

  /// No description provided for @classCodeEmptyError.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập mã lớp'**
  String get classCodeEmptyError;

  /// No description provided for @invalidClassCodeError.
  ///
  /// In vi, this message translates to:
  /// **'Mã lớp không đúng, vui lòng kiểm tra lại.'**
  String get invalidClassCodeError;

  /// No description provided for @leaveClass.
  ///
  /// In vi, this message translates to:
  /// **'Rời lớp'**
  String get leaveClass;

  /// No description provided for @joinClass.
  ///
  /// In vi, this message translates to:
  /// **'Tham gia'**
  String get joinClass;

  /// No description provided for @language.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get language;

  /// No description provided for @chooseLanguageTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngôn ngữ'**
  String get chooseLanguageTitle;

  /// No description provided for @vietnamese.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Việt'**
  String get vietnamese;

  /// No description provided for @english.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Anh'**
  String get english;

  /// No description provided for @aiTutor.
  ///
  /// In vi, this message translates to:
  /// **'Gia sư AI'**
  String get aiTutor;

  /// No description provided for @askAiTutorAboutQuestion.
  ///
  /// In vi, this message translates to:
  /// **'Hỏi gia sư AI về câu này'**
  String get askAiTutorAboutQuestion;

  /// No description provided for @askAiTutorHint.
  ///
  /// In vi, this message translates to:
  /// **'Em muốn hỏi gia sư AI điều gì?'**
  String get askAiTutorHint;

  /// No description provided for @friendshipTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thân thiết'**
  String get friendshipTitle;

  /// No description provided for @friendshipLevelLabel.
  ///
  /// In vi, this message translates to:
  /// **'Thân thiết {level}'**
  String friendshipLevelLabel(String level);

  /// No description provided for @friendshipProgress.
  ///
  /// In vi, this message translates to:
  /// **'{points} / {next} điểm đến mức kế tiếp'**
  String friendshipProgress(int points, int next);

  /// No description provided for @friendshipMaxedOut.
  ///
  /// In vi, this message translates to:
  /// **'Đã đạt mức tối đa! 🎉'**
  String get friendshipMaxedOut;

  /// No description provided for @friendshipPointsTotal.
  ///
  /// In vi, this message translates to:
  /// **'{points} điểm'**
  String friendshipPointsTotal(int points);

  /// No description provided for @friendshipRewardAiTutor.
  ///
  /// In vi, this message translates to:
  /// **'Mở khoá Gia sư AI'**
  String get friendshipRewardAiTutor;

  /// No description provided for @friendshipRewardPetStage.
  ///
  /// In vi, this message translates to:
  /// **'Mở khoá Pet cấp {stage} (+{expPercent}% EXP)'**
  String friendshipRewardPetStage(int stage, int expPercent);

  /// No description provided for @friendshipRewardCoin.
  ///
  /// In vi, this message translates to:
  /// **'+{percent}% Coin nhận được'**
  String friendshipRewardCoin(int percent);

  /// No description provided for @friendshipRewardRanking.
  ///
  /// In vi, this message translates to:
  /// **'Hiện bạn trên bảng xếp hạng'**
  String get friendshipRewardRanking;

  /// No description provided for @friendshipRewardCoinGem.
  ///
  /// In vi, this message translates to:
  /// **'+{coin}% Coin, +{gem}% Kim cương'**
  String friendshipRewardCoinGem(int coin, int gem);

  /// No description provided for @friendshipHowTo.
  ///
  /// In vi, this message translates to:
  /// **'Mỗi lần chăm sóc pet (vuốt ve, cho ăn, tắm, chơi, ngủ) được +{points} điểm Thân thiết.'**
  String friendshipHowTo(int points);

  /// No description provided for @unlockedPetStage.
  ///
  /// In vi, this message translates to:
  /// **'🎉 Đã mở khoá Pet cấp {stage}!'**
  String unlockedPetStage(int stage);

  /// No description provided for @unlockedAiTutor.
  ///
  /// In vi, this message translates to:
  /// **'🤖 Gia sư AI đã được mở khoá!'**
  String get unlockedAiTutor;

  /// No description provided for @unlockedRanking.
  ///
  /// In vi, this message translates to:
  /// **'🏆 Bạn đã có thể xuất hiện trên bảng xếp hạng!'**
  String get unlockedRanking;

  /// No description provided for @unlockedCoinBonus.
  ///
  /// In vi, this message translates to:
  /// **'💰 Bonus Coin +{percent}%!'**
  String unlockedCoinBonus(int percent);

  /// No description provided for @unlockedCoinGemBonus.
  ///
  /// In vi, this message translates to:
  /// **'💎 Bonus Coin +{coin}%, Kim cương +{gem}%!'**
  String unlockedCoinGemBonus(int coin, int gem);

  /// No description provided for @unlockedExpBonus.
  ///
  /// In vi, this message translates to:
  /// **'⭐ Bonus EXP +{percent}%!'**
  String unlockedExpBonus(int percent);

  /// No description provided for @awesome.
  ///
  /// In vi, this message translates to:
  /// **'Tuyệt vời!'**
  String get awesome;

  /// No description provided for @skinBoxTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hộp mù Skin'**
  String get skinBoxTitle;

  /// No description provided for @skinBoxSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Mở hộp để nhận ngẫu nhiên 1 skin cho pet của bạn!'**
  String get skinBoxSubtitle;

  /// No description provided for @skinBoxPrice.
  ///
  /// In vi, this message translates to:
  /// **'{price} Kim cương / lần mở'**
  String skinBoxPrice(int price);

  /// No description provided for @skinBoxOpen.
  ///
  /// In vi, this message translates to:
  /// **'Mở hộp'**
  String get skinBoxOpen;

  /// No description provided for @skinBoxOpening.
  ///
  /// In vi, this message translates to:
  /// **'✨ Đang mở...'**
  String get skinBoxOpening;

  /// No description provided for @skinBoxNotEnoughGems.
  ///
  /// In vi, this message translates to:
  /// **'Cần {price} Kim cương để mở hộp. Bạn chưa đủ!'**
  String skinBoxNotEnoughGems(int price);

  /// No description provided for @skinBoxError.
  ///
  /// In vi, this message translates to:
  /// **'Không mở được hộp. Thử lại nhé!'**
  String get skinBoxError;

  /// No description provided for @skinBoxGot.
  ///
  /// In vi, this message translates to:
  /// **'🎉 Bạn nhận được Skin {rarity}!'**
  String skinBoxGot(String rarity);

  /// No description provided for @skinBoxDuplicate.
  ///
  /// In vi, this message translates to:
  /// **'Skin này bạn đã có! Nhận lại {coin} Coin.'**
  String skinBoxDuplicate(int coin);

  /// No description provided for @skinBoxNewSkin.
  ///
  /// In vi, this message translates to:
  /// **'Skin mới!'**
  String get skinBoxNewSkin;

  /// No description provided for @skinBoxOdds.
  ///
  /// In vi, this message translates to:
  /// **'Tỷ lệ rơi'**
  String get skinBoxOdds;

  /// No description provided for @gemBalance.
  ///
  /// In vi, this message translates to:
  /// **'Kim cương: {gem}'**
  String gemBalance(String gem);

  /// No description provided for @equip.
  ///
  /// In vi, this message translates to:
  /// **'Trang bị'**
  String get equip;

  /// No description provided for @equipped.
  ///
  /// In vi, this message translates to:
  /// **'Đang trang bị'**
  String get equipped;

  /// No description provided for @unequipSkin.
  ///
  /// In vi, this message translates to:
  /// **'Tháo skin'**
  String get unequipSkin;

  /// No description provided for @equipFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không thể trang bị skin này'**
  String get equipFailed;

  /// No description provided for @rarityCommon.
  ///
  /// In vi, this message translates to:
  /// **'Thường'**
  String get rarityCommon;

  /// No description provided for @rarityRare.
  ///
  /// In vi, this message translates to:
  /// **'Hiếm'**
  String get rarityRare;

  /// No description provided for @rarityEpic.
  ///
  /// In vi, this message translates to:
  /// **'Sử thi'**
  String get rarityEpic;

  /// No description provided for @rarityLegendary.
  ///
  /// In vi, this message translates to:
  /// **'Huyền thoại'**
  String get rarityLegendary;

  /// No description provided for @libraryTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thư viện Pet'**
  String get libraryTitle;

  /// No description provided for @libraryPetTab.
  ///
  /// In vi, this message translates to:
  /// **'Pet'**
  String get libraryPetTab;

  /// No description provided for @librarySkinTab.
  ///
  /// In vi, this message translates to:
  /// **'Skin'**
  String get librarySkinTab;

  /// No description provided for @libraryStageName.
  ///
  /// In vi, this message translates to:
  /// **'Cấp {stage}'**
  String libraryStageName(int stage);

  /// No description provided for @libraryStageLocked.
  ///
  /// In vi, this message translates to:
  /// **'Mở ở Thân thiết {level}'**
  String libraryStageLocked(String level);

  /// No description provided for @librarySkinsOwned.
  ///
  /// In vi, this message translates to:
  /// **'{owned}/{total} skin đã sở hữu'**
  String librarySkinsOwned(int owned, int total);

  /// No description provided for @libraryLocked.
  ///
  /// In vi, this message translates to:
  /// **'Chưa mở khoá'**
  String get libraryLocked;

  /// No description provided for @libraryCurrent.
  ///
  /// In vi, this message translates to:
  /// **'Hiện tại'**
  String get libraryCurrent;

  /// No description provided for @libraryOpenSkinBox.
  ///
  /// In vi, this message translates to:
  /// **'Mở Hộp mù Skin'**
  String get libraryOpenSkinBox;

  /// No description provided for @leaderboardHiddenNotice.
  ///
  /// In vi, this message translates to:
  /// **'Đạt Thân thiết {level} để tên bạn xuất hiện trên bảng xếp hạng.'**
  String leaderboardHiddenNotice(String level);

  /// No description provided for @skinBoxMenuHint.
  ///
  /// In vi, this message translates to:
  /// **'Skin & Thân thiết'**
  String get skinBoxMenuHint;

  /// No description provided for @leaderboardTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bảng xếp hạng'**
  String get leaderboardTitle;

  /// No description provided for @leaderboardTabPetLevel.
  ///
  /// In vi, this message translates to:
  /// **'Cấp Pet'**
  String get leaderboardTabPetLevel;

  /// No description provided for @leaderboardTabCoin.
  ///
  /// In vi, this message translates to:
  /// **'Xu'**
  String get leaderboardTabCoin;

  /// No description provided for @leaderboardTabGem.
  ///
  /// In vi, this message translates to:
  /// **'Kim cương'**
  String get leaderboardTabGem;

  /// No description provided for @scopeClass.
  ///
  /// In vi, this message translates to:
  /// **'Lớp'**
  String get scopeClass;

  /// No description provided for @scopeSchool.
  ///
  /// In vi, this message translates to:
  /// **'Trường'**
  String get scopeSchool;

  /// No description provided for @scopeProvince.
  ///
  /// In vi, this message translates to:
  /// **'Tỉnh'**
  String get scopeProvince;

  /// No description provided for @scopeNational.
  ///
  /// In vi, this message translates to:
  /// **'Toàn quốc'**
  String get scopeNational;

  /// No description provided for @friendshipChip.
  ///
  /// In vi, this message translates to:
  /// **'Thân thiết {level}'**
  String friendshipChip(String level);

  /// No description provided for @skinRoomTitle.
  ///
  /// In vi, this message translates to:
  /// **'Phòng đổi skin'**
  String get skinRoomTitle;

  /// No description provided for @skinRoomHint.
  ///
  /// In vi, this message translates to:
  /// **'Chạm vào skin đã mở khoá để mặc cho pet. Skin chưa mở sẽ hiện màu đen.'**
  String get skinRoomHint;

  /// No description provided for @skinRoomNoSkin.
  ///
  /// In vi, this message translates to:
  /// **'Mặc định'**
  String get skinRoomNoSkin;

  /// No description provided for @skinRoomGoBox.
  ///
  /// In vi, this message translates to:
  /// **'Mở hộp để nhận thêm skin'**
  String get skinRoomGoBox;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
