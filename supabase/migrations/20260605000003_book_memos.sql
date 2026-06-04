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
