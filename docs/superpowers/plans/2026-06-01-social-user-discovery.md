# 소셜 유저 발견 & 연결 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 검색창에서 유저를 찾아 프로필로 이동하고, 팔로우하고, 그 유저가 남긴 공개 초서까지 볼 수 있게 한다.

**Architecture:** Supabase `profiles`/`follows`/`sentences` 테이블 기반. 클라이언트는 Riverpod + GoRouter. 파싱·변환 로직은 순수 함수로 분리해 단위 테스트하고, Supabase 쿼리 자체는 테스트하지 않는다 (기존 코드베이스 패턴). 인스타그램식 공개/비공개 계정 모델 — `profiles.is_private`, `follows.status`.

**Tech Stack:** Flutter, Riverpod (AsyncNotifier), GoRouter, Supabase, figma_squircle (smooth UI).

---

## File Structure

| 파일 | 책임 | 신규/수정 |
|------|------|----------|
| Supabase migration | is_private, status 컬럼 + RLS 보강 | 신규 (DB) |
| `lib/shared/models/user_profile.dart` | UserProfile 모델에 isPrivate 추가 | 수정 |
| `lib/shared/repositories/profile_repository.dart` | getUserSentences 추가, searchUsers에 is_private 포함 | 수정 |
| `lib/shared/repositories/follow_repository.dart` | follow가 status 반환, followStatus 조회 | 수정 |
| `lib/features/profile/util/sentence_row_parser.dart` | sentences row → FeedSentence 순수 변환 함수 | 신규 (테스트 대상) |
| `lib/features/profile/controller/user_profile_provider.dart` | 특정 유저 프로필+초서 로드 | 신규 |
| `lib/features/profile/screen/user_profile_screen.dart` | 프로필 화면 (4-state) | 신규 |
| `lib/core/constants/app_constants.dart` | routeUserProfile 상수 | 수정 |
| `lib/core/router/app_router.dart` | UserProfileScreen 라우트 | 수정 |
| `lib/features/search/screen/search_screen.dart` | _UserCard 탭 → 프로필 이동 | 수정 |
| `test/features/profile/sentence_row_parser_test.dart` | 파서 단위 테스트 | 신규 |

**Note:** 새 feature 폴더 `lib/features/profile/`를 만든다. 프로필 화면이 검색에 종속되지 않고 (피드·소셜 어디서든 진입), 독립적인 책임을 가지기 때문이다.

---

## Task 1: DB 스키마 — is_private, status 컬럼 + RLS 보강

**Files:**
- Supabase migration (apply_migration via MCP, project_id: `ebruktlffxduvgjgaymd`)

이 작업은 Supabase MCP `apply_migration`으로 수행한다. 코드 변경 없음.

- [ ] **Step 1: 컬럼 추가 마이그레이션 적용**

migration name: `add_social_account_visibility`

```sql
alter table public.profiles
  add column if not exists is_private boolean not null default false;

alter table public.follows
  add column if not exists status text not null default 'accepted'
  check (status in ('accepted', 'pending'));
```

- [ ] **Step 2: RLS 보강 — following 정책이 accepted만 통과**

migration name: `tighten_sentences_following_rls`

```sql
drop policy if exists sentences_select_following on public.sentences;

create policy sentences_select_following on public.sentences
  for select
  using (
    exists (
      select 1 from public.follows
      where follows.follower_id = auth.uid()
        and follows.following_id = sentences.user_id
        and follows.status = 'accepted'
    )
  );
```

- [ ] **Step 3: 검증 — 정책·컬럼 확인**

Supabase MCP `execute_sql`:
```sql
select column_name from information_schema.columns
  where table_name = 'profiles' and column_name = 'is_private';
select column_name from information_schema.columns
  where table_name = 'follows' and column_name = 'status';
```
Expected: 두 쿼리 모두 1행 반환 (컬럼 존재 확인).

