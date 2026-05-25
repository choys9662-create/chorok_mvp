-- 닉네임 중복 확인 함수
-- profiles_select RLS가 authenticated 전용이므로 가입 전 anon도 호출할 수 있도록
-- SECURITY DEFINER + anon grant로 처리
create or replace function public.is_username_available(p_username text)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select not exists(
    select 1 from public.profiles where lower(username) = lower(trim(p_username))
  );
$$;

-- anon(미로그인)과 authenticated(로그인) 모두 호출 가능
grant execute on function public.is_username_available(text) to anon, authenticated;
