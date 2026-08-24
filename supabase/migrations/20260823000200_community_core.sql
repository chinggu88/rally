-- ============================================================
-- 커뮤니티 코어 테이블 (TASK-008 / 2of6)
--
-- 게시글 · 댓글 · 좋아요 · 조회 dedup + 카운터 트리거 + 컬럼 단위 권한.
-- 선행: 20260823000100 (community_is_blocked / community_can_write / is_app_admin)
--
-- 설계 메모
--   · author_id 는 nullable + on delete set null. 탈퇴해도 글은 남기고
--     작성자만 비운다("탈퇴한 사용자"). cascade 로 두면 파워 유저 한 명이
--     떠날 때 커뮤니티 자산이 통째로 사라진다.
--   · 카운터는 비정규화 컬럼 + 트리거. count(*)는 PostgREST 에서 정렬/필터에
--     못 쓰고 응답이 중첩되어 MODEL_GUIDE 의 flat fromJson 과 맞지 않는다.
--   · 카운터 컬럼은 어떤 인덱스에도 넣지 않고 fillfactor 를 낮춰 HOT UPDATE 를
--     유지한다. 그래서 "인기순 정렬"은 MVP 범위 밖이다.
--   · Realtime publication 에 추가하지 않는다. replica identity full 상태에서
--     카운터 UPDATE 가 본문 5000자를 매번 WAL 로 흘려보낸다.
-- ============================================================

-- ── 1) 게시글 ────────────────────────────────────────────────
create table if not exists public.community_posts (
  id            uuid primary key default gen_random_uuid(),
  author_id     uuid references auth.users(id) on delete set null,
  category      text not null check (category in ('free', 'match', 'gear', 'partner')),
  title         text not null check (char_length(btrim(title))   between 1 and 100),
  content       text not null check (char_length(btrim(content)) between 1 and 5000),
  image_paths   text[] not null default '{}'::text[]
                check (coalesce(array_length(image_paths, 1), 0) <= 5),
  like_count    integer not null default 0 check (like_count    >= 0),
  comment_count integer not null default 0 check (comment_count >= 0),
  view_count    integer not null default 0 check (view_count    >= 0),
  report_count  integer not null default 0 check (report_count  >= 0),
  status        text not null default 'visible'
                check (status in ('visible', 'hidden', 'deleted')),
  hidden_reason text,
  edited_at     timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
comment on table public.community_posts is
  '커뮤니티 게시글. author_id NULL = 탈퇴한 사용자. 삭제는 status=deleted 소프트 삭제.';

-- 카운터 UPDATE 가 같은 페이지 안에서 처리되도록 여유를 둔다(HOT UPDATE).
alter table public.community_posts set (fillfactor = 85);

drop trigger if exists community_posts_set_updated_at on public.community_posts;
create trigger community_posts_set_updated_at
  before update on public.community_posts
  for each row execute function public.set_updated_at();  -- 20260622000000 정의 재사용

-- 목록 정렬은 최신순 고정. (created_at, id) 로 커서 페이지네이션 안정성 확보.
create index if not exists community_posts_created_idx
  on public.community_posts (created_at desc, id desc)
  where status = 'visible';

create index if not exists community_posts_cat_created_idx
  on public.community_posts (category, created_at desc, id desc)
  where status = 'visible';

create index if not exists community_posts_author_idx
  on public.community_posts (author_id, created_at desc);

-- 운영 큐용. 정상 글은 인덱스에 넣지 않는다.
create index if not exists community_posts_mod_idx
  on public.community_posts (status, report_count desc)
  where status <> 'visible';

-- ── 2) 댓글 ──────────────────────────────────────────────────
create table if not exists public.community_comments (
  id           uuid primary key default gen_random_uuid(),
  post_id      uuid not null references public.community_posts(id) on delete cascade,
  parent_id    uuid,
  author_id    uuid references auth.users(id) on delete set null,
  content      text not null check (char_length(btrim(content)) between 1 and 1000),
  reply_count  integer not null default 0 check (reply_count  >= 0),
  report_count integer not null default 0 check (report_count >= 0),
  status       text not null default 'visible'
               check (status in ('visible', 'hidden', 'deleted')),
  edited_at    timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  -- 복합 FK 의 참조 대상. 아래 self FK 를 위해 필요하다.
  unique (id, post_id),
  -- 부모 댓글이 반드시 "같은 글"에 속하도록 FK 로 강제한다.
  -- parent_id 가 NULL 이면 MATCH SIMPLE 규칙에 따라 제약이 통과된다.
  foreign key (parent_id, post_id)
    references public.community_comments (id, post_id) on delete cascade
);
comment on table public.community_comments is
  '커뮤니티 댓글. parent_id NULL = 최상위, NOT NULL = 대댓글(1depth 까지).';

