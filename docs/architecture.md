```
rally/lib/
├── main.dart                                              # 앱 진입점 — dotenv.load / Supabase.initialize / GetMaterialApp
│
├── app/                                                   # [앱 메인] 애플리케이션 로직
│   │
│   ├── routes/                                            # [라우팅] GetX 네비게이션
│   │   ├── app_pages.dart                                 # GetPage 매핑 (app/news/match/player/my_info/login/sign_up)
│   │   └── app_routes.dart                                # 라우트 경로 상수 (APP / NEWS / MATCH / PLAYER / MY_INFO / LOGIN / SIGN_UP)
│   │
│   ├── data/                                              # [데이터 레이어] 모델 + 레포지토리 (Supabase Edge Function 연동)
│   │   ├── models/
│   │   │   ├── tournament_response.dart                   # BWF 대회 단일 응답 모델 (private 필드 + getter/setter)
│   │   │   ├── get_tournaments_response.dart              # { year, count, tournaments } 래퍼 모델
│   │   │   ├── tournament_detail_response.dart            # 대회 상세 정보 모델 (배너 + 경기 배열)
│   │   │   ├── tournament_match_response.dart             # 대회의 단일 경기 모델 (선수/일정 정보)
│   │   │   ├── get_tournament_matches_response.dart       # { tournament_id, event_name, count, matches } 래퍼 모델
│   │   │   ├── tournament_participant_response.dart       # 종목별 참가 선수 단일 모델 (eventName/player1Id/name/country/seed 등) — TASK-006
│   │   │   ├── get_tournament_participants_response.dart  # { tournament_id, event_name, count, participants } 래퍼 모델 — TASK-006
│   │   │   ├── player_response.dart                       # BWF 선수 단일 응답 모델 (private 필드 + getter/setter)
│   │   │   ├── get_players_response.dart                  # { category, count, players } 래퍼 모델
│   │   │   ├── player_detail_response.dart                # 선수 상세 정보 모델 (랭킹/성적 등)
│   │   │   ├── get_player_response.dart                   # 선수 단일 상세 조회 래퍼 모델
│   │   │   ├── live_match_response.dart                   # 라이브 매치 단일 모델 (대회+매치+팀 비정규화 / 게임 스코어 파싱 + winnerSide/isLive/games getter) — 홈 라이브
│   │   │   ├── get_live_matches_response.dart             # { count, matches } 래퍼 모델 — 홈 라이브
│   │   │   ├── today_match_response.dart                  # 오늘 경기 단일 모델 (대회+매치+팀 비정규화, LiveGameScore 재사용) — TASK-007
│   │   │   ├── get_today_matches_response.dart            # { date, results_count, upcoming_count, results, upcoming } 래퍼 — TASK-007
│   │   │   ├── community_post_response.dart               # 커뮤니티 게시글 모델 — 뷰 `community_post_feed` 1행 (작성자 프로필 + is_liked, copyWithLike / copyWithViewCount / copyWithCommentCount) — TASK-009,010,012
│   │   │   ├── community_comment_response.dart            # 커뮤니티 댓글 모델 — 뷰 `community_comment_feed` 1행 (삭제·숨김은 content/작성자 NULL 마스킹, isRemoved / isReply / copyWithRemoved) — TASK-012
│   │   │   ├── create_community_comment_parameter.dart    # 댓글 작성 파라미터 (post_id/content + parent_id는 대댓글일 때만, author_id·status는 레포지토리/기본값) — TASK-012
│   │   │   ├── create_community_post_parameter.dart       # 게시글 작성 파라미터 (category/title/content/image_paths, author_id는 레포지토리가 세션에서 주입) — TASK-011
│   │   │   ├── update_community_post_parameter.dart       # 게시글 수정 파라미터 — null 아닌 필드만 toJson (UPDATE 허용 컬럼 5개 외 섞이면 42501) — TASK-011
│   │   │   ├── create_community_report_parameter.dart     # 신고 파라미터 — post/comment/user 생성자별로 대상 컬럼 하나만 toJson (서버 CHECK `community_reports_target_ck`), reasonLabels 6종 — TASK-013
│   │   │   ├── community_report_response.dart             # 신고 모델 — `community_reports` 1행 (운영자의 "신고 종결"이 미처리 목록을 읽을 때만 사용, isPending) — TASK-013
│   │   │   ├── public_profile_response.dart               # 타인 프로필 모델 — 뷰 `public_profiles` 1행 (id/nickname/avatar_url/created_at 4컬럼, displayName 폴백은 CommunityPostResponse 와 동일 규칙). `ProfileRepository.fetchPublicProfile(userId)` 가 `.from('public_profiles').maybeSingle()` 로 읽는다 — 뷰가 RLS 를 우회하고 anon 에도 열려 있어 비로그인·차단 상태에서도 조회된다 — TASK-017
│   │   │   └── blocked_user_response.dart                 # 차단한 사용자 모델 — `user_blocks` 1행 + `public_profiles` 클라이언트 hydrate (displayName / copyWithProfile) — TASK-013
│   │   │
│   │   └── repositories/
│   │       ├── tournament_repository.dart                 # Edge Function `get-tournaments` / `get-tournament` / `get-tournament-matches` / `get-tournament-participants` 호출
│   │       ├── player_repository.dart                     # Edge Function `get-players` / `get-player` 호출 (카테고리별 조회: MS/WS/MD/WD/XD)
│   │       ├── live_match_repository.dart                 # Edge Function `get-live-matches` 호출 (tournament_id/event_name 선택 필터, 404→빈 목록) — 홈 라이브
│   │       ├── today_match_repository.dart                # Edge Function `get-today-matches` 호출 (404→빈 응답, KST 오늘 기준) — TASK-007
│   │       ├── community_post_repository.dart             # `.from('community_post_feed')` 직접 접근 + RLS (커서 페이지네이션 / fetchById / like·unlike / community_increment_view · community_delete_post RPC / createPost·updatePost / uploadImages·removeImages) — TASK-009,010,011. **listPosts 는 `.neq('status','deleted')` 로 삭제 글을 거른다** — 본인·운영자 행은 RLS 를 통과하므로. fetchById 는 필터 없음(운영자 숨김 글 진입 경로) — TASK-015
│   │       ├── community_comment_repository.dart          # `.from('community_comment_feed')` 조회 + 테이블 INSERT/UPDATE(content 컬럼만) + community_delete_comment RPC. 작성 후 뷰 재조회로 작성자 프로필 hydrate — TASK-012
│   │       └── community_moderation_repository.dart       # 작성 자격 · 금칙어 · **신고 · 차단 · 운영자 조치** (eulaVersion/eulaAssetPath 상수 = DB community_eula_version() / hasAgreedToEula · agreeToEula · fetchBannedWords(norm) · fetchWriteEligibility · isNicknameTaken / createReport(23505→"이미 신고한 콘텐츠") · listPendingReports / blockUser·unblockUser·listBlockedUsers(public_profiles hydrate) / isAppAdmin RPC · setPostStatus · setCommentStatus · banUser · unbanUser · resolveReport ← **status 컬럼 GRANT가 없어 관리자 조치는 전부 RPC**) — TASK-011,013
│   │
│   ├── utils/                                             # [유틸] 화면·컨트롤러가 공유하는 순수 함수
│   │   ├── bwf_image.dart                                 # BWF 이미지 URL 보정
│   │   ├── country_flag.dart                              # 국가 코드 → 국기 이모지
│   │   ├── community_error.dart                           # 서버 hint/code → 한국어 문구 (communityErrorMessage) + CommunityValidationException — TASK-009,011
│   │   └── community_text_filter.dart                     # 금칙어 사전검증 — 서버 community_normalize_text() 와 동일한 정규화 규칙 — TASK-011
│   │
│   └── modules/                                           # [모듈] 기능별 MVC 패턴 구현
│       │
│       ├── app/                                           # [앱 셸] 바텀네비를 호스팅하는 루트 화면
│       │   ├── bindings/app_binding.dart                  # 바텀네비 전체 모듈 바인딩 + Live/TodayMatchRepository fenix(홈 진입 보장)
│       │   ├── controllers/app_controller.dart            # 탭 전환 상태 관리
│       │   └── views/app_view.dart                        # 바텀네비 + 페이지 호스트
│       │
│       ├── news/                                          # [홈/뉴스] 바텀네비 1번 탭 — 활성 대회 + 라이브 매치 + 오늘 경기 가로 캐러셀 + 뉴스
│       │   ├── bindings/news_binding.dart                 # LiveMatchRepository(fenix) + TodayMatchRepository(fenix) + NewsController lazyPut
│       │   ├── controllers/news_controller.dart           # 라이브/오늘경기(results+upcoming 머지) fetch / Pull-to-refresh / race-condition 가드(_inflightToken)
│       │   ├── views/news_view.dart                       # sliver: active_tournaments → live → today(가로 캐러셀, 결과→예정 순) → news / RefreshIndicator
│       │   ├── views/widgets/active_tournament_card.dart  # 활성 대회 단일 카드 (로고 + 대회명)
│       │   ├── views/widgets/live_match_card.dart         # 라이브 매치 단일 카드 (로고/대회명/LIVE 배지 + team1 vs team2 + 게임 스코어 + 코트명)
│       │   ├── views/widgets/today_match_card.dart        # 오늘 경기 가로 카드 (팀1 국가·이름 / 시각 or FINAL / 팀2 국가·이름 + 결과 시 게임 스코어) — TASK-007
│       │   ├── views/widgets/news_card_viewer.dart        # 뉴스 카드 뷰어 (pager + scrollable 이미지)
│       │   └── views/widgets/news_card_item.dart          # 뉴스 카드 단일 항목 (이미지 + 제목)
│       │
│       ├── match/                                         # [경기] 국제 대회 리스트 + 상세 + 참가 선수 — TASK-004~006
│       │   ├── bindings/match_binding.dart                # TournamentRepository + MatchController lazyPut
│       │   ├── controllers/match_controller.dart          # 연도별 대회 fetch / 로딩·에러 상태 / 외부 링크 오픈
│       │   ├── views/match_view.dart                      # 매거진 카드 리스트 + 연도 선택 + Pull-to-refresh (Stitch 225c4429594e4cb3835b154cbc861919)
│       │   ├── bindings/tournament_detail_binding.dart    # TournamentRepository(fenix) + TournamentDetailController lazyPut
│       │   ├── controllers/tournament_detail_controller.dart # 대회별 경기 fetch / 종목 칩 전환 / race-condition 가드
│       │   ├── views/tournament_detail_view.dart          # 종목 칩(MS/WS/MD/WD/XD) + 경기 리스트 + "대진표 보기" CTA
│       │   ├── bindings/tournament_participants_binding.dart # TournamentRepository(fenix) + TournamentParticipantsController lazyPut — TASK-006
│       │   ├── controllers/tournament_participants_controller.dart # 종목별 참가 선수 fetch / 종목 칩 전환 / race-condition 가드(_inflightToken) — TASK-006
│       │   └── views/tournament_participants_view.dart    # 종목 칩(MS/WS/MD/WD/XD) + 참가 선수 매거진 카드 리스트 + Pull-to-refresh — TASK-006
│       │
│       ├── player/                                        # [선수] BWF 랭킹 선수 리스트 (매거진) — TASK-005
│       │   ├── bindings/player_binding.dart                # PlayerRepository + PlayerController lazyPut
│       │   ├── controllers/player_controller.dart          # 카테고리별 선수 fetch / 로딩·에러 상태 / 카테고리 전환 / race-condition 가드
│       │   └── views/player_view.dart                      # 매거진 카드 리스트 + 카테고리 칩(MS/WS/MD/WD/XD) + Pull-to-refresh (Stitch eeae55cab3614d408743636d325e3b88)
│       │
│       ├── community/                                     # [커뮤니티] 바텀네비 4번 탭 — 목록 + 상세 + 작성/수정 + 온보딩 + 댓글 + 신고/차단/운영자 조치 — TASK-009,010,011,012,013
│       │   ├── bindings/community_binding.dart            # 딥링크(/community) 전용 — 바텀네비 경로는 AppBinding이 담당
│       │   ├── bindings/community_post_detail_binding.dart # /community/post 전용 (딥링크 대비 레포지토리 재등록 + CommunityCommentRepository) — TASK-010,012
│       │   ├── bindings/community_compose_binding.dart    # /community/compose 전용 (작성·수정 겸용) — TASK-011
│       │   ├── bindings/blocked_users_binding.dart         # /community/blocked-users 전용 (내정보 탭에서 진입) — TASK-013
│       │   ├── controllers/community_controller.dart      # 카테고리 필터 / 커서 무한 스크롤 / loadIfNeeded(최초 1회) / race-condition 가드 / applyPostUpdate·removePost(상세→목록 동기화) / openCompose(게이트 통과 후 전이) / openProfile(작성자 닉네임 탭 → 프로필 시트, authorId 없으면 무시 — TASK-017)
│       │   ├── controllers/community_post_detail_controller.dart # 상세 조회 / 좋아요 낙관적 토글+롤백 / 조회수 RPC 1회 / 본인 글 삭제 RPC / openEdit(게이트 통과 후 수정 모드) **+ 댓글 상태·액션**(loadComments·submitComment·deleteComment·startReply, threadedComments 트리 빌드 = 고아 대댓글 드롭 + 자식 없는 툼스톤 제외, comment_count 낙관적 ±1) **+ openProfile**(작성자·댓글 아바타 탭 → 프로필 시트, 탈퇴 사용자면 무시 — TASK-017) — TASK-010,011,012
│       │   ├── controllers/community_compose_controller.dart # 작성·수정 겸용 — 카테고리/제목/본문/이미지 상태, 금칙어 사전검증, 업로드→INSERT→실패 시 고아 롤백, 수정 시 업로드→UPDATE 성공→옛 path 삭제 — TASK-011. **작성 모드 카테고리 기본값 `defaultCategory='free'`**(목록이 「전체」라 물려받은 값이 null 이거나 CommunityController 미등록 딥링크일 때) — 수정 모드 `_applyPost` 는 원본 카테고리를 그대로 쓴다, TASK-018
│       │   ├── controllers/community_profile_controller.dart # 작성자 프로필 시트 상태(보기 전용) — userId + fallback 닉네임/아바타로 즉시 그린 뒤 onInit 에서 조회. **바인딩 없음**(라우트가 없는 시트라 CommunityProfileSheet.show 가 Get.put/Get.delete 를 소유) — TASK-017
│       │   ├── controllers/blocked_users_controller.dart  # 차단 목록 조회 / 확인 다이얼로그 → 차단 해제 → 목록 제거 + 커뮤니티 목록 refresh — TASK-013
│       │   ├── controllers/community_onboarding_controller.dart # 온보딩 시트 상태(닉네임 디바운스 중복검사 + 약관 동의) **+ static ensureCanWrite() 작성 게이트** (비로그인→로그인 / 정지→안내 / 닉네임·약관 미충족→시트). TASK-012 댓글도 이 게이트를 재사용한다 — TASK-011
│       │   ├── views/community_view.dart                  # 칩 + 게시글 카드 리스트 + Pull-to-refresh + 글쓰기 FAB (Stitch 미대응, PlayerView 레이아웃 준용)
│       │   ├── views/community_post_detail_view.dart      # 작성자 헤더 + 본문 + 이미지 그리드 + 댓글 섹션(헤더/리스트/빈 상태) + 하단 좋아요/댓글/조회 액션바 + 댓글 입력바 + 더보기(⋯) 진입점(시트·다이얼로그는 컨트롤러가 소유) — TASK-010,012,013. **body 탭 unfocus + 본문 `SelectableText.onTap` unfocus**(선택 텍스트가 탭을 소비해 body 래핑이 닿지 않는 유일한 위젯) — TASK-018
│       │   ├── views/blocked_users_view.dart              # 차단한 사용자 목록 — 아바타+닉네임+"차단 해제" (Stitch 미대응, FavoritePlayersView 구조 준용) — TASK-013
│       │   ├── views/community_terms_view.dart            # 커뮤니티 이용규칙 상시 열람 (Apple 1.2 요건, 바인딩 없음 — 애셋만 읽는다) — TASK-013
│       │   ├── views/community_compose_view.dart          # 카테고리 칩 + 제목/본문 + 글자수 카운터 + 이미지 첨부 바 + PopScope 이탈 확인 (Stitch 미대응, SignUpView 폼 준용) — TASK-011. body 탭 unfocus — TASK-018
│       │   └── views/widgets/                             # community_category_chips.dart, community_post_card.dart, community_image_grid.dart(1장은 원본 비율 실측 후 3/4~16/9 clamp · 모든 타일/`+N` 오버레이가 뷰어 진입점 — TASK-016), community_image_viewer.dart(전체화면 뷰어 — PageView + InteractiveViewer, 확대 중 페이지 스크롤 차단 · 페이지 전환 시 배율 리셋, 신규 패키지 없음 — TASK-016), community_eula_sheet.dart(온보딩 시트 — TASK-011, `Scaffold` 가 없어 시트 `Container` 를 unfocus 로 감쌌다 — TASK-018), community_eula_markdown.dart(이용규칙 경량 렌더러 — 시트/열람 화면 공용, TASK-013), community_comment_tile.dart(댓글/대댓글/툼스톤 + 더보기 ⋯ — TASK-012,013), community_comment_input_bar.dart(pill 입력창 + 라임 전송, 답글 헤더 — TASK-012), community_more_sheet.dart(본인=수정/삭제 · 타인=신고/차단 · 운영자=숨김/복구/강제삭제/정지/신고종결 — TASK-013), community_profile_sheet.dart(작성자 프로필 — 아바타 72 + 닉네임 + `2026년 6월 가입`, **액션 없음**. 진입점 3곳: 상세 작성자 행 · 댓글 아바타 · 목록 카드 닉네임(카드 InkWell 과 겹치지 않게 opaque 로 탭 소비) — TASK-017), community_report_sheet.dart(사유 6종 라디오 + 상세 500자 + 접수 후 "이 사용자 차단하기" CTA — TASK-013, **라이브 채팅이 targetLabel='사용자' 로 그대로 재사용 — TASK-014**)
│       │
│       ├── live_match_chat/                               # [라이브 채팅] 경기별 실시간 채팅방 (바텀네비 밖, 라이브 카드에서 진입)
│       │   ├── bindings/live_match_chat_binding.dart      # ChatMessageRepository(fenix) + CommunityModerationRepository(fenix, 신고/차단 공용) + LiveMatchChatController — TASK-014
│       │   ├── controllers/live_match_chat_controller.dart # 메시지 로드(before 커서 역방향 페이지네이션) / Realtime 구독(INSERT·DELETE·스코어 UPDATE) / Presence 접속자 dedupe / 라이브 스코어 가리기 토글 **+ 신고·차단**(reportMessage = target_type 'user' + 메시지 본문을 detail 에 인용, confirmBlockUser·blockUser, _blockedUserIds 집합으로 초기 로드·loadMore·Realtime INSERT 3경로 필터 — **RLS `lmc_select_all` 이라 서버가 걸러 주지 않는다**) — TASK-014
│       │   ├── views/live_match_chat_view.dart            # AppBar(접속자 수 + 스코어 가리기) + reverse 리스트(데이 디바이더/버블/라이브 pill) + pill 입력바 / 롱프레스 = 본인 삭제 · 타인 신고·차단 액션시트 — TASK-014. body 탭 unfocus — TASK-018
│       │   └── views/widgets/                             # chat_day_divider.dart, chat_live_status_pill.dart, chat_message_bubble.dart(롱프레스는 본인·타인 모두 발화, 분기는 View 가 결정 — TASK-014)
│       │
│       ├── my_info/                                       # [내 정보] 비로그인 상태 진입 화면 — TASK-001
│       │   ├── bindings/my_info_binding.dart
│       │   ├── controllers/my_info_controller.dart        # goToLogin / goToSignUp / isLoggedIn placeholder + goToBlockedUsers · goToCommunityTerms(비로그인도 열람 가능) — TASK-013 / goToHelp · goToFeedback = url_launcher mailto(제목에 PackageInfo 버전, 실패 시 주소 안내 스낵바) — Apple 1.2 개발자 연락처, TASK-014
│       │   └── views/my_info_view.dart                    # 다크 + 라임 옐로우 안내 화면 (Stitch 8329646c315c48fdb5bfa15f9a643418) + 메뉴 "차단한 사용자" / "커뮤니티 이용규칙" — TASK-013
│       │
│       ├── login/                                         # [로그인] 이메일/비밀번호 폼 — TASK-002
│       │   ├── bindings/login_binding.dart
│       │   ├── controllers/login_controller.dart          # TextEditingController 관리 + 이메일/비밀번호 유효성
│       │   └── views/login_view.dart                      # Stitch a7cf71e767ad4610a93373028a9c3ab0 / body 탭 unfocus — TASK-018
│       │
│       └── sign_up/                                       # [회원가입] 이메일 인증 화면 — TASK-003
│           ├── bindings/sign_up_binding.dart
│           ├── controllers/sign_up_controller.dart        # 이메일/인증코드 입력 + 타이머 placeholder
│           └── views/sign_up_view.dart                    # Stitch 3616350c62da4e95906ab4d458eb7ebc / body 탭 unfocus — TASK-018
│
├── services/                                              # [글로벌 서비스] GetxService 기반 싱글톤
│   └── supabase_service.dart                              # Supabase 클라이언트 부팅 (.env의 URL/anon key 로드 + Get.put)
│
└── theme/                                                 # [디자인 토큰] 다크/라이트 ColorScheme + 타이포 + 스페이싱
    ├── app_colors.dart                                    # ColorScheme.dark/light (액센트: 라임 옐로우 #C3F400)
    ├── app_typography.dart                                # Chivo / Source Sans 3 기반 TextStyle 세트
    ├── app_spacing.dart                                   # AppSpacing(base/container/stackGap) + AppRadius(sm~full)
    └── app_theme.dart                                     # ThemeData 빌더 (Material 3 + 다크 우선)
```

