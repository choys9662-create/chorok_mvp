# 초록 테스트 앱 — 소셜 백엔드 4종 구축 설계

**날짜:** 2026-06-05
**대상:** 테스트 앱(실데이터 모드, `kUseMock=false`)에서 아직 mock 전용으로 비어 있는 소셜 기능들의 백엔드 신규 구축 + 화면 연결

---

## 1. 배경 & 목표

테스트 앱의 주요 데이터(홈·서재·피드·분석·프로필)는 이미 실데이터에 연결돼 있고 `flutter analyze`도 깨끗하다. 남아 있는 mock 전용 영역은 **백엔드 테이블 자체가 없어서** 실데이터 모드에서 빈 값을 반환하는 소셜 기능들이다.

현재 Supabase 테이블: `profiles, books, reading_sessions, sentences, follows, sentence_likes, global_books` (+ `global_book_sentences` 뷰).

이 설계는 다음 4개 서브시스템의 백엔드를 만들고 화면에 연결한다. **의존성 순서**(알림이 나머지 이벤트를 소비)로 구축한다:

1. 다른 독자 (Other readers)
2. 문장 댓글 (Sentence comments) + 댓글 공감
3. 독서 메모 (Reading memos)
4. 알림 (Notifications) — DB 트리거 생성, overlap 포함

### 확정된 스코프 결정

- **Decision A:** 댓글 공감(좋아요) **이번에 같이 구축** (`sentence_comment_likes` 테이블).
- **Decision B:** 겹문장(overlap) 알림 **이번에 포함** (sentences insert 트리거 + normalized 비교).
- **Decision C:** 시스템 알림('목표까지 N분' 등)은 **제외** (이벤트 비기반 — cron/edge function 필요, 추후 별도).
- **알림 생성 방식:** DB 트리거(`SECURITY DEFINER`), 클라이언트 insert 금지.

### 비목표 (Out of scope)

- 시스템/예약 알림, 푸시 알림(FCM/APNs) 전송.
- 알림 화면 외 배지·실시간 구독(추후 가능, 이번엔 fetch 기반).
- Design App(mock) UI 변경 — **mock UI는 그대로 유지**. 데이터 소스만 달라진다(CLAUDE.md §5).

### 핵심 제약 (불변)

- mock UI와 실데이터 UI의 룩·카피·레이아웃·인터랙션 100% 동일. 데이터 출처만 차이.
- 모든 신규 조회 화면은 **4-state**(loading / empty / error / success) 처리.
- 모든 쓰기는 **낙관적 UI + 실패 시 롤백**, 기존 패턴(`async_state_view`, `chorok_shimmer`, `chorok_snackbar`) 재사용.
- 마이그레이션은 **멱등**(`if not exists`) 작성. 적용 전 **라이브 스키마를 `list_tables`로 확인**(마이그레이션 파일이 불완전한 전력 있음).

---

## 2. 사전 검증 (구현 첫 단계, 필수)

마이그레이션 파일 폴더가 실제 DB와 불일치한 이력이 있다(`follows.status`, `profiles.is_private`, `touch_updated_at()` 등이 파일에 없음). 따라서 구현 착수 시:

1. Supabase MCP `list_tables`로 라이브 스키마 확인.
2. 신규 테이블 4종(`sentence_comments`, `sentence_comment_likes`, `book_memos`, `notifications`)이 **존재하지 않음** 확인.
3. `sentences`에 `thought`, `global_book_id`, `normalized_sentences` 컬럼 존재 확인.
4. 홈 `Book` 모델에 `globalBookId`(또는 ISBN→global 매핑 경로) 존재 확인. 없으면 ① 설계의 fallback 경로 사용.

---

## 3. 서브시스템 ① — 다른 독자 (Other readers)

**새 테이블 없음.** 기존 `global_book_sentences` 뷰가 `_OtherReaderSentence`가 필요로 하는 필드를 모두 제공한다(content, page_number, username/display_name, like_count, created_at, user_id). 뷰는 `security_invoker = true`라 `sentences_select_public`(global_book_id 있는 문장 공개) RLS를 따른다.

