-- 공개용 프로필 view: 채팅방 등에서 모든 사용자가 다른 사용자의 닉네임/아바타를 조회할 수 있도록 한다.
--
-- 배경:
--   profiles 테이블의 RLS는 본인 행만 SELECT 허용(profiles_select_own).
--   채팅 메시지 리스트는 작성자의 nickname/avatar_url을 함께 보여야 하므로
--   타인 행도 읽을 수 있어야 한다. profiles에 향후 민감 필드가 추가될 수 있어
--   테이블 정책을 풀지 않고, 필요한 필드만 노출하는 view를 새로 만든다.
--
-- 보안:
--   view를 security_invoker 없이 생성하면 view 소유자(postgres) 권한으로 base
--   테이블을 읽으므로 RLS가 우회된다. 노출 필드를 id/nickname/avatar_url로만
--   한정해 민감 정보 누출을 방지한다.
--   anon에도 SELECT를 부여해 비로그인 상태에서도 채팅 미리보기(닉네임/아바타)
--   표시가 가능하도록 한다.

create or replace view public.public_profiles as
select
  id,
  nickname,
  avatar_url
from public.profiles;

comment on view public.public_profiles is
  '공개용 프로필 view. 닉네임/아바타만 노출. RLS를 우회하므로 컬럼을 최소화한다.';

grant select on public.public_profiles to anon, authenticated;