## 화면 플로우

```
[AppView (바텀네비)]
   │
   ├── 뉴스(Home/News)          ─► [NewsView] 활성 대회 캐러셀 + 라이브 매치 캐러셀 + 오늘 경기(results/upcoming 토글) + 뉴스 카드
   ├── 경기(Match)               ─► [MatchView] 대회 리스트
   │                              │
   │                              └─► [TournamentDetailView] 대회 상세 (경기 배열)
   │                                   │
   │                                   └─► "대진표 보기" CTA ─► [TournamentParticipantsView] 참가 선수 (종목별) — TASK-006
   │
   ├── 선수(Player)              ─► BWF 랭킹 선수 리스트 (매거진, get-players Edge Function)
   │                              │
   │                              └─► [PlayerDetailView] 선수 상세
   │
   ├── 커뮤니티(Community)        ─► 카테고리별 게시글 목록 (community_post_feed 뷰, .from() 직접 접근) — TASK-009
   │                              │
   │                              └─► [CommunityPostDetailView] 게시글 상세 — 좋아요/조회수/본인 글 삭제 — TASK-010
   │
   └── 내정보(MyInfo)
            │
            └── 로그인 버튼 ─► [LoginView] ─► "회원가입" ─► [SignUpView (이메일 인증)]
```

