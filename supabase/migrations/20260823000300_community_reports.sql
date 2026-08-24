-- ============================================================
-- 커뮤니티 신고 · 자동 숨김 · 금칙어 (TASK-008 / 3of6)
--
-- Apple App Review Guideline 1.2 대응의 핵심 파일.
-- "24시간 내 조치"는 사람이 대기하는 방식이 아니라 3중 구조로 담보한다.
--   ① 사유별 차등 자동 숨김 (사람 개입 없이 즉시)
--   ② 신고 1건부터 운영자에게 FCM 푸시 (기존 notifications → send-push 재사용)
--   ③ 앱 내 관리자 조치 (별도 관리자 화면 없이 폰에서 완결)
--
-- 선행: 20260823000200
-- ============================================================

-- ── 1) 신고 테이블 ───────────────────────────────────────────
create table if not exists public.community_reports (
  id              uuid primary key default gen_random_uuid(),
  reporter_id     uuid not null references auth.users(id) on delete cascade,
  target_type     text not null check (target_type in ('post', 'comment', 'user')),
  post_id         uuid references public.community_posts(id)    on delete cascade,
  comment_id      uuid references public.community_comments(id) on delete cascade,
  target_user_id  uuid references auth.users(id) on delete cascade,
  reason          text not null
                  check (reason in ('spam', 'abuse', 'sexual', 'illegal', 'privacy', 'other')),
  detail          text check (char_length(detail) <= 500),
  status          text not null default 'pending'
                  check (status in ('pending', 'actioned', 'rejected')),
  resolved_at     timestamptz,
  resolved_by     uuid references auth.users(id) on delete set null,
  resolution_note text,
  created_at      timestamptz not null default now(),
  -- 대상은 정확히 하나여야 한다.
  constraint community_reports_target_ck check (
       (target_type = 'post'    and post_id is not null        and comment_id is null)
    or (target_type = 'comment' and comment_id is not null     and post_id is null)
    or (target_type = 'user'    and target_user_id is not null and post_id is null and comment_id is null)
  )
);
comment on table public.community_reports is
  '커뮤니티 신고. target_type=user 는 라이브 채팅 신고에도 재사용한다(TASK-014).';

-- 같은 사용자가 같은 대상을 반복 신고해 임계값을 혼자 채우는 것을 막는다.
create unique index if not exists community_reports_uq_post
  on public.community_reports (reporter_id, post_id)    where post_id is not null;
create unique index if not exists community_reports_uq_comment
  on public.community_reports (reporter_id, comment_id) where comment_id is not null;
create unique index if not exists community_reports_uq_user
  on public.community_reports (reporter_id, target_user_id) where target_type = 'user';

create index if not exists community_reports_pending_idx
  on public.community_reports (created_at) where status = 'pending';

alter table public.community_reports enable row level security;

revoke all on public.community_reports from anon, authenticated;
grant select, insert on public.community_reports to authenticated;
grant update (status, resolved_at, resolved_by, resolution_note)
  on public.community_reports to authenticated;   -- 정책으로 운영자만 통과

drop policy if exists cr_select_own on public.community_reports;
create policy cr_select_own on public.community_reports
  for select to authenticated
  using (reporter_id = (select auth.uid()) or public.is_app_admin());

drop policy if exists cr_insert_own on public.community_reports;
create policy cr_insert_own on public.community_reports
  for insert to authenticated
  with check (reporter_id = (select auth.uid()) and status = 'pending');

drop policy if exists cr_update_admin on public.community_reports;
create policy cr_update_admin on public.community_reports
  for update to authenticated
  using (public.is_app_admin())
  with check (public.is_app_admin());

-- ── 2) 자동 숨김 + 운영자 푸시 ───────────────────────────────
--
-- 사유별 차등 임계값 (기획서 §6-3 ①, 확정 D-4)
--   sexual / illegal → 1건    고위험. 밤새 방치되면 App Store 리스크이자 실제 피해
--   그 외            → 3건    담합·오탐 저항
--
-- 1건 임계값은 악용 소지가 있지만 자동 숨김은 되돌릴 수 있고 운영자에게
-- 즉시 푸시가 가므로 오탐은 몇 분 단위로 복구된다. 반대 방향의 실수
-- (실제 음란물을 몇 시간 노출)는 복구가 불가능하다. 비대칭이 명확하다.
create or replace function public.community_report_threshold(p_reason text)
returns integer
language sql
immutable
as $$
  select case when p_reason in ('sexual', 'illegal') then 1 else 3 end;
$$;

create or replace function public.community_on_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count     integer;
  v_threshold integer := public.community_report_threshold(new.reason);
  v_kind      text;
  v_target    uuid;
