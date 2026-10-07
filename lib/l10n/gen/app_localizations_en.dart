// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get retry => 'Retry';

  @override
  String get loginWelcomeTitle => 'Welcome back!';

  @override
  String get loginWelcomeSubtitle => 'Log in to keep taking care of your pet';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailInvalid => 'Invalid email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordTooShort => 'At least 6 characters';

  @override
  String get loginButton => 'Log in';

  @override
  String get noAccountRegister => 'Don\'t have an account? Sign up';

  @override
  String get navPet => 'Pet Home';

  @override
  String get navLearn => 'Learn';

  @override
  String get navShop => 'Shop';

  @override
  String get navMinigame => 'Minigame';

  @override
  String get navProfile => 'Profile';

  @override
  String get navClasses => 'Classes';

  @override
  String get navQuestions => 'Questions';

  @override
  String get navAccount => 'Account';

  @override
  String get profileTitle => 'My profile';

  @override
  String get accountSection => 'Account';

  @override
  String get changeDisplayName => 'Change display name';

  @override
  String get changePassword => 'Change password';

  @override
  String get myClass => 'My class';

  @override
  String get myClassJoined => 'Joined a class — tap to view';

  @override
  String get myClassNotJoined => 'Not added to any class yet';

  @override
  String get otherSection => 'Other';

  @override
  String get achievements => 'Achievements';

  @override
  String achievementsUnlocked(int unlocked, int total) {
    return '$unlocked/$total unlocked';
  }

  @override
  String get notifications => 'Notifications';

  @override
  String get aboutEdupet => 'About PetMath';

  @override
  String get logout => 'Log out';

  @override
  String get logoutConfirmTitle => 'Log out';

  @override
  String get logoutConfirmMessage => 'Are you sure you want to log out?';

  @override
  String streakDays(int count) {
    return '$count days';
  }

  @override
  String get changeNameTitle => 'Change display name';

  @override
  String get nameHint => 'Display name';

  @override
  String get nameEmptyError => 'Name cannot be empty';

  @override
  String genericError(Object error) {
    return 'Something went wrong: $error';
  }

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get confirmNewPasswordLabel => 'Confirm new password';

  @override
  String get currentPasswordEmptyError => 'Please enter your current password';

  @override
  String get newPasswordTooShortError =>
      'New password must be at least 6 characters';

  @override
  String get passwordMismatchError => 'Passwords do not match';

  @override
  String get changePasswordSuccess => 'Password changed successfully!';

  @override
  String get wrongCurrentPasswordError => 'Current password is incorrect';

  @override
  String get weakNewPasswordError => 'New password is too weak';

  @override
  String get sessionExpiredError =>
      'Your session has expired, please log out and log in again';

  @override
  String get tooManyAttemptsError =>
      'Too many attempts, please try again later';

  @override
  String get genericAuthError => 'Something went wrong, please try again';

  @override
  String get myClassTitle => 'My class';

  @override
  String get loadingClassInfo => 'Loading class info…';

  @override
  String currentClassInfo(String className) {
    return 'You\'re in class: $className';
  }

  @override
  String get classNotFound => '(class not found)';

  @override
  String get joinClassPrompt =>
      'Enter the class code your teacher gave you to join.';

  @override
  String get classCodeLabel => 'Class code';

  @override
  String get changeClassLabel => 'Enter a code to switch class';

  @override
  String get classCodeEmptyError => 'Please enter a class code';

  @override
  String get invalidClassCodeError => 'Wrong class code, please check again.';

  @override
  String get leaveClass => 'Leave class';

  @override
  String get joinClass => 'Join';

  @override
  String get language => 'Language';

  @override
  String get chooseLanguageTitle => 'Choose language';

  @override
  String get vietnamese => 'Vietnamese';

  @override
  String get english => 'English';

  @override
  String get aiTutor => 'AI Tutor';

  @override
  String get askAiTutorAboutQuestion => 'Ask the AI Tutor about this question';

  @override
  String get askAiTutorHint => 'What would you like to ask the AI Tutor?';

  @override
  String get friendshipTitle => 'Friendship';

  @override
  String friendshipLevelLabel(String level) {
    return 'Friendship $level';
  }

  @override
  String friendshipProgress(int points, int next) {
    return '$points / $next points to next level';
  }

  @override
  String get friendshipMaxedOut => 'Max level reached! 🎉';

  @override
  String friendshipPointsTotal(int points) {
    return '$points points';
  }

  @override
  String get friendshipRewardAiTutor => 'Unlocks the AI Tutor';

  @override
  String friendshipRewardPetStage(int stage, int expPercent) {
    return 'Unlocks Pet stage $stage (+$expPercent% EXP)';
  }

  @override
  String friendshipRewardCoin(int percent) {
    return '+$percent% Coins earned';
  }

  @override
  String get friendshipRewardRanking => 'Show yourself on the leaderboard';

  @override
  String friendshipRewardCoinGem(int coin, int gem) {
    return '+$coin% Coins, +$gem% Diamonds';
  }

  @override
  String friendshipHowTo(int points) {
    return 'Every pet care action (pat, feed, bathe, play, sleep) gives +$points Friendship points.';
  }

  @override
  String unlockedPetStage(int stage) {
    return '🎉 Pet stage $stage unlocked!';
  }

  @override
  String get unlockedAiTutor => '🤖 AI Tutor unlocked!';

  @override
  String get unlockedRanking => '🏆 You can now appear on the leaderboard!';

  @override
  String unlockedCoinBonus(int percent) {
    return '💰 Coin bonus +$percent%!';
  }

  @override
  String unlockedCoinGemBonus(int coin, int gem) {
    return '💎 Coin bonus +$coin%, Diamond bonus +$gem%!';
  }

  @override
  String unlockedExpBonus(int percent) {
    return '⭐ EXP bonus +$percent%!';
  }

  @override
  String get awesome => 'Awesome!';

  @override
  String get skinBoxTitle => 'Skin Blind Box';

  @override
  String get skinBoxSubtitle => 'Open a box to get a random skin for your pet!';

  @override
  String skinBoxPrice(int price) {
    return '$price Diamonds / open';
  }

  @override
  String get skinBoxOpen => 'Open box';

  @override
  String get skinBoxOpening => '✨ Opening...';

  @override
  String skinBoxNotEnoughGems(int price) {
    return 'You need $price Diamonds to open a box. Not enough!';
  }

  @override
  String get skinBoxError => 'Could not open the box. Please try again!';

  @override
  String skinBoxGot(String rarity) {
    return '🎉 You got a $rarity Skin!';
  }

  @override
  String skinBoxDuplicate(int coin) {
    return 'You already own this skin! Refunded $coin Coins.';
  }

  @override
  String get skinBoxNewSkin => 'New skin!';

  @override
  String get skinBoxOdds => 'Drop rates';

  @override
  String gemBalance(String gem) {
    return 'Diamonds: $gem';
  }

  @override
  String get equip => 'Equip';

  @override
  String get equipped => 'Equipped';

  @override
  String get unequipSkin => 'Remove skin';

  @override
  String get equipFailed => 'Cannot equip this skin';

  @override
  String get rarityCommon => 'Common';

  @override
  String get rarityRare => 'Rare';

  @override
  String get rarityEpic => 'Epic';

  @override
  String get rarityLegendary => 'Legendary';

  @override
  String get libraryTitle => 'Pet Library';

  @override
  String get libraryPetTab => 'Pets';

  @override
  String get librarySkinTab => 'Skins';

  @override
  String libraryStageName(int stage) {
    return 'Stage $stage';
  }

  @override
  String libraryStageLocked(String level) {
    return 'Unlocks at Friendship $level';
  }

  @override
  String librarySkinsOwned(int owned, int total) {
    return '$owned/$total skins owned';
  }

  @override
  String get libraryLocked => 'Locked';

  @override
  String get libraryCurrent => 'Current';

  @override
  String get libraryOpenSkinBox => 'Open Skin Blind Box';

  @override
  String leaderboardHiddenNotice(String level) {
    return 'Reach Friendship $level to appear on the leaderboard.';
  }

  @override
  String get skinBoxMenuHint => 'Skins & Friendship';

  @override
  String get leaderboardTitle => 'Leaderboard';

  @override
  String get leaderboardTabPetLevel => 'Pet Level';

  @override
  String get leaderboardTabCoin => 'Coins';

  @override
  String get leaderboardTabGem => 'Diamonds';

  @override
  String get scopeClass => 'Class';

  @override
  String get scopeSchool => 'School';

  @override
  String get scopeProvince => 'Province';

  @override
  String get scopeNational => 'National';

  @override
  String friendshipChip(String level) {
    return 'Friendship $level';
  }

  @override
  String get skinRoomTitle => 'Skin Room';

  @override
  String get skinRoomHint =>
      'Tap an unlocked skin to dress your pet. Locked skins are shown in black.';

  @override
  String get skinRoomNoSkin => 'Default';

  @override
  String get skinRoomGoBox => 'Open boxes to get more skins';
}
