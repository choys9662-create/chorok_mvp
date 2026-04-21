import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

// ─── 뱃지 데이터 ───────────────────────────────────────────────────────────
enum _BadgeCategory { reading, collection, social, special }

class _Badge {
  final String emoji;
  final String title;
  final String description;
  final bool unlocked;
  final double progress; // 0~1, unlocked면 무시
  final _BadgeCategory category;

  const _Badge({
    required this.emoji,
    required this.title,
    required this.description,
    this.unlocked = false,
    this.progress = 0,
    required this.category,
  });
}

const _kBadges = <_Badge>[
  // 독서 습관
  _Badge(emoji: '🌱', title: '첫 발걸음', description: '첫 독서 세션 완료', unlocked: true, category: _BadgeCategory.reading),
  _Badge(emoji: '🔥', title: '3일 연속', description: '3일 연속 독서', unlocked: true, category: _BadgeCategory.reading),
  _Badge(emoji: '⚡', title: '일주일 독서가', description: '7일 연속 독서', unlocked: true, category: _BadgeCategory.reading),
  _Badge(emoji: '🌙', title: '저녁형 독서가', description: '저녁 시간대 독서 20회', unlocked: true, category: _BadgeCategory.reading),
  _Badge(emoji: '🏅', title: '한 달 독서왕', description: '30일 연속 독서', progress: 0.7, category: _BadgeCategory.reading),
  _Badge(emoji: '🕐', title: '집중력 마스터', description: '90분 연속 독서', progress: 0.4, category: _BadgeCategory.reading),
  _Badge(emoji: '🌅', title: '새벽 독서가', description: '오전 6시 이전 독서 10회', progress: 0.2, category: _BadgeCategory.reading),
  _Badge(emoji: '💯', title: '퍼펙트 위크', description: '7일 모두 목표 달성', progress: 0, category: _BadgeCategory.reading),

  // 문장 수집
  _Badge(emoji: '✏️', title: '첫 문장', description: '첫 초서 완료', unlocked: true, category: _BadgeCategory.collection),
  _Badge(emoji: '📚', title: '문장 수집가', description: '초서 50개 달성', unlocked: true, category: _BadgeCategory.collection),
  _Badge(emoji: '💬', title: '겹문장 발견', description: '겹문장 첫 발견', unlocked: true, category: _BadgeCategory.collection),
  _Badge(emoji: '🎯', title: '초서 100', description: '초서 100개 달성', progress: 0.62, category: _BadgeCategory.collection),
  _Badge(emoji: '📖', title: '완독 달성', description: '첫 책 완독', progress: 0, category: _BadgeCategory.collection),
  _Badge(emoji: '🌟', title: '명문장 큐레이터', description: '좋아요 10개 이상 초서', progress: 0, category: _BadgeCategory.collection),

  // 소셜
  _Badge(emoji: '👥', title: '첫 팔로워', description: '첫 팔로워 생김', unlocked: true, category: _BadgeCategory.social),
  _Badge(emoji: '❤️', title: '공감왕', description: '좋아요 100개 받기', progress: 0.3, category: _BadgeCategory.social),
  _Badge(emoji: '🤝', title: '독서 친구', description: '팔로잉 10명 달성', progress: 0.6, category: _BadgeCategory.social),

  // 특별
  _Badge(emoji: '🎄', title: '크리스마스 독서', description: '12월 25일 독서', progress: 0, category: _BadgeCategory.special),
  _Badge(emoji: '🎆', title: '새해 첫 독서', description: '1월 1일 독서', progress: 0, category: _BadgeCategory.special),
  _Badge(emoji: '🌸', title: '봄날의 독서', description: '벚꽃 시즌 독서 (3~4월)', unlocked: true, category: _BadgeCategory.special),
];

// ─── 챌린지 데이터 ─────────────────────────────────────────────────────────
class _Challenge {
  final String title;
  final String description;
  final double progress;
  final String progressLabel;
  final String deadline;
  final Color color;

