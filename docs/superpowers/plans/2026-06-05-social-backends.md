# 소셜 백엔드 4종 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 테스트 앱(실데이터)에서 다른 독자·문장 댓글(+공감)·독서 메모·알림(트리거 생성, overlap 포함)을 백엔드부터 구축해 화면에 연결한다.

**Architecture:** Supabase Postgres에 신규 테이블 3종 + 뷰 1개 갱신 + `SECURITY DEFINER` 트리거로 알림 자동 생성. Flutter는 Riverpod `FutureProvider(.family)` + Repository로 조회/쓰기. mock 분기(`kUseMock`)는 보존하고 실데이터 분기만 교체. 화면은 4-state.

**Tech Stack:** Supabase(supabase_flutter), Riverpod, GoRouter, Flutter. 마이그레이션은 Supabase MCP `apply_migration` + `supabase/migrations/` 파일.

**검증된 라이브 사실 (project `ebruktlffxduvgjgaymd`):** `profiles.is_private`, `follows.status`(accepted/pending), `sentences.{thought,global_book_id,normalized_sentences}`, `books.{global_book_id,isbn}` 모두 존재. 신규 4테이블 부재. `SentenceDetailExtra`는 `feed_screen.dart:860` 단 한 곳에서 생성.

---

## File Structure

**SQL (Create):**
- `supabase/migrations/20260605000001_global_book_sentences_thought.sql`
- `supabase/migrations/20260605000002_sentence_comments.sql`
- `supabase/migrations/20260605000003_book_memos.sql`
- `supabase/migrations/20260605000004_notifications.sql`

**Dart models (Create):** `lib/shared/models/`
- `comment.dart` (Comment), `book_memo.dart` (BookMemo), `other_reader_sentence.dart` (OtherReaderSentence), `app_notification.dart` (AppNotification + NotificationType + 텍스트 렌더러)

**Dart repositories (Create):** `lib/shared/repositories/`
- `comment_repository.dart`, `memo_repository.dart`, `notification_repository.dart`, `community_repository.dart` (다른 독자)

**Dart providers (Create):** `lib/shared/providers/`
- `social_providers.dart` (commentsProvider, memosProvider, notificationsProvider, otherReadersProvider, myLikedCommentIds 등)

**Dart (Modify):**
- `lib/features/feed/screen/sentence_detail_screen.dart` — `_thoughts` 실데이터, `_submitThought` 실저장, sentenceId 사용
- `lib/features/feed/screen/feed_screen.dart:860` — `SentenceDetailExtra(sentenceId: ...)` 전달
- `lib/features/home/screen/book_detail_screen.dart` — `_otherReaders`/`_memos`/`socialThoughts` 실데이터
- `lib/features/home/screen/notification_screen.dart` — `_notifications` 실데이터 + mark read

**Tests (Create):** `test/`
- `notification_text_test.dart` (AppNotification 텍스트 렌더), `isbn_resolution_test.dart` 등 순수 함수

---

## Phase 1 — Migrations

### Task 1: global_book_sentences 뷰에 thought 추가

**Files:** Create `supabase/migrations/20260605000001_global_book_sentences_thought.sql`

- [ ] **Step 1: 마이그레이션 SQL 작성**

```sql
-- 다른 독자 화면용: global_book_sentences 뷰에 thought(원 수집자 생각) 노출
create or replace view public.global_book_sentences as
select
  s.id as sentence_id, s.content, s.page_number, s.created_at, s.user_id,
  s.thought,
  p.username, p.display_name, p.avatar_url,
  gb.id as global_book_id, gb.isbn13,
  gb.title as book_title, gb.author as book_author, gb.cover_url as book_cover_url,
  count(sl.sentence_id) as like_count
from public.sentences s
join public.global_books gb on s.global_book_id = gb.id
join public.profiles p on s.user_id = p.id
left join public.sentence_likes sl on sl.sentence_id = s.id
group by s.id, gb.id, p.id;

alter view public.global_book_sentences set (security_invoker = true);
```

- [ ] **Step 2: 라이브 적용** — Supabase MCP `apply_migration`(name=`global_book_sentences_thought`, query=위 SQL, project=`ebruktlffxduvgjgaymd`).
- [ ] **Step 3: 검증** — `execute_sql`: `select sentence_id, thought from public.global_book_sentences limit 1;` 에러 없이 컬럼 존재 확인.
- [ ] **Step 4: Commit** `git add supabase/migrations/20260605000001_*.sql && git commit -m "feat(db): expose thought in global_book_sentences view"`

