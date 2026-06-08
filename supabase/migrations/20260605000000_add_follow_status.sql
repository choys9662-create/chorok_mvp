alter table public.follows
  add column if not exists status text not null default 'accepted'
  check (status in ('accepted', 'pending'));

create index if not exists follows_following_status_idx
  on public.follows (following_id, status);