  const _Challenge({
    required this.title,
    required this.description,
    required this.progress,
    required this.progressLabel,
    required this.deadline,
    required this.color,
  });
}

const _kChallenges = <_Challenge>[
  _Challenge(
    title: '이번 주 5일 독서',
    description: '주간 독서 목표를 달성하세요',
    progress: 0.6,
    progressLabel: '3/5일',
    deadline: '3일 남음',
    color: Color(0xFF009B58),
  ),
  _Challenge(
    title: '초서 100개 달성',
    description: '문장을 꾸준히 수집하세요',
    progress: 0.62,
    progressLabel: '62/100개',
    deadline: '이번 달',
    color: Color(0xFF5C6BC0),
  ),
  _Challenge(
    title: '이번 달 10시간 독서',
    description: '월간 독서 시간 목표',
    progress: 0.78,
    progressLabel: '7.8/10시간',
    deadline: '11일 남음',
    color: Color(0xFFEF6C00),
  ),
];

// ─── 메인 화면 ─────────────────────────────────────────────────────────────
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  _BadgeCategory? _selectedCategory;

  static const _categories = [
    (label: '전체', value: null),
    (label: '독서 습관', value: _BadgeCategory.reading),
    (label: '문장 수집', value: _BadgeCategory.collection),
    (label: '소셜', value: _BadgeCategory.social),
    (label: '특별', value: _BadgeCategory.special),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  List<_Badge> get _filteredBadges => _selectedCategory == null
      ? _kBadges
      : _kBadges.where((b) => b.category == _selectedCategory).toList();

  int get _unlockedCount => _kBadges.where((b) => b.unlocked).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: context.appTextPrimary),
          onPressed: () {
            HapticFeedback.selectionClick();
            context.pop();
          },
        ),
        title: Text(
          '성취 & 뱃지',
          style: AppTheme.headingSmall.copyWith(
            fontFamily: 'Pretendard',
            color: context.appTextPrimary,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tab,
            indicatorColor: context.appPrimaryAccent,
            labelColor: context.appPrimaryAccent,
            unselectedLabelColor: context.appTextTertiary,
            labelStyle: AppTheme.bodyMedium.copyWith(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: AppTheme.bodyMedium.copyWith(
              fontFamily: 'Pretendard',
            ),
            tabs: const [Tab(text: '뱃지'), Tab(text: '챌린지')],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _BadgesTab(
            badges: _filteredBadges,
            unlockedCount: _unlockedCount,
            totalCount: _kBadges.length,
            selectedCategory: _selectedCategory,
            categories: _categories,
            onCategoryChanged: (c) {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = c);
            },
          ),
          const _ChallengesTab(),
        ],
      ),
    );
  }
}

// ─── 뱃지 탭 ──────────────────────────────────────────────────────────────
class _BadgesTab extends StatelessWidget {
  final List<_Badge> badges;
  final int unlockedCount;
  final int totalCount;
  final _BadgeCategory? selectedCategory;
  final List<({String label, _BadgeCategory? value})> categories;
  final ValueChanged<_BadgeCategory?> onCategoryChanged;

  const _BadgesTab({
    required this.badges,
    required this.unlockedCount,
    required this.totalCount,
    required this.selectedCategory,
    required this.categories,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ─── 레벨 헤더 ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: _LevelHeader(
            unlockedCount: unlockedCount,
            totalCount: totalCount,
          ),
        ),

        // ─── 카테고리 필터 ────────────────────────────────────────
        SliverToBoxAdapter(
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
              itemCount: categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = categories[i];
                final selected = cat.value == selectedCategory;
                return GestureDetector(
                  onTap: () => onCategoryChanged(cat.value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: selected
                        ? AppTheme.smoothBox(
                            gradient: context.appReadingGradient,
                            radius: AppTheme.radiusMD,
                          )
                        : AppTheme.smoothBox(
                            color: context.appCard,
                            radius: AppTheme.radiusMD,
                            side: BorderSide(color: context.appBorder),
                          ),
                    child: Text(
                      cat.label,
                      style: AppTheme.captionLarge.copyWith(
                        fontFamily: 'Pretendard',
                        color: selected ? Colors.white : context.appTextSecondary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spaceLG)),

        // ─── 뱃지 그리드 ──────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: badges.length,
            itemBuilder: (_, i) => _BadgeTile(badge: badges[i]),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.space3XL)),
      ],
    );
  }
}