### Task 2: sentence_comments + sentence_comment_likes

**Files:** Create `supabase/migrations/20260605000002_sentence_comments.sql`

- [ ] **Step 1: 마이그레이션 SQL 작성**

```sql
-- 문장 댓글 + 댓글 공감
create table if not exists public.sentence_comments (
  id          uuid primary key default uuid_generate_v4(),
  sentence_id uuid not null references public.sentences(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  content     text not null,
  like_count  int  not null default 0,
  created_at  timestamptz not null default now()
);
create index if not exists sentence_comments_sentence_idx
  on public.sentence_comments (sentence_id, created_at desc);

create table if not exists public.sentence_comment_likes (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  comment_id uuid not null references public.sentence_comments(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, comment_id)
);

alter table public.sentence_comments       enable row level security;
alter table public.sentence_comment_likes  enable row level security;

-- 댓글 가시성: 부모 문장이 공개거나 내가 작성자를 팔로우(accepted)했거나 내 문장
create policy "sentence_comments_select" on public.sentence_comments
  for select to authenticated using (
    exists (
      select 1 from public.sentences s where s.id = sentence_id and (
        s.global_book_id is not null
        or s.user_id = auth.uid()
        or exists (
          select 1 from public.follows f
          where f.follower_id = auth.uid() and f.following_id = s.user_id
            and f.status = 'accepted'
        )
      )
    )
  );

-- insert: 본인 user_id + 위 가시성을 만족하는 문장에만
create policy "sentence_comments_insert" on public.sentence_comments
  for insert to authenticated with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.sentences s where s.id = sentence_id and (
        s.global_book_id is not null
        or s.user_id = auth.uid()
        or exists (
          select 1 from public.follows f
          where f.follower_id = auth.uid() and f.following_id = s.user_id
            and f.status = 'accepted'
        )
      )
    )
  );

create policy "sentence_comments_delete" on public.sentence_comments
  for delete to authenticated using (auth.uid() = user_id);

-- 댓글 좋아요: 집계는 누구나(authenticated), 본인만 토글
create policy "comment_likes_select" on public.sentence_comment_likes
  for select to authenticated using (true);
create policy "comment_likes_insert" on public.sentence_comment_likes
  for insert to authenticated with check (auth.uid() = user_id);
create policy "comment_likes_delete" on public.sentence_comment_likes
  for delete to authenticated using (auth.uid() = user_id);

-- like_count 동기화
create or replace function public.sync_comment_like_count()
returns trigger language plpgsql security definer
set search_path = public, pg_temp as $$
declare cid uuid;
begin
  cid := coalesce(new.comment_id, old.comment_id);
  update public.sentence_comments
    set like_count = (select count(*) from public.sentence_comment_likes where comment_id = cid)
    where id = cid;
  return null;
end;
$$;
revoke execute on function public.sync_comment_like_count() from public, anon, authenticated;

drop trigger if exists trg_comment_like_count on public.sentence_comment_likes;
create trigger trg_comment_like_count
  after insert or delete on public.sentence_comment_likes
  for each row execute procedure public.sync_comment_like_count();
```

- [ ] **Step 2: 라이브 적용** `apply_migration` name=`sentence_comments`.
- [ ] **Step 3: 검증** `execute_sql`: 테이블 2개 + 정책 존재 확인 (`select to_regclass('public.sentence_comments');` 등).
- [ ] **Step 4: Commit** `feat(db): add sentence_comments + comment likes with RLS`

### Task 3: book_memos

**Files:** Create `supabase/migrations/20260605000003_book_memos.sql`

- [ ] **Step 1: SQL 작성**

```sql
-- 책 단위 개인 메모 (완전 비공개)
create table if not exists public.book_memos (
  id             uuid primary key default uuid_generate_v4(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  global_book_id uuid references public.global_books(id) on delete cascade,
  book_id        uuid references public.books(id) on delete set null,
  content        text not null,
  created_at     timestamptz not null default now()
);
create index if not exists book_memos_user_book_idx
  on public.book_memos (user_id, global_book_id, created_at desc);

alter table public.book_memos enable row level security;
create policy "book_memos_select" on public.book_memos for select to authenticated using (auth.uid() = user_id);
create policy "book_memos_insert" on public.book_memos for insert to authenticated with check (auth.uid() = user_id);
create policy "book_memos_update" on public.book_memos for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "book_memos_delete" on public.book_memos for delete to authenticated using (auth.uid() = user_id);
```

