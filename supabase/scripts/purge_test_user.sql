-- ================================================================
-- 테스트 계정 데이터 정리 스크립트 (purge_test_user)
-- ================================================================
-- 용도: 개발 중 실기기/웹에서 전용 "테스트 계정"으로 쌓은 데이터를
--       운영 Supabase에서 한 번에 삭제한다.
--
-- 실행: Supabase Dashboard > SQL Editor 에 원하는 블록을 붙여넣고 Run.
--       (SQL Editor / MCP execute_sql 은 service_role 로 돌아가 RLS 를 우회함)
--
-- ⚠️  운영 DB 를 직접 삭제한다. 실제 유저 데이터가 없는 "출시 전" 단계에서만 사용.
--     실행 전 v_email 이 정말 테스트 계정인지 두 번 확인할 것.
--
-- 구조 메모: 모든 user 소유 테이블(books, reading_sessions, sentences,
--   follows, sentence_likes, sentence_comments, sentence_comment_likes,
--   book_memos, book_reviews, notifications, reading_presence)은
--   profiles(id) ON DELETE CASCADE 이고, profiles 는 auth.users(id)
--   ON DELETE CASCADE 다. → auth.users 한 행 삭제로 전부 정리된다.
--   global_books(공유 책 카탈로그)는 user 소유가 아니므로 건드리지 않는다.
-- ================================================================


-- ── 옵션 A (권장): 계정+데이터 전부 삭제 ─────────────────────────────
-- auth.users 한 행 삭제 → profiles → 모든 소유 데이터까지 cascade.
-- 그 계정으로 다시 로그인하면 트리거(handle_new_user)가 프로필을 새로 만든다.
do $$
declare
  v_email text := 'CHANGE_ME@example.com';   -- ← 테스트 계정 이메일로 변경
  v_uid   uuid;
begin
  select id into v_uid from auth.users where lower(email) = lower(v_email);
  if v_uid is null then
    raise exception '해당 이메일의 유저를 찾을 수 없음: %', v_email;
  end if;

  delete from auth.users where id = v_uid;   -- profiles + 전 데이터 cascade
  raise notice '삭제 완료 (계정+데이터 전부): % (%)', v_email, v_uid;
end $$;


-- ── 옵션 B: 계정/프로필은 유지하고 데이터만 비우기 ────────────────────
-- 같은 계정으로 계속 로그인하면서 콘텐츠만 초기화하고 싶을 때.
-- (아래 블록 전체의 주석을 풀고, 위 옵션 A 블록은 지운 뒤 실행)
/*
do $$
declare
  v_email text := 'CHANGE_ME@example.com';   -- ← 테스트 계정 이메일로 변경
  v_uid   uuid;
begin
  select id into v_uid from auth.users where lower(email) = lower(v_email);
  if v_uid is null then
    raise exception '해당 이메일의 유저를 찾을 수 없음: %', v_email;
  end if;

  -- 이 유저가 남의 콘텐츠에 한 행위 (좋아요/댓글/팔로우/알림)
  delete from public.sentence_comment_likes where user_id = v_uid;
  delete from public.sentence_comments       where user_id = v_uid;
  delete from public.sentence_likes          where user_id = v_uid;
  delete from public.follows       where follower_id = v_uid or following_id = v_uid;
  delete from public.notifications where recipient_id = v_uid or actor_id = v_uid;

  -- 이 유저가 소유한 콘텐츠
  -- (sentences 삭제 시 그 문장 위에 달린 남들의 좋아요/댓글/알림도 cascade 삭제됨)
  delete from public.book_reviews     where user_id = v_uid;
  delete from public.book_memos       where user_id = v_uid;
  delete from public.reading_presence where user_id = v_uid;
  delete from public.sentences        where user_id = v_uid;
  delete from public.reading_sessions where user_id = v_uid;
  delete from public.books            where user_id = v_uid;

  raise notice '데이터 삭제 완료 (계정/프로필 유지): % (%)', v_email, v_uid;
end $$;
*/


-- ── 검증: 잔여 데이터 카운트 (이메일만 바꿔 실행) ─────────────────────
-- 옵션 A 후: 전부 0 (auth_user, profiles 포함).
-- 옵션 B 후: auth_user/profiles 는 1, 나머지는 0.
with u as (
  select id from auth.users where lower(email) = lower('CHANGE_ME@example.com')
)
select
  (select count(*) from u)                                                        as auth_user,
  (select count(*) from public.profiles         where id           in (select id from u)) as profiles,
  (select count(*) from public.books            where user_id      in (select id from u)) as books,
  (select count(*) from public.reading_sessions where user_id      in (select id from u)) as sessions,
  (select count(*) from public.sentences        where user_id      in (select id from u)) as sentences,
  (select count(*) from public.book_memos       where user_id      in (select id from u)) as memos,
  (select count(*) from public.book_reviews     where user_id      in (select id from u)) as reviews,
  (select count(*) from public.sentence_likes   where user_id      in (select id from u)) as likes,
  (select count(*) from public.sentence_comments where user_id     in (select id from u)) as comments,
  (select count(*) from public.follows
     where follower_id in (select id from u) or following_id in (select id from u))       as follows,
  (select count(*) from public.notifications
     where recipient_id in (select id from u) or actor_id in (select id from u))          as notifications;