// ─── 레벨 헤더 ────────────────────────────────────────────────────────────
class _LevelHeader extends StatelessWidget {
  final int unlockedCount;
  final int totalCount;

  const _LevelHeader({required this.unlockedCount, required this.totalCount});

  int get _level => (unlockedCount / 3).floor() + 1;
  double get _xpProgress => (unlockedCount % 3) / 3;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppTheme.screenPadding),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.smoothBox(
        gradient: context.appReadingGradient,
        radius: AppTheme.radiusXL,
      ),
      child: Row(
        children: [
          // 레벨 원
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                'Lv.$_level',
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '독서 레벨 $_level',
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$unlockedCount / $totalCount 뱃지 획득',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _xpProgress,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '다음 레벨까지 ${3 - (unlockedCount % 3)}개',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 뱃지 타일 ────────────────────────────────────────────────────────────
class _BadgeTile extends StatelessWidget {
  final _Badge badge;

  const _BadgeTile({required this.badge});

  @override
  Widget build(BuildContext context) {
    final locked = !badge.unlocked && badge.progress == 0;
    final inProgress = !badge.unlocked && badge.progress > 0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _showBadgeDetail(context, badge);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: AppTheme.smoothBox(
          color: badge.unlocked
              ? context.primaryBg(0.12)
              : context.appCard,
          radius: AppTheme.radiusLG,
          side: BorderSide(
            color: badge.unlocked
                ? context.appPrimaryAccent.withValues(alpha: 0.3)
                : context.appBorder,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 이모지
            ColorFiltered(
              colorFilter: locked
                  ? const ColorFilter.matrix([
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0,      0,      0,      1, 0,
                    ])
                  : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
              child: Text(
                badge.emoji,
                style: TextStyle(
                  fontSize: 32,
                  color: locked ? null : null,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              badge.title,
              style: AppTheme.captionLarge.copyWith(
                fontFamily: 'Pretendard',
                color: badge.unlocked
                    ? context.appTextPrimary
                    : context.appTextTertiary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (inProgress) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: badge.progress,
                    backgroundColor: context.appBorder,
                    valueColor: AlwaysStoppedAnimation(context.appPrimaryAccent),
                    minHeight: 3,
                  ),
                ),
              ),
            ],
            if (badge.unlocked) ...[
              const SizedBox(height: 4),
              Icon(Icons.check_circle_rounded, size: 14, color: context.appPrimaryAccent),
            ],
          ],
        ),
      ),
    );
  }

  void _showBadgeDetail(BuildContext context, _Badge badge) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appCard,
      shape: SmoothRectangleBorderCompat.fromBorderRadius(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BadgeDetailSheet(badge: badge),
    );
  }
}

// ─── SmoothRectangleBorder 호환 헬퍼 ──────────────────────────────────────
class SmoothRectangleBorderCompat {
  static ShapeBorder fromBorderRadius({required BorderRadius borderRadius}) {
    return RoundedRectangleBorder(borderRadius: borderRadius);
  }
}

// ─── 뱃지 상세 시트 ───────────────────────────────────────────────────────
class _BadgeDetailSheet extends StatelessWidget {
  final _Badge badge;
  const _BadgeDetailSheet({required this.badge});

