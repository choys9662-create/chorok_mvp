-- ─────────────────────────────────────────────────────────────────────────
-- 닉네임(핸들) 정책
--   username  = 고유 핸들. latin 슬러그(^[a-z0-9_]{3,20}$), 대소문자 무시 유일.
--   display_name = 표시명. 한글 등 자유, 중복 허용.
-- (2026-06-23 적용. 원격 직접 적용분의 repo 기록본 — 모든 구문 idempotent)
-- ─────────────────────────────────────────────────────────────────────────

-- 1) 정규화: 임의 문자열 → latin 슬러그(소문자, [a-z0-9_], 연속 _ 축약, 양끝 _ 제거)
create or replace function public.normalize_username(p_raw text)
returns text
language sql
immutable
as $$
  select nullif(
    trim(both '_' from
      regexp_replace(
        regexp_replace(lower(coalesce(p_raw, '')), '[^a-z0-9_]+', '_', 'g'),
        '_+', '_', 'g'
      )
    ),
    ''
  );
$$;

-- 2) 사용 가능 여부: 형식 검증 + 대소문자 무시 중복 검사
create or replace function public.is_username_available(p_username text)
returns boolean
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $$
  select trim(lower(coalesce(p_username, ''))) ~ '^[a-z0-9_]{3,20}$'
     and not exists (
       select 1 from public.profiles
       where lower(username) = lower(trim(p_username))
     );
$$;

-- 3) 자동 생성: seed에서 슬러그를 만들고, 충돌 시 숫자 접미로 유일화
create or replace function public.generate_username(p_seed text)
returns text
language plpgsql
volatile
security definer
set search_path to 'public', 'pg_temp'
as $$
declare
  base text;
  candidate text;
  i int := 0;
begin
  base := public.normalize_username(p_seed);
  if base is null or length(base) < 3 then
    base := 'reader';
  end if;
  base := left(base, 15); -- 접미 숫자 여유 확보

  candidate := base;
  while exists (select 1 from public.profiles where lower(username) = candidate) loop
    i := i + 1;
    if i <= 3 then
      candidate := base || (floor(random() * 900 + 100))::int::text;      -- 3자리
    elsif i <= 20 then
      candidate := base || (floor(random() * 9000 + 1000))::int::text;    -- 4자리
    else
      -- 극단적 충돌: uuid 일부로 확실히 유일화
      return left(base, 11) || substr(replace(gen_random_uuid()::text, '-', ''), 1, 8);
    end if;
  end loop;
  return candidate;
end;
$$;

-- 4) 기존 비정상 username 자가 치유 (latin 슬러그 규칙 위반 행 → 이메일 기반 슬러그)
update public.profiles p
set username = public.generate_username(coalesce(split_part(u.email, '@', 1), 'reader'))
from auth.users u
where u.id = p.id
  and (p.username is null or p.username !~ '^[a-z0-9_]{3,20}$');

-- 5) 대소문자 무시 유일성 (기존 case-sensitive 제약 대체)
alter table public.profiles drop constraint if exists profiles_username_key;
create unique index if not exists profiles_username_lower_key
  on public.profiles (lower(username));

-- 6) 형식 CHECK 제약
alter table public.profiles drop constraint if exists profiles_username_format_chk;
alter table public.profiles
  add constraint profiles_username_format_chk
  check (username ~ '^[a-z0-9_]{3,20}$');

-- 7) 신규 가입 트리거: 이메일/소셜 모두 generate_username 단일 경로로 통일.
--    username 충돌 시 재생성 재시도(레이스 안전).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_display text;
  v_seed text;
  v_username text;
  v_attempt int := 0;
begin
  v_display := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
    nullif(split_part(new.email, '@', 1), ''),
    '독자'
  );
  v_seed := coalesce(
    nullif(new.raw_user_meta_data ->> 'username', ''),
    nullif(new.raw_user_meta_data ->> 'preferred_username', ''),
    nullif(split_part(new.email, '@', 1), ''),
    'reader'
  );

  loop
    v_attempt := v_attempt + 1;
    v_username := public.generate_username(v_seed);
    begin
      insert into public.profiles (id, username, display_name, avatar_url)
      values (new.id, v_username, v_display, new.raw_user_meta_data ->> 'avatar_url');
      exit; -- 성공
    exception
      when unique_violation then
        -- 이미 프로필이 있으면(id 충돌) 종료
        if exists (select 1 from public.profiles where id = new.id) then
          exit;
        end if;
        -- username 충돌: 5회까지 재생성, 이후 id 기반 확정 유일값
        if v_attempt >= 5 then
          insert into public.profiles (id, username, display_name, avatar_url)
          values (
            new.id,
            'reader_' || substr(replace(new.id::text, '-', ''), 1, 12),
            v_display,
            new.raw_user_meta_data ->> 'avatar_url'
          )
          on conflict (id) do nothing;
          exit;
        end if;
    end;
  end loop;

  return new;
end;
$$;

grant execute on function public.normalize_username(text) to anon, authenticated;
grant execute on function public.generate_username(text) to anon, authenticated;
