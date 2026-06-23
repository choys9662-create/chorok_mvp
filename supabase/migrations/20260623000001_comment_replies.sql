-- 문장 댓글에 1단계 답글(대댓글) 지원
-- parent_comment_id가 있으면 답글, 없으면 최상위 댓글.
-- 답글의 답글은 만들지 않는다(1단계). UI에서 답글 버튼은 최상위 댓글에만 노출.
alter table public.sentence_comments
  add column if not exists parent_comment_id uuid
    references public.sentence_comments(id) on delete cascade;

-- 답글 조회용 인덱스 (부모 기준 시간순)
create index if not exists sentence_comments_parent_idx
  on public.sentence_comments (parent_comment_id, created_at);

-- 알림: 최상위 댓글이면 문장 작성자에게, 답글이면 부모 댓글 작성자에게 알림.
-- (답글일 때 문장 작성자는 이미 최상위 댓글 시점에 알림을 받았으므로 중복 방지)
create or replace function public.notify_on_comment()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare recipient uuid;
begin
  if new.parent_comment_id is null then
    select user_id into recipient from public.sentences where id = new.sentence_id;
  else
    select user_id into recipient from public.sentence_comments where id = new.parent_comment_id;
  end if;
  perform public.create_notification(recipient, new.user_id, 'comment', new.sentence_id);
  return null;
end;
$$;
revoke execute on function public.notify_on_comment() from public, anon, authenticated;
