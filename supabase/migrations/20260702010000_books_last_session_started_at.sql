-- chorok_app: '읽고 있는 책' 정렬용 — 라이브 포레스트(독서 세션) 시작 시각 기록
--
-- 배경:
--   홈 화면 '읽고 있는 책' 카드 순서를 "가장 최근에 라이브 포레스트를 켠 순서 →
--   추가한 순서"로 바꾸기 위해, 세션 시작 시각을 책 단위로 별도 기록한다.
--   기존 updated_at은 페이지 갱신·문장 추가 등에도 갱신되어 이 용도로 쓸 수 없다.

alter table public.books
  add column if not exists last_session_started_at timestamptz;
