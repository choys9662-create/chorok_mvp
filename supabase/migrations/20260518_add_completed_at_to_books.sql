-- chorok_app: public.books 테이블에 completed_at 컬럼 추가
--
-- 배경:
--   앱 Book 모델과 SQLite v5에는 completed_at 컬럼이 있어 완독 시각을 저장하지만,
--   Supabase 스키마에는 해당 컬럼이 없어 supabase_book_repository.saveFromBook이
--   upsert를 시도하면 "Could not find the 'completed_at' column" 에러로
--   전체 upsert가 실패한다. 결과적으로 웹 빌드에서 '읽었어요'를 눌러도 status
--   변경이 영속화되지 않는다.
--
-- 적용:
--   Supabase 대시보드 → SQL Editor → 이 파일 내용 실행
--   (또는 supabase CLI: supabase db push)

alter table public.books add column if not exists completed_at timestamptz;
