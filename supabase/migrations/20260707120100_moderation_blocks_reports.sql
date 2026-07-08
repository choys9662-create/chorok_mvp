-- 차단(blocked_users) + 신고(content_reports)
-- App Store 가이드라인 1.2(UGC 안전) 대응: 유저 차단 + 콘텐츠/유저 신고 최소 구현.
-- 신고 접수 후 대응(콘텐츠 삭제·유저 조치)은 운영자가 Supabase 대시보드에서 수동 처리한다.

create table if not exists public.blocked_users (
  id         uuid primary key default uuid_generate_v4(),
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint blocked_users_no_self check (blocker_id <> blocked_id),
  constraint blocked_users_unique unique (blocker_id, blocked_id)
);
create index if not exists blocked_users_blocker_idx on public.blocked_users (blocker_id);

alter table public.blocked_users enable row level security;
create policy "blocked_users_select_own" on public.blocked_users
  for select to authenticated using (auth.uid() = blocker_id);
create policy "blocked_users_insert_own" on public.blocked_users
  for insert to authenticated with check (auth.uid() = blocker_id);
create policy "blocked_users_delete_own" on public.blocked_users
  for delete to authenticated using (auth.uid() = blocker_id);

-- 신고: target_type에 따라 target_id가 가리키는 테이블이 다른 폴리모픽 참조라 FK는 걸지 않는다.
create table if not exists public.content_reports (
  id          uuid primary key default uuid_generate_v4(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('user', 'sentence', 'comment')),
  target_id   uuid not null,
  reason      text,
  created_at  timestamptz not null default now()
);
create index if not exists content_reports_target_idx
  on public.content_reports (target_type, target_id);

alter table public.content_reports enable row level security;
create policy "content_reports_select_own" on public.content_reports
  for select to authenticated using (auth.uid() = reporter_id);
create policy "content_reports_insert_own" on public.content_reports
  for insert to authenticated with check (auth.uid() = reporter_id);
