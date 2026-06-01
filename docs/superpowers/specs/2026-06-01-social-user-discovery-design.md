# 소셜 기능 설계 — 유저 발견 & 연결 (1차 사이클)

**작성일**: 2026-06-01
**상태**: 설계 합의 완료, 구현 대기

## 배경 & 목표

초록의 소셜 기능 전체 그림을 설계하고, 그중 첫 번째 구현 사이클을 정의한다.

**확정된 방향 (브레인스토밍 합의):**

- **핵심 가치**: 연결감·동기부여 우선 ("남도 읽고 있다" > 교감형 기능)
- **피드 범위**: 하이브리드 — 공개 전체 + 팔로우 가중
- **공개 범위**: 초서(수집 문장+생각) 기본 공개
- **소셜 단위**: 초서 블록이 좋아요·댓글의 기본 단위 (확정된 제품 결정)
- **핵심 타겟**: 종인이 — 읽으려 하지만 실천 못 하는 사람. 연결감이 동기를 만든다.

**팔로우 모델 (인스타그램 방식):**

- 기본은 **공개 계정** → 즉시 팔로우, 초서 바로 열람
- 유저가 **비공개 계정**으로 전환 가능 → 팔로우 승인제, 초서는 승인된 팔로워만

## 전체 서브시스템 분해

| # | 서브시스템 | 내용 | 사이클 |
|---|-----------|------|--------|
| A | **유저 발견 & 연결** | 검색·프로필·팔로우·타인 초서 열람 | **1차 (이 문서)** |
| B | 공개 피드 파이프라인 | 하이브리드 피드 쿼리, mock 제거 | 2차 |
| C | 좋아요 (교감) | sentence_likes DB 연동 | 3차 |
| D | 댓글 "다른 생각" | 신규 테이블 + UI | 4차 |
| E | 알림 | 팔로우·좋아요·겹문장 알림 | 5차 |

이 문서는 **1차 사이클 (A: 유저 발견 & 연결)**만 다룬다. B~E는 각자 별도 spec → plan → 구현 사이클을 가진다.

## 1차 사이클 범위 — 유저 발견 & 연결

사용자 핵심 요구:
> 검색 창에서 유저 프로필을 검색하고, 팔로우 신청을 하고, 그 유저가 남긴 문장(초서)까지 볼 수 있어야 한다.

흐름: **검색 → 프로필 화면 → 팔로우 → 그 유저 초서 열람**

### 현재 코드/DB 상태 (구현 시작점)

**DB (Supabase, 확인 완료):**

- `profiles` (4행): id, username, display_name, avatar_url, bio — 검색 데이터 존재
- `follows` (0행): follower_id, following_id, created_at (복합 PK)
- `sentences` (15행): id, user_id, content, thought, global_book_id, book_id 등
- RLS 정책:
  - `profiles_select: true` — 누구나 프로필 조회 가능 (검색 차단 안 됨)
  - `sentences_select_public: (global_book_id IS NOT NULL)` — 공개 초서 누구나 조회
  - `sentences_select_following` — 팔로우한 유저 초서 조회 (현재 status 체크 없음)
  - `follows_select: true`, `follows_insert: auth.uid()=follower_id`

**클라이언트 (확인 완료):**

- `ProfileRepository.searchUsers()` — `.or('username.ilike.%q%,display_name.ilike.%q%')`, 쿼리 형태 정상
- `FollowRepository` — follow/unfollow/isFollowing/getFollowing/getFollowers 구현됨
- `SearchScreen`의 유저 탭 — 검색·팔로우 버튼 있음. 단, **검색 결과 카드 탭 시 프로필 화면 이동 없음** (팔로우 버튼만)
- `UserProfileScreen` — **존재하지 않음** (신규 필요)

### DB 변경 (작음)

1. `profiles.is_private boolean not null default false` 컬럼 추가
2. `follows.status text not null default 'accepted'` 컬럼 추가
   - 공개 계정 팔로우 → 즉시 `accepted`
   - 비공개 계정 팔로우 → `pending`
