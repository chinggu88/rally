-- ============================================================
-- 커뮤니티 알림 트리거 (TASK-008 / 6of6)
--
-- 내 글에 댓글 / 내 댓글에 답글이 달리면 푸시를 보낸다.
-- notifications INSERT → 기존 DB Webhook → send-push Edge Function → FCM.
-- 별도 인프라 없이 기존 파이프라인을 그대로 탄다.
--
-- 선행: 20260823000200
--
-- 알림 수신 여부는 profiles.notifications_enabled 를 존중한다.
-- (실제 발송 차단은 device_tokens 유무로도 이루어지지만, 불필요한 행을
--  쌓지 않도록 여기서 먼저 거른다 — ranking_notifier 배치와 같은 방식.)
-- ============================================================

create or replace function public.community_notify_on_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target_user  uuid;
  v_post_title   text;
  v_actor_name   text;
  v_type         text;
  v_title        text;
begin
  if new.status <> 'visible' then
    return null;
  end if;

  select title into v_post_title
    from public.community_posts
   where id = new.post_id;

  select coalesce(nullif(btrim(nickname), ''), '누군가') into v_actor_name
    from public.profiles
   where id = new.author_id;

  if new.parent_id is null then
    -- 최상위 댓글 → 게시글 작성자에게
    select author_id into v_target_user
      from public.community_posts
     where id = new.post_id;
    v_type  := 'community_comment';
    v_title := '💬 내 글에 댓글이 달렸어요';
  else
    -- 대댓글 → 부모 댓글 작성자에게
    select author_id into v_target_user
      from public.community_comments
     where id = new.parent_id;
    v_type  := 'community_reply';
    v_title := '💬 내 댓글에 답글이 달렸어요';
  end if;

  -- 대상이 없거나(탈퇴로 author_id NULL) 본인이 본인에게 단 경우는 제외.
  if v_target_user is null or v_target_user = new.author_id then
    return null;
  end if;

  -- 알림 끔 상태면 보내지 않는다.
  if not exists (
    select 1 from public.profiles
     where id = v_target_user and notifications_enabled
  ) then
    return null;
  end if;

  -- 서로 차단한 사이면 보내지 않는다.
  -- community_is_blocked() 는 auth.uid() 기준이라 트리거 문맥에서 쓸 수 없으므로
  -- 여기서는 두 사용자 id 로 직접 확인한다.
  if exists (
    select 1 from public.user_blocks b
     where (b.blocker_id = v_target_user and b.blocked_id = new.author_id)
        or (b.blocker_id = new.author_id and b.blocked_id = v_target_user)
  ) then
    return null;
  end if;

  insert into public.notifications (user_id, title, body, data, status)
  values (
    v_target_user,
    v_title,
    format('%s: %s', v_actor_name, left(new.content, 60)),
    jsonb_build_object(
      'type',       v_type,
      'post_id',    new.post_id,
      'comment_id', new.id,
      'post_title', coalesce(v_post_title, '')
    ),
    'pending'
  );

  return null;
end
$$;

drop trigger if exists community_comments_notify on public.community_comments;
create trigger community_comments_notify
  after insert on public.community_comments
  for each row execute function public.community_notify_on_comment();

-- ============================================================
-- 적용 후 확인 사항 (수동)
--
-- 1. Supabase Dashboard → Database → Webhooks 에서 notifications INSERT
--    웹훅이 활성 상태인지 확인. 이 트리거는 행만 넣고 발송은 웹훅이 한다.
-- 2. 운영자 계정을 app_admins 에 등록해야 신고 알림을 받는다:
--      insert into public.app_admins (user_id) values ('<운영자 uuid>');
-- 3. 금칙어 초기 목록을 community_banned_words 에 넣는다:
--      insert into public.community_banned_words (word) values ('...');
--    norm 컬럼은 generated 이므로 word 만 넣으면 된다.
-- 4. Flutter 의 notification_service.dart 는 data['type'] 라우팅이
--    아직 TODO(253행)다. community_comment / community_reply /
--    community_report 처리는 TASK-009 이후에 붙인다.
-- ============================================================