- [ ] **Step 4: Commit (마이그레이션은 DB에 적용됨, 코드 변경 없으므로 문서만 갱신)**

이 태스크는 DB-only이므로 별도 커밋 없이 다음 태스크에서 함께 커밋한다. (코드 변경 없음)

---

## Task 2: UserProfile 모델에 isPrivate 추가

**Files:**
- Modify: `lib/shared/models/user_profile.dart`

- [ ] **Step 1: isPrivate 필드 추가**

`lib/shared/models/user_profile.dart` 전체를 아래로 교체:

```dart
class UserProfile {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final bool isPrivate;

  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.isPrivate = false,
  });

  factory UserProfile.fromRow(Map<String, dynamic> r) {
    return UserProfile(
      id: r['id'] as String,
      username: r['username'] as String? ?? '',
      displayName:
          (r['display_name'] as String?) ?? (r['username'] as String?) ?? '사용자',
      avatarUrl: r['avatar_url'] as String?,
      bio: r['bio'] as String?,
      isPrivate: r['is_private'] as bool? ?? false,
    );
  }
}
```

- [ ] **Step 2: analyze 통과 확인**

Run: `cd /Users/joyongseong/Documents/dev/chorok_app && flutter analyze lib/shared/models/user_profile.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
cd /Users/joyongseong/Documents/dev/chorok_app
git add lib/shared/models/user_profile.dart
git commit -m "feat: UserProfile에 isPrivate 필드 추가

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: sentences row → FeedSentence 순수 파서 (TDD)

**Files:**
- Create: `lib/features/profile/util/sentence_row_parser.dart`
- Test: `test/features/profile/sentence_row_parser_test.dart`

기존 `feed_provider.dart`의 `_loadFromSupabase` 안에 인라인된 row 파싱 로직을, 테스트 가능한 순수 함수로 추출한다. 프로필 화면과 피드가 같은 파서를 재사용한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/features/profile/sentence_row_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:chorok_app/features/profile/util/sentence_row_parser.dart';

void main() {
  group('parseSentenceRow', () {
    test('global_books 우선으로 책 정보 추출', () {
      final row = {
        'id': 's1',
        'content': '문장 내용',
        'thought': '내 생각',
        'created_at': '2026-05-01T10:00:00Z',
        'profiles': {'username': 'reader', 'display_name': '독자'},
        'books': {'title': '로컬책', 'author': '로컬저자', 'cover_url': null},
        'global_books': {
          'title': '글로벌책',
          'author': '글로벌저자',
          'cover_url': 'http://cover',
        },
      };
      final s = parseSentenceRow(row, fallbackUsername: '나');
      expect(s.id, 's1');
      expect(s.content, '문장 내용');
      expect(s.thought, '내 생각');
      expect(s.bookTitle, '글로벌책');
      expect(s.bookAuthor, '글로벌저자');
      expect(s.coverUrl, 'http://cover');
      expect(s.username, '독자');
    });

    test('global_books 없으면 books 사용', () {
      final row = {
        'id': 's2',
        'content': 'c',
        'created_at': '2026-05-01T10:00:00Z',
        'books': {'title': '로컬책', 'author': '로컬저자'},
      };
      final s = parseSentenceRow(row, fallbackUsername: '나');
      expect(s.bookTitle, '로컬책');
      expect(s.bookAuthor, '로컬저자');
    });

    test('profiles 없으면 fallbackUsername 사용', () {
      final row = {
        'id': 's3',
        'content': 'c',
        'created_at': '2026-05-01T10:00:00Z',
      };
      final s = parseSentenceRow(row, fallbackUsername: '용성');
      expect(s.username, '용성');
      expect(s.bookTitle, '알 수 없는 책');
    });

    test('display_name 없으면 username 사용', () {
      final row = {
        'id': 's4',
        'content': 'c',
        'created_at': '2026-05-01T10:00:00Z',
        'profiles': {'username': 'janice', 'display_name': null},
      };
      final s = parseSentenceRow(row, fallbackUsername: '나');
      expect(s.username, 'janice');
    });

    test('sentence_likes count 추출', () {
      final row = {
        'id': 's5',
        'content': 'c',
        'created_at': '2026-05-01T10:00:00Z',
        'sentence_likes': [
          {'count': 7},
        ],
      };
      final s = parseSentenceRow(row, fallbackUsername: '나');
      expect(s.empathyCount, 7);
    });

    test('잘못된 created_at은 현재 시각으로 폴백', () {
      final row = {'id': 's6', 'content': 'c', 'created_at': 'invalid'};
      final s = parseSentenceRow(row, fallbackUsername: '나');
      expect(s.savedAt, isA<DateTime>());
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd /Users/joyongseong/Documents/dev/chorok_app && flutter test test/features/profile/sentence_row_parser_test.dart`
Expected: FAIL — `sentence_row_parser.dart` 없음 (compile error).