- [ ] **Step 2: 적용** `apply_migration` name=`book_memos`.
- [ ] **Step 3: 검증** `select to_regclass('public.book_memos');`
- [ ] **Step 4: Commit** `feat(db): add book_memos with owner-only RLS`

### Task 4: notifications + 트리거 (follow/like/comment/overlap)

**Files:** Create `supabase/migrations/20260605000004_notifications.sql`

- [ ] **Step 1: SQL 작성**

```sql
create table if not exists public.notifications (
  id           uuid primary key default uuid_generate_v4(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id     uuid references public.profiles(id) on delete cascade,
  type         text not null check (type in ('follow','like','comment','overlap')),
  sentence_id  uuid references public.sentences(id) on delete cascade,
  is_read      boolean not null default false,
  created_at   timestamptz not null default now()
);
create index if not exists notifications_recipient_idx
  on public.notifications (recipient_id, created_at desc);

alter table public.notifications enable row level security;
-- 수신자만 조회/수정. insert 정책 없음 → 트리거(SECURITY DEFINER)만 기록.
create policy "notifications_select" on public.notifications for select to authenticated using (auth.uid() = recipient_id);
create policy "notifications_update" on public.notifications for update to authenticated using (auth.uid() = recipient_id) with check (auth.uid() = recipient_id);
create policy "notifications_delete" on public.notifications for delete to authenticated using (auth.uid() = recipient_id);

-- helper: 알림 insert (self-action skip)
create or replace function public.create_notification(
  p_recipient uuid, p_actor uuid, p_type text, p_sentence uuid
) returns void language plpgsql security definer
set search_path = public, pg_temp as $$
begin
  if p_recipient is null or p_actor is null or p_recipient = p_actor then return; end if;
  insert into public.notifications(recipient_id, actor_id, type, sentence_id)
  values (p_recipient, p_actor, p_type, p_sentence);
end;
$$;
revoke execute on function public.create_notification(uuid,uuid,text,uuid) from public, anon, authenticated;

-- follow (accepted만)
create or replace function public.notify_on_follow()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if new.status = 'accepted' then
    perform public.create_notification(new.following_id, new.follower_id, 'follow', null);
  end if;
  return null;
end;
$$;
revoke execute on function public.notify_on_follow() from public, anon, authenticated;
drop trigger if exists trg_notify_follow on public.follows;
create trigger trg_notify_follow after insert on public.follows
  for each row execute procedure public.notify_on_follow();

-- like
create or replace function public.notify_on_like()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare owner uuid;
begin
  select user_id into owner from public.sentences where id = new.sentence_id;
  perform public.create_notification(owner, new.user_id, 'like', new.sentence_id);
  return null;
end;
$$;
revoke execute on function public.notify_on_like() from public, anon, authenticated;
drop trigger if exists trg_notify_like on public.sentence_likes;
create trigger trg_notify_like after insert on public.sentence_likes
  for each row execute procedure public.notify_on_like();

-- comment
create or replace function public.notify_on_comment()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare owner uuid;
begin
  select user_id into owner from public.sentences where id = new.sentence_id;
  perform public.create_notification(owner, new.user_id, 'comment', new.sentence_id);
  return null;
end;
$$;
revoke execute on function public.notify_on_comment() from public, anon, authenticated;
drop trigger if exists trg_notify_comment on public.sentence_comments;
create trigger trg_notify_comment after insert on public.sentence_comments
  for each row execute procedure public.notify_on_comment();

-- overlap: 새 문장의 normalized_sentences와 겹치는 다른 유저의 공개 문장 작성자에게 알림
create or replace function public.notify_on_overlap()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare rec record;
begin
  if new.normalized_sentences is null or array_length(new.normalized_sentences,1) is null then
    return null;
  end if;
  for rec in
    select distinct s.user_id
    from public.sentences s
    where s.id <> new.id
      and s.user_id <> new.user_id
      and s.global_book_id is not null
      and s.normalized_sentences && new.normalized_sentences
    limit 20
  loop
    perform public.create_notification(rec.user_id, new.user_id, 'overlap', new.id);
  end loop;
  return null;
end;
$$;
revoke execute on function public.notify_on_overlap() from public, anon, authenticated;
drop trigger if exists trg_notify_overlap on public.sentences;
create trigger trg_notify_overlap after insert on public.sentences
  for each row execute procedure public.notify_on_overlap();
```

