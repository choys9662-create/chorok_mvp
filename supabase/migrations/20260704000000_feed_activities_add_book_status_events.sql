-- chorok_app: 피드에 '읽고 싶은 책 추가'·'읽기 시작' 이벤트 노출
--
-- 배경:
--   기존 피드는 문장 기록·세션 완료·완독만 다뤘다. 책을 찜하거나 읽기
--   시작으로 표시하는 순간도 소식으로 보이길 원해서 이벤트 소스를 추가한다.
--   reading_started_at은 last_session_started_at(세션마다 갱신)과 달리
--   최초 1회만 채워지므로 "읽기 시작" 이벤트에 적합하다. 트리거로 채워서
--   saveFromBook 등 기존 upsert 호출부는 건드릴 필요가 없다.

alter table public.books
  add column if not exists reading_started_at timestamptz;

create or replace function public.set_reading_started_at()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'reading' and new.reading_started_at is null then
    new.reading_started_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists books_set_reading_started_at on public.books;
create trigger books_set_reading_started_at
  before insert or update on public.books
  for each row execute function public.set_reading_started_at();

create or replace function public.get_feed_activities(
  p_scope text default 'all',
  p_limit int default 50
)
returns table (
  event_id text,
  event_type text,
  username text,
  avatar_url text,
  book_title text,
  book_author text,
  cover_url text,
  isbn13 text,
  occurred_at timestamptz,
  sentence_count int,
  sentences jsonb,
  duration_seconds int,
  progress_percent int
)
language sql
security definer
set search_path = public, pg_temp
as $$
  with eligible_users as (
    select p.id, coalesce(p.display_name, p.username, '독자') as username,
           p.avatar_url
    from public.profiles p
    where p.id <> auth.uid()
      and (
        (
          p_scope = 'friends'
          and exists (
            select 1 from public.follows f
            where f.follower_id = auth.uid()
              and f.following_id = p.id
              and f.status = 'accepted'
          )
        )
        or (p_scope = 'all' and not coalesce(p.is_private, false))
      )
  ),
  sentence_events as (
    select
      'sb_' || s.user_id::text || '_' ||
        coalesce(s.session_id::text, s.id::text) as event_id,
      'sentence_batch'::text as event_type,
      u.username,
      u.avatar_url,
      coalesce(gb.title, b.title, '알 수 없는 책') as book_title,
      coalesce(gb.author, b.author, '') as book_author,
      coalesce(gb.cover_url, b.cover_url) as cover_url,
      coalesce(gb.isbn13, b.isbn) as isbn13,
      max(s.created_at) as occurred_at,
      count(*)::int as sentence_count,
      jsonb_agg(
        jsonb_build_object(
          'id', s.id,
          'content', s.content,
          'thought', s.thought,
          'page_number', s.page_number
        )
        order by s.created_at desc
      ) as sentences,
      0::int as duration_seconds,
      100::int as progress_percent
    from public.sentences s
    join eligible_users u on u.id = s.user_id
    left join public.books b on b.id = s.book_id
    left join public.global_books gb on gb.id = s.global_book_id
    group by s.user_id, coalesce(s.session_id::text, s.id::text),
             u.username, u.avatar_url, gb.title, b.title, gb.author, b.author,
             gb.cover_url, b.cover_url, gb.isbn13, b.isbn
  ),
  session_events as (
    select
      'ss_' || rs.id::text,
      'session_complete'::text,
      u.username,
      u.avatar_url,
      coalesce(b.title, '알 수 없는 책'),
      coalesce(b.author, ''),
      b.cover_url,
      b.isbn,
      rs.ended_at,
      0::int,
      '[]'::jsonb,
      rs.duration_seconds,
      100::int
    from public.reading_sessions rs
    join eligible_users u on u.id = rs.user_id
    left join public.books b on b.id = rs.book_id
    where rs.ended_at is not null
  ),
  book_events as (
    select
      'bc_' || b.id::text,
      'book_complete'::text,
      u.username,
      u.avatar_url,
      b.title,
      b.author,
      b.cover_url,
      b.isbn,
      b.completed_at,
      0::int,
      '[]'::jsonb,
      0::int,
      100::int
    from public.books b
    join eligible_users u on u.id = b.user_id
    where b.status = 'completed' and b.completed_at is not null
  ),
  want_to_read_events as (
    select
      'wr_' || b.id::text,
      'want_to_read'::text,
      u.username,
      u.avatar_url,
      b.title,
      b.author,
      b.cover_url,
      b.isbn,
      b.created_at,
      0::int,
      '[]'::jsonb,
      0::int,
      0::int
    from public.books b
    join eligible_users u on u.id = b.user_id
    where b.status = 'wantToRead'
  ),
  reading_start_events as (
    select
      'rs_' || b.id::text,
      'reading_start'::text,
      u.username,
      u.avatar_url,
      b.title,
      b.author,
      b.cover_url,
      b.isbn,
      b.reading_started_at,
      0::int,
      '[]'::jsonb,
      0::int,
      0::int
    from public.books b
    join eligible_users u on u.id = b.user_id
    where b.reading_started_at is not null
  )
  select * from (
    select * from sentence_events
    union all
    select * from session_events
    union all
    select * from book_events
    union all
    select * from want_to_read_events
    union all
    select * from reading_start_events
  ) events
  order by occurred_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

revoke execute on function public.get_feed_activities(text, int) from public;
grant execute on function public.get_feed_activities(text, int) to authenticated;
