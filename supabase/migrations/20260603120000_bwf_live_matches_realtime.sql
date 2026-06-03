-- bwf_live_matches 테이블의 Realtime publication 활성화 + 클라이언트 SELECT 허용.
--
-- 홈(뉴스) 화면의 라이브 매치 캐러셀이 Supabase Realtime으로 스코어 변경을 즉시
-- 받기 위한 설정. Edge Function은 service_role로 RLS를 우회하지만, Flutter 앱은
-- anon 키로 직접 채널을 구독하므로 anon/authenticated에 SELECT 권한이 있어야
-- Realtime이 row를 push 한다.
--
-- 1) Realtime publication 등록
-- 2) UPDATE OLD row 전체 수신을 위한 REPLICA IDENTITY FULL
-- 3) RLS 활성화 + anon/authenticated SELECT 정책

-- ── 1) publication 등록 ──────────────────────────────────────
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'bwf_live_matches'
  ) then
    alter publication supabase_realtime add table public.bwf_live_matches;
  end if;
end
$$;

-- ── 2) REPLICA IDENTITY FULL ───────────────────────────────
alter table public.bwf_live_matches replica identity full;

-- ── 3) RLS + SELECT 정책 ────────────────────────────────────
alter table public.bwf_live_matches enable row level security;

-- 이미 같은 이름 정책이 있으면 재생성 (idempotent)
drop policy if exists "bwf_live_matches_anon_select"
  on public.bwf_live_matches;

create policy "bwf_live_matches_anon_select"
  on public.bwf_live_matches
  for select
  to anon, authenticated
  using (true);
