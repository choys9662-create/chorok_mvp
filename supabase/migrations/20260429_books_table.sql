-- chorok_app: public.books 테이블에 웹 빌드 동기화용 컬럼 추가
--
-- 배경:
--   기존 schema.sql에 public.books가 이미 존재하지만, 앱 Book 모델과
--   다음 컬럼들이 빠져 있다 — book_id(앱 내부 ID), isbn, total_reading_hours,
--   saved_sentences, updated_at. 또한 status check에 'wantToRead'가 없다.
--
-- 이 마이그레이션은:
--   - 누락된 컬럼들을 ALTER TABLE로 추가
--   - status check를 'wantToRead' 포함하도록 확장
--   - (user_id, book_id) 유니크 인덱스 생성 (upsert 키로 사용)
--
-- 적용:
--   Supabase 대시보드 → SQL Editor → 이 파일 내용 붙여넣고 실행
--   (또는 supabase CLI: supabase db push)

-- ─── 컬럼 추가 (멱등) ──────────────────────────────────────────────────────
alter table public.books add column if not exists book_id text;
alter table public.books add column if not exists isbn text;
alter table public.books add column if not exists total_reading_hours numeric not null default 0;
alter table public.books add column if not exists saved_sentences text[] not null default array[]::text[];
alter table public.books add column if not exists updated_at timestamptz not null default now();

-- 기존 행 보정 — book_id가 비어 있으면 행의 uuid를 텍스트로 사용
update public.books set book_id = id::text where book_id is null;
alter table public.books alter column book_id set not null;

-- ─── (user_id, book_id) 유니크 — upsert 키 ────────────────────────────────
create unique index if not exists books_user_id_book_id_key
  on public.books (user_id, book_id);

-- 정렬 인덱스
create index if not exists books_user_id_updated_at_idx
  on public.books (user_id, updated_at desc);

-- ─── status check 확장 ─ 'wantToRead' 추가 ───────────────────────────────
alter table public.books drop constraint if exists books_status_check;
alter table public.books add constraint books_status_check
  check (status in ('reading', 'completed', 'wantToRead', 'paused'));

-- 참고: RLS 정책은 기존 schema.sql의 books_select/insert/update/delete가
-- 이미 적용되어 있으므로 추가 작업 불필요.
