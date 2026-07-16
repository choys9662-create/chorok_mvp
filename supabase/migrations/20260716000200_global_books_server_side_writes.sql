-- global_books 수정 권한 서버화.
--
-- global_books_update 정책이 (auth.uid() IS NOT NULL)뿐이라 인증된 아무 유저나
-- 임의 ISBN 행(title/cover_url/total_pages 등)을 덮어쓸 수 있었다. 개인 서재 저장
-- (_upsertGlobalBook)이 매번 공용 메타데이터를 그대로 upsert해, 빈 값·0페이지가
-- 더 좋은 기존 값을 지울 수 있었다.
--
-- 서지 보강을 SECURITY DEFINER RPC로만 허용하고, null/빈 값만 채우는 병합 규칙을 적용한다.
-- 기존 유효 값은 절대 덮지 않는다.
create or replace function public.upsert_global_book(
  p_isbn13 text,
  p_title text,
  p_author text,
  p_cover_url text default null,
  p_description text default null,
  p_total_pages int default null,
  p_category text default null,
  p_publisher text default null,
  p_pub_date text default null
)
returns uuid
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  result_id uuid;
begin
  if p_isbn13 is null or btrim(p_isbn13) = '' then
    return null;
  end if;

  insert into public.global_books (isbn13, title, author, cover_url, description, total_pages, category, publisher, pub_date)
  values (
    p_isbn13,
    coalesce(nullif(btrim(p_title), ''), '제목 없음'),
    coalesce(nullif(btrim(p_author), ''), ''),
    nullif(btrim(coalesce(p_cover_url, '')), ''),
    nullif(btrim(coalesce(p_description, '')), ''),
    nullif(p_total_pages, 0),
    nullif(btrim(coalesce(p_category, '')), ''),
    nullif(btrim(coalesce(p_publisher, '')), ''),
    nullif(btrim(coalesce(p_pub_date, '')), '')
  )
  on conflict (isbn13) do update set
    -- 기존 값이 비어있을 때만 새 값으로 채운다. 이미 유효한 값은 절대 덮지 않는다.
    title        = case when nullif(btrim(global_books.title), '') is null
                        then coalesce(nullif(btrim(excluded.title), ''), global_books.title)
                        else global_books.title end,
    author       = case when nullif(btrim(global_books.author), '') is null
                        then coalesce(nullif(btrim(excluded.author), ''), global_books.author)
                        else global_books.author end,
    cover_url    = coalesce(global_books.cover_url, excluded.cover_url),
    description  = coalesce(global_books.description, excluded.description),
    total_pages  = coalesce(nullif(global_books.total_pages, 0), excluded.total_pages),
    category     = coalesce(global_books.category, excluded.category),
    publisher    = coalesce(global_books.publisher, excluded.publisher),
    pub_date     = coalesce(global_books.pub_date, excluded.pub_date)
  returning id into result_id;

  return result_id;
end;
$$;

grant execute on function public.upsert_global_book(text, text, text, text, text, int, text, text, text) to authenticated;

-- 직접 쓰기 경로를 닫는다 — global_books는 이제 위 RPC를 통해서만 생성·보강된다.
drop policy if exists "global_books_insert" on public.global_books;
drop policy if exists "global_books_update" on public.global_books;
