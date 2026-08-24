-- ============================================================
-- 커뮤니티 피드 뷰 + RPC (TASK-008 / 4of6)
--
-- 선행: 20260823000300
--
-- ★★ security_invoker = on 이 이 파일의 핵심이다 ★★
--    빼면 뷰 소유자(postgres) 권한으로 실행돼 community_posts 의 status 필터와
--    차단 필터가 전부 우회되고, 삭제·숨김 글까지 그대로 노출된다. 리뷰 리젝 직결.
--
--    주의: 기존 public_profiles view(20260630010000)는 **의도적으로**
--    security_invoker 없이 만들어져 있다. 노출 컬럼을 id/nickname/avatar_url
--    3개로 최소화해 정당화한 케이스다. 그 파일을 참고해 복붙하면 정반대의
--    결과가 나온다. 여기서는 반드시 invoker 를 켠다.
-- ============================================================

-- ── 1) 게시글 피드 뷰 ────────────────────────────────────────
--
-- 목적: 작성자 프로필 + is_liked 까지 라운드트립 1회로 가져온다.
-- ChatMessageRepository._hydrateProfiles() 의 2회 쿼리 패턴은 is_liked 까지
-- 필요해 3회가 되므로 커뮤니티에는 부적합하다.
--
-- posts.author_id → auth.users 라 PostgREST 가 public_profiles 와의 관계를
-- 추론하지 못한다. 그래서 임베드가 아니라 뷰에서 직접 join 한다.
create or replace view public.community_post_feed
with (security_invoker = on) as
select p.id,
       p.author_id,
       p.category,
       p.title,
       p.content,
       p.image_paths,
       p.like_count,
       p.comment_count,
       p.view_count,
       p.status,
       p.edited_at,
       p.created_at,
       p.updated_at,
       pr.nickname   as author_nickname,
       pr.avatar_url as author_avatar_url,
       exists (
         select 1
           from public.community_post_likes l
          where l.post_id = p.id
            and l.user_id = auth.uid()
       ) as is_liked
  from public.community_posts p
  left join public.public_profiles pr on pr.id = p.author_id;

comment on view public.community_post_feed is
  '게시글 목록/상세용 피드. security_invoker=on 이므로 community_posts 의 RLS(공개여부·차단)가 그대로 적용된다. 절대 끄지 말 것.';

grant select on public.community_post_feed to anon, authenticated;

-- ── 2) 댓글 피드 뷰 ──────────────────────────────────────────
--
-- 삭제/숨김 댓글도 reply_count > 0 이면 SELECT 를 통과한다(스레드 구조 유지).
-- 대신 본문을 NULL 로 마스킹해 내용이 새어나가지 않게 한다.
-- 클라이언트는 content 가 null 이면 "삭제된 댓글입니다" 툼스톤을 그린다.
create or replace view public.community_comment_feed
with (security_invoker = on) as
select c.id,
       c.post_id,
       c.parent_id,
       c.author_id,
       case when c.status = 'visible' then c.content else null end as content,
       c.reply_count,
       c.status,
       c.edited_at,
       c.created_at,
       c.updated_at,
       case when c.status = 'visible' then pr.nickname   else null end as author_nickname,
       case when c.status = 'visible' then pr.avatar_url else null end as author_avatar_url
  from public.community_comments c
  left join public.public_profiles pr on pr.id = c.author_id;

comment on view public.community_comment_feed is
  '댓글 목록용 피드. 삭제/숨김 댓글은 content/작성자를 NULL 로 마스킹하되 행 자체는 남겨 대댓글 고아를 방지한다.';

grant select on public.community_comment_feed to anon, authenticated;