- [ ] **Step 2: 적용** `apply_migration` name=`notifications`.
- [ ] **Step 3: 검증 시나리오** `execute_sql`로 테스트 계정 2명(profiles에 이미 3명 존재) 사용:
  - A→B follow insert(status accepted) → `notifications`에 recipient=B,type=follow 1행.
  - self-follow(불가, PK) / self-like → 0행(create_notification에서 skip).
  - 검증 후 테스트로 만든 follow/notification 행 정리(delete).
- [ ] **Step 4: Advisor 점검** `get_advisors(type=security)` — 신규 ERROR 없는지. (정책 누락/SECURITY DEFINER 노출 경고)
- [ ] **Step 5: Commit** `feat(db): add notifications + follow/like/comment/overlap triggers`

---

## Phase 2 — Dart 모델 / 리포지토리 / 프로바이더

### Task 5: 모델 4종

**Files:** Create `lib/shared/models/comment.dart`, `book_memo.dart`, `other_reader_sentence.dart`, `app_notification.dart`
**Test:** Create `test/notification_text_test.dart`

- [ ] **Step 1: 실패 테스트 작성** (`test/notification_text_test.dart`)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:chorok_app/shared/models/app_notification.dart';

void main() {
  test('follow notification renders title with actor name', () {
    final n = AppNotification(
      id: '1', type: NotificationType.follow, actorName: '준석',
      isRead: false, createdAt: DateTime.now(),
    );
    expect(n.title, '준석님이 회원님을 팔로우해요');
  });
  test('like notification renders body with snippet', () {
    final n = AppNotification(
      id: '2', type: NotificationType.like, actorName: '민재',
      sentenceContent: '나는 채식주의자가 되기로 했다.', isRead: true,
      createdAt: DateTime.now(),
    );
    expect(n.title, '민재님이 내 문장을 좋아해요');
    expect(n.body, contains('채식주의자'));
  });
  test('overlap notification', () {
    final n = AppNotification(
      id: '3', type: NotificationType.overlap, actorName: '지현',
      isRead: false, createdAt: DateTime.now(),
    );
    expect(n.title, contains('겹'));
  });
}
```

- [ ] **Step 2: 실패 확인** `( cd chorok_app && flutter test test/notification_text_test.dart )` → 컴파일 실패(모델 없음).

- [ ] **Step 3: 모델 구현**

`app_notification.dart`:
```dart
enum NotificationType { follow, like, comment, overlap }

