-- presence 위치 좌표 보호.
--
-- 1) presence_select_following에 status='accepted' 조건이 없어 pending(미승인) 팔로워도
--    좌표를 포함한 행 전체를 읽을 수 있었다. accept-only 원칙(20260609)을 이 테이블에도 적용.
drop policy if exists presence_select_following on public.reading_presence;
create policy presence_select_following on public.reading_presence
  for select using (
    auth.uid() = user_id
    or exists (
      select 1 from public.follows f
      where f.follower_id = auth.uid()
        and f.following_id = reading_presence.user_id
        and f.status = 'accepted'
    )
  );

-- 2) 좌표 컬럼은 팔로워에게도 직접 노출하지 않는다. 근처 독자 수는
--    nearby_reader_count(SECURITY DEFINER)로만 제공하며, 이 함수는 함수 소유자 권한으로
--    실행되므로 아래 컬럼 권한 축소의 영향을 받지 않는다.
--    클라이언트(reading_presence_repository.dart)는 location_lat/lng를 select한 적이 없어
--    안전하게 컬럼 권한을 좁힐 수 있다.
revoke select on public.reading_presence from authenticated, anon;
grant select (user_id, started_at, last_heartbeat_at, book_title, book_author, book_cover_url)
  on public.reading_presence to authenticated, anon;

-- 3) 실제 만료 삭제. 지금까지 90초 TTL은 조회 쿼리의 필터일 뿐이라 앱이 크래시해
--    end()를 못 부르면 좌표가 무기한 남았다. pg_cron으로 5분마다 정리한다.
create or replace function public.purge_stale_presence()
returns void
language sql
security definer
set search_path to 'public', 'pg_temp'
as $$
  delete from public.reading_presence
  where last_heartbeat_at < now() - interval '5 minutes';
$$;

select cron.schedule(
  'purge-stale-presence',
  '*/5 * * * *',
  $$select public.purge_stale_presence();$$
);
