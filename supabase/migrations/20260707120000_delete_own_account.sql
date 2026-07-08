-- 계정 탈퇴: 로그인한 유저 본인이 auth.users 행을 직접 지울 권한이 없으므로
-- (RLS/권한상 일반 authenticated 롤은 auth 스키마에 쓰기 불가) security definer 함수로 대행한다.
-- auth.users → profiles → 소유 데이터 전부 ON DELETE CASCADE로 연결돼 있어
-- (supabase/scripts/purge_test_user.sql 참고) 이 한 행 삭제로 계정+데이터가 전부 정리된다.
create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;

grant execute on function public.delete_own_account() to authenticated;
