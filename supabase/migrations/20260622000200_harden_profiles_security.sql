-- 마이페이지 신규 객체 보안 강화 (Supabase security advisor 대응)

-- 1) set_updated_at: 고정 search_path (function_search_path_mutable 경고 해소)
alter function public.set_updated_at() set search_path = '';

-- 2) handle_new_user: 트리거 전용 함수 — RPC로 직접 호출되지 않도록 EXECUTE 회수
revoke execute on function public.handle_new_user() from anon, authenticated, public;

-- 3) avatars 버킷: public 버킷은 공개 URL(/object/public/...)로 접근하므로
--    storage.objects SELECT 정책이 불필요. 광범위 SELECT는 파일 목록 노출 위험이
--    있어 제거한다 (public_bucket_allows_listing 경고 해소).
drop policy if exists "avatars_read" on storage.objects;
