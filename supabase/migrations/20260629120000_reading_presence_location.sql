-- reading_presence에 세션 중 임시 위치를 추가한다.
-- 위치는 주변 독자 수 집계에만 쓰고, presence 행 삭제/TTL과 함께 사라진다.

alter table public.reading_presence
  add column if not exists location_lat double precision,
  add column if not exists location_lng double precision;

alter table public.reading_presence
  drop constraint if exists reading_presence_location_lat_check,
  add constraint reading_presence_location_lat_check
    check (location_lat is null or location_lat between -90 and 90),
  drop constraint if exists reading_presence_location_lng_check,
  add constraint reading_presence_location_lng_check
    check (location_lng is null or location_lng between -180 and 180);

create or replace function public.nearby_reader_count(radius_meters integer default 500)
returns integer
language sql
security definer
set search_path = public, pg_temp
as $$
  with me as (
    select location_lat as lat, location_lng as lng
    from public.reading_presence
    where user_id = (select auth.uid())
      and (select auth.uid()) is not null
      and last_heartbeat_at >= now() - interval '90 seconds'
      and location_lat is not null
      and location_lng is not null
    limit 1
  ),
  params as (
    select least(greatest(coalesce(radius_meters, 500), 100), 5000)::double precision as radius
  )
  select count(*)::integer
  from public.reading_presence rp
  cross join me
  cross join params
  where rp.user_id <> (select auth.uid())
    and rp.last_heartbeat_at >= now() - interval '90 seconds'
    and rp.location_lat is not null
    and rp.location_lng is not null
    and not exists (
      select 1
      from public.follows outgoing
      join public.follows incoming
        on incoming.follower_id = rp.user_id
       and incoming.following_id = (select auth.uid())
       and incoming.status = 'accepted'
      where outgoing.follower_id = (select auth.uid())
        and outgoing.following_id = rp.user_id
        and outgoing.status = 'accepted'
    )
    and (
      6371000 * 2 * asin(sqrt(
        pow(sin(radians((rp.location_lat - me.lat) / 2)), 2)
        + cos(radians(me.lat))
        * cos(radians(rp.location_lat))
        * pow(sin(radians((rp.location_lng - me.lng) / 2)), 2)
      ))
    ) <= params.radius;
$$;

revoke execute on function public.nearby_reader_count(integer) from public;
grant execute on function public.nearby_reader_count(integer) to authenticated;
