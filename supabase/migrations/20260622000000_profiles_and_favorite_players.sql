-- ============================================================
-- profiles: 사용자 프로필 (닉네임/아바타/알림설정). id = auth.users.id
-- ============================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text,
  avatar_url text,
  notifications_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.profiles is '사용자 프로필 (닉네임/아바타/알림 설정). id = auth.users.id (on delete cascade).';

alter table public.profiles enable row level security;

create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- updated_at 자동 갱신
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- 가입 시 빈 profiles 행 자동 생성
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id) values (new.id) on conflict (id) do nothing;
  return new;
end;
$$;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- favorite_players: 사용자별 좋아하는 선수 (bwf_players.id 스냅샷)
-- ============================================================
create table if not exists public.favorite_players (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  player_id bigint not null,
  player_name text,
  country_code text,
  photo_url text,
  created_at timestamptz not null default now(),
  unique (user_id, player_id)
);
comment on table public.favorite_players is '사용자별 좋아하는 선수. player_id = bwf_players.id. 이름/국가/사진은 스냅샷.';

alter table public.favorite_players enable row level security;

create policy "fav_select_own" on public.favorite_players
  for select using (auth.uid() = user_id);
create policy "fav_insert_own" on public.favorite_players
  for insert with check (auth.uid() = user_id);
create policy "fav_delete_own" on public.favorite_players
  for delete using (auth.uid() = user_id);