class AppNotification {
  final String id;
  final NotificationType type;
  final String actorName;       // actor display_name (없으면 username)
  final String? actorId;
  final String? sentenceId;
  final String? sentenceContent;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id, required this.type, required this.actorName,
    this.actorId, this.sentenceId, this.sentenceContent,
    required this.isRead, required this.createdAt,
  });

  String get title => switch (type) {
    NotificationType.follow  => '$actorName님이 회원님을 팔로우해요',
    NotificationType.like    => '$actorName님이 내 문장을 좋아해요',
    NotificationType.comment => '$actorName님이 내 문장에 생각을 남겼어요',
    NotificationType.overlap => '$actorName님과 같은 문장을 수집했어요',
  };

  String get body => sentenceContent == null ? '' : '"$sentenceContent"';

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id, type: type, actorName: actorName, actorId: actorId,
    sentenceId: sentenceId, sentenceContent: sentenceContent,
    isRead: isRead ?? this.isRead, createdAt: createdAt,
  );

  static NotificationType _type(String s) => switch (s) {
    'follow' => NotificationType.follow,
    'like' => NotificationType.like,
    'comment' => NotificationType.comment,
    _ => NotificationType.overlap,
  };

  factory AppNotification.fromRow(Map<String, dynamic> r) {
    final actor = r['actor'] as Map<String, dynamic>?;
    final sentence = r['sentence'] as Map<String, dynamic>?;
    final name = (actor?['display_name'] as String?)?.trim();
    final uname = actor?['username'] as String?;
    return AppNotification(
      id: r['id'] as String,
      type: _type(r['type'] as String),
      actorName: (name != null && name.isNotEmpty) ? name : (uname ?? '누군가'),
      actorId: actor?['id'] as String?,
      sentenceId: r['sentence_id'] as String?,
      sentenceContent: sentence?['content'] as String?,
      isRead: r['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(r['created_at'] as String),
    );
  }
}
```

`comment.dart`:
```dart
class Comment {
  final String id;
  final String sentenceId;
  final String userId;
  final String username;     // display_name 우선
  final String content;
  final int likeCount;
  final bool likedByMe;
  final DateTime createdAt;
  const Comment({
    required this.id, required this.sentenceId, required this.userId,
    required this.username, required this.content, required this.likeCount,
    required this.likedByMe, required this.createdAt,
  });
  Comment copyWith({int? likeCount, bool? likedByMe}) => Comment(
    id: id, sentenceId: sentenceId, userId: userId, username: username,
    content: content, likeCount: likeCount ?? this.likeCount,
    likedByMe: likedByMe ?? this.likedByMe, createdAt: createdAt,
  );
}
```

`book_memo.dart`:
```dart
class BookMemo {
  final String id;
  final String content;
  final DateTime createdAt;
  const BookMemo({required this.id, required this.content, required this.createdAt});
  factory BookMemo.fromRow(Map<String, dynamic> r) => BookMemo(
    id: r['id'] as String,
    content: r['content'] as String,
    createdAt: DateTime.parse(r['created_at'] as String),
  );
}
```

`other_reader_sentence.dart`:
```dart
class OtherReaderSentence {
  final String id;
  final String content;
  final int page;
  final String username;
  final String? thought;
  final int empathyCount;
  final DateTime savedAt;
  const OtherReaderSentence({
    required this.id, required this.content, required this.page,
    required this.username, this.thought, this.empathyCount = 0,
    required this.savedAt,
  });
  factory OtherReaderSentence.fromRow(Map<String, dynamic> r) => OtherReaderSentence(
    id: r['sentence_id'] as String,
    content: r['content'] as String,
    page: (r['page_number'] as num?)?.toInt() ?? 0,
    username: ((r['display_name'] as String?)?.trim().isNotEmpty ?? false)
        ? r['display_name'] as String
        : (r['username'] as String? ?? '익명'),
    thought: r['thought'] as String?,
    empathyCount: (r['like_count'] as num?)?.toInt() ?? 0,
    savedAt: DateTime.parse(r['created_at'] as String),
  );
}
```

- [ ] **Step 4: 통과 확인** `flutter test test/notification_text_test.dart` → PASS.
- [ ] **Step 5: Commit** `feat(models): add comment, memo, other-reader, notification models`

### Task 6: Repositories

**Files:** Create `lib/shared/repositories/comment_repository.dart`, `memo_repository.dart`, `notification_repository.dart`, `community_repository.dart`

- [ ] **Step 1: comment_repository.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/comment.dart';

class CommentRepository {
  final SupabaseClient _c;
  CommentRepository(this._c);
  String? get _me => _c.auth.currentUser?.id;

  Future<List<Comment>> fetchComments(String sentenceId) async {
    final rows = await _c
        .from('sentence_comments')
        .select('id, sentence_id, user_id, content, like_count, created_at, '
            'profiles!sentence_comments_user_id_fkey(username, display_name)')
        .eq('sentence_id', sentenceId)
        .order('created_at', ascending: false);
    final me = _me;
    Set<String> liked = {};
    if (me != null && (rows as List).isNotEmpty) {
      final ids = rows.map((r) => r['id'] as String).toList();
      final likeRows = await _c
          .from('sentence_comment_likes')
          .select('comment_id')
          .eq('user_id', me)
          .inFilter('comment_id', ids);
      liked = (likeRows as List).map((r) => r['comment_id'] as String).toSet();
    }
    return (rows as List).map((r) {
      final p = r['profiles'] as Map<String, dynamic>?;
      final name = (p?['display_name'] as String?)?.trim();
      return Comment(
        id: r['id'] as String,
        sentenceId: r['sentence_id'] as String,
        userId: r['user_id'] as String,
        username: (name != null && name.isNotEmpty)
            ? name : (p?['username'] as String? ?? '익명'),
        content: r['content'] as String,
        likeCount: (r['like_count'] as num?)?.toInt() ?? 0,
        likedByMe: liked.contains(r['id']),
        createdAt: DateTime.parse(r['created_at'] as String),
      );
    }).toList();
  }

  Future<Comment> addComment(String sentenceId, String content) async {
    final me = _me!;
    final row = await _c.from('sentence_comments').insert({
      'sentence_id': sentenceId, 'user_id': me, 'content': content,
    }).select('id, created_at').single();
    return Comment(
      id: row['id'] as String, sentenceId: sentenceId, userId: me,
      username: '나', content: content, likeCount: 0, likedByMe: false,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Future<void> deleteComment(String id) async =>
      _c.from('sentence_comments').delete().eq('id', id);

  Future<void> likeComment(String id) async {
    final me = _me; if (me == null) return;
    await _c.from('sentence_comment_likes').insert({'comment_id': id, 'user_id': me});
  }
  Future<void> unlikeComment(String id) async {
    final me = _me; if (me == null) return;
    await _c.from('sentence_comment_likes').delete()
        .eq('comment_id', id).eq('user_id', me);
  }
}

final commentRepositoryProvider = Provider((ref) => CommentRepository(Supabase.instance.client));
```

