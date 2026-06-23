-- 공개 계정(is_private=false)의 책·독서세션을 비팔로워도 볼 수 있게 한다.
-- sentences의 public 정책과 일관성을 맞춤. 비공개 계정은 기존 팔로워 전용 정책으로 보호 유지.
-- (2026-06-23 적용. 원격 직접 적용분의 repo 기록본)

drop policy if exists books_select_public on public.books;
create policy books_select_public on public.books
  for select
  using (
    exists (
      select 1 from public.profiles p
      where p.id = books.user_id
        and coalesce(p.is_private, false) = false
    )
  );

drop policy if exists sessions_select_public on public.reading_sessions;
create policy sessions_select_public on public.reading_sessions
  for select
  using (
    exists (
      select 1 from public.profiles p
      where p.id = reading_sessions.user_id
        and coalesce(p.is_private, false) = false
    )
  );
