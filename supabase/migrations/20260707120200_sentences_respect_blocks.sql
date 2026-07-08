-- 공개 문장(sentences_select_public)이 차단 관계를 무시하고 노출되던 문제 수정.
-- 기존 조건(20260623100200_sentences_public_respect_privacy.sql)에
-- "나-작성자 사이에 차단이 없을 것" 조건만 추가한다. 방향 무관(둘 중 누가 차단했든 숨김).
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
    and not exists (
      select 1 from public.blocked_users b
      where (b.blocker_id = auth.uid() and b.blocked_id = sentences.user_id)
         or (b.blocker_id = sentences.user_id and b.blocked_id = auth.uid())
    )
  );
