-- ============================================================
-- 커뮤니티 이미지 스토리지 (TASK-008 / 5of6)
--
-- 경로 규칙: community/{user_id}/{draft_id}/{index}_{ts}.jpg
--   · draft_id 는 작성 화면 진입 시 클라이언트가 만드는 UUID.
--     INSERT 전에는 post_id 가 없으므로 대신 쓴다.
--   · 첫 세그먼트를 user_id 로 유지해야 기존 avatars RLS 패턴
--     (20260622000100)을 그대로 재사용할 수 있다.
--   · 한 글의 이미지가 한 폴더에 모여 일괄 정리가 쉽다.
--
-- avatars 버킷과 섞지 않는 이유: 용량 관리와 정리 정책이 엉킨다.
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'community',
  'community',
  true,
  5242880,  -- 5MB
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- 본인 폴더에만 쓰기.
drop policy if exists "community_img_insert_own" on storage.objects;
create policy "community_img_insert_own"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'community'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "community_img_update_own" on storage.objects;
create policy "community_img_update_own"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'community'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- 글 수정 시 교체된 옛 이미지 제거, INSERT 실패 시 방금 올린 파일 롤백에 쓰인다.
drop policy if exists "community_img_delete_own" on storage.objects;
create policy "community_img_delete_own"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'community'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- SELECT 정책은 만들지 않는다.
--   public 버킷이므로 이미지는 /object/public/community/... 경로로 읽힌다.
--   광범위한 SELECT 정책은 파일 목록 노출(public_bucket_allows_listing) 경고를
--   유발한다. 20260622000200_harden_profiles_security.sql 에서 avatars_read 를
--   제거한 것과 동일한 판단이다.
