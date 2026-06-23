-- reading_presence에 '지금 읽고 있는 책' 정보를 추가한다.
-- 세션 시작 시 어떤 책으로 시작했는지 기록해, 친구들의 라이브 독서 시트에서
-- 더미 데이터 대신 실제 책 제목/저자/표지를 보여주기 위함.
-- 기존 행과의 호환을 위해 모두 nullable. 읽기 권한은 기존 select 정책을 그대로 따른다.

alter table public.reading_presence
  add column if not exists book_title      text,
  add column if not exists book_author     text,
  add column if not exists book_cover_url  text;