  @override
  Widget build(BuildContext context) {
    final inProgress = !badge.unlocked && badge.progress > 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.appBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(badge.emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              badge.title,
              style: AppTheme.headingMedium.copyWith(
                fontFamily: 'Pretendard',
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              style: AppTheme.bodyMedium.copyWith(
                fontFamily: 'Pretendard',
                color: context.appTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (inProgress) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: badge.progress,
                        backgroundColor: context.appBorder,
                        valueColor: AlwaysStoppedAnimation(context.appPrimaryAccent),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(badge.progress * 100).round()}%',
                    style: AppTheme.bodyMedium.copyWith(
                      fontFamily: 'Pretendard',
                      color: context.appPrimaryAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
            if (badge.unlocked) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: AppTheme.smoothPill(
                  color: context.appPrimaryAccent.withValues(alpha: 0.12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: context.appPrimaryAccent),
                    const SizedBox(width: 6),
                    Text(
                      '획득 완료',
                      style: AppTheme.captionLarge.copyWith(
                        fontFamily: 'Pretendard',
                        color: context.appPrimaryAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── 챌린지 탭 ────────────────────────────────────────────────────────────
class _ChallengesTab extends StatelessWidget {
  const _ChallengesTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        // 진행 중 섹션
        _ChallengeSection(
          title: '진행 중',
          subtitle: '${_kChallenges.length}개',
          children: _kChallenges.map((c) => _ChallengeTile(challenge: c)).toList(),
        ),
        const SizedBox(height: AppTheme.space2XL),

        // 예정 섹션
        _ChallengeSection(
          title: '다가오는 챌린지',
          subtitle: null,
          children: [
            _UpcomingChallengeTile(
              emoji: '🌿',
              title: '5월의 독서',
              description: '5월 한 달 동안 8권 읽기',
              startDate: '5월 1일 시작',
            ),
            const SizedBox(height: 8),
            _UpcomingChallengeTile(
              emoji: '☀️',
              title: '여름 독서 챌린지',
              description: '6~8월 하루 40분 독서',
              startDate: '6월 1일 시작',
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space3XL),
      ],
    );
  }
}

class _ChallengeSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _ChallengeSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: AppTheme.headingSmall.copyWith(
                fontFamily: 'Pretendard',
                color: context.appTextPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(width: 8),
              Text(
                subtitle!,
                style: AppTheme.captionLarge.copyWith(
                  fontFamily: 'Pretendard',
                  color: context.appTextTertiary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  final _Challenge challenge;

  const _ChallengeTile({required this.challenge});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: AppTheme.radiusLG,
        side: BorderSide(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  challenge.title,
                  style: AppTheme.bodyMedium.copyWith(
                    fontFamily: 'Pretendard',
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: AppTheme.smoothPill(
                  color: challenge.color.withValues(alpha: 0.12),
                ),
                child: Text(
                  challenge.deadline,
                  style: AppTheme.captionLarge.copyWith(
                    fontFamily: 'Pretendard',
                    color: challenge.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            challenge.description,
            style: AppTheme.captionLarge.copyWith(
              fontFamily: 'Pretendard',
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: challenge.progress,
                    backgroundColor: context.appBorder,
                    valueColor: AlwaysStoppedAnimation(challenge.color),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                challenge.progressLabel,
                style: AppTheme.captionLarge.copyWith(
                  fontFamily: 'Pretendard',
                  color: challenge.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingChallengeTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final String startDate;

  const _UpcomingChallengeTile({
    required this.emoji,
    required this.title,
    required this.description,
    required this.startDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: AppTheme.radiusLG,
        side: BorderSide(color: context.appBorder),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(
                    fontFamily: 'Pretendard',
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: AppTheme.captionLarge.copyWith(
                    fontFamily: 'Pretendard',
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            startDate,
            style: AppTheme.captionLarge.copyWith(
              fontFamily: 'Pretendard',
              color: context.appTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
