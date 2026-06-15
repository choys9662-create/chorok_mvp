-- chorok_app: 책 장르 기반 취향 분석을 위한 books.genre 컬럼

alter table public.books add column if not exists genre text;
