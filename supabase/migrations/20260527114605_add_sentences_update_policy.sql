-- Allow users to edit their own collected sentence thoughts.
-- The app updates public.sentences.thought from the book detail screen.

drop policy if exists "sentences_update" on public.sentences;

create policy "sentences_update"
  on public.sentences
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