**UI 계약** (`features/home/screen/book_detail_screen.dart` `_OtherReaderSentence`):
`{ id, content, page, username, thought?, empathyCount, savedAt }`

> 주의: 뷰는 현재 `s.thought`를 노출하지 않는다 → 뷰에 `s.thought as thought` 컬럼 추가 마이그레이션 필요(멱등 `create or replace view`).

**조회:** `global_book_sentences`에서 `global_book_id = :gid AND user_id != :me`, `like_count desc, created_at desc`, limit 20.

**Provider:** `otherReadersProvider = FutureProvider.family<List<OtherReaderSentence>, String /*globalBookId*/>`.
**Repository:** 신규 메서드 `BookSentenceRepository.fetchOtherReaders(globalBookId)` 또는 기존 repository에 추가(피드/community와 일관).

**연결 지점:** `book_detail_screen.dart:291` `_otherReaders = kUseMock ? ... : []`
→ 실데이터 모드는 `ref.watch(otherReadersProvider(globalBookId))`로 교체. `globalBookId` 부재 시 빈 상태.

**4-state:** loading=shimmer, empty="아직 이 책을 읽은 다른 독자가 없어요", error=재시도.

---

## 4. 서브시스템 ② — 문장 댓글 (Sentence comments) + 공감

### 테이블

```sql
create table if not exists public.sentence_comments (
  id          uuid primary key default uuid_generate_v4(),
  sentence_id uuid not null references public.sentences(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  content     text not null,
  like_count  int  not null default 0,        -- 역정규화 (트리거로 갱신)
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
```

### RLS (sentences 가시성과 동일 패턴, authenticated 한정)

- `sentence_comments` **select**: 부모 문장이 공개(`global_book_id is not null`)이거나, 내가 작성자를 팔로우(accepted)했거나, 내 댓글일 때.
  ```sql
  using (
    exists (select 1 from public.sentences s where s.id = sentence_id and (
      s.global_book_id is not null
      or s.user_id = auth.uid()
      or exists (select 1 from public.follows f
                 where f.follower_id = auth.uid() and f.following_id = s.user_id)
    ))
  )
  ```
- **insert**: `auth.uid() = user_id` **AND** 위 가시성 충족(공개 문장에만 댓글). **delete**: 본인만. **update**: 없음(편집 미지원, mock에 없음).
- `sentence_comment_likes`: select=true(집계용), insert/delete=`auth.uid() = user_id`. (`sentence_likes`와 동일.)

### like_count 동기화 트리거

`sentence_comment_likes` AFTER INSERT/DELETE → 해당 `sentence_comments.like_count` 재계산(`SECURITY DEFINER`, `search_path` 고정).

### UI 계약

- `features/feed/screen/sentence_detail_screen.dart` `_ReaderThought`: `{ username, thought, createdAt, empathyCount, isLiked }`
- `features/home/screen/book_detail_screen.dart` `_SocialThought` / `_CollectedSentence.socialThoughts` + `socialCount`: 같은 데이터의 프리뷰.

### ⚠️ 필수 리팩터 — sentence_id 전달

`SentenceDetailExtra`(`sentence_detail_screen.dart:15`)에 **`sentenceId`가 없다**. 댓글을 문장 행에 붙이려면 ID가 필요.
- `SentenceDetailExtra`에 `String? sentenceId` 추가.
- 라우팅 호출부(피드 → 상세) 전부에서 `sentenceId` 전달. mock 경로는 `null` 허용 → mock 모드는 기존 `_buildMockThoughts()` 유지.
- `sentenceId == null`(mock)일 때 실데이터 댓글 조회 안 함.

### Repository / Provider

