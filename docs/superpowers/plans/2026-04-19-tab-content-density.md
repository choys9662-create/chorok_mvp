# 탭 콘텐츠 밀도 보강 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 홈·피드·서재 탭에 시각적으로 비어있는 섹션을 추가해 콘텐츠 밀도를 높인다.

**Architecture:** 기존 파일 내 private 위젯으로만 추가. 새 파일 생성 없음. 모두 목업 const 데이터 사용.

**Tech Stack:** Flutter, Riverpod, figma_squircle, go_router, AppTheme/ChorokCard 공유 위젯

---

## 파일 맵

| 파일 | 변경 내용 |
|---|---|
| `lib/features/home/screen/home_screen.dart` | `_kWishlistBooks` 목업 + `_WishlistSection` + `_WishlistBookCard` 추가, slivers 삽입 |
| `lib/features/feed/screen/feed_screen.dart` | `_kTrendingBooks` 목업 + `_ActivityBanner` + `_TrendingBooksSection` + `_TrendingBookCard` 추가, build 수정 |
| `lib/features/library/screen/library_screen.dart` | `_MonthlyAchievementCard` + `_LibraryWishlistSection` + `_WishlistListCard` 추가, 기존 ListView 수정 |

---

## Task 1: 홈 탭 — "다음에 읽을 책" 섹션

**Files:**
- Modify: `lib/features/home/screen/home_screen.dart`

- [ ] **Step 1: 목업 데이터 + typedef 추가**

`home_screen.dart` 파일 상단 목업 데이터 영역 (`_kReadingBooks` 정의 아래)에 추가:

```dart
typedef _WishlistBook = ({
  String title,
  String author,
  int addedDays,
  int gradientIndex,
  int totalPages,
});

const List<_WishlistBook> _kWishlistBooks = [
  (
    title: '소년이 온다',
    author: '한강',
    addedDays: 3,
    gradientIndex: 3,
    totalPages: 216,
  ),
  (
    title: '불편한 편의점',
    author: '김호연',
    addedDays: 7,
    gradientIndex: 6,
    totalPages: 312,
  ),
  (
    title: '달러구트 꿈 백화점',
    author: '이미예',
    addedDays: 14,
    gradientIndex: 1,
    totalPages: 304,
  ),
];
```

- [ ] **Step 2: `_WishlistSection` 위젯 추가**

`home_screen.dart` 파일 하단 (`_ProgressBar` 위젯 위)에 추가:

```dart
// ─── ⑤ 다음에 읽을 책 ────────────────────────────────────────────────────

class _WishlistSection extends StatelessWidget {
  const _WishlistSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
          child: Row(
            children: [
              Text(
                '다음에 읽을 책',
                style: AppTheme.headingSmall.copyWith(
                  fontFamily: 'Pretendard',
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_kWishlistBooks.length}권',
                style: AppTheme.captionLarge.copyWith(
                  color: context.appPrimaryAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.screenPadding),
            itemCount: _kWishlistBooks.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < _kWishlistBooks.length - 1 ? 12 : 0,
                ),
                child: _WishlistBookCard(book: _kWishlistBooks[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: `_WishlistBookCard` 위젯 추가**

`_WishlistSection` 바로 아래에 추가:

```dart
class _WishlistBookCard extends StatefulWidget {
  final _WishlistBook book;
  const _WishlistBookCard({required this.book});

  @override
  State<_WishlistBookCard> createState() => _WishlistBookCardState();
}

