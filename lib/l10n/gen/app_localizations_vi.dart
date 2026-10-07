// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get cancel => 'Hủy';

  @override
  String get save => 'Lưu';

  @override
  String get retry => 'Thử tải lại';

  @override
  String get loginWelcomeTitle => 'Chào mừng trở lại!';

  @override
  String get loginWelcomeSubtitle => 'Đăng nhập để tiếp tục nuôi thú cưng nhé';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailInvalid => 'Email không hợp lệ';

  @override
  String get passwordLabel => 'Mật khẩu';

  @override
  String get passwordTooShort => 'Tối thiểu 6 ký tự';

  @override
  String get loginButton => 'Đăng nhập';

  @override
  String get noAccountRegister => 'Chưa có tài khoản? Đăng ký ngay';

  @override
  String get navPet => 'Nhà pet';

  @override
  String get navLearn => 'Học tập';

  @override
  String get navShop => 'Cửa hàng';

  @override
  String get navMinigame => 'Minigame';

  @override
  String get navProfile => 'Hồ sơ';

  @override
  String get navClasses => 'Lớp học';

  @override
  String get navQuestions => 'Câu hỏi';

  @override
  String get navAccount => 'Tài khoản';

  @override
  String get profileTitle => 'Hồ sơ của tôi';

  @override
  String get accountSection => 'Tài khoản';

  @override
  String get changeDisplayName => 'Đổi tên hiển thị';

  @override
  String get changePassword => 'Đổi mật khẩu';

  @override
  String get myClass => 'Lớp học của tôi';

  @override
  String get myClassJoined => 'Đã tham gia lớp — chạm để xem';

  @override
  String get myClassNotJoined => 'Chưa được thêm vào lớp nào';

  @override
  String get otherSection => 'Khác';

  @override
  String get achievements => 'Thành tựu';

  @override
  String achievementsUnlocked(int unlocked, int total) {
    return '$unlocked/$total đã mở khoá';
  }

  @override
  String get notifications => 'Thông báo';

  @override
  String get aboutEdupet => 'Về PetMath';

  @override
  String get logout => 'Đăng xuất';

  @override
  String get logoutConfirmTitle => 'Đăng xuất';

  @override
  String get logoutConfirmMessage => 'Bạn có chắc muốn đăng xuất không?';

  @override
  String streakDays(int count) {
    return '$count ngày';
  }

  @override
  String get changeNameTitle => 'Đổi tên hiển thị';

  @override
  String get nameHint => 'Tên hiển thị';

  @override
  String get nameEmptyError => 'Tên không được để trống';

  @override
  String genericError(Object error) {
    return 'Có lỗi xảy ra: $error';
  }

  @override
  String get changePasswordTitle => 'Đổi mật khẩu';

  @override
  String get currentPasswordLabel => 'Mật khẩu hiện tại';

  @override
  String get newPasswordLabel => 'Mật khẩu mới';

  @override
  String get confirmNewPasswordLabel => 'Xác nhận mật khẩu mới';

  @override
  String get currentPasswordEmptyError => 'Vui lòng nhập mật khẩu hiện tại';

  @override
  String get newPasswordTooShortError => 'Mật khẩu mới phải có ít nhất 6 ký tự';

  @override
  String get passwordMismatchError => 'Mật khẩu xác nhận không khớp';

  @override
  String get changePasswordSuccess => 'Đổi mật khẩu thành công!';

  @override
  String get wrongCurrentPasswordError => 'Mật khẩu hiện tại không đúng';

  @override
  String get weakNewPasswordError => 'Mật khẩu mới quá yếu';

  @override
  String get sessionExpiredError =>
      'Phiên đăng nhập đã cũ, vui lòng đăng xuất rồi đăng nhập lại';

  @override
  String get tooManyAttemptsError =>
      'Bạn thử quá nhiều lần, vui lòng thử lại sau';

  @override
  String get genericAuthError => 'Đã có lỗi xảy ra, vui lòng thử lại';

  @override
  String get myClassTitle => 'Lớp học của tôi';

  @override
  String get loadingClassInfo => 'Đang tải thông tin lớp…';

  @override
  String currentClassInfo(String className) {
    return 'Bạn đang ở lớp: $className';
  }

  @override
  String get classNotFound => '(không tìm thấy lớp)';

  @override
  String get joinClassPrompt =>
      'Nhập mã lớp giáo viên cung cấp để tham gia lớp học.';

  @override
  String get classCodeLabel => 'Mã lớp';

  @override
  String get changeClassLabel => 'Nhập mã để chuyển lớp khác';

  @override
  String get classCodeEmptyError => 'Vui lòng nhập mã lớp';

  @override
  String get invalidClassCodeError =>
      'Mã lớp không đúng, vui lòng kiểm tra lại.';

  @override
  String get leaveClass => 'Rời lớp';

  @override
  String get joinClass => 'Tham gia';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get chooseLanguageTitle => 'Chọn ngôn ngữ';

  @override
  String get vietnamese => 'Tiếng Việt';

  @override
  String get english => 'Tiếng Anh';

  @override
  String get aiTutor => 'Gia sư AI';

  @override
  String get askAiTutorAboutQuestion => 'Hỏi gia sư AI về câu này';

  @override
  String get askAiTutorHint => 'Em muốn hỏi gia sư AI điều gì?';

  @override
  String get friendshipTitle => 'Thân thiết';

  @override
  String friendshipLevelLabel(String level) {
    return 'Thân thiết $level';
  }

  @override
  String friendshipProgress(int points, int next) {
    return '$points / $next điểm đến mức kế tiếp';
  }

  @override
  String get friendshipMaxedOut => 'Đã đạt mức tối đa! 🎉';

  @override
  String friendshipPointsTotal(int points) {
    return '$points điểm';
  }

  @override
  String get friendshipRewardAiTutor => 'Mở khoá Gia sư AI';

  @override
  String friendshipRewardPetStage(int stage, int expPercent) {
    return 'Mở khoá Pet cấp $stage (+$expPercent% EXP)';
  }

  @override
  String friendshipRewardCoin(int percent) {
    return '+$percent% Coin nhận được';
  }

  @override
  String get friendshipRewardRanking => 'Hiện bạn trên bảng xếp hạng';

  @override
  String friendshipRewardCoinGem(int coin, int gem) {
    return '+$coin% Coin, +$gem% Kim cương';
  }

  @override
  String friendshipHowTo(int points) {
    return 'Mỗi lần chăm sóc pet (vuốt ve, cho ăn, tắm, chơi, ngủ) được +$points điểm Thân thiết.';
  }

  @override
  String unlockedPetStage(int stage) {
    return '🎉 Đã mở khoá Pet cấp $stage!';
  }

  @override
  String get unlockedAiTutor => '🤖 Gia sư AI đã được mở khoá!';

  @override
  String get unlockedRanking =>
      '🏆 Bạn đã có thể xuất hiện trên bảng xếp hạng!';

  @override
  String unlockedCoinBonus(int percent) {
    return '💰 Bonus Coin +$percent%!';
  }

  @override
  String unlockedCoinGemBonus(int coin, int gem) {
    return '💎 Bonus Coin +$coin%, Kim cương +$gem%!';
  }

  @override
  String unlockedExpBonus(int percent) {
    return '⭐ Bonus EXP +$percent%!';
  }

  @override
  String get awesome => 'Tuyệt vời!';

  @override
  String get skinBoxTitle => 'Hộp mù Skin';

  @override
  String get skinBoxSubtitle =>
      'Mở hộp để nhận ngẫu nhiên 1 skin cho pet của bạn!';

  @override
  String skinBoxPrice(int price) {
    return '$price Kim cương / lần mở';
  }

  @override
  String get skinBoxOpen => 'Mở hộp';

  @override
  String get skinBoxOpening => '✨ Đang mở...';

  @override
  String skinBoxNotEnoughGems(int price) {
    return 'Cần $price Kim cương để mở hộp. Bạn chưa đủ!';
  }

  @override
  String get skinBoxError => 'Không mở được hộp. Thử lại nhé!';

  @override
  String skinBoxGot(String rarity) {
    return '🎉 Bạn nhận được Skin $rarity!';
  }

  @override
  String skinBoxDuplicate(int coin) {
    return 'Skin này bạn đã có! Nhận lại $coin Coin.';
  }

  @override
  String get skinBoxNewSkin => 'Skin mới!';

  @override
  String get skinBoxOdds => 'Tỷ lệ rơi';

  @override
  String gemBalance(String gem) {
    return 'Kim cương: $gem';
  }

  @override
  String get equip => 'Trang bị';

  @override
  String get equipped => 'Đang trang bị';

  @override
  String get unequipSkin => 'Tháo skin';

  @override
  String get equipFailed => 'Không thể trang bị skin này';

  @override
  String get rarityCommon => 'Thường';

  @override
  String get rarityRare => 'Hiếm';

  @override
  String get rarityEpic => 'Sử thi';

  @override
  String get rarityLegendary => 'Huyền thoại';

  @override
  String get libraryTitle => 'Thư viện Pet';

  @override
  String get libraryPetTab => 'Pet';

  @override
  String get librarySkinTab => 'Skin';

  @override
  String libraryStageName(int stage) {
    return 'Cấp $stage';
  }

  @override
  String libraryStageLocked(String level) {
    return 'Mở ở Thân thiết $level';
  }

  @override
  String librarySkinsOwned(int owned, int total) {
    return '$owned/$total skin đã sở hữu';
  }

  @override
  String get libraryLocked => 'Chưa mở khoá';

  @override
  String get libraryCurrent => 'Hiện tại';

  @override
  String get libraryOpenSkinBox => 'Mở Hộp mù Skin';

  @override
  String leaderboardHiddenNotice(String level) {
    return 'Đạt Thân thiết $level để tên bạn xuất hiện trên bảng xếp hạng.';
  }

  @override
  String get skinBoxMenuHint => 'Skin & Thân thiết';

  @override
  String get leaderboardTitle => 'Bảng xếp hạng';

  @override
  String get leaderboardTabPetLevel => 'Cấp Pet';

  @override
  String get leaderboardTabCoin => 'Xu';

  @override
  String get leaderboardTabGem => 'Kim cương';

  @override
  String get scopeClass => 'Lớp';

  @override
  String get scopeSchool => 'Trường';

  @override
  String get scopeProvince => 'Tỉnh';

  @override
  String get scopeNational => 'Toàn quốc';

  @override
  String friendshipChip(String level) {
    return 'Thân thiết $level';
  }

  @override
  String get skinRoomTitle => 'Phòng đổi skin';

  @override
  String get skinRoomHint =>
      'Chạm vào skin đã mở khoá để mặc cho pet. Skin chưa mở sẽ hiện màu đen.';

  @override
  String get skinRoomNoSkin => 'Mặc định';

  @override
  String get skinRoomGoBox => 'Mở hộp để nhận thêm skin';
}