- [ ] **Step 2: memo_repository.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/book_memo.dart';

class MemoRepository {
  final SupabaseClient _c;
  MemoRepository(this._c);
  String? get _me => _c.auth.currentUser?.id;

  Future<List<BookMemo>> fetchMemos({String? globalBookId, String? bookId}) async {
    final me = _me; if (me == null) return const [];
    var q = _c.from('book_memos').select('id, content, created_at').eq('user_id', me);
    if (globalBookId != null) {
      q = q.eq('global_book_id', globalBookId);
    } else if (bookId != null) {
      q = q.eq('book_id', bookId);
    } else {
      return const [];
    }
    final rows = await q.order('created_at', ascending: false);
    return (rows as List).map((r) => BookMemo.fromRow(r)).toList();
  }

  Future<BookMemo> addMemo(String content, {String? globalBookId, String? bookId}) async {
    final me = _me!;
    final row = await _c.from('book_memos').insert({
      'user_id': me, 'content': content,
      if (globalBookId != null) 'global_book_id': globalBookId,
      if (bookId != null) 'book_id': bookId,
    }).select('id, content, created_at').single();
    return BookMemo.fromRow(row);
  }

  Future<void> deleteMemo(String id) async =>
      _c.from('book_memos').delete().eq('id', id);
}

final memoRepositoryProvider = Provider((ref) => MemoRepository(Supabase.instance.client));
```

- [ ] **Step 3: notification_repository.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_notification.dart';

class NotificationRepository {
  final SupabaseClient _c;
  NotificationRepository(this._c);
  String? get _me => _c.auth.currentUser?.id;

  Future<List<AppNotification>> fetch() async {
    final me = _me; if (me == null) return const [];
    final rows = await _c
        .from('notifications')
        .select('id, type, sentence_id, is_read, created_at, '
            'actor:profiles!notifications_actor_id_fkey(id, username, display_name), '
            'sentence:sentences!notifications_sentence_id_fkey(content)')
        .eq('recipient_id', me)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((r) => AppNotification.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String id) async =>
      _c.from('notifications').update({'is_read': true}).eq('id', id);

  Future<void> markAllRead() async {
    final me = _me; if (me == null) return;
    await _c.from('notifications').update({'is_read': true})
        .eq('recipient_id', me).eq('is_read', false);
  }
}

final notificationRepositoryProvider =
    Provider((ref) => NotificationRepository(Supabase.instance.client));
```

> 참고: `notifications`의 actor FK는 `notifications_actor_id_fkey`, sentence FK는 `notifications_sentence_id_fkey` (테이블 정의에서 자동 생성). 적용 후 정확한 제약명을 `list_tables verbose`로 확인하고 select 임베딩 문자열 보정.

- [ ] **Step 4: community_repository.dart (다른 독자)**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/other_reader_sentence.dart';

class CommunityRepository {
  final SupabaseClient _c;
  CommunityRepository(this._c);
  String? get _me => _c.auth.currentUser?.id;

