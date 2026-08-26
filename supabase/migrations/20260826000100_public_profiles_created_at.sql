-- public_profiles 뷰에 created_at(가입일)을 노출한다.
--
-- 배경:
--   커뮤니티 작성자 프로필 바텀시트(TASK-017)가 "2026.03 가입" 형태로 가입일을
--   보여준다. profiles.created_at 은 존재하지만(20260622000000) 이 뷰에는
--   노출돼 있지 않아 조회할 수 없다.
--
-- ★ 노출 범위 (반드시 인지할 것) ★
--   이 뷰는 20260630010000 에서 security_invoker 없이 생성됐다. 즉 뷰 소유자
--   (postgres) 권한으로 base 테이블을 읽어 profiles 의 RLS(본인 행만 SELECT)를
--   우회한다. 게다가 anon 에도 select grant 가 있다.
--   따라서 이 변경으로 **비로그인 사용자를 포함한 모든 사용자에게 전체 사용자의
--   가입일이 공개된다.** 프로필 시트의 가입일 표시를 위한 의도된 노출이다.
--
-- ★ 컬럼을 더 늘리지 말 것 ★
--   이 뷰가 RLS 우회를 정당화하는 근거는 "노출 필드 최소화" 하나뿐이다.
--   컬럼을 늘릴수록 그 근거가 약해진다. 향후 필드가 더 필요하면 이 뷰를
--   키우지 말고 security_invoker 를 켠 별도 뷰를 만드는 쪽을 검토한다.
--
-- ★ created_at 은 반드시 맨 뒤 ★
--   community_post_feed / community_comment_feed(20260823000400)가 이 뷰를
--   join 으로 참조한다. `create or replace view` 는 기존 컬럼 뒤에 추가하는
--   것만 허용하므로, 순서를 바꾸거나 중간에 끼워 넣으면 의존 뷰 때문에 실패한다.
--   (두 피드 뷰는 pr.nickname / pr.avatar_url 만 참조하므로 동작에는 영향이 없다.)

create or replace view public.public_profiles as
select
  id,
  nickname,
  avatar_url,
  created_at
from public.profiles;

comment on view public.public_profiles is
  '공개용 프로필 view. 닉네임/아바타/가입일만 노출. RLS를 우회하며 anon 에도 열려 있으므로 컬럼을 최소화한다.';

grant select on public.public_profiles to anon, authenticated;
