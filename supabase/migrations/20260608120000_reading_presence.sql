-- 실시간 독서 세션 presence.
-- 세션을 '실행 중'인 동안만 행이 존재한다(앱이 start/heartbeat/end로 관리).
-- 이 마이그레이션은 이미 원격에 직접 적용돼 있던 테이블을 코드베이스에 기록한다(멱등).

create table if not exists public.reading_presence (
  user_id           uuid primary key references public.profiles(id) on delete cascade,
  started_at        timestamptz not null default now(),
  last_heartbeat_at timestamptz not null default now()
);

alter table public.reading_presence enable row level security;

-- 본인만 자신의 presence를 생성/갱신/삭제
drop policy if exists "presence_insert" on public.reading_presence;
create policy "presence_insert" on public.reading_presence
  for insert with check (auth.uid() = user_id);

drop policy if exists "presence_update" on public.reading_presence;
create policy "presence_update" on public.reading_presence
  for update using (auth.uid() = user_id);

drop policy if exists "presence_delete" on public.reading_presence;
create policy "presence_delete" on public.reading_presence
  for delete using (auth.uid() = user_id);

-- 본인 + 팔로우한 사람의 presence 읽기 (sentences/sessions/books 정책과 동일 패턴)
drop policy if exists "presence_select_following" on public.reading_presence;
create policy "presence_select_following" on public.reading_presence
  for select using (
    auth.uid() = user_id
    or exists (
      select 1 from public.follows
      where follower_id = auth.uid() and following_id = reading_presence.user_id
    )
  );