  /// isbn으로 global_book_id 해석 후 다른 독자 문장 조회.
  Future<List<OtherReaderSentence>> fetchOtherReaders({String? isbn}) async {
    if (isbn == null || isbn.isEmpty) return const [];
    final gb = await _c.from('global_books').select('id').eq('isbn13', isbn).maybeSingle();
    final gid = gb?['id'] as String?;
    if (gid == null) return const [];
    final me = _me;
    final rows = await _c
        .from('global_book_sentences')
        .select('sentence_id, content, page_number, thought, like_count, created_at, user_id, username, display_name')
        .eq('global_book_id', gid)
        .order('like_count', ascending: false)
        .limit(20);
    return (rows as List)
        .where((r) => r['user_id'] != me)
        .map((r) => OtherReaderSentence.fromRow(r as Map<String, dynamic>))
        .toList();
  }
}

final communityRepositoryProvider =
    Provider((ref) => CommunityRepository(Supabase.instance.client));
```

- [ ] **Step 5: analyze** `( cd chorok_app && flutter analyze )` → 무경고.
- [ ] **Step 6: Commit** `feat(repos): comment/memo/notification/community repositories`

### Task 7: Providers

**Files:** Create `lib/shared/providers/social_providers.dart`

- [ ] **Step 1: 구현**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/comment.dart';
import '../models/book_memo.dart';
import '../models/other_reader_sentence.dart';
import '../models/app_notification.dart';
import '../repositories/comment_repository.dart';
import '../repositories/memo_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/community_repository.dart';

final commentsProvider = FutureProvider.autoDispose
    .family<List<Comment>, String>((ref, sentenceId) async {
  return ref.read(commentRepositoryProvider).fetchComments(sentenceId);
});

final otherReadersProvider = FutureProvider.autoDispose
    .family<List<OtherReaderSentence>, String?>((ref, isbn) async {
  return ref.read(communityRepositoryProvider).fetchOtherReaders(isbn: isbn);
});

typedef MemoKey = ({String? globalBookId, String? bookId});
final memosProvider = FutureProvider.autoDispose
    .family<List<BookMemo>, MemoKey>((ref, key) async {
  return ref.read(memoRepositoryProvider)
      .fetchMemos(globalBookId: key.globalBookId, bookId: key.bookId);
});

final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  return ref.read(notificationRepositoryProvider).fetch();
});
```

- [ ] **Step 2: analyze** 무경고.
- [ ] **Step 3: Commit** `feat(providers): social_providers`

---

## Phase 3 — UI 연결 (mock 분기 보존, 실데이터 분기 교체)

### Task 8: SentenceDetailExtra에 sentenceId + 댓글 실연결

**Files:** Modify `lib/features/feed/screen/sentence_detail_screen.dart`, `lib/features/feed/screen/feed_screen.dart`

- [ ] **Step 1:** `SentenceDetailExtra`에 `final String? sentenceId;` 필드 + 생성자 파라미터 추가(`sentence_detail_screen.dart:15-31`).
- [ ] **Step 2:** `feed_screen.dart:860` 의 `SentenceDetailExtra(...)`에 `sentenceId: <FeedSentence.id>` 전달. (FeedSentence에 id 필드 존재 확인 — 없으면 feed_provider select에 `id` 포함시키고 모델에 추가.)
- [ ] **Step 3:** `_SentenceDetailScreenState`를 실데이터 연결:
  - `kUseMock`이면 기존 `_buildMockThoughts()` 유지(불변).
  - 실데이터: `widget.data.sentenceId`가 있으면 `ref.watch(commentsProvider(sentenceId))`로 댓글 리스트 렌더(4-state). 없으면 빈 상태.
  - `_submitThought()`: 실데이터일 때 `commentRepository.addComment` 호출 → 성공 시 `ref.invalidate(commentsProvider(sentenceId))`; 실패 시 `chorok_snackbar`로 에러. mock일 때 기존 로컬 insert 유지.
  - 댓글 하트 토글: `likeComment/unlikeComment` 낙관적 + invalidate.
- [ ] **Step 4: analyze** 무경고.
- [ ] **Step 5: Commit** `feat(feed): wire real comments into sentence detail`

### Task 9: 책 상세 — 다른 독자 / 메모 / socialThoughts

**Files:** Modify `lib/features/home/screen/book_detail_screen.dart`

