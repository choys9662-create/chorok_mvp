-- 책 단위 공개 평가.
-- 완독 후 남긴 별점과 선택 감상을 global_book 기준으로 모아 책 정보 화면에 노출한다.
create table if not exists public.book_reviews (
  id              uuid primary key default uuid_generate_v4(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  global_book_id  uuid not null references public.global_books(id) on delete cascade,
  star_rating     int not null check (star_rating between 1 and 5),
  memorable_line  text,
  legacy          text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (user_id, global_book_id)
);

create index if not exists book_reviews_global_book_idx
  on public.book_reviews (global_book_id, created_at desc);

alter table public.book_reviews enable row level security;

create policy "book_reviews_select" on public.book_reviews
  for select to authenticated using (true);

create policy "book_reviews_insert" on public.book_reviews
  for insert to authenticated with check (auth.uid() = user_id);

create policy "book_reviews_update" on public.book_reviews
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "book_reviews_delete" on public.book_reviews
  for delete to authenticated using (auth.uid() = user_id);
