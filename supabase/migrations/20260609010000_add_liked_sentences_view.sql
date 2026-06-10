-- 좋아요한 문장 조회는 sentence_likes.user_id 기준으로 분리한다.
-- sentences.user_id는 문장 작성자이므로, 내 기록 목록과 섞어 쓰지 않는다.

create index if not exists sentence_likes_user_created_at_idx
  on public.sentence_likes (user_id, created_at desc);

create index if not exists sentence_likes_sentence_id_idx
  on public.sentence_likes (sentence_id);

create or replace view public.liked_sentences_with_books as
select
  sl.user_id as liked_by_user_id,
  sl.created_at as liked_at,
  s.id as sentence_id,
  s.user_id as sentence_owner_id,
  s.content,
  s.thought,
  coalesce(gb.title, b.title) as book_title,
  coalesce(gb.author, b.author) as book_author
from public.sentence_likes sl
join public.sentences s on s.id = sl.sentence_id
left join public.books b on b.id = s.book_id
left join public.global_books gb on gb.id = s.global_book_id;