- [ ] **Step 3: 파서 구현**

`lib/features/profile/util/sentence_row_parser.dart`:

```dart
import '../../../shared/models/reading_session.dart';

/// Supabase sentences 조인 row를 FeedSentence로 변환하는 순수 함수.
/// 피드와 유저 프로필 화면이 공유한다.
///
/// [fallbackUsername]은 row에 profiles 조인이 없을 때 사용한다 (예: 본인 문장 → '나').
FeedSentence parseSentenceRow(
  Map<String, dynamic> row, {
  required String fallbackUsername,
}) {
  final localBook = row['books'] as Map<String, dynamic>?;
  final globalBook = row['global_books'] as Map<String, dynamic>?;
  final book = globalBook ?? localBook;

  final profile = row['profiles'] as Map<String, dynamic>?;
  final username =
      (profile?['display_name'] as String?) ??
      (profile?['username'] as String?) ??
      fallbackUsername;

  final likesAgg = row['sentence_likes'] as List?;
  final likeCount = likesAgg != null && likesAgg.isNotEmpty
      ? ((likesAgg.first as Map)['count'] as int? ?? 0)
      : 0;

  final createdAt =
      DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now();

  return FeedSentence(
    id: row['id'] as String? ?? '',
    content: row['content'] as String? ?? '',
    thought: row['thought'] as String?,
    bookTitle: book?['title'] as String? ?? '알 수 없는 책',
    bookAuthor: book?['author'] as String? ?? '',
    coverUrl: book?['cover_url'] as String?,
    username: username,
    savedAt: createdAt,
    empathyCount: likeCount,
  );
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd /Users/joyongseong/Documents/dev/chorok_app && flutter test test/features/profile/sentence_row_parser_test.dart`
Expected: PASS — 6 tests.

- [ ] **Step 5: Commit**

```bash
cd /Users/joyongseong/Documents/dev/chorok_app
git add lib/features/profile/util/sentence_row_parser.dart test/features/profile/sentence_row_parser_test.dart
git commit -m "feat: sentences row → FeedSentence 순수 파서 추가 (TDD)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: ProfileRepository — searchUsers에 is_private 포함, getUserSentences 추가

**Files:**
- Modify: `lib/shared/repositories/profile_repository.dart`

- [ ] **Step 1: searchUsers가 is_private를 select하도록 수정**

`profile_repository.dart`의 `searchUsers` 메서드에서 `.select()`를 명시적 컬럼 select로 변경:

```dart
  Future<List<UserProfile>> searchUsers(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final pattern = '%$q%';
    final rows = await _client
        .from('profiles')
        .select('id, username, display_name, avatar_url, bio, is_private')
        .or('username.ilike.$pattern,display_name.ilike.$pattern')
        .limit(limit);
    return (rows as List)
        .map((r) => UserProfile.fromRow(r as Map<String, dynamic>))
        .toList();
  }
