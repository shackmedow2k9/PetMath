import 'dart:math';

import 'package:edupet/config/game_balance.dart';
import 'package:edupet/models/friendship_level.dart';
import 'package:edupet/models/pet_family_catalog.dart';
import 'package:edupet/services/skin_box_roller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Skin box weighted random', () {
    test('100.000 lần mở: tỷ lệ độ hiếm ≈ 65/20/10/5 (mọi họ pet)', () {
      final roller = SkinBoxRoller(Random(20261004));
      const rolls = 100000;
      for (final family in PetFamily.values) {
        final count = {for (final r in SkinRarity.values) r: 0};
        for (var i = 0; i < rolls; i++) {
          final skin = roller.rollSkin(family);
          count[skin.rarity] = count[skin.rarity]! + 1;
        }
        for (final r in SkinRarity.values) {
          final pct = count[r]! * 100 / rolls;
          final expected = GameBalance.skinRatePercent[r]!.toDouble();
          expect((pct - expected).abs(), lessThan(1.0),
              reason: '${family.name} ${r.name}: $pct% (kỳ vọng $expected%)');
        }
      }
    });

    test('mỗi họ có ≥ 1 skin ở mỗi độ hiếm và đúng 10 skin', () {
      for (final f in PetFamily.values) {
        final skins = PetFamilyCatalog.skinsOf(f);
        expect(skins.length, 10);
        for (final r in SkinRarity.values) {
          expect(skins.any((s) => s.rarity == r), isTrue, reason: '${f.name} ${r.name}');
        }
      }
    });

    test('skinById hợp lệ / không hợp lệ', () {
      expect(PetFamilyCatalog.skinById('dragon_03')?.number, 3);
      expect(PetFamilyCatalog.skinById('dragon_11'), isNull);
      expect(PetFamilyCatalog.skinById('xxx_01'), isNull);
      expect(PetFamilyCatalog.skinById(null), isNull);
    });
  });

  group('Friendship', () {
    test('mức theo điểm + mở khoá', () {
      expect(FriendshipInfo.fromPoints(0).level, 0);
      expect(FriendshipInfo.fromPoints(0).aiTutorUnlocked, isFalse);
      expect(FriendshipInfo.fromPoints(0).petStage, 1);
      expect(FriendshipInfo.fromPoints(0).canShowOnLeaderboard, isFalse);
      expect(FriendshipInfo.fromPoints(100).level, 1);
      expect(FriendshipInfo.fromPoints(100).aiTutorUnlocked, isTrue);
      expect(FriendshipInfo.fromPoints(500).petStage, 2);
      expect(FriendshipInfo.fromPoints(1800).petStage, 3);
      expect(FriendshipInfo.fromPoints(2800).canShowOnLeaderboard, isTrue);
      expect(FriendshipInfo.fromPoints(5500).petStage, 4);
      expect(FriendshipInfo.fromPoints(10000).petStage, 5);
      expect(FriendshipInfo.fromPoints(99999999).level, 10);
      expect(FriendshipInfo.fromPoints(-5).level, 0);
    });

    test('bonus EXP/Coin/Kim cương không cộng dồn', () {
      final lv10 = FriendshipInfo.fromPoints(10000);
      expect(lv10.expMultiplier, closeTo(1.5, 1e-9));
      expect(lv10.coinMultiplier, closeTo(1.25, 1e-9));
      expect(lv10.gemMultiplier, closeTo(1.15, 1e-9));
      final lv2 = FriendshipInfo.fromPoints(500);
      expect(lv2.expMultiplier, closeTo(1.1, 1e-9));
      expect(lv2.coinMultiplier, 1.0);
      expect(FriendshipInfo.fromPoints(1000).coinMultiplier, closeTo(1.1, 1e-9));
      expect(FriendshipInfo.fromPoints(4000).gemMultiplier, closeTo(1.05, 1e-9));
      expect(lv10.boostExp(100), 150);
      expect(lv10.boostExp(100), 150); // gọi lại vẫn y nguyên
      expect(lv10.boostExp(0), 0);
    });
  });
}
