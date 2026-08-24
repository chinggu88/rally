-- ============================================================
-- 커뮤니티 모더레이션 프리미티브 (TASK-008 / 1of6)
--
-- 차단 · 운영자 · 약관동의 · 금칙어와 그 헬퍼 함수들.
-- community_posts 의 SELECT 정책이 차단 헬퍼를, INSERT 정책이 약관동의
-- 헬퍼를 참조하므로 코어 테이블(000200)보다 반드시 먼저 적용한다.
--
-- 주의: public 스키마에 CREATE TABLE 하면 rls_auto_enable() event trigger가
--       RLS를 자동으로 켠다. 하지만 GRANT는 자동으로 빠지지 않는다.
--       Supabase default privileges가 anon/authenticated 에게 GRANT ALL 을
--       붙이므로, 각 테이블마다 revoke 후 필요한 권한만 다시 부여한다.
-- ============================================================

-- ── 1) profiles 확장 ─────────────────────────────────────────
-- 사용자 정지(Apple 1.2 "abusive user ejection") 만료 시각.
alter table public.profiles
  add column if not exists community_banned_until timestamptz;

comment on column public.profiles.community_banned_until is
  '커뮤니티 이용 정지 만료 시각. now()보다 미래면 글/댓글 작성 불가.';

-- 닉네임 정규화 컬럼. 대소문자/앞뒤공백 차이로 인한 사칭을 막는다.
alter table public.profiles
  add column if not exists nickname_norm text
  generated always as (lower(btrim(nickname))) stored;

comment on column public.profiles.nickname_norm is
  '닉네임 정규화값(소문자+trim). 부분 유니크 인덱스의 대상.';

-- ── 1-1) 유니크 인덱스 적용 전 기존 중복 정리 ────────────────
-- 적용 시점 기준 정규화 중복이 1쌍 존재한다(프로필 15건 중 닉네임 보유 4건).
-- 가장 먼저 가입한 계정이 원래 닉네임을 유지하고, 이후 계정만 접미사를 붙인다.
-- 되돌리려면 해당 사용자가 프로필 편집에서 다시 변경하면 된다.
do $$
declare
  r record;
  n integer := 0;
begin
  for r in
    select id, nickname
    from (
      select id, nickname,
             row_number() over (
               partition by lower(btrim(nickname))
               order by created_at, id
             ) as rn
      from public.profiles
      where nickname is not null and btrim(nickname) <> ''
    ) t
    where t.rn > 1
  loop
    -- 접미사가 '_' + 4자라, 아래 길이 CHECK(2~12자)를 넘지 않도록 base를 7자로 자른다.
    update public.profiles
       set nickname = left(btrim(r.nickname), 7)
                      || '_' || substr(replace(r.id::text, '-', ''), 1, 4)
     where id = r.id;
    n := n + 1;
    raise notice '중복 닉네임 정리: [%] -> [%]',
      r.nickname,
      left(btrim(r.nickname), 7) || '_' || substr(replace(r.id::text, '-', ''), 1, 4);
  end loop;
  if n > 0 then
    raise notice '총 %건의 닉네임을 변경했습니다.', n;
  end if;
end
$$;

-- 부분 유니크 인덱스: 닉네임 미설정(NULL) 사용자들은 그대로 공존한다.
-- 기존 사용자를 강제 이주시키지 않기 위한 선택.
create unique index if not exists profiles_nickname_norm_key
  on public.profiles (nickname_norm)
  where nickname_norm is not null and nickname_norm <> '';

-- 닉네임 길이 규칙(2~12자)을 서버에도 강제한다.
--
-- 기획서 §5-5 가 정한 규칙인데 유니크 인덱스와 금칙어 트리거만으로는 길이를
-- 막지 못한다. 클라이언트 두 지점(온보딩 시트 / profile_edit)에만 검증이 있으면
-- 제3의 경로(직접 API 호출 등)로 1자·50자 닉네임이 들어온다.
--
-- NULL 은 허용한다 — handle_new_user() 가 가입 시 닉네임 없는 행을 만들고,
-- 커뮤니티에 글을 쓸 때 비로소 온보딩 시트가 채운다.
do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conrelid = 'public.profiles'::regclass
       and conname = 'profiles_nickname_len_ck'
  ) then
    alter table public.profiles
      add constraint profiles_nickname_len_ck
      check (nickname is null or char_length(btrim(nickname)) between 2 and 12);
  end if;
end
$$;

-- ── 2) 차단 ──────────────────────────────────────────────────
create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_not_self check (blocker_id <> blocked_id)
);
comment on table public.user_blocks is
  '사용자 차단. 양방향으로 해석한다(내가 차단한 쪽/나를 차단한 쪽 모두 숨김).';

-- 역방향 조회(나를 차단한 사람 찾기)용.
create index if not exists user_blocks_blocked_idx
  on public.user_blocks (blocked_id);

alter table public.user_blocks enable row level security;

revoke all on public.user_blocks from anon, authenticated;
grant select, insert, delete on public.user_blocks to authenticated;

-- 차단 사실은 차단당한 쪽에 노출하지 않는다 → 본인이 건 차단만 조회 가능.
drop policy if exists ub_select_own on public.user_blocks;
create policy ub_select_own on public.user_blocks
  for select to authenticated
  using (blocker_id = (select auth.uid()));

drop policy if exists ub_insert_own on public.user_blocks;
create policy ub_insert_own on public.user_blocks
  for insert to authenticated
  with check (blocker_id = (select auth.uid()));

