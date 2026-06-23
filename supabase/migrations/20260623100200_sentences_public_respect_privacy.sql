-- 문장 public 노출도 소유자가 비공개가 아닐 때만 허용한다.
-- (기존: global_book_id만 있으면 무조건 공개 → 비공개 계정 문장 노출 누수)
-- 본인(sentences_select_own)·수락된 팔로워(sentences_select_following) 정책은 그대로 유지.
-- (2026-06-23 적용. 원격 직접 적용분의 repo 기록본)

drop policy if exists sentences_select_public on public.sentences;
create policy sentences_select_public on public.sentences
  for select
  using (
    global_book_id is not null
    and exists (
      select 1 from public.profiles p
      where p.id = sentences.user_id
        and coalesce(p.is_private, false) = false
    )
  );
