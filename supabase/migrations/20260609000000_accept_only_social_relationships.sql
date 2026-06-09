-- 소셜 읽기 권한은 수락된 팔로우 관계만 인정한다.
-- pending 요청은 팔로잉/맞팔/세션 presence 후보가 아니며 읽기 권한도 만들지 않는다.

drop policy if exists "sentences_select_following" on public.sentences;
create policy "sentences_select_following" on public.sentences
  for select using (
    exists (
      select 1 from public.follows f
      where f.follower_id = auth.uid()
        and f.following_id = sentences.user_id
        and f.status = 'accepted'
    )
  );

drop policy if exists "sessions_select_following" on public.reading_sessions;
create policy "sessions_select_following" on public.reading_sessions
  for select using (
    exists (
      select 1 from public.follows f
      where f.follower_id = auth.uid()
        and f.following_id = reading_sessions.user_id
        and f.status = 'accepted'
    )
  );

drop policy if exists "books_select_following" on public.books;
create policy "books_select_following" on public.books
  for select using (
    exists (
      select 1 from public.follows f
      where f.follower_id = auth.uid()
        and f.following_id = books.user_id
        and f.status = 'accepted'
    )
  );

drop policy if exists "presence_select_following" on public.reading_presence;
create policy "presence_select_following" on public.reading_presence
  for select using (
    auth.uid() = user_id
    or exists (
      select 1 from public.follows f
      where f.follower_id = auth.uid()
        and f.following_id = reading_presence.user_id
        and f.status = 'accepted'
    )
  );
