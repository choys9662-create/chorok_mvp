-- chorok_app: Supabase 보안 강화 (advisor 권고 적용)
--
-- 배경:
--   `mcp__claude_ai_Supabase__get_advisors` 결과 ERROR 1건 + WARN 다수가 보고됨.
--   이 마이그레이션은 다음을 처리한다:
--
--   1. global_book_sentences view의 SECURITY INVOKER 전환 (RLS 우회 차단)
--   2. SECURITY DEFINER 함수의 REST API 노출 제거
--      - handle_new_user: auth.users 트리거 전용
--      - refresh_global_book_counts: 클라이언트에서 호출하지 않음
--   3. 함수 search_path 명시 고정 (SQL injection 표면 축소)
--   4. RLS 정책 중복 제거 + authenticated 역할로 한정 (anon 차단)
--
-- 미적용 항목 (별도 작업 필요):
--   - leaked_password_protection: Supabase 대시보드 → Authentication → Password Protection
--   - anonymous sign-ins: 대시보드 → Authentication → Sign In/Up에서 비활성 확인
--   - pg_trgm extension을 extensions 스키마로 이동 (위험도 낮음, 추후 진행)

-- ── 1. view SECURITY INVOKER 전환 ─────────────────────────────────────────
alter view public.global_book_sentences set (security_invoker = true);

-- ── 2. SECURITY DEFINER 함수의 REST 노출 차단 ─────────────────────────────
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.refresh_global_book_counts(uuid) from public, anon, authenticated;

-- ── 3. 함수 search_path 고정 ──────────────────────────────────────────────
alter function public.touch_updated_at() set search_path = public, pg_temp;
alter function public.refresh_global_book_counts(uuid) set search_path = public, pg_temp;

-- ── 4. RLS 정책 중복 제거 ─────────────────────────────────────────────────
drop policy if exists follows_delete_own on public.follows;
drop policy if exists follows_insert_own on public.follows;
drop policy if exists follows_select_all on public.follows;
drop policy if exists profiles_select_all on public.profiles;
drop policy if exists profiles_update_own on public.profiles;

-- ── 5. 모든 RLS 정책을 authenticated 역할로 한정 ──────────────────────────
alter policy books_delete  on public.books to authenticated;
alter policy books_insert  on public.books to authenticated;
alter policy books_select  on public.books to authenticated;
alter policy books_update  on public.books to authenticated;

alter policy follows_delete on public.follows to authenticated;
alter policy follows_insert on public.follows to authenticated;
alter policy follows_select on public.follows to authenticated;

alter policy global_books_insert on public.global_books to authenticated;
alter policy global_books_select on public.global_books to authenticated;
alter policy global_books_update on public.global_books to authenticated;

alter policy profiles_insert_own on public.profiles to authenticated;
alter policy profiles_select     on public.profiles to authenticated;
alter policy profiles_update     on public.profiles to authenticated;

alter policy sessions_insert on public.reading_sessions to authenticated;
alter policy sessions_select on public.reading_sessions to authenticated;
alter policy sessions_update on public.reading_sessions to authenticated;

alter policy likes_delete on public.sentence_likes to authenticated;
alter policy likes_insert on public.sentence_likes to authenticated;
alter policy likes_select on public.sentence_likes to authenticated;

alter policy sentences_delete           on public.sentences to authenticated;
alter policy sentences_insert           on public.sentences to authenticated;
alter policy sentences_select_following on public.sentences to authenticated;
alter policy sentences_select_own       on public.sentences to authenticated;
alter policy sentences_select_public    on public.sentences to authenticated;
