create table if not exists public.notifications (
  id           uuid primary key default uuid_generate_v4(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id     uuid references public.profiles(id) on delete cascade,
  type         text not null check (type in ('follow','like','comment','overlap')),
  sentence_id  uuid references public.sentences(id) on delete cascade,
  is_read      boolean not null default false,
  created_at   timestamptz not null default now()
);
create index if not exists notifications_recipient_idx
  on public.notifications (recipient_id, created_at desc);

alter table public.notifications enable row level security;
-- 수신자만 조회/수정. insert 정책 없음 → 트리거(SECURITY DEFINER)만 기록.
create policy "notifications_select" on public.notifications for select to authenticated using (auth.uid() = recipient_id);
create policy "notifications_update" on public.notifications for update to authenticated using (auth.uid() = recipient_id) with check (auth.uid() = recipient_id);
create policy "notifications_delete" on public.notifications for delete to authenticated using (auth.uid() = recipient_id);

-- helper: 알림 insert (self-action skip)
create or replace function public.create_notification(
  p_recipient uuid, p_actor uuid, p_type text, p_sentence uuid
) returns void language plpgsql security definer
set search_path = public, pg_temp as $$
begin
  if p_recipient is null or p_actor is null or p_recipient = p_actor then return; end if;
  insert into public.notifications(recipient_id, actor_id, type, sentence_id)
  values (p_recipient, p_actor, p_type, p_sentence);
end;
$$;
revoke execute on function public.create_notification(uuid,uuid,text,uuid) from public, anon, authenticated;

-- follow (accepted만)
create or replace function public.notify_on_follow()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if new.status = 'accepted' then
    perform public.create_notification(new.following_id, new.follower_id, 'follow', null);
  end if;
  return null;
end;
$$;
revoke execute on function public.notify_on_follow() from public, anon, authenticated;
drop trigger if exists trg_notify_follow on public.follows;
create trigger trg_notify_follow after insert on public.follows
  for each row execute procedure public.notify_on_follow();

-- like
create or replace function public.notify_on_like()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare owner uuid;
begin
  select user_id into owner from public.sentences where id = new.sentence_id;
  perform public.create_notification(owner, new.user_id, 'like', new.sentence_id);
  return null;
end;
$$;
revoke execute on function public.notify_on_like() from public, anon, authenticated;
drop trigger if exists trg_notify_like on public.sentence_likes;
create trigger trg_notify_like after insert on public.sentence_likes
  for each row execute procedure public.notify_on_like();

-- comment
create or replace function public.notify_on_comment()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare owner uuid;
begin
  select user_id into owner from public.sentences where id = new.sentence_id;
  perform public.create_notification(owner, new.user_id, 'comment', new.sentence_id);
  return null;
end;
$$;
revoke execute on function public.notify_on_comment() from public, anon, authenticated;
drop trigger if exists trg_notify_comment on public.sentence_comments;
create trigger trg_notify_comment after insert on public.sentence_comments
  for each row execute procedure public.notify_on_comment();

-- overlap: 새 문장의 normalized_sentences와 겹치는 다른 유저의 공개 문장 작성자에게 알림
create or replace function public.notify_on_overlap()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare rec record;
begin
  if new.normalized_sentences is null or array_length(new.normalized_sentences,1) is null then
    return null;
  end if;
  for rec in
    select distinct s.user_id
    from public.sentences s
    where s.id <> new.id
      and s.user_id <> new.user_id
      and s.global_book_id is not null
      and s.normalized_sentences && new.normalized_sentences
    limit 20
  loop
    perform public.create_notification(rec.user_id, new.user_id, 'overlap', new.id);
  end loop;
  return null;
end;
$$;
revoke execute on function public.notify_on_overlap() from public, anon, authenticated;
drop trigger if exists trg_notify_overlap on public.sentences;
create trigger trg_notify_overlap after insert on public.sentences
  for each row execute procedure public.notify_on_overlap();
