-- 다른 독자 화면용: global_book_sentences 뷰에 thought(원 수집자 생각) 노출
-- 주의: create or replace view 는 기존 컬럼 순서를 유지하고 신규 컬럼은 끝에만 추가 가능.
create or replace view public.global_book_sentences as
select
  s.id as sentence_id,
  s.content,
  s.page_number,
  s.created_at,
  s.user_id,
  p.username,
  p.display_name,
  p.avatar_url,
  gb.id as global_book_id,
  gb.isbn13,
  gb.title as book_title,
  gb.author as book_author,
  gb.cover_url as book_cover_url,
  count(sl.sentence_id) as like_count,
  s.thought
from public.sentences s
join public.global_books gb on s.global_book_id = gb.id
join public.profiles p on s.user_id = p.id
left join public.sentence_likes sl on sl.sentence_id = s.id
group by s.id, gb.id, p.id;

alter view public.global_book_sentences set (security_invoker = true);
