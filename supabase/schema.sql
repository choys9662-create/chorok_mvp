-- ================================================================
-- 초록 (Chorok) — Supabase DB 스키마
-- Supabase Dashboard > SQL Editor 에서 전체 실행
-- ================================================================

-- ── 확장 ──────────────────────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ── 1. profiles ───────────────────────────────────────────────────
-- auth.users 와 1:1 연결되는 공개 프로필
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  username      text unique not null,
  display_name  text,
  avatar_url    text,
  bio           text,
  created_at    timestamptz default now() not null
);

-- 신규 유저 가입 시 자동으로 profiles 행 생성
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ── 2. books ──────────────────────────────────────────────────────
create table if not exists public.books (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  title         text not null,
  author        text not null,
  publisher     text,
  published_year int,
  cover_url     text,
  total_pages   int,
  current_page  int default 0,
  status        text default 'reading' check (status in ('reading', 'completed', 'paused')),
  created_at    timestamptz default now() not null
);

-- ── 3. reading_sessions ───────────────────────────────────────────
create table if not exists public.reading_sessions (
  id              uuid primary key default uuid_generate_v4(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  book_id         uuid references public.books(id) on delete set null,
  duration_seconds int not null default 0,
  sentence_count  int not null default 0,
  score           int,
  started_at      timestamptz default now() not null,
  ended_at        timestamptz
);

-- ── 4. sentences ──────────────────────────────────────────────────
create table if not exists public.sentences (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  book_id     uuid references public.books(id) on delete set null,
  session_id  uuid references public.reading_sessions(id) on delete set null,
  content     text not null,
  page_number int,
  created_at  timestamptz default now() not null
);

-- ── 5. follows ────────────────────────────────────────────────────
create table if not exists public.follows (
  follower_id   uuid not null references public.profiles(id) on delete cascade,
  following_id  uuid not null references public.profiles(id) on delete cascade,
  created_at    timestamptz default now() not null,
  primary key (follower_id, following_id)
);

-- ── 6. sentence_likes ─────────────────────────────────────────────
create table if not exists public.sentence_likes (
  user_id     uuid not null references public.profiles(id) on delete cascade,
  sentence_id uuid not null references public.sentences(id) on delete cascade,
  created_at  timestamptz default now() not null,
  primary key (user_id, sentence_id)
);

-- ================================================================
-- Row Level Security (RLS) — 본인 데이터만 읽기/쓰기
-- ================================================================

alter table public.profiles        enable row level security;
alter table public.books           enable row level security;
alter table public.reading_sessions enable row level security;
alter table public.sentences       enable row level security;
alter table public.follows         enable row level security;
alter table public.sentence_likes  enable row level security;

-- profiles: 누구나 읽기, 본인만 수정
create policy "profiles_select" on public.profiles for select using (true);
create policy "profiles_update" on public.profiles for update using (auth.uid() = id);

-- books: 본인만 CRUD
create policy "books_select" on public.books for select using (auth.uid() = user_id);
create policy "books_insert" on public.books for insert with check (auth.uid() = user_id);
create policy "books_update" on public.books for update using (auth.uid() = user_id);
create policy "books_delete" on public.books for delete using (auth.uid() = user_id);

-- reading_sessions: 본인만 CRUD
create policy "sessions_select" on public.reading_sessions for select using (auth.uid() = user_id);
create policy "sessions_insert" on public.reading_sessions for insert with check (auth.uid() = user_id);
create policy "sessions_update" on public.reading_sessions for update using (auth.uid() = user_id);

-- sentences: 본인 것은 CRUD, 팔로우한 사람 것은 읽기
create policy "sentences_select_own" on public.sentences for select using (auth.uid() = user_id);
create policy "sentences_select_following" on public.sentences for select using (
  exists (select 1 from public.follows where follower_id = auth.uid() and following_id = sentences.user_id)
);
create policy "sentences_insert" on public.sentences for insert with check (auth.uid() = user_id);
create policy "sentences_delete" on public.sentences for delete using (auth.uid() = user_id);

-- follows: 누구나 읽기, 본인만 팔로우/언팔
create policy "follows_select" on public.follows for select using (true);
create policy "follows_insert" on public.follows for insert with check (auth.uid() = follower_id);
create policy "follows_delete" on public.follows for delete using (auth.uid() = follower_id);

-- sentence_likes: 본인만 CRUD, 집계는 누구나
create policy "likes_select" on public.sentence_likes for select using (true);
create policy "likes_insert" on public.sentence_likes for insert with check (auth.uid() = user_id);
create policy "likes_delete" on public.sentence_likes for delete using (auth.uid() = user_id);

-- ================================================================
-- 유용한 뷰 (선택 사항)
-- ================================================================

-- 문장 + 좋아요 수 + 유저 정보
create or replace view public.sentences_with_stats as
select
  s.*,
  p.username,
  p.display_name,
  p.avatar_url,
  count(sl.sentence_id) as like_count
from public.sentences s
join public.profiles p on s.user_id = p.id
left join public.sentence_likes sl on sl.sentence_id = s.id
group by s.id, p.id;