3. RLS 보강:
   - `sentences_select_following`을 `follows.status = 'accepted'`까지 체크하도록 수정
   - 비공개 계정의 초서는 accepted 팔로워에게만 노출

### 클라이언트 작업

**1. 유저 검색 검증/수정**
- 실제 로그인 상태에서 유저 검색이 동작하는지 먼저 확인 (RLS는 정상이므로 클라이언트 또는 인증 상태 문제로 추정)
- 안 되면 원인 디버깅 후 수정

**2. `UserProfileScreen` 신규 추가**
- 위치: `features/search/screen/user_profile_screen.dart` (또는 features 하위 적절 위치)
- 구성:
  - 헤더: 아바타, display_name, @username, bio
  - 팔로우/팔로잉 버튼 (비공개 계정이면 "요청됨" 상태 처리)
  - 그 유저의 공개 초서 리스트 (피드 카드와 동일한 카드 컴포넌트 재사용)
  - 4-state UI (로딩/빈/에러/성공) — ux-planner 원칙 적용
- 라우트: GoRouter에 `routeUserProfile` 추가, `extra`로 UserProfile 또는 userId 전달

**3. 검색 결과 카드 → 프로필 이동**
- `SearchScreen`의 `_UserCard` 탭 시 `UserProfileScreen`으로 push
- 기존 팔로우 버튼은 카드에 유지

**4. 팔로우 상태 처리**
- 공개 계정: 즉시 팔로우/언팔로우 (기존 로직)
- 비공개 계정: 팔로우 시 `status='pending'`, UI는 "요청됨" 표시
- `FollowRepository`에 status 인지 로직 추가

**5. 타인 초서 조회**
- `ProfileRepository` 또는 신규 메서드: `getUserSentences(userId)` — 공개 초서 (또는 accepted 팔로워면 전체) 조회
- 피드의 `_loadFromSupabase` 쿼리 패턴 재사용

### 컴포넌트 경계

| 컴포넌트 | 책임 | 의존 |
|---------|------|------|
| `UserProfileScreen` | 프로필 화면 렌더링·상태 관리 | userProfileProvider, FollowRepository |
| `userProfileProvider` (신규) | 특정 유저의 프로필+초서 로드 | ProfileRepository |
| `ProfileRepository.getUserSentences` (신규) | 타인 공개 초서 조회 | Supabase |
| `FollowRepository` (수정) | status 인지 팔로우 | Supabase |

### 환경 동기화 (CLAUDE.md 5번 규칙)

- 이 작업은 실데이터(Test App) 기능이 중심이나, UI(프로필 화면)가 추가되므로 mock 모드에서도 화면이 깨지지 않아야 한다.
- mock 모드에서는 프로필 화면이 mock 유저/초서로 동작하거나, 최소한 빈 상태로 graceful하게 처리.

## 성공 기준

1. 로그인한 유저가 검색창 유저 탭에서 다른 유저(예: "김준석", "용성")를 검색하면 결과가 나온다.
2. 검색 결과를 탭하면 그 유저의 프로필 화면으로 이동한다.
3. 프로필 화면에서 팔로우 버튼을 누르면 (공개 계정) 즉시 팔로우되고 `follows` 테이블에 행이 생긴다.
4. 프로필 화면에서 그 유저가 남긴 공개 초서 목록이 보인다.
5. 비공개 계정을 팔로우하면 "요청됨" 상태가 되고, 초서는 승인 전까지 안 보인다.

## 범위 밖 (이번 사이클 아님)

- 공개 피드 파이프라인 mock 제거 (B 사이클)
- 좋아요·댓글 DB 연동 (C, D 사이클)
- 알림 (E 사이클)
- 팔로우 요청 승인/거절 UI (비공개 계정 수신 측) — 1차에서는 요청 생성까지만, 승인 UI는 E 사이클 알림과 함께
