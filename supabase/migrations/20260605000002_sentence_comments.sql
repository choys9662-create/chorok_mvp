-- 문장 댓글 + 댓글 공감
create table if not exists public.sentence_comments (
  id          uuid primary key default uuid_generate_v4(),
  sentence_id uuid not null references public.sentences(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  content     text not null,
  like_count  int  not null default 0,
  created_at  timestamptz not null default now()
);
create index if not exists sentence_comments_sentence_idx
  on public.sentence_comments (sentence_id, created_at desc);

create table if not exists public.sentence_comment_likes (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  comment_id uuid not null references public.sentence_comments(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, comment_id)
);

alter table public.sentence_comments       enable row level security;
alter table public.sentence_comment_likes  enable row level security;

-- 댓글 가시성: 부모 문장이 공개거나 내가 작성자를 팔로우(accepted)했거나 내 문장
create policy "sentence_comments_select" on public.sentence_comments
  for select to authenticated using (
    exists (
      select 1 from public.sentences s where s.id = sentence_id and (
        s.global_book_id is not null
        or s.user_id = auth.uid()
        or exists (
          select 1 from public.follows f
          where f.follower_id = auth.uid() and f.following_id = s.user_id
            and f.status = 'accepted'
        )
      )
    )
  );

-- insert: 본인 user_id + 위 가시성을 만족하는 문장에만
create policy "sentence_comments_insert" on public.sentence_comments
  for insert to authenticated with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.sentences s where s.id = sentence_id and (
        s.global_book_id is not null
        or s.user_id = auth.uid()
        or exists (
          select 1 from public.follows f
          where f.follower_id = auth.uid() and f.following_id = s.user_id
            and f.status = 'accepted'
        )
      )
    )
  );

create policy "sentence_comments_delete" on public.sentence_comments
  for delete to authenticated using (auth.uid() = user_id);

-- 댓글 좋아요: 집계는 누구나(authenticated), 본인만 토글
create policy "comment_likes_select" on public.sentence_comment_likes
  for select to authenticated using (true);
create policy "comment_likes_insert" on public.sentence_comment_likes
  for insert to authenticated with check (auth.uid() = user_id);
create policy "comment_likes_delete" on public.sentence_comment_likes
  for delete to authenticated using (auth.uid() = user_id);

-- like_count 동기화
create or replace function public.sync_comment_like_count()
returns trigger language plpgsql security definer
set search_path = public, pg_temp as $$
declare cid uuid;
begin
  cid := coalesce(new.comment_id, old.comment_id);
  update public.sentence_comments
    set like_count = (select count(*) from public.sentence_comment_likes where comment_id = cid)
    where id = cid;
  return null;
end;
$$;
revoke execute on function public.sync_comment_like_count() from public, anon, authenticated;

drop trigger if exists trg_comment_like_count on public.sentence_comment_likes;
create trigger trg_comment_like_count
  after insert or delete on public.sentence_comment_likes
  for each row execute procedure public.sync_comment_like_count();