## 공통 UX 규칙

- **키보드 내리기 (TASK-018)**: 텍스트 입력이 있는 화면은 `Scaffold` 의 **body 를** `GestureDetector(onTap: () => FocusScope.of(context).unfocus(), behavior: HitTestBehavior.opaque)` 로 감싼다. `Scaffold` 자체를 감싸면 AppBar 탭이 먹지 않고, 공용 헬퍼 위젯은 만들지 않는다(3줄 래핑).
  - 적용 화면 7종: `community_post_detail_view` · `community_compose_view` · `community_eula_sheet`(Scaffold 가 없어 시트 `Container` 를 감싼다) · `live_match_chat_view` · `profile_edit_view` · `login_view` · `sign_up_view`
  - `HitTestBehavior.opaque` 는 자식 제스처를 삼키지 않는다 — 히트테스트가 깊은 자식부터 등록되므로 아레나에서 안쪽 `GestureDetector`/`InkWell` 이 이긴다. 기존 중첩 `GestureDetector` 를 통합하지 않는다.
  - **주의**: `SelectableText` 처럼 자체 탭 인식기를 가진 위젯은 부모 래핑이 닿지 않으므로 그 위젯의 `onTap` 에 unfocus 를 직접 붙인다(현재 게시글 상세 본문 1곳).
  - `resizeToAvoidBottomInset` 은 화면별 기존 설정을 그대로 둔다.

