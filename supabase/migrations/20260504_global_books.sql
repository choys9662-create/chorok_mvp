-- ================================================================
-- 공유 플랫폼 전환: global_books 테이블 추가
--
-- 왓챠피디아처럼 '공용 도서관'(global_books)을 만들고,
-- 개인 서재(books)는 그 책을 참조만 하는 구조로 변경.
--
-- global_books: 세상에 존재하는 책 1건 = 1행 (isbn13 기준)
-- books: 기존과 동일하게 유저별 서재. global_book_id FK 추가.
-- sentences: global_book_id FK 추가하여 공유 문장 지원.
-- ================================================================

-- ── 1. global_books 테이블 ─────────────────────────────────────────────
create table if not exists public.global_books (
  id           uuid primary key default uuid_generate_v4(),
  isbn13       text unique not null,
  title        text not null,
  author       text not null,
  publisher    text,
  cover_url    text,
  description  text,
  total_pages  int,
  category     text,
  pub_date     text,
  created_at   timestamptz default now() not null,
  -- 역정규화된 집계 (리뷰 수, 평균 별점 등 나중에 추가 가능)
  reader_count int not null default 0,
  sentence_count int not null default 0
);

-- 검색 인덱스
create index if not exists global_books_title_idx on public.global_books using gin (title gin_trgm_ops);
create index if not exists global_books_author_idx on public.global_books using gin (author gin_trgm_ops);

-- RLS: 누구나 읽기, 로그인 유저만 insert (upsert용)
alter table public.global_books enable row level security;
create policy "global_books_select" on public.global_books for select using (true);
create policy "global_books_insert" on public.global_books for insert with check (auth.uid() is not null);
create policy "global_books_update" on public.global_books for update using (auth.uid() is not null);

-- ── 2. books 테이블에 global_book_id FK 추가 ──────────────────────────
alter table public.books add column if not exists global_book_id uuid references public.global_books(id);
create index if not exists books_global_book_id_idx on public.books (global_book_id);

-- ── 3. sentences 테이블에 global_book_id FK 추가 ──────────────────────
alter table public.sentences add column if not exists global_book_id uuid references public.global_books(id);
create index if not exists sentences_global_book_id_idx on public.sentences (global_book_id);

-- 공개 피드: 로그인 유저라면 누구나 global_book_id가 있는 문장을 읽을 수 있음
create policy "sentences_select_public" on public.sentences for select using (
  global_book_id is not null
);

-- ── 4. global_books의 집계 갱신용 함수 ────────────────────────────────
-- reader_count: 해당 global_book을 서재에 담은 유저 수
create or replace function public.refresh_global_book_counts(gbook_id uuid)
returns void language plpgsql security definer as $$
begin
  update public.global_books
  set
    reader_count = (select count(*) from public.books where global_book_id = gbook_id),
    sentence_count = (select count(*) from public.sentences where global_book_id = gbook_id)
  where id = gbook_id;
end;
$$;

-- ── 5. 유용한 뷰: global_books + 문장들 ──────────────────────────────
create or replace view public.global_book_sentences as
select
  s.id as sentence_id,
  s.content,
  s.page_number,
  s.created_at,
  s.user_id,
  p.username,
  p.display_name,
  p.avatar_url,
  gb.id as global_book_id,
  gb.isbn13,
  gb.title as book_title,
  gb.author as book_author,
  gb.cover_url as book_cover_url,
  count(sl.sentence_id) as like_count
from public.sentences s
join public.global_books gb on s.global_book_id = gb.id
join public.profiles p on s.user_id = p.id
left join public.sentence_likes sl on sl.sentence_id = s.id
group by s.id, gb.id, p.id;