drop policy if exists ub_delete_own on public.user_blocks;
create policy ub_delete_own on public.user_blocks
  for delete to authenticated
  using (blocker_id = (select auth.uid()));

-- ── 3) 운영자 ────────────────────────────────────────────────
create table if not exists public.app_admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
comment on table public.app_admins is
  '운영자 목록. RLS ON + 정책 0개 = 클라이언트 접근 전면 차단. is_app_admin()으로만 판정.';

alter table public.app_admins enable row level security;
revoke all on public.app_admins from anon, authenticated;
-- 정책을 만들지 않는다. 의도적이다.

-- ── 4) 약관 동의 ─────────────────────────────────────────────
create table if not exists public.user_agreements (
  user_id   uuid not null references auth.users(id) on delete cascade,
  doc       text not null check (doc in ('community_eula', 'privacy')),
  version   text not null,
  agreed_at timestamptz not null default now(),
  primary key (user_id, doc)
);
comment on table public.user_agreements is
  '약관 동의 기록. 버전이 바뀌면 재동의가 필요하다(community_eula_version() 참조).';

alter table public.user_agreements enable row level security;

revoke all on public.user_agreements from anon, authenticated;
-- 재동의 시 version 갱신이 필요하므로 update 도 허용(철회는 계정 탈퇴로).
grant select, insert, update on public.user_agreements to authenticated;

drop policy if exists ua_select_own on public.user_agreements;
create policy ua_select_own on public.user_agreements
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists ua_insert_own on public.user_agreements;
create policy ua_insert_own on public.user_agreements
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists ua_update_own on public.user_agreements;
create policy ua_update_own on public.user_agreements
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- ── 5) 금칙어 ────────────────────────────────────────────────
-- norm: 공백/특수문자를 모두 제거한 비교용 값. "ㅅ ㅂ", "씨-발" 류 회피를 막는다.
create table if not exists public.community_banned_words (
  id         bigint generated always as identity primary key,
  word       text not null,
  norm       text generated always as (
               regexp_replace(lower(word), '[^0-9a-z가-힣]', '', 'g')
             ) stored,
  severity   text not null default 'block' check (severity in ('block', 'warn')),
  created_at timestamptz not null default now()
);
comment on table public.community_banned_words is
  '금칙어. norm은 영숫자/한글만 남긴 정규화값이며 서버 트리거와 클라 사전검증이 같은 규칙을 쓴다.';

create unique index if not exists community_banned_words_norm_key
  on public.community_banned_words (norm);

alter table public.community_banned_words enable row level security;

revoke all on public.community_banned_words from anon, authenticated;
-- 클라이언트가 왕복 없이 즉시 피드백을 주려면 목록을 읽어야 한다.
-- 회피 힌트를 주는 트레이드오프가 있으나, 서버 트리거가 최종 권위이므로 수용한다.
grant select on public.community_banned_words to authenticated;

drop policy if exists cbw_select on public.community_banned_words;
create policy cbw_select on public.community_banned_words
  for select to authenticated
  using (true);

-- ── 6) 헬퍼 함수 ─────────────────────────────────────────────
-- 전부 security definer 다. 이유는 함수별 주석 참조.

-- 양방향 차단 판정.
--
-- security definer가 반드시 필요하다: 정책 안에서 user_blocks 를 인라인
-- 서브쿼리로 읽으면 ub_select_own(blocker_id = me)이 역방향 행(blocked_id = me)을
-- 걸러내 "나를 차단한 쪽" 필터가 조용히 무력화된다.
create or replace function public.community_is_blocked(p_other uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select p_other is not null
     and auth.uid() is not null
     and exists (
       select 1
       from public.user_blocks b
       where (b.blocker_id = auth.uid() and b.blocked_id = p_other)
          or (b.blocker_id = p_other     and b.blocked_id = auth.uid())
     );
$$;

comment on function public.community_is_blocked(uuid) is
  '나와 상대가 어느 방향으로든 차단 관계인지. RLS 정책에서 사용하므로 security definer 필수.';

-- 현재 유효한 이용규칙 버전.
--
-- 클라이언트 상수와 반드시 같은 값이어야 한다. 어긋나면 전 사용자가 글을 못 쓴다.
-- 버전을 올릴 때는 DB를 먼저 배포하고 앱을 나중에 올린다.
create or replace function public.community_eula_version()
returns text
language sql
immutable
as $$
  select '2026-08-23'::text;
$$;

-- 작성 자격: 현재 버전 약관에 동의했고, 이용 정지 상태가 아닐 것.
create or replace function public.community_can_write()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null
     and exists (
       select 1
       from public.user_agreements ua
       where ua.user_id = auth.uid()
         and ua.doc = 'community_eula'
         and ua.version = public.community_eula_version()
     )
     and not exists (
       select 1
       from public.profiles p
       where p.id = auth.uid()
         and p.community_banned_until > now()
     );
$$;

comment on function public.community_can_write() is
  '약관 동의 + 정지 아님. profiles/user_agreements RLS를 우회해야 하므로 security definer.';

-- 운영자 판정. app_admins 는 정책이 0개이므로 definer 로만 읽을 수 있다.
create or replace function public.is_app_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select auth.uid() is not null
     and exists (select 1 from public.app_admins a where a.user_id = auth.uid());
$$;

-- 클라이언트가 온보딩 시트에서 자기 자격을 조회할 수 있어야 한다.
grant execute on function public.community_is_blocked(uuid) to anon, authenticated;
grant execute on function public.community_eula_version()  to anon, authenticated;
grant execute on function public.community_can_write()     to authenticated;
grant execute on function public.is_app_admin()            to authenticated;
