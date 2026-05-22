-- chorok_app: 테스트 앱 독서 기록 저장/표시용 세션 컬럼 추가
--
-- client_session_id: 앱에서 자동 저장과 페이지 저장을 같은 세션으로 upsert
-- pages_read: 캘린더/서재 디자인에서 "N쪽 읽음" 표시
-- exit_*: 세션 리캡/분석에서 집중도 데이터 재사용

alter table public.reading_sessions
  add column if not exists client_session_id text,
  add column if not exists pages_read int not null default 0,
  add column if not exists exit_count int not null default 0,
  add column if not exists exit_duration_seconds int not null default 0;

create unique index if not exists reading_sessions_user_client_session_key
  on public.reading_sessions (user_id, client_session_id);