```

- [ ] **Step 2: getUserSentences 메서드 추가**

`profile_repository.dart`의 `getByIds` 메서드 바로 아래에 추가:

```dart
  /// 특정 유저의 초서 목록 조회.
  /// RLS가 가시성을 제어한다: 공개 문장(global_book_id 있음) 또는
  /// 본인이 accepted 팔로워인 경우 노출.
  Future<List<Map<String, dynamic>>> getUserSentences(
    String userId, {
    int limit = 50,
  }) async {
    final rows = await _client
        .from('sentences')
        .select(
          'id, content, thought, created_at, '
          'books(title, author, cover_url), '
          'global_books(title, author, cover_url), '
          'sentence_likes(count)',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>();
  }
```

- [ ] **Step 3: analyze 통과 확인**

Run: `cd /Users/joyongseong/Documents/dev/chorok_app && flutter analyze lib/shared/repositories/profile_repository.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
cd /Users/joyongseong/Documents/dev/chorok_app
git add lib/shared/repositories/profile_repository.dart
git commit -m "feat: ProfileRepository에 getUserSentences·is_private select 추가

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: FollowRepository — follow가 status 반환, followStatus 조회

**Files:**
- Modify: `lib/shared/repositories/follow_repository.dart`

공개 계정은 즉시 accepted, 비공개 계정은 pending으로 insert해야 한다. 대상 계정의 is_private를 먼저 조회한다.

- [ ] **Step 1: FollowState enum + follow 수정**

`follow_repository.dart` 상단 import 아래에 enum 추가:

```dart
/// 팔로우 시도 결과 상태.
enum FollowState { accepted, pending, none }
```

`follow_repository.dart`의 기존 `follow` 메서드를 아래로 교체:

```dart
  /// 팔로우 시도. 공개 계정이면 accepted, 비공개 계정이면 pending.
  /// 반환값은 결과 상태.
  Future<FollowState> follow(String targetUserId) async {
    final me = _meId;
    if (me == null || me == targetUserId) return FollowState.none;

    final targetRow = await _client
        .from('profiles')
        .select('is_private')
        .eq('id', targetUserId)
        .maybeSingle();
    final isPrivate = targetRow?['is_private'] as bool? ?? false;
    final status = isPrivate ? 'pending' : 'accepted';

    await _client.from('follows').insert({
      'follower_id': me,
      'following_id': targetUserId,
      'status': status,
    });
    return isPrivate ? FollowState.pending : FollowState.accepted;
  }
```

- [ ] **Step 2: followStatus 조회 메서드 추가 (기존 isFollowing 아래)**

기존 `isFollowing` 메서드 바로 아래에 추가:

```dart
  /// 내가 대상에 대해 가진 팔로우 상태. 팔로우 안 했으면 none.
  Future<FollowState> followStatus(String targetUserId) async {
    final me = _meId;
    if (me == null) return FollowState.none;
    final row = await _client
        .from('follows')
        .select('status')
        .eq('follower_id', me)
        .eq('following_id', targetUserId)
        .maybeSingle();
    if (row == null) return FollowState.none;
    final status = row['status'] as String?;
    return status == 'pending' ? FollowState.pending : FollowState.accepted;
  }
```

- [ ] **Step 3: analyze 통과 확인**

Run: `cd /Users/joyongseong/Documents/dev/chorok_app && flutter analyze lib/shared/repositories/follow_repository.dart`
Expected: No issues found. (만약 `follow`의 반환 타입 변경으로 호출처 에러가 나면 Task 8에서 수정하므로, 이 단계에서는 repository 파일만 analyze)

- [ ] **Step 4: Commit**

```bash
cd /Users/joyongseong/Documents/dev/chorok_app
git add lib/shared/repositories/follow_repository.dart
git commit -m "feat: FollowRepository에 status 인지 follow·followStatus 추가

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: userProfileProvider — 프로필+초서 로드

**Files:**
- Create: `lib/features/profile/controller/user_profile_provider.dart`

- [ ] **Step 1: provider 구현**

`lib/features/profile/controller/user_profile_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/reading_session.dart';
import '../../../shared/repositories/follow_repository.dart';
import '../../../shared/repositories/profile_repository.dart';
import '../util/sentence_row_parser.dart';

/// 유저 프로필 화면 데이터: 그 유저의 초서 목록 + 내 팔로우 상태.
typedef UserProfileData = ({
  List<FeedSentence> sentences,
  FollowState followState,
});

/// userId별 프로필 데이터를 로드한다.
final userProfileProvider =
    FutureProvider.family<UserProfileData, String>((ref, userId) async {
  final profileRepo = ref.read(profileRepositoryProvider);
  final followRepo = ref.read(followRepositoryProvider);

  final followState = await followRepo.followStatus(userId);
  final rows = await profileRepo.getUserSentences(userId);
  final sentences = rows
      .map((r) => parseSentenceRow(r, fallbackUsername: '독자'))
      .toList();

  return (sentences: sentences, followState: followState);
});
```

- [ ] **Step 2: analyze 통과 확인**

Run: `cd /Users/joyongseong/Documents/dev/chorok_app && flutter analyze lib/features/profile/controller/user_profile_provider.dart`
Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
cd /Users/joyongseong/Documents/dev/chorok_app
git add lib/features/profile/controller/user_profile_provider.dart
git commit -m "feat: userProfileProvider 추가 (프로필+초서+팔로우 상태 로드)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: UserProfileScreen — 4-state 프로필 화면

**Files:**
- Create: `lib/features/profile/screen/user_profile_screen.dart`

ux-planner 원칙: 로딩(shimmer)/빈/에러/성공 4-state. 팔로우 버튼은 followState에 따라 팔로우/팔로잉/요청됨 3상태.

- [ ] **Step 1: 화면 구현**

`lib/features/profile/screen/user_profile_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/repositories/follow_repository.dart';
import '../controller/user_profile_provider.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final UserProfile profile;
  const UserProfileScreen({super.key, required this.profile});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  FollowState? _followOverride;
  bool _busy = false;

  Future<void> _toggleFollow(FollowState current) async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      final repo = ref.read(followRepositoryProvider);
      if (current == FollowState.none) {
        final result = await repo.follow(widget.profile.id);
        if (mounted) setState(() => _followOverride = result);
      } else {
        await repo.unfollow(widget.profile.id);
        if (mounted) setState(() => _followOverride = FollowState.none);
        ref.invalidate(userProfileProvider(widget.profile.id));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final async = ref.watch(userProfileProvider(p.id));

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.appTextSecondary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '@${p.username}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.appTextPrimary,
          ),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          onRetry: () => ref.invalidate(userProfileProvider(p.id)),
        ),
        data: (data) {
          final followState = _followOverride ?? data.followState;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _Header(
                profile: p,
                followState: followState,
                busy: _busy,
                onToggleFollow: () => _toggleFollow(followState),
              ),
              const SizedBox(height: 24),
              if (data.sentences.isEmpty)
                _EmptySentences(isPrivate: p.isPrivate, followState: followState)
              else
                ...data.sentences.map((s) => _SentenceTile(sentence: s)),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final UserProfile profile;
  final FollowState followState;
  final bool busy;
  final VoidCallback onToggleFollow;

  const _Header({
    required this.profile,
    required this.followState,
    required this.busy,
    required this.onToggleFollow,
  });

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: context.appCardElevated,
          backgroundImage: (p.avatarUrl != null && p.avatarUrl!.isNotEmpty)
              ? NetworkImage(p.avatarUrl!)
              : null,
          child: (p.avatarUrl == null || p.avatarUrl!.isEmpty)
              ? Icon(Icons.person_rounded, color: context.appTextTertiary, size: 40)
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          p.displayName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
        if (p.bio != null && p.bio!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            p.bio!,
            style: TextStyle(fontSize: 13, color: context.appTextSecondary),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        _FollowButton(
          followState: followState,
          busy: busy,
          onTap: onToggleFollow,
        ),
      ],
    );
  }
}

