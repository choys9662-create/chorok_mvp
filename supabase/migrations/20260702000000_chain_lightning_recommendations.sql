-- 체인 라이트닝: 방금 완독한 책을 읽은 다른 유저들이 좋아한 책을 추천한다.
-- "좋아한" = 완독한 책. (book_reviews 테이블은 아직 미적용이라 별점 가중치는 제외)
create schema if not exists private;

create or replace function private.chain_lightning_recommendations(
  p_title text,
  p_author text,
  p_isbn text default null,
  limit_count int default 3
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
  with target_readers as (
    -- 방금 완독한 책을 서재에 둔 다른 유저들 (isbn 우선, 없으면 제목+저자 매칭)
    select distinct b.user_id
    from public.books b
    where b.user_id <> auth.uid()
      and b.status in ('reading', 'completed')
      and (
        (nullif(trim(p_isbn), '') is not null
          and nullif(trim(b.isbn), '') = nullif(trim(p_isbn), ''))
        or (lower(trim(b.title)) = lower(trim(p_title))
          and lower(trim(b.author)) = lower(trim(p_author)))
      )
  ),
  my_keys as (
    select distinct
      lower(trim(b.title)) || '|' || lower(trim(b.author)) as taste_key
    from public.books b
    where b.user_id = auth.uid()
  ),
  candidates as (
    select
      coalesce(gb.isbn13, b.isbn) as isbn13,
      coalesce(gb.title, b.title) as title,
      coalesce(gb.author, b.author) as author,
      coalesce(gb.cover_url, b.cover_url) as cover_url,
      count(distinct b.user_id)::int as reader_count
    from public.books b
    join target_readers tr on tr.user_id = b.user_id
    left join public.global_books gb on gb.id = b.global_book_id
    where b.status = 'completed'
      -- 완독한 그 책 자신은 제외
      and not (lower(trim(b.title)) = lower(trim(p_title))
        and lower(trim(b.author)) = lower(trim(p_author)))
      and (nullif(trim(p_isbn), '') is null
        or nullif(trim(b.isbn), '') is distinct from nullif(trim(p_isbn), ''))
      -- 내 서재에 이미 있는 책 제외
      and not exists (
        select 1 from my_keys mk
        where mk.taste_key = lower(trim(b.title)) || '|' || lower(trim(b.author))
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
    least(0.99, 0.8 + c.reader_count * 0.04),
    '『' || p_title || '』을(를) 읽은 ' || c.reader_count || '명이 좋아한 책'
  from candidates c
  where c.title is not null and trim(c.title) <> ''
  order by c.reader_count desc, c.title
  limit greatest(1, least(limit_count, 10));
$$;

revoke all on function private.chain_lightning_recommendations(text, text, text, int)
  from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.chain_lightning_recommendations(text, text, text, int)
  to authenticated;

-- Data API에는 권한 상승이 없는 public 래퍼만 노출한다.
create or replace function public.chain_lightning_recommendations(
  p_title text,
  p_author text,
  p_isbn text default null,
  limit_count int default 3
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
  from private.chain_lightning_recommendations(p_title, p_author, p_isbn, limit_count);
$$;

revoke execute on function public.chain_lightning_recommendations(text, text, text, int)
  from public, anon;
grant execute on function public.chain_lightning_recommendations(text, text, text, int)
  to authenticated;
