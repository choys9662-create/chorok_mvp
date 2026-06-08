-- books: 팔로우한 사람의 책장 읽기 허용
-- sentences_select_following / sessions_select_following 정책과 동일 패턴.
-- 비공개 계정 프라이버시는 앱 UI에서 followState == accepted 게이팅으로 처리한다.
create policy "books_select_following" on public.books
  for select using (
    exists (
      select 1 from public.follows
      where follower_id = auth.uid() and following_id = books.user_id
    )
  );