`CommentRepository`:
- `fetchComments(sentenceId) → List<Comment>` (작성자 join, 내 좋아요 여부 포함)
- `addComment(sentenceId, content)`
- `deleteComment(commentId)`
- `likeComment(commentId)` / `unlikeComment(commentId)`

`commentsProvider = FutureProvider.family<List<Comment>, String /*sentenceId*/>`.

### 연결 지점

- `sentence_detail_screen.dart:115` `_thoughts = kUseMock ? _buildMockThoughts() : []` → 실데이터는 `commentsProvider(sentenceId)`.
- `_submitThought()` (`:125`) → `addComment` 실제 호출(낙관적 insert, 실패 롤백). 현재 `Future.delayed` 가짜 저장 제거.
- 댓글 하트 토글 → `likeComment/unlikeComment` (낙관적).
- `book_detail_screen.dart`의 `socialThoughts`: 수집 문장별 `commentsProvider(sentenceId)` 프리뷰(상위 N개) + count.

**4-state:** loading=shimmer, empty="첫 생각을 남겨보세요", error=재시도. 빈 입력 submit 차단(기존 로직 유지).

---

## 5. 서브시스템 ③ — 독서 메모 (Reading memos)

### 테이블

```sql
create table if not exists public.book_memos (
  id             uuid primary key default uuid_generate_v4(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  global_book_id uuid references public.global_books(id) on delete cascade,
  book_id        uuid references public.books(id) on delete set null,  -- 로컬 fallback
  content        text not null,
  created_at     timestamptz not null default now()
);
create index if not exists book_memos_user_book_idx
  on public.book_memos (user_id, global_book_id, created_at desc);
```

`sentences.thought`(문장별 노트)와 **다른** 책 단위 자유 메모(`_ReadingMemo { content, createdAt }`).

### RLS — 완전 비공개 (owner-only)

select/insert/update/delete 모두 `auth.uid() = user_id`. authenticated 한정.

### Repository / Provider

`MemoRepository`: `fetchMemos(globalBookId|bookId)`, `addMemo(...)`, `deleteMemo(id)`.
`memosProvider = FutureProvider.family`.

### 연결 지점

`book_detail_screen.dart:290` `_memos = kUseMock ? _buildMockMemos() : []`
→ 실데이터는 `memosProvider`. 메모 추가/삭제 UI(이미 mock에 존재하면 동일 컴포넌트 재사용, 없으면 mock과 동일 형태로).

**4-state:** empty="이 책에 대한 메모를 남겨보세요".

---

## 6. 서브시스템 ④ — 알림 (Notifications) + overlap

