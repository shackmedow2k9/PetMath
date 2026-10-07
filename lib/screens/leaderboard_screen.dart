import 'package:flutter/material.dart' hide Text;
import '../widgets/app_background.dart';
import '../l10n/tr.dart';
import '../widgets/tr_text.dart';
import 'package:provider/provider.dart';
import '../widgets/emoji_icon.dart';
import '../l10n/gen/app_localizations.dart';
import '../models/friendship_level.dart';
import '../models/pet_model.dart';
import '../models/student_model.dart';
import '../providers/auth_provider.dart';
import '../providers/pet_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

/// Bảng xếp hạng — 3 mục lớn (Cấp Pet / Xu / Kim cương), mỗi mục có 4 mục
/// nhỏ theo phạm vi (Lớp / Trường / Tỉnh / Toàn quốc). Quy tắc xếp hạng
/// giữ nguyên như trước (giảm dần theo chỉ số, hoà thì ai đạt trước xếp
/// trên — riêng Cấp Pet mới có tie-break này).
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final pet = context.watch<PetProvider>().pet;
    // Trước mức Thân thiết V: vẫn XEM được bảng xếp hạng, nhưng profile của
    // bản thân chưa hiện trong bảng (xem FirestoreService.watchLeaderboard).
    final showHiddenNotice =
        pet != null && !pet.friendship.canShowOnLeaderboard;
    return DefaultTabController(
      length: 3,
      child: ScreenScaffold(bg: BgKind.light, 
        appBar: AppBar(
          title: Text(l.leaderboardTitle),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          bottom: TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Image.asset('assets/ui/ic_book_cap.png', width: 28, height: 28), text: l.leaderboardTabPetLevel),
              Tab(icon: Image.asset('assets/ui/ic_coin_book.png', width: 28, height: 28), text: l.leaderboardTabCoin),
              Tab(icon: Image.asset('assets/ui/ic_gem.png', width: 28, height: 28), text: l.leaderboardTabGem),
            ],
          ),
        ),
        body: Column(
          children: [
            if (showHiddenNotice)
              Container(
                width: double.infinity,
                color: const Color(0xFFFFF4D6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  l.leaderboardHiddenNotice(
                      FriendshipInfo.roman(FriendshipInfo.rankingUnlockLevel)),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF7A5B00)),
                ),
              ),
            const Expanded(
              child: TabBarView(
                children: [
                  _ScopeTabs(metric: 'petLevel'),
                  _ScopeTabs(metric: 'coin'),
                  _ScopeTabs(metric: 'gem'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Scope { class_, school, province, national }

/// 4 tab nhỏ (Lớp/Trường/Tỉnh/Toàn quốc) cho 1 chỉ số cụ thể.
class _ScopeTabs extends StatelessWidget {
  final String metric;
  const _ScopeTabs({required this.metric});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(text: AppLocalizations.of(context)!.scopeClass),
                Tab(text: AppLocalizations.of(context)!.scopeSchool),
                Tab(text: AppLocalizations.of(context)!.scopeProvince),
                Tab(text: AppLocalizations.of(context)!.scopeNational),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ScopedLeaderboard(metric: metric, scope: _Scope.class_),
                _ScopedLeaderboard(metric: metric, scope: _Scope.school),
                _ScopedLeaderboard(metric: metric, scope: _Scope.province),
                _ScopedLeaderboard(metric: metric, scope: _Scope.national),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScopedLeaderboard extends StatelessWidget {
  final String metric;
  final _Scope scope;
  const _ScopedLeaderboard({required this.metric, required this.scope});

  @override
  Widget build(BuildContext context) {
    final student = context.watch<AuthProvider>().currentStudent;

    String? scopeField;
    Object? scopeValue;
    String emptyMessage;
    switch (scope) {
      case _Scope.class_:
        scopeField = 'classId';
        scopeValue = student?.classId;
        emptyMessage =
            'Bạn chưa tham gia lớp học nào.\nVào Hồ sơ để nhập mã lớp giáo viên cho.';
      case _Scope.school:
        scopeField = 'schoolName';
        scopeValue = student?.schoolName;
        emptyMessage = 'Hồ sơ của bạn chưa có tên trường.';
      case _Scope.province:
        scopeField = 'provinceCode';
        scopeValue = student?.provinceCode;
        emptyMessage = 'Hồ sơ của bạn chưa có Tỉnh/Thành phố.';
      case _Scope.national:
        scopeField = null;
        scopeValue = null;
        emptyMessage = '';
    }

    final missingScope = scope != _Scope.national &&
        (scopeValue == null || (scopeValue is String && scopeValue.isEmpty));
    if (missingScope) {
      return _EmptyState(message: emptyMessage);
    }

    return StreamBuilder<List<StudentModel>>(
      stream: FirestoreService().watchLeaderboard(
        metric: metric,
        scopeField: scopeField,
        scopeValue: scopeValue,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _EmptyState(
              message: tr('Không tải được bảng xếp hạng.\n${snapshot.error}'));
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return  _EmptyState(message: tr('Chưa có dữ liệu xếp hạng.'));
        }
        // Danh sách tối đa 560px, căn giữa — banner giữ đúng tỉ lệ trên màn rộng.
        final sideGap = ((MediaQuery.of(context).size.width - 560) / 2)
            .clamp(16.0, 4000.0)
            .toDouble();
        return ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: sideGap, vertical: 16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final s = list[index];
            final isMe = s.uid == student?.uid;
            return _RankTile(
                rank: index + 1, student: s, metric: metric, highlight: isMe);
          },
        );
      },
    );
  }
}

class _RankTile extends StatelessWidget {
  final int rank;
  final StudentModel student;
  final String metric;
  final bool highlight;

  const _RankTile({
    required this.rank,
    required this.student,
    required this.metric,
    required this.highlight,
  });

  // Banner nền theo hạng: top1 banner_profile, top2 banner_light,
  // top3 banner_orange, từ top 4 trở đi banner_cream. Top 1-3 đã có sẵn huy
  // chương in trên banner nên không vẽ thêm số/emoji.
  static const _bannerAssets = {
    1: 'assets/ui/banner_profile.png',
    2: 'assets/ui/banner_light.png',
    3: 'assets/ui/banner_orange.png',
  };
  static const _bannerAspect = {
    1: 813 / 82,
    2: 1024 / 101,
    3: 1100 / 108,
  };

  @override
  Widget build(BuildContext context) {
    final asset = _bannerAssets[rank] ?? 'assets/ui/banner_cream.png';
    final aspect = _bannerAspect[rank] ?? 1100 / 105;
    final hasMedal = rank <= 3;

    return LayoutBuilder(
      builder: (context, c) {
        // Chiều cao theo tỉ lệ banner nhưng không nhỏ hơn 52 / lớn hơn 64 để
        // chữ luôn đủ chỗ trên màn hẹp lẫn màn rộng.
        final h = (c.maxWidth / aspect).clamp(52.0, 64.0).toDouble();
        return Container(
          height: h,
          padding: EdgeInsets.only(left: hasMedal ? h * 1.15 : 14, right: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: highlight
                ? Border.all(
                    color: AppColors.primary.withValues(alpha: 0.6), width: 2)
                : null,
            image: DecorationImage(
              image: AssetImage(asset),
              fit: BoxFit.fill,
              onError: (_, __) {},
            ),
          ),
          child: Row(
            children: [
              if (!hasMedal)
                SizedBox(
                  width: 32,
                  child: Text('$rank',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary)),
                ),
              if (!hasMedal) const SizedBox(width: 8),
              Expanded(
                child: Text(student.fullName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight:
                            highlight ? FontWeight.bold : FontWeight.w600)),
              ),
              _MetricValue(metric: metric, student: student),
            ],
          ),
        );
      },
    );
  }
}

class _MetricValue extends StatelessWidget {
  final String metric;
  final StudentModel student;
  const _MetricValue({required this.metric, required this.student});

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final Color color;
    switch (metric) {
      case 'coin':
        text = '🪙 ${student.coinDisplay}';
        color = AppColors.secondary;
      case 'gem':
        text = '💎 ${student.gemDisplay}';
        color = AppColors.info;
      default:
        text = 'Cấp ${student.petLevel}';
        color = AppColors.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.leaderboard_outlined,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