- [ ] **Step 1:** `ConsumerState`이므로 `ref` 사용 가능. `initState`의 `_otherReaders`/`_memos` 하드 `[]` 제거하고 build에서 provider watch로 전환(또는 `ref.listen`/`FutureBuilder` 대신 Riverpod `when`).
  - 다른 독자: `ref.watch(otherReadersProvider(widget.book.isbn))` → 기존 `_OtherReaderSentence` UI에 매핑(모델 필드 동일).
  - 메모: `ref.watch(memosProvider((globalBookId: null, bookId: widget.book.id)))` (Book에 globalBookId 없음 → bookId 키). 추가/삭제는 `memoRepository` 호출 후 invalidate.
  - socialThoughts(수집 문장별 댓글 프리뷰): 각 `_CollectedSentence`에 sentenceId가 있을 때 `commentsProvider(sentenceId)`의 상위 N개로 채움. 저장 문장(`saved_*`)은 로컬 ID라 sentenceId 없으면 프리뷰 생략.
  - **mock 분기(`kUseMock`)는 기존 `_buildMock*` 그대로 유지.**
- [ ] **Step 2:** 각 영역 4-state(shimmer/empty/error) 적용. 빈 카피: 다른 독자 "아직 이 책을 읽은 다른 독자가 없어요", 메모 "이 책에 대한 메모를 남겨보세요".
- [ ] **Step 3: analyze** 무경고.
- [ ] **Step 4: Commit** `feat(book-detail): wire other-readers, memos, social thoughts`

### Task 10: 알림 화면 실연결

**Files:** Modify `lib/features/home/screen/notification_screen.dart`

- [ ] **Step 1:** `StatefulWidget` → `ConsumerStatefulWidget`(또는 내부 `Consumer`)로 전환.
  - `kUseMock`이면 기존 `_kNotifications` 유지.
  - 실데이터: `ref.watch(notificationsProvider)` → `AppNotification` 리스트. `_iconFor`/`_colorFor`는 `NotificationType`에 맞게 매핑(기존 NotiType과 1:1; system 케이스는 실데이터에 없음).
  - `_markRead`/`_markAllRead` → `notificationRepository.markRead/markAllRead` 낙관적 호출 후 invalidate.
  - 항목 탭 → sentence_id 있으면 sentence detail로, follow면 actor 프로필로 이동(가능 범위).
- [ ] **Step 2:** 4-state. empty "아직 알림이 없어요".
- [ ] **Step 3: analyze** 무경고.
- [ ] **Step 4: Commit** `feat(notifications): wire real notifications + mark read`

---

## Phase 4 — 검증 & 마무리

### Task 11: 통합 검증

- [ ] **Step 1: 정적** `( cd chorok_app && flutter analyze )` → No issues.
- [ ] **Step 2: 단위** `( cd chorok_app && flutter test )` → 통과.
- [ ] **Step 3: DB 시나리오** `execute_sql`로 end-to-end:
  - 테스트 sentence(공개)에 다른 유저가 comment insert → 작성자 notifications에 comment 1행.
  - 같은 문장에 comment_like insert → like_count 증가 확인.
  - overlap: 동일 normalized 문장을 다른 유저가 insert → overlap 알림.
  - 검증용으로 만든 행 정리.
- [ ] **Step 4: Advisor** `get_advisors(security)` 신규 ERROR 0 확인.
- [ ] **Step 5: mock 회귀** `--dart-define=USE_MOCK=true` 빌드가 깨지지 않는지 analyze로 확인(시각 불변 — mock 분기 미변경).
- [ ] **Step 6: Commit** `test: verify social backends end-to-end`

---

## Self-Review (spec 대비)

- ① 다른 독자 → Task 1, 4(model/repo/provider), 9 ✓
- ② 댓글+공감 → Task 2, 5–7, 8 ✓ (sentenceId 리팩터 Task 8)
- ③ 메모 → Task 3, 5–7, 9 ✓
- ④ 알림+overlap → Task 4, 5–7, 10 ✓
- 4-state / mock 불변 → Task 8–10 각 step ✓
- 테스트/advisor → Task 11 ✓

타입 일관성: `AppNotification`, `Comment`, `BookMemo`, `OtherReaderSentence`, provider 시그니처(`commentsProvider(String)`, `otherReadersProvider(String?)`, `memosProvider(MemoKey)`, `notificationsProvider`) 전 task 일치.