-- ── 3) 조회수 RPC ────────────────────────────────────────────
--
-- 로그인 사용자 1인 1회 영구 카운트.
--   · 클라이언트 로컬 dedup 만으로는 재설치 시 무한 증가한다.
--   · view_count 컬럼에 UPDATE 권한을 열면 컬럼 권한 방어(000200)가 무너진다.
--   · 그래서 definer RPC 로만 증가시킨다.
-- 비로그인은 아예 카운트하지 않는다(과소집계 수용, 라벨은 "조회").
create or replace function public.community_increment_view(p_post_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  if auth.uid() is null then
    select view_count into v_count from public.community_posts where id = p_post_id;
    return coalesce(v_count, 0);
  end if;

  insert into public.community_post_views (post_id, user_id)
  values (p_post_id, auth.uid())
  on conflict do nothing;

  if not found then
    -- 이미 본 글. 현재 값만 반환한다.
    select view_count into v_count from public.community_posts where id = p_post_id;
    return coalesce(v_count, 0);
  end if;

  update public.community_posts
     set view_count = view_count + 1
   where id = p_post_id
   returning view_count into v_count;

  return coalesce(v_count, 0);
end
$$;

-- ── 4) 소프트 삭제 RPC ───────────────────────────────────────
-- DELETE 권한을 클라이언트에 주지 않으므로(000200) 삭제는 여기를 통한다.
create or replace function public.community_delete_post(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.community_posts
     set status = 'deleted'
   where id = p_id
     and (author_id = auth.uid() or public.is_app_admin())
     and status <> 'deleted';

  if not found then
    raise exception '삭제 권한이 없습니다.' using hint = 'forbidden';
  end if;
end
$$;

create or replace function public.community_delete_comment(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.community_comments
     set status = 'deleted'
   where id = p_id
     and (author_id = auth.uid() or public.is_app_admin())
     and status <> 'deleted';

  if not found then
    raise exception '삭제 권한이 없습니다.' using hint = 'forbidden';
  end if;
end
$$;

-- ── 5) 관리자 조치 RPC ───────────────────────────────────────
-- 별도 관리자 화면 없이 앱 더보기 시트에서 호출한다(24시간 SLA 담보).
create or replace function public.community_ban_user(p_user_id uuid, p_days integer default 7)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_app_admin() then
    raise exception '권한이 없습니다.' using hint = 'forbidden';
  end if;
  if p_days is null or p_days < 1 then
    raise exception '정지 기간이 올바르지 않습니다.' using hint = 'invalid_days';
  end if;

  update public.profiles
     set community_banned_until = now() + make_interval(days => p_days)
   where id = p_user_id;

  if not found then
    raise exception '대상 사용자를 찾을 수 없습니다.' using hint = 'not_found';
  end if;
end
$$;

create or replace function public.community_unban_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_app_admin() then
    raise exception '권한이 없습니다.' using hint = 'forbidden';
  end if;

  update public.profiles set community_banned_until = null where id = p_user_id;
end
$$;

-- 관리자 숨김/복구.
--   status 컬럼에 GRANT UPDATE 를 주지 않았으므로(000200) 클라이언트의
--   .from().update({'status': ...}) 는 통하지 않는다. definer RPC 로만 처리한다.
create or replace function public.community_set_post_status(p_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_app_admin() then
    raise exception '권한이 없습니다.' using hint = 'forbidden';
  end if;
  if p_status not in ('visible', 'hidden', 'deleted') then
    raise exception '상태값이 올바르지 않습니다.' using hint = 'invalid_status';
  end if;

  update public.community_posts
     set status = p_status,
         hidden_reason = case
           when p_status = 'hidden' then 'admin'
           when p_status = 'visible' then null
           else hidden_reason
         end
   where id = p_id;

  if not found then
    raise exception '게시글을 찾을 수 없습니다.' using hint = 'not_found';
  end if;
end
$$;

create or replace function public.community_set_comment_status(p_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_app_admin() then
    raise exception '권한이 없습니다.' using hint = 'forbidden';
  end if;
  if p_status not in ('visible', 'hidden', 'deleted') then
    raise exception '상태값이 올바르지 않습니다.' using hint = 'invalid_status';
  end if;

  update public.community_comments set status = p_status where id = p_id;

  if not found then
    raise exception '댓글을 찾을 수 없습니다.' using hint = 'not_found';
  end if;
end
$$;

create or replace function public.community_resolve_report(
  p_report_id uuid,
  p_status    text,
  p_note      text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_app_admin() then
    raise exception '권한이 없습니다.' using hint = 'forbidden';
  end if;
  if p_status not in ('actioned', 'rejected') then
    raise exception '처리 상태가 올바르지 않습니다.' using hint = 'invalid_status';
  end if;

  update public.community_reports
     set status          = p_status,
         resolved_at     = now(),
         resolved_by     = auth.uid(),
         resolution_note = p_note
   where id = p_report_id
     and status = 'pending';

  if not found then
    raise exception '이미 처리된 신고입니다.' using hint = 'already_resolved';
  end if;
end
$$;

-- ── 6) 실행 권한 ─────────────────────────────────────────────
grant execute on function public.community_increment_view(uuid)            to anon, authenticated;
grant execute on function public.community_delete_post(uuid)               to authenticated;
grant execute on function public.community_delete_comment(uuid)            to authenticated;
grant execute on function public.community_set_post_status(uuid, text)     to authenticated;
grant execute on function public.community_set_comment_status(uuid, text)  to authenticated;
grant execute on function public.community_ban_user(uuid, integer)         to authenticated;
grant execute on function public.community_unban_user(uuid)                to authenticated;
grant execute on function public.community_resolve_report(uuid, text, text) to authenticated;
grant execute on function public.community_recount(uuid)                   to authenticated;
