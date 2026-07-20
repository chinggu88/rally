-- claim_device_token: FCM 디바이스 토큰의 소유권을 현재 로그인 유저로 이관하는 RPC.
--
-- 배경: device_tokens.fcm_token은 UNIQUE인데, 같은 기기를 다른 계정으로 쓰다가
-- 새 계정으로 로그인하면 토큰 행이 이전 계정 소유로 남는다. 클라이언트는 RLS
-- 때문에 남의 행을 지우거나 수정할 수 없어 23505로 저장이 조용히 스킵됐고,
-- 그 결과 푸시가 이전 계정으로만 발송됐다.
--
-- FCM 토큰은 물리 기기 1대를 식별하므로 "지금 이 기기에 로그인한 유저"가
-- 소유하는 것이 맞다. SECURITY DEFINER로 타 유저 소유 행을 정리하고 upsert한다.
-- (FCM 토큰은 추측 불가능한 랜덤 문자열이라 타인 토큰 탈취 우려는 없음)

create or replace function public.claim_device_token(
  p_fcm_token text,
  p_platform text,
  p_device_name text default null,
  p_app_version text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not authenticated';
  end if;

  -- 같은 토큰이 다른 유저 소유로 남아있으면 제거 (기기 소유권 이관)
  delete from public.device_tokens
  where fcm_token = p_fcm_token
    and user_id <> v_user;

  insert into public.device_tokens
    (user_id, fcm_token, platform, device_name, app_version, last_seen_at, updated_at)
  values
    (v_user, p_fcm_token, p_platform, p_device_name, p_app_version, now(), now())
  on conflict (fcm_token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        device_name = excluded.device_name,
        app_version = excluded.app_version,
        last_seen_at = now(),
        updated_at = now();
end;
$$;

revoke execute on function public.claim_device_token(text, text, text, text) from public, anon;
grant execute on function public.claim_device_token(text, text, text, text) to authenticated;