## 데이터 레이어 / 외부 의존성

- **API 호출 방식**: 모든 API는 Supabase Edge Function (`Supabase.instance.client.functions.invoke('<name>')`) 경유. Dio·http·PostgREST 직접 접근 금지.
- **.env 키**: `SUPABASE_URL`, `SUPABASE_ANON_KEY` (rally 루트 `.env`). 누락 시 SupabaseService.initialize가 경고 로그만 남기고 정상 부팅.
- **Edge Function 매핑**:
  - `match` 모듈 ↔ `supabase/functions/get-tournaments` (대회 목록)
  - `match` 모듈 ↔ `supabase/functions/get-tournament` (대회 상세)
  - `match` 모듈 ↔ `supabase/functions/get-tournament-matches` (경기 목록)
  - `match` 모듈 ↔ `supabase/functions/get-tournament-participants` (참가 선수, 종목별) — TASK-006
  - `player` 모듈 ↔ `supabase/functions/get-players` (선수 목록)
  - `player` 모듈 ↔ `supabase/functions/get-player` (선수 상세)
  - `news` 모듈(홈) ↔ `supabase/functions/get-live-matches` (현재 진행 중 라이브 매치 목록 — `tournament_status='live'`)
  - `news` 모듈(홈) ↔ `supabase/functions/get-today-matches` (KST 오늘 매치 — results/upcoming 분류, `bwf_live_matches` 중 `tournament_status='live'`만 제외 / 응답에 `match_time_kst_hhmm` 사전계산 포함) — TASK-007
