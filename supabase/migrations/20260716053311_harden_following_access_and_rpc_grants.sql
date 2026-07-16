-- Blocks pending followers from private books/sessions and removes anonymous
-- execution of RPCs that the app only calls after authentication.

drop policy if exists books_select_following on public.books;
create policy books_select_following on public.books
  for select to authenticated
  using (
    exists (
      select 1
      from public.follows f
      where f.follower_id = auth.uid()
        and f.following_id = books.user_id
        and f.status = 'accepted'
    )
  );

drop policy if exists sessions_select_following on public.reading_sessions;
create policy sessions_select_following on public.reading_sessions
  for select to authenticated
  using (
    exists (
      select 1
      from public.follows f
      where f.follower_id = auth.uid()
        and f.following_id = reading_sessions.user_id
        and f.status = 'accepted'
    )
  );

revoke execute on function public.get_feed_activities(text, integer) from public, anon;
revoke execute on function public.live_reader_counts() from public, anon;
revoke execute on function public.nearby_reader_count(integer) from public, anon;
revoke execute on function public.search_public_profiles(text, integer) from public, anon;

grant execute on function public.get_feed_activities(text, integer) to authenticated;
grant execute on function public.live_reader_counts() to authenticated;
grant execute on function public.nearby_reader_count(integer) to authenticated;
grant execute on function public.search_public_profiles(text, integer) to authenticated;

alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;

alter function public.popular_authors(integer) set search_path = '';
alter function public.popular_books(integer) set search_path = '';
alter function public.normalize_username(text) set search_path = '';
alter function public.set_reading_started_at() set search_path = '';
