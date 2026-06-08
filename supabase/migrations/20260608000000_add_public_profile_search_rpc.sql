create or replace function public.search_public_profiles(
  p_query text,
  p_limit int default 20
)
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  bio text,
  is_private boolean
)
language sql
security definer
set search_path = public, pg_temp
as $$
  with normalized as (
    select trim(leading '@' from trim(coalesce(p_query, ''))) as q,
           least(greatest(coalesce(p_limit, 20), 1), 50) as lim
  ),
  matches as (
    select
      p.id,
      p.username,
      p.display_name,
      p.avatar_url,
      p.bio,
      coalesce(p.is_private, false) as is_private,
      case
        when p.username = n.q then 0
        when p.display_name = n.q then 1
        when p.username ilike n.q || '%' then 2
        when p.display_name ilike n.q || '%' then 3
        else 4
      end as rank
    from public.profiles p
    cross join normalized n
    where n.q <> ''
      and (
        p.username ilike '%' || n.q || '%'
        or p.display_name ilike '%' || n.q || '%'
      )
  )
  select
    matches.id,
    matches.username,
    matches.display_name,
    matches.avatar_url,
    matches.bio,
    matches.is_private
  from matches
  order by matches.rank, matches.username
  limit (select lim from normalized);
$$;

revoke execute on function public.search_public_profiles(text, int) from public;
grant execute on function public.search_public_profiles(text, int) to anon, authenticated;