alter table public.community_comments set (fillfactor = 90);

create index if not exists community_comments_post_created_idx
  on public.community_comments (post_id, created_at asc);

create index if not exists community_comments_author_idx
  on public.community_comments (author_id, created_at desc);

drop trigger if exists community_comments_set_updated_at on public.community_comments;
create trigger community_comments_set_updated_at
  before update on public.community_comments
  for each row execute function public.set_updated_at();

-- 1depth 강제. 복합 FK 가 "다른 글의 댓글을 부모로 지정"을 이미 막으므로
-- 여기서는 깊이와 부모 상태만 본다.
create or replace function public.community_comments_enforce_depth()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_parent_parent uuid;
  v_parent_status text;
begin
  if new.parent_id is null then
    return new;
  end if;

  select parent_id, status
    into v_parent_parent, v_parent_status
    from public.community_comments
   where id = new.parent_id;

  if not found then
    raise exception '부모 댓글을 찾을 수 없습니다.' using hint = 'parent_missing';
  end if;

  if v_parent_parent is not null then
    raise exception '대댓글에는 답글을 달 수 없습니다.' using hint = 'depth_exceeded';
  end if;

  if v_parent_status <> 'visible' then
    raise exception '삭제된 댓글에는 답글을 달 수 없습니다.' using hint = 'parent_removed';
  end if;

  return new;
end
$$;

drop trigger if exists community_comments_depth on public.community_comments;
create trigger community_comments_depth
  before insert on public.community_comments
  for each row execute function public.community_comments_enforce_depth();

-- ── 3) 좋아요 / 조회 dedup ───────────────────────────────────
create table if not exists public.community_post_likes (
  post_id    uuid not null references public.community_posts(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)   -- 중복 좋아요 원천 차단
);

create index if not exists community_post_likes_user_idx
  on public.community_post_likes (user_id, created_at desc);

-- 조회수 1인 1회 판정용. 비로그인은 아예 기록하지 않는다.
create table if not exists public.community_post_views (
  post_id    uuid not null references public.community_posts(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
comment on table public.community_post_views is
  '조회수 중복 방지용. RPC(community_increment_view) 경유로만 기록된다.';

-- ── 4) 카운터 트리거 ─────────────────────────────────────────
--
-- ★ 전부 security definer 여야 한다.
--   트리거 함수는 호출자 권한으로 실행되므로, 남의 글에 댓글/좋아요를 달면
--   community_posts UPDATE RLS(작성자만)에 막혀 "예외 없이 0건 UPDATE"로
--   조용히 실패한다. 본인 계정 하나로 테스트하면 절대 재현되지 않는다.

create or replace function public.community_bump_like_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.community_posts
       set like_count = like_count + 1
     where id = new.post_id;
  else
    update public.community_posts
       set like_count = greatest(like_count - 1, 0)
     where id = old.post_id;
  end if;
  return null;
end
$$;

drop trigger if exists community_post_likes_count on public.community_post_likes;
create trigger community_post_likes_count
  after insert or delete on public.community_post_likes
  for each row execute function public.community_bump_like_count();

-- 게시글 comment_count + 부모 댓글 reply_count 동시 관리.
-- 소프트 삭제(status 변경)도 카운터에 반영해야 하므로 UPDATE 도 받는다.
create or replace function public.community_bump_comment_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_delta integer := 0;
begin
  if tg_op = 'INSERT' then
    if new.status = 'visible' then v_delta := 1; end if;
  elsif tg_op = 'DELETE' then
    if old.status = 'visible' then v_delta := -1; end if;
  else -- UPDATE
    if old.status = 'visible' and new.status <> 'visible' then
      v_delta := -1;
    elsif old.status <> 'visible' and new.status = 'visible' then
      v_delta := 1;
    end if;
  end if;

  if v_delta = 0 then
    return null;
  end if;

  update public.community_posts
     set comment_count = greatest(comment_count + v_delta, 0)
   where id = coalesce(new.post_id, old.post_id);

  if coalesce(new.parent_id, old.parent_id) is not null then
    update public.community_comments
       set reply_count = greatest(reply_count + v_delta, 0)
     where id = coalesce(new.parent_id, old.parent_id);
  end if;

  return null;
end
$$;

drop trigger if exists community_comments_count on public.community_comments;
create trigger community_comments_count
  after insert or delete or update of status on public.community_comments
  for each row execute function public.community_bump_comment_count();

-- ── 4-1) edited_at 자동 기록 ─────────────────────────────────
--
-- 사용자가 본문을 실제로 고쳤을 때만 서버 시각으로 찍는다.
-- 카운터 트리거(like_count/comment_count/view_count)나 관리자 status 변경은
-- 내용 변경이 아니므로 "수정됨" 표시를 남기면 안 된다 — 그래서 컬럼별로
-- is distinct from 비교를 한다.
create or replace function public.community_posts_touch_edited_at()
returns trigger
language plpgsql
as $$
begin
  if new.title       is distinct from old.title
  or new.content     is distinct from old.content
  or new.category    is distinct from old.category
  or new.image_paths is distinct from old.image_paths then
    new.edited_at := now();
  end if;
  return new;
