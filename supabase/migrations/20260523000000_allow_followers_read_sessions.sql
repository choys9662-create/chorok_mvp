-- reading_sessions: 팔로우한 사람의 세션 읽기 허용
-- sentences_select_following 정책과 동일한 패턴
create policy "sessions_select_following" on public.reading_sessions
  for select using (
    exists (
      select 1 from public.follows
      where follower_id = auth.uid() and following_id = reading_sessions.user_id
    )
  );
