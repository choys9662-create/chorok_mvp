-- 팔로우 상태 위조 차단.
--
-- 기존 follows_insert 정책은 auth.uid()=follower_id만 검사하고 status 값은 클라이언트가
-- 보내는 그대로 신뢰했다. 비공개 여부 판단이 클라이언트(follow_repository.dart)에만
-- 있었기 때문에, 인증된 아무 유저나 status='accepted'를 직접 INSERT해 비공개 계정의
-- 책·문장·세션·위치(*_select_following 정책)에 접근할 수 있었다.
--
-- 대상 프로필의 is_private를 서버가 직접 읽어 status를 강제한다.
-- 클라이언트가 INSERT 시 어떤 status를 보내든 트리거가 덮어쓴다.
create or replace function public.enforce_follow_status()
returns trigger
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  target_is_private boolean;
begin
  select coalesce(is_private, false) into target_is_private
  from public.profiles
  where id = new.following_id;

  new.status := case when target_is_private then 'pending' else 'accepted' end;
  return new;
end;
$$;

drop trigger if exists follows_enforce_status on public.follows;
create trigger follows_enforce_status
  before insert on public.follows
  for each row
  execute function public.enforce_follow_status();

-- 승인/거절은 대상 사용자(following_id) 전용 경로로만 허용한다.
-- 승인: pending -> accepted 전환만 허용 (다른 필드·다른 상태 전이는 불가).
drop policy if exists "follows_update_target_accept" on public.follows;
create policy "follows_update_target_accept" on public.follows
  for update to authenticated
  using (auth.uid() = following_id and status = 'pending')
  with check (auth.uid() = following_id and status = 'accepted');

-- 거절: 대상 사용자가 자신에게 온 pending 요청을 삭제할 수 있다.
-- (기존 follows_delete는 follower_id 본인의 취소만 허용 — 이 정책은 OR로 추가된다)
drop policy if exists "follows_delete_target_reject" on public.follows;
create policy "follows_delete_target_reject" on public.follows
  for delete to authenticated
  using (auth.uid() = following_id and status = 'pending');

-- 감사: 위조 가능 시점(트리거 도입 이전)에 생성된 accepted 관계 중,
-- 대상이 비공개인데 accepted로 되어 있는 위조 의심 행을 조회한다(참고용, 자동 삭제하지 않음).
-- select f.* from public.follows f
--   join public.profiles p on p.id = f.following_id
--   where f.status = 'accepted' and coalesce(p.is_private, false) = true;