class _WishlistBookCardState extends State<_WishlistBookCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    final gradColors =
        AppTheme.coverGradients[b.gradientIndex % AppTheme.coverGradients.length];
    final daysText = b.addedDays == 0 ? '오늘' : '${b.addedDays}일 전';

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 150,
          clipBehavior: Clip.antiAlias,
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: 20,
            side: BorderSide(color: context.appBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 표지
              Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradColors,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -8,
                      bottom: -8,
                      child: Icon(
                        Icons.bookmark_rounded,
                        size: 56,
                        color: context.appPrimaryAccent.withValues(alpha: 0.08),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: ShapeDecoration(
                          color: context.appSurface.withValues(alpha: 0.75),
                          shape: SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius(
                              cornerRadius: 6,
                              cornerSmoothing: 0.6,
                            ),
                          ),
                        ),
                        child: Text(
                          daysText,
                          style: AppTheme.captionSmall.copyWith(
                            fontFamily: 'Pretendard',
                            color: context.appTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 책 정보
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.title,
                      style: AppTheme.bodySmall.copyWith(
                        fontFamily: 'Pretendard',
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.author,
                      style: AppTheme.captionSmall.copyWith(
                        fontFamily: 'Pretendard',
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // 읽기 시작 버튼
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Semantics(
                  label: '${b.title} 읽기 시작',
                  button: true,
                  child: GestureDetector(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      final goal = await showModalBottomSheet<SessionGoal>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => SessionGoalSheet(
                          currentPage: 0,
                          totalPages: b.totalPages,
                          bookTitle: b.title,
                        ),
                      );
                      if (goal != null && context.mounted) {
                        context.push(
                          AppConstants.routeSession,
                          extra: SessionExtra(
                            goal: goal,
                            bookId: b.title.hashCode.toString(),
                            bookTitle: b.title,
                            bookAuthor: b.author,
                            startPage: 0,
                            totalPages: b.totalPages,
                          ),
                        );
                      }
                    },
                    child: Container(
                      height: 34,
                      alignment: Alignment.center,
                      decoration: AppTheme.smoothBox(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                        radius: 10,
                        side: BorderSide(
                          color: context.appPrimaryAccent.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 14,
                            color: context.appPrimaryAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '읽기 시작',
                            style: AppTheme.captionLarge.copyWith(
                              fontFamily: 'Pretendard',
                              color: context.appPrimaryAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: HomeScreen slivers 목록에 섹션 삽입**

`home_screen.dart`의 `HomeScreen.build()` 내 slivers 리스트에서
`// ③ 문장 기반 추천` 슬라이버 블록 아래, `// ④ 피드 하이라이트` 위에 삽입:

```dart
// ④ 다음에 읽을 책
const SliverToBoxAdapter(child: SizedBox(height: 24)),
const SliverToBoxAdapter(child: _WishlistSection()),
```

기존 `// ④ 피드 하이라이트`, `// ⑤ 타임캡슐 문장` 주석 번호를 각각 ⑤, ⑥으로 변경.

- [ ] **Step 5: 커밋**

```bash
git add lib/features/home/screen/home_screen.dart
git commit -m "feat: 홈 탭에 '다음에 읽을 책' 위시리스트 섹션 추가"
```

---

## Task 2: 피드 탭 — 활동 배너 + 트렌딩 책 섹션

**Files:**
- Modify: `lib/features/feed/screen/feed_screen.dart`

- [ ] **Step 1: 목업 데이터 + typedef 추가**

`feed_screen.dart` 상단 import 아래, `class FeedScreen` 위에 추가:

```dart
typedef _TrendingBook = ({
  String title,
  String author,
  int sentenceCount,
  int gradientIndex,
});

const List<_TrendingBook> _kTrendingBooks = [
  (title: '채식주의자', author: '한강', sentenceCount: 142, gradientIndex: 0),
  (title: '파친코', author: '이민진', sentenceCount: 98, gradientIndex: 2),
  (title: '아몬드', author: '손원평', sentenceCount: 87, gradientIndex: 4),
  (title: '소년이 온다', author: '한강', sentenceCount: 76, gradientIndex: 3),
  (title: '82년생 김지영', author: '조남주', sentenceCount: 61, gradientIndex: 1),
];
```

- [ ] **Step 2: `_ActivityBanner` 위젯 추가**

`feed_screen.dart` 하단 (`_FeedFilterChip` 위)에 추가:

```dart
// ─── 활동 배너 ────────────────────────────────────────────────────────────
class _ActivityBanner extends StatelessWidget {
  const _ActivityBanner();

  @override
  Widget build(BuildContext context) {
    // 날짜 seed 기반 목업 숫자 (매일 달라 보이도록)
    final seed = DateTime.now().day;
    final readers = 300 + (seed * 7) % 200;
    final overlaps = 8 + seed % 13;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding, 10,
        AppTheme.screenPadding, 0,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: AppTheme.smoothBox(
          color: context.appCard,
          radius: AppTheme.radiusMD,
          side: BorderSide(color: context.appBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: context.appPrimaryAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.appPrimaryAccent.withValues(alpha: 0.5),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: AppTheme.captionLarge.copyWith(
                    color: context.appTextSecondary,
                  ),
                  children: [
                    TextSpan(
                      text: '오늘 $readers명',
                      style: AppTheme.captionLarge.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(text: '이 문장을 기록했어요 · '),
                    TextSpan(
                      text: '겹문장 $overlaps건',
                      style: AppTheme.captionLarge.copyWith(
                        color: context.appPrimaryAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: `_TrendingBooksSection` + `_TrendingBookCard` 위젯 추가**

`_ActivityBanner` 아래에 추가:

```dart
// ─── 트렌딩 책 섹션 ──────────────────────────────────────────────────────
class _TrendingBooksSection extends StatelessWidget {
  const _TrendingBooksSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding, 16, AppTheme.screenPadding, 8,
          ),
          child: Text(
            '이번 주 화제의 책',
            style: AppTheme.captionLarge.copyWith(
              fontFamily: 'Pretendard',
              color: context.appTextTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.screenPadding,
            ),
            itemCount: _kTrendingBooks.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < _kTrendingBooks.length - 1 ? 10 : 0,
                ),
                child: _TrendingBookCard(book: _kTrendingBooks[index]),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _TrendingBookCard extends StatefulWidget {
  final _TrendingBook book;
  const _TrendingBookCard({required this.book});

  @override
  State<_TrendingBookCard> createState() => _TrendingBookCardState();
}

class _TrendingBookCardState extends State<_TrendingBookCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    final gradColors =
        AppTheme.coverGradients[b.gradientIndex % AppTheme.coverGradients.length];

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 200,
          clipBehavior: Clip.antiAlias,
          decoration: AppTheme.smoothBox(
            color: context.appCard,
            radius: AppTheme.radiusMD,
            side: BorderSide(color: context.appBorder),
          ),
          child: Row(
            children: [
              // 표지 컬러 바
              Container(
                width: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: gradColors,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      b.title,
                      style: AppTheme.bodySmall.copyWith(
                        fontFamily: 'Pretendard',
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.author,
                      style: AppTheme.captionSmall.copyWith(
                        fontFamily: 'Pretendard',
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // 문장 수집 뱃지
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: ShapeDecoration(
                    color: context.appPrimaryAccent.withValues(alpha: 0.08),
                    shape: SmoothRectangleBorder(
                      borderRadius: SmoothBorderRadius(
                        cornerRadius: 6,
                        cornerSmoothing: 0.6,
                      ),
                    ),
                  ),
                  child: Text(
                    '${b.sentenceCount}개',
                    style: AppTheme.captionSmall.copyWith(
                      fontFamily: 'Pretendard',
                      color: context.appPrimaryAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: FeedScreen.build() 수정**

`FeedScreen.build()`의 `Column children` 목록을 수정한다.

**헤더 `Padding` 위젯 아래, `Divider` 위에** `_ActivityBanner()` 삽입:

```dart
// 기존:
// Padding(header...),
// Divider(height: 1, ...),

// 변경 후:
Padding(
  padding: const EdgeInsets.fromLTRB(
    AppTheme.screenPadding, 20,
    AppTheme.screenPadding, 12,
  ),
  child: Row(
    children: [
      // ... 기존 헤더 내용 유지 ...
    ],
  ),
),
const _ActivityBanner(),   // ← 추가
const SizedBox(height: 10),
Divider(height: 1, color: context.appBorder),
```

**`Expanded` 자식을 Column으로 감싸 트렌딩 섹션 삽입:**

```dart
// 기존:
Expanded(
  child: _filter == _FeedFilter.overlap
      ? _buildOverlapView(groups, scrollCtrl)
      : filtered.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(...),
),

// 변경 후:
Expanded(
  child: _filter == _FeedFilter.overlap
      ? _buildOverlapView(groups, scrollCtrl)
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _TrendingBooksSection(),
            Divider(height: 1, color: context.appBorder),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      color: context.appPrimaryAccent,
                      backgroundColor: context.appCard,
                      onRefresh: _onRefresh,
                      child: _SentenceList(
                        sentences: filtered,
                        overlapIds: overlapIds,
                        controller: scrollCtrl,
                      ),
                    ),
            ),
          ],
        ),
),
```

- [ ] **Step 5: 커밋**

```bash
git add lib/features/feed/screen/feed_screen.dart
git commit -m "feat: 피드 탭에 활동 배너 및 트렌딩 책 섹션 추가"
```

---

## Task 3: 서재 탭 — 성과 뱃지 카드 + 읽고 싶은 책 섹션

**Files:**
- Modify: `lib/features/library/screen/library_screen.dart`

- [ ] **Step 1: `_MonthlyAchievementCard` 위젯 추가**

`library_screen.dart` 하단 (기존 마지막 private 위젯 아래)에 추가:

```dart
// ─── 이번 달 독서 성과 뱃지 ──────────────────────────────────────────────
class _MonthlyAchievementCard extends StatelessWidget {
  const _MonthlyAchievementCard();

  @override
  Widget build(BuildContext context) {
    const items = [
      (icon: Icons.menu_book_rounded, value: '2권', label: '이번 달 완독'),
      (icon: Icons.local_fire_department_rounded, value: '5일', label: '최장 연속'),
      (icon: Icons.format_quote_rounded, value: '47개', label: '수집 문장'),
    ];

    return Semantics(
      label: '이번 달 독서 성과 — 분석 보기',
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          context.go(AppConstants.routeAnalytics);
        },
        child: ChorokCard(
          padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
          child: Row(
            children: items.asMap().entries.expand((e) {
              final item = e.value;
              return [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: AppTheme.smoothBox(
                          color: context.appPrimaryAccent.withValues(alpha: 0.10),
                          radius: AppTheme.radiusMD,
                          side: BorderSide(
                            color: context.appPrimaryAccent.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Icon(
                          item.icon,
                          size: 18,
                          color: context.appPrimaryAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.value,
                        style: AppTheme.headingSmall.copyWith(
                          color: context.appTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: AppTheme.captionSmall.copyWith(
                          fontFamily: 'Pretendard',
                          color: context.appTextTertiary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (e.key < items.length - 1)
                  Container(
                    width: 1,
                    height: 48,
                    color: context.appBorder,
                  ),
              ];
            }).toList(),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: `_LibraryWishlistSection` + `_WishlistListCard` 위젯 추가**

`_MonthlyAchievementCard` 아래에 추가:

```dart
// ─── 읽고 싶은 책 목록 ────────────────────────────────────────────────────
typedef _LibraryWishlistBook = ({
  String title,
  String author,
  int addedDays,
  int gradientIndex,
  int totalPages,
});

const List<_LibraryWishlistBook> _kLibraryWishlistBooks = [
  (title: '소년이 온다', author: '한강', addedDays: 3, gradientIndex: 3, totalPages: 216),
  (title: '불편한 편의점', author: '김호연', addedDays: 7, gradientIndex: 6, totalPages: 312),
  (title: '달러구트 꿈 백화점', author: '이미예', addedDays: 14, gradientIndex: 1, totalPages: 304),
];

class _LibraryWishlistSection extends StatelessWidget {
  const _LibraryWishlistSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChorokSectionHeader(
          title: '읽고 싶은 책',
          trailing: Text(
            '${_kLibraryWishlistBooks.length}권',
            style: AppTheme.captionLarge.copyWith(
              color: context.appPrimaryAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceMD),
        ChorokCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: _kLibraryWishlistBooks.asMap().entries.map((e) {
              final isLast = e.key == _kLibraryWishlistBooks.length - 1;
              return Column(
                children: [
                  _WishlistListCard(book: e.value),
                  if (!isLast) Divider(height: 1, color: context.appBorder, indent: 64),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _WishlistListCard extends StatefulWidget {
  final _LibraryWishlistBook book;
  const _WishlistListCard({required this.book});

  @override
  State<_WishlistListCard> createState() => _WishlistListCardState();
}

class _WishlistListCardState extends State<_WishlistListCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.book;
    final gradColors =
        AppTheme.coverGradients[b.gradientIndex % AppTheme.coverGradients.length];
    final daysText = b.addedDays == 0 ? '오늘 추가' : '${b.addedDays}일 전 추가';

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedOpacity(
        opacity: _isPressed ? 0.7 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.cardPaddingMD,
            vertical: AppTheme.spaceMD,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 표지 컬러 바
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: gradColors,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMD),
                // 책 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.title,
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.appTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        b.author,
                        style: AppTheme.captionLarge.copyWith(
                          color: context.appTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        daysText,
                        style: AppTheme.captionSmall.copyWith(
                          color: context.appTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                // 읽기 시작
                Semantics(
                  label: '${b.title} 읽기 시작',
                  button: true,
                  child: GestureDetector(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      final goal = await showModalBottomSheet<SessionGoal>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => SessionGoalSheet(
                          currentPage: 0,
                          totalPages: b.totalPages,
                          bookTitle: b.title,
                        ),
                      );
                      if (goal != null && context.mounted) {
                        context.push(
                          AppConstants.routeSession,
                          extra: SessionExtra(
                            goal: goal,
                            bookId: b.title.hashCode.toString(),
                            bookTitle: b.title,
                            bookAuthor: b.author,
                            startPage: 0,
                            totalPages: b.totalPages,
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: AppTheme.smoothBox(
                        color: AppTheme.primary.withValues(alpha: 0.4),
                        radius: AppTheme.radiusSM,
                        side: BorderSide(
                          color: context.appPrimaryAccent.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        '읽기 시작',
                        style: AppTheme.captionLarge.copyWith(
                          fontFamily: 'Pretendard',
                          color: context.appPrimaryAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 서재 화면의 ListView children 수정**

`library_screen.dart`의 `LibraryScreen`(또는 내부 state)의 `ListView` 혹은 `CustomScrollView`에서:

1. **성과 뱃지 카드** — 프로필 헤더 바로 뒤 첫 번째 항목으로 삽입:
```dart
// 프로필 헤더 위젯 다음에:
const SizedBox(height: AppTheme.spaceMD),
const _MonthlyAchievementCard(),
const SizedBox(height: AppTheme.spaceXL),
```

2. **읽고 싶은 책 섹션** — 파일 내 마지막 콘텐츠 섹션(스택 영역 차트 또는 독서 캘린더) 아래에 삽입:
```dart
const SizedBox(height: AppTheme.spaceXL),
const _LibraryWishlistSection(),
const SizedBox(height: AppTheme.spaceXL),
```

- [ ] **Step 4: 필요한 import 확인**

`library_screen.dart` 상단에 다음이 이미 import되어 있는지 확인:
- `go_router/go_router.dart` ✓ (기존)
- `session_goal.dart` ✓ (기존)
- `app_constants.dart` ✓ (기존)
- `chorok_section_header.dart` ✓ (기존)

없으면 추가.

- [ ] **Step 5: 커밋**

```bash
git add lib/features/library/screen/library_screen.dart
git commit -m "feat: 서재 탭에 이번 달 성과 뱃지 및 읽고 싶은 책 섹션 추가"
```

---

## Self-Review

**스펙 커버리지:**
- 홈 "다음에 읽을 책" → Task 1 ✓
- 피드 활동 배너 → Task 2 Step 2 ✓
- 피드 트렌딩 책 → Task 2 Step 3-4 ✓
- 서재 성과 뱃지 → Task 3 Step 1 ✓
- 서재 읽고 싶은 책 → Task 3 Step 2 ✓

**Empty State:** 홈 `_WishlistSection`은 `_kWishlistBooks`가 const non-empty이므로 Empty State 분기 불필요 (목업). 서재도 동일.

**타입 일관성:**
- `_WishlistBook` (홈) vs `_LibraryWishlistBook` (서재): 동일 구조, 파일이 달라 별도 typedef 사용 ✓
- `SessionExtra` / `SessionGoal` 사용 방식: 홈 기존 코드와 동일 패턴 ✓
- `AppTheme.radiusSM` — AppTheme에 실제로 정의되어 있는지 확인 필요. 없으면 `AppTheme.radiusMD`로 대체.
