-- ================================================================
-- 검색 탭 디스커버리용 "인기 책 / 인기 작가" 집계
--
-- 검색 로그 테이블이 아직 없어 기존 데이터로 근사한다.
-- global_books.reader_count 역정규화 컬럼은 갱신되지 않아(전부 0) 못 쓰므로,
-- books / sentences 를 라이브 조인해 실제 독자 수·문장 수로 순위를 매긴다.
-- ================================================================

-- ── 인기 책: 서재에 담은 유저 수(readers) → 문장 수 순 ───────────────────────
create or replace function public.popular_books(limit_count int default 10)
returns table(
  isbn13 text,
  title text,
  author text,
  publisher text,
  cover_url text,
  total_pages int
)
language sql
stable
as $$
  select gb.isbn13, gb.title, gb.author, gb.publisher, gb.cover_url,
         gb.total_pages
  from public.global_books gb
  left join public.books b on b.global_book_id = gb.id
  left join public.sentences s on s.global_book_id = gb.id
  group by gb.id
  order by count(distinct b.user_id) desc,
           count(distinct s.id) desc,
           gb.created_at desc
  limit limit_count;
$$;

-- ── 인기 작가: 작가별 독자 수 합계 + 대표작 2개 ──────────────────────────────
create or replace function public.popular_authors(limit_count int default 5)
returns table(author text, reader_total bigint, titles text[])
language sql
stable
as $$
  with author_book as (
    select gb.author, gb.title,
           count(distinct b.user_id) as readers,
           count(distinct s.id) as sentences
    from public.global_books gb
    left join public.books b on b.global_book_id = gb.id
    left join public.sentences s on s.global_book_id = gb.id
    where gb.author is not null and gb.author <> ''
    group by gb.id
  )
  select author,
         sum(readers)::bigint as reader_total,
         (array_agg(title order by readers desc, sentences desc))[1:2]
           as titles
  from author_book
  group by author
  order by reader_total desc, sum(sentences) desc, count(*) desc
  limit limit_count;
$$;

grant execute on function public.popular_books(int) to anon, authenticated;
grant execute on function public.popular_authors(int) to anon, authenticated;