- **푸시 알림 (관심 선수 라이브 경기 시작)**: `bwf_live_matches`에 새 라이브 행 INSERT(또는 post→live 재승격) 시 DB 트리거 `trg_notify_favorite_live_match`가 `favorite_players`×`profiles.notifications_enabled` 유저를 찾아 `notifications`에 INSERT → 기존 웹훅(`send-push-on-notification`)이 `send-push` Edge Function으로 FCM 발송. 유저+경기당 1회만(부분 유니크 인덱스 dedup). 마이그레이션: `supabase/migrations/20260720000000_live_match_start_notifications.sql`

## 주요 의존성

- `get` ^4.6.6 — 상태관리 / 라우팅 / DI
- `supabase_flutter` ^2.5.0 — Edge Function 호출 / 세션 JWT 자동 첨부
- `flutter_dotenv` ^5.1.0 — `.env` 환경변수 로드
- `cached_network_image` ^3.3.1 — 대회 로고 / 국기 캐시
- `url_launcher` ^6.2.6 — 대회 상세 외부 브라우저 오픈

## 라우트 상수 (Routes)

```dart
abstract class Routes {
  static const APP = '/app';
  static const NEWS = '/news';
  static const MATCH = '/match';
  static const MATCH_DETAIL = '/match/detail';
  static const MATCH_PARTICIPANTS = '/match/participants';  // TASK-006
  static const PLAYER = '/player';
  static const PLAYER_DETAIL = '/player/detail';
  static const COMMUNITY = '/community';                  // TASK-009
  static const COMMUNITY_POST_DETAIL = '/community/post'; // TASK-010
  static const COMMUNITY_COMPOSE = '/community/compose';  // TASK-011
  static const COMMUNITY_BLOCKED_USERS = '/community/blocked-users'; // TASK-013
  static const COMMUNITY_TERMS = '/community/terms';      // TASK-013
  static const MY_INFO = '/my-info';
  static const LOGIN = '/login';
  static const SIGN_UP = '/sign-up';
}
```