begin
  if new.target_type = 'post' then
    update public.community_posts
       set report_count = report_count + 1
     where id = new.post_id
     returning report_count, author_id into v_count, v_target;

    if v_count >= v_threshold then
      update public.community_posts
         set status = 'hidden',
             hidden_reason = 'auto_report_threshold:' || new.reason
       where id = new.post_id
         and status = 'visible';
    end if;
    v_kind := '게시글';

  elsif new.target_type = 'comment' then
    update public.community_comments
       set report_count = report_count + 1
     where id = new.comment_id
     returning report_count, author_id into v_count, v_target;

    if v_count >= v_threshold then
      update public.community_comments
         set status = 'hidden'
       where id = new.comment_id
         and status = 'visible';
    end if;
    v_kind := '댓글';

  else
    -- target_type = 'user' (라이브 채팅 신고 포함). 자동 조치 없음, 알림만.
    select count(*)::int into v_count
      from public.community_reports
     where target_type = 'user' and target_user_id = new.target_user_id;
    v_target := new.target_user_id;
    v_kind := '사용자';
  end if;

  -- 운영자 전원에게 알림 INSERT.
  -- notifications INSERT → 기존 DB Webhook → send-push Edge Function → FCM.
  -- 추가 인프라 0으로 운영자 폰에 수 초 내 도달한다. 24시간 SLA 의 실질적 담보.
  insert into public.notifications (user_id, title, body, data, status)
  select a.user_id,
         '🚨 커뮤니티 신고 접수',
         format('%s 신고 (%s) · 누적 %s건', v_kind, new.reason, coalesce(v_count, 1)),
         jsonb_build_object(
           'type',        'community_report',
           'report_id',   new.id,
           'target_type', new.target_type,
           'post_id',     new.post_id,
           'comment_id',  new.comment_id,
           'target_user_id', v_target,
           'reason',      new.reason,
           'count',       coalesce(v_count, 1)
         ),
         'pending'
    from public.app_admins a;

  return null;
end
$$;

drop trigger if exists community_reports_on_insert on public.community_reports;
create trigger community_reports_on_insert
  after insert on public.community_reports
  for each row execute function public.community_on_report();

-- ── 3) 금칙어 서버 강제 ──────────────────────────────────────
--
-- 클라이언트가 같은 정규화 규칙으로 사전 검증해 즉시 피드백을 주지만,
-- 최종 권위는 이 트리거다. hint='banned_word' 로 던지므로 Flutter 에서
-- PostgrestException.hint 로 분기해 한국어 스낵바를 띄운다.
create or replace function public.community_normalize_text(p_text text)
returns text
language sql
immutable
as $$
  select regexp_replace(lower(coalesce(p_text, '')), '[^0-9a-z가-힣]', '', 'g');
$$;

create or replace function public.community_reject_banned_words()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_norm text;
  v_hit  text;
begin
  -- posts 에는 title 이 있고 comments 에는 없다. to_jsonb 로 안전하게 접근한다.
  v_norm := public.community_normalize_text(
              coalesce(to_jsonb(new) ->> 'title', '') || ' ' || new.content
            );

  select w.word into v_hit
    from public.community_banned_words w
   where w.severity = 'block'
     and w.norm <> ''
     and position(w.norm in v_norm) > 0
   limit 1;

  if v_hit is not null then
    raise exception '사용할 수 없는 표현이 포함되어 있습니다.'
      using hint = 'banned_word';
  end if;

  return new;
end
$$;

drop trigger if exists community_posts_banned_words on public.community_posts;
create trigger community_posts_banned_words
  before insert or update of title, content on public.community_posts
  for each row execute function public.community_reject_banned_words();

drop trigger if exists community_comments_banned_words on public.community_comments;
create trigger community_comments_banned_words
  before insert or update of content on public.community_comments
  for each row execute function public.community_reject_banned_words();

-- 닉네임에도 같은 필터를 적용한다(사칭·욕설 닉네임 차단).
create or replace function public.profiles_reject_banned_nickname()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_norm text;
  v_hit  text;
begin
  if new.nickname is null or btrim(new.nickname) = '' then
    return new;
  end if;

  v_norm := public.community_normalize_text(new.nickname);
  if v_norm = '' then
    return new;
  end if;

  select w.word into v_hit
    from public.community_banned_words w
   where w.severity = 'block'
     and w.norm <> ''
     and position(w.norm in v_norm) > 0
   limit 1;

  if v_hit is not null then
    raise exception '사용할 수 없는 닉네임입니다.' using hint = 'banned_word';
  end if;

  return new;
end
$$;

drop trigger if exists profiles_banned_nickname on public.profiles;
create trigger profiles_banned_nickname
  before insert or update of nickname on public.profiles
  for each row execute function public.profiles_reject_banned_nickname();

-- ── 4) 운영 큐 뷰 (Supabase Studio 폴백) ─────────────────────
-- 앱 내 관리자 조치가 주 경로이고, 이 뷰는 백업이다. service_role 전용.
create or replace view public.community_moderation_queue as
select r.id,
       r.created_at,
       r.target_type,
       r.reason,
       r.detail,
       r.status,
       coalesce(p.id, cp.id)                              as post_id,
       c.id                                               as comment_id,
       coalesce(p.title, '')                              as post_title,
       coalesce(p.content, c.content)                     as body,
       coalesce(p.author_id, c.author_id, r.target_user_id) as target_user_id,
       coalesce(p.report_count, c.report_count, 0)        as report_count,
       coalesce(p.status, c.status)                       as content_status,
       now() - r.created_at                               as age
  from public.community_reports r
  left join public.community_comments c  on c.id  = r.comment_id
  left join public.community_posts    p  on p.id  = r.post_id
  left join public.community_posts    cp on cp.id = c.post_id
 where r.status = 'pending'
 order by coalesce(p.report_count, c.report_count, 0) desc, r.created_at;

comment on view public.community_moderation_queue is
  '미처리 신고 큐. service_role 전용(Supabase Studio에서 조회).';

revoke all on public.community_moderation_queue from anon, authenticated;