end
$$;

drop trigger if exists community_posts_edited_at on public.community_posts;
create trigger community_posts_edited_at
  before update on public.community_posts
  for each row execute function public.community_posts_touch_edited_at();

create or replace function public.community_comments_touch_edited_at()
returns trigger
language plpgsql
as $$
begin
  if new.content is distinct from old.content then
    new.edited_at := now();
  end if;
  return new;
end
$$;

drop trigger if exists community_comments_edited_at on public.community_comments;
create trigger community_comments_edited_at
  before update on public.community_comments
  for each row execute function public.community_comments_touch_edited_at();

-- 정합성 복구용(운영자 전용). p_post_id 가 NULL 이면 전체 재계산.
create or replace function public.community_recount(p_post_id uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_app_admin() then
    raise exception '권한이 없습니다.' using hint = 'forbidden';
  end if;

  update public.community_posts p
     set like_count = coalesce(l.c, 0),
         comment_count = coalesce(c.c, 0)
    from (select id from public.community_posts
           where p_post_id is null or id = p_post_id) t
    left join lateral (
      select count(*)::int as c from public.community_post_likes
       where post_id = t.id) l on true
    left join lateral (
      select count(*)::int as c from public.community_comments
       where post_id = t.id and status = 'visible') c on true
   where p.id = t.id;

  update public.community_comments cc
     set reply_count = coalesce(r.c, 0)
    from (select id, post_id from public.community_comments
           where parent_id is null
             and (p_post_id is null or post_id = p_post_id)) t
    left join lateral (
      select count(*)::int as c from public.community_comments
       where parent_id = t.id and status = 'visible') r on true
   where cc.id = t.id;
end
$$;

-- ── 5) 컬럼 단위 권한 ────────────────────────────────────────
--
-- ★ 이 프로젝트에서 가장 빠뜨리기 쉬운 부분.
--   Supabase default privileges 가 신규 테이블에 GRANT ALL 을 자동으로 붙인다.
--   RLS 는 "행" 단위라 컬럼을 막지 못하므로, like_count = 99999 나
--   status = 'visible' 같은 자기 행 조작을 RLS 만으로는 막을 수 없다.

revoke all on public.community_posts       from anon, authenticated;
revoke all on public.community_comments    from anon, authenticated;
revoke all on public.community_post_likes  from anon, authenticated;
revoke all on public.community_post_views  from anon, authenticated;

grant select on public.community_posts    to anon, authenticated;
grant select on public.community_comments to anon, authenticated;
grant insert on public.community_posts    to authenticated;
grant insert on public.community_comments to authenticated;

-- 작성자가 고칠 수 있는 컬럼만 열어준다. status/카운터는 포함하지 않는다.
--
-- edited_at 은 클라이언트에게 주지 않는다. PostgREST UPDATE 본문에서는 서버
-- now() 를 쓸 수 없어 클라이언트 시각을 넣게 되는데, 기기 시계가 틀리면
-- "수정됨" 시각이 어긋난다. 아래 touch 트리거가 서버 시각으로 대신 찍는다.
grant update (title, content, category, image_paths)
  on public.community_posts to authenticated;
grant update (content)
  on public.community_comments to authenticated;

-- DELETE 권한은 주지 않는다. 소프트 삭제는 RPC(000400)로만.

-- 좋아요는 본인 행 insert/delete. anon 에게도 select 를 주는 이유는
-- 피드 뷰(000400)의 is_liked 서브쿼리가 이 테이블을 읽기 때문이다.
-- RLS 가 행을 막으므로 anon 은 항상 0건 → is_liked = false 가 된다.
grant select, insert, delete on public.community_post_likes to authenticated;
grant select on public.community_post_likes to anon;