class _FollowButton extends StatelessWidget {
  final FollowState followState;
  final bool busy;
  final VoidCallback onTap;

  const _FollowButton({
    required this.followState,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (label, filled) = switch (followState) {
      FollowState.none => ('팔로우', true),
      FollowState.accepted => ('팔로잉', false),
      FollowState.pending => ('요청됨', false),
    };
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        alignment: Alignment.center,
        decoration: AppTheme.smoothBox(
          color: filled ? context.appPrimaryAccent : context.appCardElevated,
          radius: AppTheme.radiusMD,
          side: BorderSide.none,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: filled ? Colors.white : context.appTextSecondary,
          ),
        ),
      ),
    );
  }
}

class _SentenceTile extends StatelessWidget {
  final FeedSentence sentence;
  const _SentenceTile({required this.sentence});

  @override
  Widget build(BuildContext context) {
    final s = sentence;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        side: BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.bookTitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.appPrimaryAccent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"${s.content}"',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: context.appTextPrimary,
              height: 1.6,
            ),
          ),
          if (s.thought != null && s.thought!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              s.thought!,
              style: TextStyle(
                fontSize: 13,
                color: context.appTextSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptySentences extends StatelessWidget {
  final bool isPrivate;
  final FollowState followState;
  const _EmptySentences({required this.isPrivate, required this.followState});

  @override
  Widget build(BuildContext context) {
    final isLocked = isPrivate && followState != FollowState.accepted;
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Icon(
            isLocked ? Icons.lock_outline_rounded : Icons.menu_book_outlined,
            size: 48,
            color: context.appTextTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            isLocked ? '비공개 계정이에요' : '아직 공개된 초서가 없어요',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isLocked ? '팔로우가 수락되면 초서를 볼 수 있어요' : '이 유저가 초서를 남기면 여기 표시돼요',
            style: TextStyle(fontSize: 13, color: context.appTextSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: context.appTextTertiary),
          const SizedBox(height: 16),
          Text(
            '프로필을 불러오지 못했어요',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.center,
              decoration: AppTheme.smoothBox(
                gradient: AppTheme.greenGradient,
                radius: AppTheme.radiusMD,
              ),
              child: const Text(
                '다시 시도',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkBg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: analyze 통과 확인**

Run: `cd /Users/joyongseong/Documents/dev/chorok_app && flutter analyze lib/features/profile/screen/user_profile_screen.dart`
Expected: No issues found. (AppTheme의 greenGradient/darkBg/smoothBox/radiusMD/appPrimaryAccent 등이 존재해야 함 — search_screen.dart에서 동일하게 사용 중이므로 존재 확인됨)

- [ ] **Step 3: Commit**

```bash
cd /Users/joyongseong/Documents/dev/chorok_app
git add lib/features/profile/screen/user_profile_screen.dart
git commit -m "feat: UserProfileScreen 추가 (프로필·팔로우·초서 4-state)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 8: 라우트 등록 + 검색 카드 → 프로필 이동 + 기존 follow 호출처 수정

**Files:**
- Modify: `lib/core/constants/app_constants.dart`
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/search/screen/search_screen.dart`

- [ ] **Step 1: 라우트 상수 추가**

`lib/core/constants/app_constants.dart`의 `routeBookInfo` 줄 아래에 추가:

```dart
  static const String routeUserProfile = '/user-profile';
```

- [ ] **Step 2: 라우트 등록**

`lib/core/router/app_router.dart`의 `routeBookInfo` GoRoute 블록(파일에서 확인: 250-256줄 근처) 바로 아래에 추가. 먼저 파일 상단 import에 추가:

```dart
import '../../features/profile/screen/user_profile_screen.dart';
import '../../shared/models/user_profile.dart';
```

그리고 routeBookInfo GoRoute 닫는 `),` 다음에:

```dart
      // 유저 프로필
      GoRoute(
        path: AppConstants.routeUserProfile,
        builder: (context, state) {
          final profile = state.extra as UserProfile;
          return UserProfileScreen(profile: profile);
        },
      ),
```

- [ ] **Step 3: 검색 카드 탭 → 프로필 이동**

`lib/features/search/screen/search_screen.dart`에서:

import에 추가 (기존 import 블록 안, `app_constants.dart` import는 이미 있음):
```dart
import 'package:go_router/go_router.dart';
```
(이미 있으면 생략)

`_UserCard`의 `build` 메서드에서 최상위 `Container(...)`를 `GestureDetector`로 감싼다. 기존:

```dart
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        side: BorderSide.none,
      ),
      child: Row(
```

를 아래로 교체:

```dart
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push(AppConstants.routeUserProfile, extra: widget.profile);
      },
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        side: BorderSide.none,
      ),
      child: Row(
```

그리고 이 `Container`의 닫는 부분(`_UserCard` build의 최종 `);` 직전, Row를 닫고 Container를 닫는 지점)에 GestureDetector 닫기를 추가한다. 기존 `_UserCard` build 끝부분:

```dart
        ],
      ),
    );
  }
}
```

를 아래로 교체:

```dart
        ],
      ),
      ),
    );
  }
}
```

- [ ] **Step 4: 카드 내 기존 _FollowButton 호출이 변경된 follow 반환타입과 호환되는지 확인**

`_UserCardState._toggleFollow`는 `repo.follow(...)`를 호출하지만 반환값을 쓰지 않으므로 `FollowState` 반환으로 바뀌어도 컴파일 에러 없음. 단, `_isFollowing == true` 분기 로직은 유지된다. analyze로 확인.

- [ ] **Step 5: 전체 analyze**

Run: `cd /Users/joyongseong/Documents/dev/chorok_app && flutter analyze lib/`
Expected: No issues found. (follow 반환타입 변경으로 인한 에러가 있으면 해당 호출처를 `await repo.follow(...)` 형태로 반환값 무시하도록 유지)

- [ ] **Step 6: Commit**

```bash
cd /Users/joyongseong/Documents/dev/chorok_app
git add lib/core/constants/app_constants.dart lib/core/router/app_router.dart lib/features/search/screen/search_screen.dart
git commit -m "feat: UserProfile 라우트 등록 + 검색 카드 탭 시 프로필 이동

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 9: 통합 검증 (런타임)

**Files:** 없음 (실행 검증)

- [ ] **Step 1: 전체 테스트 통과 확인**

Run: `cd /Users/joyongseong/Documents/dev/chorok_app && flutter test`
Expected: 모든 테스트 PASS.

- [ ] **Step 2: 웹앱 실행 후 로그인 → 검색 → 프로필 → 팔로우 흐름 수동 검증**

verify 스킬로 실데이터 웹앱을 띄워 다음을 확인 (로그인 자격증명은 사용자에게 요청):
1. 유저 탭에서 "김준석" 또는 "용성" 검색 → 결과 노출
2. 결과 카드 탭 → UserProfileScreen 이동
3. 팔로우 버튼 → 라벨이 "팔로잉"으로 변경, `follows` 테이블에 행 생성 (Supabase MCP로 확인)
4. 프로필 화면에 그 유저 공개 초서 노출

Expected: 위 4개 모두 동작.

- [ ] **Step 3: 검증 결과를 사용자에게 보고**

스크린샷·DB 상태 캡처와 함께 PASS/FAIL 보고.

---

## 범위 밖 (이 계획 아님)

- 공개 피드 파이프라인 mock 제거 (B 사이클)
- 좋아요·댓글 DB 연동 (C, D 사이클)
- 알림 + 비공개 계정 팔로우 요청 승인/거절 UI (E 사이클)
- feed_provider의 인라인 파서를 Task 3의 parseSentenceRow로 리팩터 (별도, 선택적 — 동작에 영향 없음)