## Stitch 매핑 (rally 프로젝트 ID: 307006344264476289)

| View | Stitch 화면명 | screenId |
|------|---------------|----------|
| `match_view.dart` | 국제 대회 리스트 (매거진) | `225c4429594e4cb3835b154cbc861919` |
| `tournament_detail_view.dart` | 대회 상세 - 경기 리스트 | TBD |
| `tournament_participants_view.dart` | 대회 상세 - 참가 선수 (TASK-006) | TBD |
| `player_view.dart` | 선수 리스트 (매거진) | `eeae55cab3614d408743636d325e3b88` |
| `community_view.dart` | (Stitch 미대응 — PlayerView 레이아웃 준용) | — |
| `community_post_detail_view.dart` | (Stitch 미대응 — CommunityView / PlayerDetailView 톤 준용) | — |
| `community_comment_tile.dart` | (Stitch 미대응 — CommunityPostCard 작성자 행 준용) | — |
| `community_comment_input_bar.dart` | (Stitch 미대응 — LiveMatchChatView pill 입력창 준용) | — |
| `community_compose_view.dart` | (Stitch 미대응 — SignUpView 입력 폼 준용) | — |
| `blocked_users_view.dart` | (Stitch 미대응 — FavoritePlayersView 리스트 준용) | — |
| `community_terms_view.dart` | (Stitch 미대응 — FavoritePlayersView 앱바 톤 준용) | — |
| `community_more_sheet.dart` / `community_report_sheet.dart` | (Stitch 미대응 — CommunityEulaSheet 시트 톤 준용) | — |
| `community_profile_sheet.dart` | (Stitch 미대응 — CommunityMoreSheet 시트 톤 준용) | — |
| `community_image_viewer.dart` / `community_image_grid.dart` | (Stitch 미대응 — 표준 풀스크린 갤러리 패턴 / 기존 그리드 디자인 유지) | — |
| `player_detail_view.dart` | 선수 상세 | TBD |
| `my_info_view.dart` | 내 정보 (매거진) | `8329646c315c48fdb5bfa15f9a643418` |
| `login_view.dart` | 로그인 (Kinetic Court) | `a7cf71e767ad4610a93373028a9c3ab0` |
| `sign_up_view.dart` | 회원가입 - 이메일 인증 | `3616350c62da4e95906ab4d458eb7ebc` |
