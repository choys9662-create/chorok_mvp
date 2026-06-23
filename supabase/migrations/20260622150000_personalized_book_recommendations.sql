-- 내가 실제로 읽는 중이거나 완독한 책과 겹치는 유저를 찾고,
-- 그 유저들이 읽은 책 중 내 서재에 없는 책을 추천한다.
create schema if not exists private;

create or replace function private.personalized_book_recommendations(
  limit_count int default 8
)
returns table(
  isbn13 text,
  title text,
  author text,
  cover_url text,
  match_score double precision,
  reason text
)
language sql
stable
security definer
set search_path = ''
as $$
  with my_books as (
    select distinct coalesce(
      b.global_book_id::text,
      nullif(trim(b.isbn), ''),
      lower(trim(b.title)) || '|' || lower(trim(b.author))
    ) as taste_key
    from public.books b
    where b.user_id = auth.uid()
      and b.status in ('reading', 'completed')
  ),
  reader_books as (
    select
      b.user_id,
      b.id,
      b.global_book_id,
      coalesce(
        b.global_book_id::text,
        nullif(trim(b.isbn), ''),
        lower(trim(b.title)) || '|' || lower(trim(b.author))
      ) as taste_key
    from public.books b
    where b.user_id <> auth.uid()
      and b.status in ('reading', 'completed')
  ),
  similar_readers as (
    select rb.user_id, count(distinct rb.taste_key)::int as shared_count
    from reader_books rb
    join my_books mine on mine.taste_key = rb.taste_key
    group by rb.user_id
  ),
  candidates as (
    select
      coalesce(gb.isbn13, b.isbn) as isbn13,
      coalesce(gb.title, b.title) as title,
      coalesce(gb.author, b.author) as author,
      coalesce(gb.cover_url, b.cover_url) as cover_url,
      sum(sr.shared_count)::double precision as affinity,
      count(distinct b.user_id)::int as similar_reader_count
    from similar_readers sr
    join public.books b
      on b.user_id = sr.user_id
     and b.status in ('reading', 'completed')
    left join public.global_books gb on gb.id = b.global_book_id
    where not exists (
      select 1
      from my_books mine
      where mine.taste_key = coalesce(
        b.global_book_id::text,
        nullif(trim(b.isbn), ''),
        lower(trim(b.title)) || '|' || lower(trim(b.author))
      )
    )
    group by
      coalesce(gb.isbn13, b.isbn),
      coalesce(gb.title, b.title),
      coalesce(gb.author, b.author),
      coalesce(gb.cover_url, b.cover_url)
  )
  select
    c.isbn13,
    c.title,
    c.author,
    c.cover_url,
    least(0.99, 0.72 + c.affinity * 0.04 + c.similar_reader_count * 0.02),
    c.similar_reader_count || '명의 비슷한 취향 유저가 읽은 책'
  from candidates c
  where c.title is not null and trim(c.title) <> ''
  order by c.affinity desc, c.similar_reader_count desc, c.title
  limit greatest(1, least(limit_count, 20));
$$;

revoke all on function private.personalized_book_recommendations(int)
  from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.personalized_book_recommendations(int)
  to authenticated;

-- Data API에는 권한 상승이 없는 public 래퍼만 노출한다.
create or replace function public.personalized_book_recommendations(
  limit_count int default 8
)
returns table(
  isbn13 text,
  title text,
  author text,
  cover_url text,
  match_score double precision,
  reason text
)
language sql
stable
security invoker
set search_path = ''
as $$
  select *
  from private.personalized_book_recommendations(limit_count);
$$;

revoke execute on function public.personalized_book_recommendations(int)
  from public, anon;
grant execute on function public.personalized_book_recommendations(int)
  to authenticated;