### 테이블

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
```

**구조화 저장 + 클라이언트 렌더링.** title/body 한국어 문구는 앱에서 type+actor로 생성(현재 `notification_screen.dart`의 `_iconFor`/`_colorFor`/title 로직 재사용). `system` type 미포함(Decision C).

### RLS

- select/update: `auth.uid() = recipient_id` (목록 조회 + is_read 갱신).
- **insert 정책 없음** → 트리거(`SECURITY DEFINER`)만 기록. authenticated 한정.

### 생성 트리거 (모두 `SECURITY DEFINER`, `search_path = public, pg_temp`, self-action skip)

| type | 트리거 | recipient | actor |
|------|--------|-----------|-------|
| `follow`  | AFTER INSERT on `follows` | `following_id` | `follower_id` |
| `like`    | AFTER INSERT on `sentence_likes` | 문장 작성자 | `user_id` |
| `comment` | AFTER INSERT on `sentence_comments` | 문장 작성자 | `user_id` |
| `overlap` | AFTER INSERT on `sentences` | 겹치는 기존 문장 작성자(들) | 새 문장 `user_id` |

- self-action(`actor == recipient`)이면 insert 안 함.
- `follow`: 라이브 `follows`에 `status` 컬럼이 있으면 `status='accepted'`일 때만 알림(비공개 pending 제외), 없으면 모든 follow insert가 알림 생성. (§2에서 확인 후 트리거 본문 확정.)
- **overlap 트리거:** 새 `sentences` 행의 `normalized_sentences`와 겹치는 **다른 유저의** 공개 문장(`global_book_id` 동일 권장)을 찾아 각 작성자에게 `overlap` 알림. 중복 폭주 방지를 위해 같은 (recipient, sentence) 쌍은 1건. 비용 큰 쿼리이므로 `normalized_sentences` GIN 인덱스(`sentences_normalized_gin`, 이미 존재) 활용 + 매칭 상한(예: 최대 20명).

### Repository / Provider

`NotificationRepository`: `fetchNotifications()`, `markRead(id)`, `markAllRead()`, `unreadCount()`.
`notificationsProvider = FutureProvider<List<AppNotification>>` (actor profile join).

### 연결 지점

`features/home/screen/notification_screen.dart:89` `_notifications = kUseMock ? ... : []`
→ 실데이터는 `notificationsProvider`. `_markAllRead`/`_markRead`(`:107`,`:117`)를 `markAllRead`/`markRead` 실제 호출로(낙관적). 알림 항목 탭 → 관련 화면(문장 상세/프로필)로 이동.

**4-state:** loading=shimmer, empty="아직 알림이 없어요", error=재시도.

---

## 7. 마이그레이션 파일 계획 (순서)

`supabase/migrations/` 에 멱등 SQL 추가(날짜 prefix):

1. `2026..._other_readers_view_thought.sql` — `global_book_sentences` 뷰에 `thought` 추가(`create or replace view`, `security_invoker` 유지).
2. `2026..._sentence_comments.sql` — `sentence_comments` + `sentence_comment_likes` + RLS + like_count 트리거.
3. `2026..._book_memos.sql` — `book_memos` + RLS.
4. `2026..._notifications.sql` — `notifications` + RLS + follow/like/comment/overlap 트리거.

적용은 Supabase MCP `apply_migration`(라이브 확인 후). 각 파일 적용 후 `get_advisors`로 보안 경고 점검(기존 harden_security 관례 따름).

---

## 8. 테스트 전략

- **순수 함수/렌더링:** 알림 title/body 생성기, overlap 매칭 정규화 로직은 Dart 단위 테스트(기존 `recommended_books_provider` 순수함수 테스트 패턴).
- **RLS/트리거:** SQL 레벨 — 가시성(타인 문장 댓글 차단/허용), self-action skip, like_count 정합성을 `execute_sql`로 시나리오 검증(테스트 계정 2개).
- **위젯:** 각 화면 4-state 렌더 확인(mock 모드 회귀 — mock UI 불변 보장).
- **회귀 게이트:** `flutter analyze` 무경고 유지, `flutter test` 통과.

---

## 9. 리스크 & 완화

| 리스크 | 완화 |
|--------|------|
| 마이그레이션 파일 ≠ 라이브 스키마 | 착수 시 `list_tables`로 ground truth 확보 |
| 홈 `Book`에 `globalBookId` 없음 | ① 다른 독자 / ③ 메모가 global 키 의존 → 없으면 ISBN→global 매핑 or `book_id` fallback |
| `SentenceDetailExtra`에 sentence_id 부재 | 라우팅 전 구간 sentenceId 전달(②의 필수 리팩터) |
| overlap 트리거 성능 | GIN 인덱스 활용 + 매칭 상한 + 동일 (recipient,sentence) 1건 |
| mock UI 깨짐 | mock 경로(`kUseMock`) 분기 보존, 실데이터 분기만 교체 |

---

## 10. 완료 정의 (Definition of Done)

- 4개 화면 모두 실데이터 모드에서 실제 데이터 표시 + 4-state 동작.
- 댓글/공감/메모/팔로우/좋아요 → 알림 자동 생성(트리거) 확인.
- mock 모드 UI 변화 없음(시각 회귀 없음).
- `flutter analyze` 무경고, 테스트 통과, Supabase advisor 신규 ERROR 없음.
