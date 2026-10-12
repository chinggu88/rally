-- ============================================================
-- favorite_matches: 사용자별 관심 경기 (홈스크린 위젯 표시용)
--
-- 논리 키는 match_code다. bwf_matches.id와 bwf_live_matches.id는 서로 다른
-- 테이블의 PK라 라이브 전환 시 이어지지 않지만, match_code는 두 테이블에
-- 공통으로 존재해 경기 생애주기 전체를 관통한다.
-- (get-today-matches는 라이브 중인 경기를 match_code 기준으로 제외한다.)
--
-- 스코어/상태는 위젯이 네트워크 없이 그리기 위한 스냅샷이며 앱이 갱신한다.
-- ============================================================
create table if not exists public.favorite_matches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  match_code text not null,
  match_id bigint,

  -- 렌더 스냅샷
  tournament_name text,
  round_name text,
  event_name text,
  court_name text,
  team1_name text,
  team1_country text,
  team2_name text,
  team2_country text,
  score text,
  match_status text,
  match_time_kst text,
  is_live boolean not null default false,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, match_code)
);
comment on table public.favorite_matches is
  '사용자별 관심 경기. 논리 키 = match_code (bwf_matches / bwf_live_matches 공통). 스코어는 위젯 렌더용 스냅샷.';

create index if not exists favorite_matches_user_idx
  on public.favorite_matches (user_id, updated_at desc);

alter table public.favorite_matches enable row level security;

create policy "fav_match_select_own" on public.favorite_matches
  for select using (auth.uid() = user_id);
create policy "fav_match_insert_own" on public.favorite_matches
  for insert with check (auth.uid() = user_id);
-- favorite_players와 달리 UPDATE가 필요하다: 스코어 스냅샷을 계속 덮어쓴다.
create policy "fav_match_update_own" on public.favorite_matches
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "fav_match_delete_own" on public.favorite_matches
  for delete using (auth.uid() = user_id);

-- set_updated_at()은 20260622000000_profiles_and_favorite_players.sql에서 생성됨.
create trigger favorite_matches_set_updated_at
  before update on public.favorite_matches
  for each row execute function public.set_updated_at();