-- 조회 기록은 RPC 경유로만. 클라이언트 직접 접근 불가.

-- ── 6) RLS 정책 ──────────────────────────────────────────────
alter table public.community_posts      enable row level security;
alter table public.community_comments   enable row level security;
alter table public.community_post_likes enable row level security;
alter table public.community_post_views enable row level security;

-- 게시글: 공개 글 + 내 글 + 운영자. 차단 관계인 작성자는 제외.
drop policy if exists cp_select on public.community_posts;
create policy cp_select on public.community_posts
  for select to anon, authenticated
  using (
    (status = 'visible'
      or author_id = (select auth.uid())
      or public.is_app_admin())
    and not public.community_is_blocked(author_id)
  );

drop policy if exists cp_insert on public.community_posts;
create policy cp_insert on public.community_posts
  for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and status = 'visible'
    and public.community_can_write()
    -- 남의 스토리지 폴더 경로를 자기 글에 끼워 넣는 것을 막는다.
    and (
      coalesce(array_length(image_paths, 1), 0) = 0
      or (select bool_and(p like ((select auth.uid())::text || '/%'))
            from unnest(image_paths) p)
    )
  );

drop policy if exists cp_update_own on public.community_posts;
create policy cp_update_own on public.community_posts
  for update to authenticated
  using (author_id = (select auth.uid()) and status = 'visible')
  with check (author_id = (select auth.uid()));

-- 관리자 UPDATE 정책은 두지 않는다.
--   status 컬럼에 GRANT UPDATE 를 주지 않았으므로(위 컬럼 권한 참조) 정책만
--   만들어봐야 42501 permission denied 로 막힌다. 정책은 "행"을, GRANT 는
--   "컬럼"을 통제하며 둘 다 통과해야 한다 — 놓치기 쉬운 조합이다.
--   관리자의 숨김/복구는 community_set_post_status() RPC 로 처리한다(000400).
drop policy if exists cp_update_admin on public.community_posts;

-- 댓글: reply_count > 0 이면 삭제/숨김 댓글도 SELECT 를 통과시킨다.
-- 스레드 구조를 유지해야 대댓글이 고아가 되지 않기 때문이다.
-- 본문은 피드 뷰(000400)에서 NULL 로 마스킹한다.
drop policy if exists cc_select on public.community_comments;
create policy cc_select on public.community_comments
  for select to anon, authenticated
  using (
    (status = 'visible'
      or reply_count > 0
      or author_id = (select auth.uid())
      or public.is_app_admin())
    and not public.community_is_blocked(author_id)
    -- 부모 글이 보이지 않으면 댓글도 보이지 않아야 한다.
    -- 이 서브쿼리에는 community_posts 의 RLS(cp_select)가 그대로 적용되므로
    -- 공개여부/작성자/운영자/차단 판정을 여기서 다시 쓸 필요가 없다.
    and exists (select 1 from public.community_posts p where p.id = post_id)
  );

drop policy if exists cc_insert on public.community_comments;
create policy cc_insert on public.community_comments
  for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and status = 'visible'
    and public.community_can_write()
    and exists (
      select 1 from public.community_posts p
       where p.id = post_id and p.status = 'visible'
    )
  );

drop policy if exists cc_update_own on public.community_comments;
create policy cc_update_own on public.community_comments
  for update to authenticated
  using (author_id = (select auth.uid()) and status = 'visible')
  with check (author_id = (select auth.uid()));

-- 위와 같은 이유로 관리자 UPDATE 정책 없음.
-- 관리자의 댓글 숨김/복구는 community_set_comment_status() RPC(000400).
drop policy if exists cc_update_admin on public.community_comments;

-- 좋아요: 본인 것만. "누가 좋아요 눌렀는지" 목록은 제공하지 않는다
-- (차단 우회 정보가 되기 때문). is_liked 는 피드 뷰가 제공한다.
drop policy if exists cpl_select_own on public.community_post_likes;
create policy cpl_select_own on public.community_post_likes
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists cpl_insert_own on public.community_post_likes;
create policy cpl_insert_own on public.community_post_likes
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.community_posts p
       where p.id = post_id and p.status = 'visible'
    )
  );

drop policy if exists cpl_delete_own on public.community_post_likes;
create policy cpl_delete_own on public.community_post_likes
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- 조회 기록: 정책 0개. RPC(security definer)만 접근한다.

-- ── 7) Realtime 미등록 확인 ──────────────────────────────────
-- 의도적으로 supabase_realtime publication 에 추가하지 않는다.
-- live_match_chat_messages 선례를 습관적으로 따라가지 말 것.
