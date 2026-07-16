-- 겹문장 알림 정정
--
-- 기존 트리거는 normalized_sentences 를 `&&`(배열 교집합)로 비교했지만, 앱이
-- 이 컬럼에 "문장 전체를 통째로 정규화한 값 1개"만 넣고 있었다. 그래서 초서 전문이
-- 100% 같을 때만 알림이 갔고, 겹문장의 핵심 케이스(`A.B.C.D` ↔ `B.C`)는 전부 누락됐다.
-- 앱이 이제 문장 단위로 쪼개 넣으므로(`SentenceNormalizer.tokenizeAndNormalize`)
-- `&&` 가 의도대로 "한 문장 단위라도 겹치면"으로 동작한다.
--
-- 함께 바로잡는 것:
--   1) 같은 책 안에서만 — 기존엔 global_book_id 를 비교하지 않아 다른 책끼리도 겹쳤다.
--   2) 숲벗(수신자가 팔로우한 사람)의 초서만 — 기존엔 전체 독자에게 알림이 갔다.
--      근거: `현재 초록` "겹문장 알림 (같은 문장 초서한 숲벗)", 겹문장 개념의 "알림 = 1:1 관점".
--   3) 너무 짧은 겹침 제외 — 위키 미해결 질문이었던 "부분 일치 최소 길이".
--   4) 차단 관계 제외 — 트리거가 SECURITY DEFINER 라 RLS 를 우회하므로 직접 확인해야 한다.

-- 기존 행 백필: 통짜 1개 → 문장 단위 배열.
-- Dart SentenceNormalizer 와 같은 규칙(구분자 [.!?\n]+, 한글·영숫자만 남김, 소문자).
-- update 는 after-insert 트리거를 깨우지 않으므로 과거 초서로 알림이 쏟아지지 않는다.
update public.sentences s
set normalized_sentences = coalesce(
  (
    select array_agg(t.u)
    from (
      select lower(regexp_replace(part, '[^가-힣a-zA-Z0-9]', '', 'g')) as u
      from unnest(regexp_split_to_array(s.content, '[.!?\n]+')) as part
    ) t
    where t.u <> ''
  ),
  '{}'
)
where s.content is not null;

create or replace function public.notify_on_overlap()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare
  rec record;
  units text[];
begin
  if new.global_book_id is null then return null; end if;

  -- ponytail: 8자 미만 단위는 "그렇다" 같은 흔한 표현이라 겹쳐도 의미가 없다.
  -- 오탐이 잦으면 이 숫자만 올린다. Dart 쪽 SentenceNormalizer.minOverlapUnitLength 와 같이 움직여야 한다.
  select array_agg(u) into units
  from unnest(coalesce(new.normalized_sentences, '{}'::text[])) as u
  where length(u) >= 8;

  if units is null then return null; end if;

  for rec in
    select distinct s.user_id
    from public.sentences s
    join public.follows f
      on f.follower_id = s.user_id
     and f.following_id = new.user_id
     and f.status = 'accepted'
    where s.user_id <> new.user_id
      and s.global_book_id = new.global_book_id
      and s.normalized_sentences && units
      and not exists (
        select 1 from public.blocked_users b
        where (b.blocker_id = s.user_id and b.blocked_id = new.user_id)
           or (b.blocker_id = new.user_id and b.blocked_id = s.user_id)
      )
    limit 20
  loop
    perform public.create_notification(rec.user_id, new.user_id, 'overlap', new.id);
  end loop;
  return null;
end;
$$;
revoke execute on function public.notify_on_overlap() from public, anon, authenticated;
