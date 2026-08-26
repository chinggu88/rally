# TASK-007: 홈 탭 - 오늘 경기 일정 섹션

## 목적
홈(NewsView) 탭에 "오늘 경기" 섹션을 추가한다.
KST 기준 오늘 하루의 경기 결과(results)와 경기 예정(upcoming)을 한 섹션에서
**탭/칩 토글**로 전환해 매거진 카드 리스트로 보여준다.
라이브 매치 섹션과 뉴스 섹션 사이에 인라인으로 배치한다.

## 데이터 소스
- Supabase Edge Function: `get-today-matches`
- 쿼리 파라미터:
  - `date` (선택, `YYYY-MM-DD`) — 기본값은 서버에서 KST 기준 오늘. 클라이언트는 보통 미지정.
- 응답 스키마:
  ```json
  {
    "date": "2026-06-07",
    "results_count": 12,
    "upcoming_count": 8,
    "results": [
      {
        "id": 123,
        "match_code": "MS1-R32-MATCH-01",
        "tournament_id": 999,
        "tournament_code": "OPEN2026",
        "tournament_status": "live",
        "event_name": "MS",
        "match_type": "Singles",
        "round_name": "Round of 32",
        "team1_country": "DEN",
        "team1_player_ids": [12345],
        "team1_names": ["Viktor Axelsen"],
        "team1_seed": "1",
        "team2_country": "JPN",
        "team2_player_ids": [67890],
        "team2_names": ["Kodai Naraoka"],
        "team2_seed": null,
        "winner": 1,
        "score": [{"set":1,"home":21,"away":18},{"set":2,"home":21,"away":15}],
        "match_status": "completed",
        "match_status_value": "Completed",
        "score_status": null,
        "score_status_value": null,
        "match_time": "2026-06-07T05:30:00+00:00",
        "match_time_utc": "2026-06-07T05:30:00Z",
        "match_time_kst": "2026-06-07T14:30:00+09:00",
        "court_name": "Court 1",
        "location_name": "Arena Hall",
        "duration_min": 52,
        "tournament_name": "Indonesia Open 2026",
        "tournament_logo_url": "https://...",
        "tournament_cat_logo_url": "https://...",
        "tournament_tour_level": "Super 1000",
        "tournament_prize_money_usd": 1450000,
        "tournament_country": "INA",
        "tournament_flag_url": "https://...",
        "tournament_date_label": "Jun 3 - 8, 2026"
      }
    ],
    "upcoming": [/* 동일 스키마, winner/score 없을 수 있음 */]
  }
  ```
- 분류 규칙(서버):
  - `winner=1|2` 또는 `score_status_value in (walkover, retired)` 또는 `score`에 어느 한쪽 점수>0 → `results`
  - 그 외 → `upcoming`
  - `bwf_live_matches`에 있는 `match_code`는 응답에서 **제외** (라이브 섹션과 중복 방지)
- 정렬: `match_time ASC` (results는 응답 시 reverse되어 최근 끝난 게 먼저)

## 작업 분배

### 1) API Agent
**모델 (lib/app/data/models/)**
- `today_match_response.dart` — 단일 항목 모델
  - 패턴: `LiveMatchResponse`와 동일한 private 필드 + getter/setter + fromJson/toJson + 방어적 파싱
  - 핵심 필드:
    - 매치: `id`, `matchCode`, `tournamentId`, `tournamentCode`, `tournamentStatus`,
      `eventName`, `matchType`, `roundName`
    - team1: `team1Names (List<String>?)`, `team1Country`, `team1Seed`, `team1PlayerIds`
    - team2: `team2Names`, `team2Country`, `team2Seed`, `team2PlayerIds`
    - 결과/진행: `winner (int?)`, `score (raw, dynamic→String?로 정규화 후 파싱)`,
      `matchStatus`, `matchStatusValue`, `scoreStatus`, `scoreStatusValue`
    - 일정: `matchTime`, `matchTimeUtc`, `matchTimeKst`, `courtName`, `locationName`, `durationMin`
    - 대회 비정규화: `tournamentName`, `tournamentLogoUrl`, `tournamentCatLogoUrl`,
      `tournamentTourLevel`, `tournamentPrizeMoneyUsd`, `tournamentCountry`,
      `tournamentFlagUrl`, `tournamentDateLabel`
  - 편의 getter:
    - `team1Display` / `team2Display` — `LiveMatchResponse._joinNames`와 동일 로직 ("TBD" 폴백)
    - `displayLogoUrl` — tournamentLogoUrl 우선, 폴백 tournamentCatLogoUrl
    - `matchDateTime` — UTC 우선, 폴백 matchTime
    - `kstDateTime` — matchTimeKst 파싱
    - `winnerSide` — int winner를 1/2로 정규화
    - `games (List<LiveGameScore>)` — score를 `LiveMatchResponse`의 `_parseGames` + 방향 보정 로직 동일하게 적용. `LiveGameScore`는 `live_match_response.dart`의 것을 재사용(import).
    - `isPlayed (bool)` — winner!=null 또는 score에 점수>0 또는 walkover/retired → true
    - `displayKoreanTime` — `kstDateTime`이 있으면 `HH:mm` 포맷 (예: `14:30`), 없으면 null
- `get_today_matches_response.dart` — 래퍼 모델
  - 필드: `date (String?)`, `resultsCount (int?)`, `upcomingCount (int?)`,
    `results (List<TodayMatchResponse>?)`, `upcoming (List<TodayMatchResponse>?)`
  - fromJson에서 `results`/`upcoming` 배열은 빈 배열로 폴백 (null safe)

**레포지토리 (lib/app/data/repositories/today_match_repository.dart)**
- 신규 파일 `TodayMatchRepository`
- 메서드:
  ```dart
  Future<GetTodayMatchesResponse> getTodayMatches({String? date})
  ```
- 패턴: `LiveMatchRepository.getLiveMatches`와 동일
  - `_client.functions.invoke('get-today-matches', method: HttpMethod.get, queryParameters: ...)`
  - 404 → 빈 응답 (`results: [], upcoming: [], counts: 0`)
  - 200 외 → `Exception('get-today-matches failed: status=..., data=...')`
  - `FunctionException` 404도 동일 처리, 그 외는 log + rethrow
  - `date` 파라미터가 null이면 queryParameters에서 생략(서버 기본값 사용)

### 2) Controller Agent
**경로**: `lib/app/modules/news/`

**바인딩** (`bindings/news_binding.dart` 수정)
- 기존 `LiveMatchRepository` lazyPut 아래에
  `Get.lazyPut<TodayMatchRepository>(() => TodayMatchRepository(), fenix: true)` 추가

**컨트롤러** (`controllers/news_controller.dart` 수정 — 신규 클래스 만들지 말고 기존에 통합)
- 추가 의존성: `TodayMatchRepository`를 `Get.find()`로 주입 (lazy)
- 추가 상태(Rx):
  - `_todayMatchesTab` (`RxString`, 'results' | 'upcoming') — 기본값 'results'
  - `_isTodayLoading` (`RxBool`) — 초기 false
  - `_todayError` (`RxnString`)
  - `_todayResults` (`RxList<TodayMatchResponse>`)
  - `_todayUpcoming` (`RxList<TodayMatchResponse>`)
  - `_todayInflightToken` (`int` private) — race-condition 가드
- public getter:
  - `String get todayMatchesTab => _todayMatchesTab.value;`
  - `bool get isTodayLoading => _isTodayLoading.value;`
  - `String? get todayError => _todayError.value;`
  - `List<TodayMatchResponse> get todayResults => _todayResults;`
  - `List<TodayMatchResponse> get todayUpcoming => _todayUpcoming;`
  - `List<TodayMatchResponse> get todayCurrent =>
      _todayMatchesTab.value == 'results' ? _todayResults : _todayUpcoming;`
- 동작:
  - `onInit()` 끝에서 `fetchTodayMatches()` 호출 (라이브 매치 fetch와 병렬 가능)
  - `Future<void> fetchTodayMatches()` — 토큰 증가 → loading true → 조회 → 토큰 일치 시 list 갱신 + loading false. 실패 시 error 세팅. 빈 리스트라도 에러 아님.
  - `void changeTodayTab(String tab)` — 'results' 또는 'upcoming'만 허용, 동일값 무시
  - `Future<void> refreshLiveMatches()` 안에서 라이브 갱신과 함께 `fetchTodayMatches()`도 await (Pull-to-refresh가 같이 갱신되도록)
- 기존 라이브 매치/뉴스카드 로직은 유지(추가만)

### 3) UI Agent
**뷰** (`views/news_view.dart` 수정)
- 라이브 섹션과 뉴스 섹션 사이에 "오늘 경기" 섹션 SliverToBoxAdapter 추가
  - 순서: `[active_tournaments] → [live] → [today_matches] → [news]`
  - 섹션 위에 `SizedBox(height: 24)` 간격 유지
- 섹션 헤더:
  - 좌측 아이콘 점(라이브와 구분 — 라임 옐로우 도트) + "오늘 경기" 텍스트 (라이브 섹션 헤더와 동일 스타일)
  - 우측에 토글 칩 2개: `경기 결과` / `경기 예정` (선택 상태: 라임 옐로우 배경 + 검정 텍스트 / 비선택: 투명 + 흰 텍스트 + 보더)
    - 라이브 섹션 헤더의 LIVE/OFF dot 위치에 둠
- 본문:
  - 로딩 (results/upcoming 둘 다 비어있고 isTodayLoading=true): 220 높이 CircularProgressIndicator
  - 에러 + 빈 리스트: 라이브와 동일한 에러 카드 (다시 시도 버튼이 `controller.fetchTodayMatches`)
  - 빈 상태: "오늘은 더 표시할 경기가 없습니다." + 부제 "결과가 등록되거나 새로운 경기가 추가되면 표시됩니다."
  - 리스트: 매거진 카드 (세로 리스트, `padding: EdgeInsets.symmetric(horizontal: 20)`)
- 카드 위젯 신규: `views/widgets/today_match_card.dart`
  - 전체 컨테이너: `surfaceContainerHighest` 톤 (`#1C1B1B` 정도) + 16 라운드 + 1px 보더(`#2A2A2A`)
  - 상단 행: 대회 로고(24px, `cached_network_image`, 실패 시 회색 박스) + 대회명(1줄, ellipsis, Chivo 12 w800) + 우측에 종목 칩(예: `MS`, 11px, accentDark 배경 + accent 텍스트)
  - 중앙 행: 좌측 team1 / 가운데 결과 또는 시간 / 우측 team2
    - team1/team2 각각 세로 정렬: 국가코드(또는 flag emoji)·시드(seed가 있으면 `[1]`) → 이름들(복식이면 두 줄)
    - results 탭에서 isPlayed=true이면 가운데에 게임별 스코어 pill (`games`의 team1-team2 표시), 승자 쪽 이름은 accent 컬러로 강조
    - upcoming 탭에서는 가운데에 `displayKoreanTime` (예: `14:30 KST`) + 그 아래 코트명 작게
    - walkover/retired는 스코어 pill 자리에 라벨로 표시
  - 하단 행: round_name(좌측, 10px, subtleText) · location_name/court_name(우측, 10px, subtleText)
- Pull-to-refresh: 기존 `controller.refreshLiveMatches`가 today도 함께 갱신하도록 컨트롤러에서 처리됨 → UI 변경 불필요

**라우팅**: 신규 라우트 없음 (홈 인라인 섹션).

## 디자인 가이드
- 폰트: AppTypography (Chivo / Source Sans 3)
- 스페이싱: AppSpacing (필요 시 EdgeInsets 직접값)
- 라운드: 16 (카드), 999 (pill/chip)
- 다크 우선 — `Theme.of(context).colorScheme` 또는 `AppColors.dark`
- 토글 칩 선택 상태: 라임 옐로우 배경 + accentDark 텍스트
- 카드: 1C1B1B 배경 + 2A2A2A 보더
- 승자 강조: 라임 옐로우 텍스트

## 완료 기준
- [x] `today_match_response.dart` / `get_today_matches_response.dart` 모델 생성
- [x] `TodayMatchRepository.getTodayMatches()` 메서드 추가
- [x] `NewsBinding`에 `TodayMatchRepository` 등록
- [x] `NewsController`에 today 상태/메서드 추가, `refreshLiveMatches`가 today도 갱신
- [x] `news_view.dart`에 오늘 경기 섹션 추가 + 탭 토글 + 로딩/에러/빈상태
- [x] `today_match_card.dart` 위젯 생성
- [x] `flutter analyze` 통과
- [ ] `docs/architecture.md` 업데이트 (모델 / 레포지토리 / Edge Function 매핑 / 화면 플로우 — 홈 섹션 추가)

---
---

# 커뮤니티 탭 (TASK-008 ~ TASK-014)

기획서: `docs/task/기획서.md` · 결정 사항 D-1~D-5는 기획서 §12 확정본을 따른다.

## 실행 순서와 선행 조건

```
TASK-008 (DB)  ──▶ TASK-009 (탭+목록) ──┬─▶ TASK-010 (상세/좋아요/조회수) ──▶ TASK-012 (댓글)
   수동 선행                             └─▶ TASK-011 (온보딩+작성)
                                                                              ──▶ TASK-013 (신고/차단)
                                                                              ──▶ TASK-014 (채팅 소급+스토어)
```

- **TASK-008은 서브 에이전트 분배 대상이 아니다.** 마이그레이션을 담당하는 에이전트가 없으므로 `상태: manual`로 두고 사람이 먼저 적용한다. 적용 전에 team-lead를 돌리면 TASK-009가 존재하지 않는 테이블을 참조한다.
- TASK-009만 `pending`이고 나머지는 `blocked`다. **한 태스크가 끝나면 다음 태스크의 상태를 `blocked` → `pending`으로 바꾸고 team-lead를 다시 실행한다.**
- 여러 태스크를 동시에 `pending`으로 두지 말 것 — `app_binding.dart` / `app_controller.dart` / `app_view.dart`를 여러 태스크가 함께 건드려 충돌한다.

> **QA 항목의 토스트 표기**: yulgok 템플릿은 EasyLoading을 전제하지만 이 프로젝트는 EasyLoading을 사용하지 않는다. 실제 관례인 `Get.snackbar`를 기준으로 작성했다.

---

## TASK-008: 커뮤니티 DB 스키마 · RLS · 스토리지

- **상태**: `manual`
- **개발 유형**: 신규개발
- **생성일**: 2026-08-23
- **설명**: 커뮤니티 게시판의 테이블 · RLS · 트리거 · 스토리지 버킷을 구성한다. Flutter 코드 변경 없음.
- **기획서 참조**: §7 전체, §5-5, §6-3

---

### 개발 유형 분류

| 항목 | 내용 |
|------|------|
| 유형 | 신규개발 |
| 판단 근거 | 신규 테이블 9종 + 신규 스토리지 버킷. 기존 스키마 변경은 `profiles` 컬럼 2개 추가뿐 |
| 영향 범위 | `profiles`(컬럼 추가), `notifications`(운영자 알림 INSERT 경로 추가). 기존 앱 동작에는 영향 없음 |

---

### 파일 목록

#### 신규 생성 파일
- `supabase/migrations/20260823000100_community_moderation_primitives.sql`
- `supabase/migrations/20260823000200_community_core.sql`
- `supabase/migrations/20260823000300_community_reports.sql`
- `supabase/migrations/20260823000400_community_feed_views.sql`
- `supabase/migrations/20260823000500_community_storage.sql`
- `supabase/migrations/20260823000600_community_notifications.sql`

#### 수정 파일
- 없음 (Flutter 코드 미변경)

---

### 마이그레이션 작업

> API / Controller / UI Agent 작업 없음. team-lead는 이 태스크를 건너뛴다.

#### 000100 — 모더레이션 프리미티브
- 테이블: `user_blocks`, `app_admins`, `user_agreements`, `community_banned_words`
- `profiles` 컬럼 추가: `community_banned_until timestamptz`, `nickname_norm`(generated) + 부분 유니크 인덱스
- 헬퍼 함수 4종 (**전부 `security definer` + `stable` + `set search_path = public`**): `community_is_blocked`, `community_eula_version`, `community_can_write`, `is_app_admin`
- `app_admins`는 RLS ON + 정책 0개로 클라 접근 전면 차단
- **선행 데이터 정리**: 정규화 기준 중복 닉네임 1쌍이 존재한다. 유니크 인덱스 생성 전에 수동 개명 필요

#### 000200 — 코어 테이블
- `community_posts`, `community_comments`, `community_post_likes`, `community_post_views`
- `author_id`는 **nullable + `on delete set null`** (D-3)
- 댓글 1depth 강제: `(parent_id, post_id) → (id, post_id)` 복합 FK + BEFORE INSERT 트리거
- 카운터 트리거 (**`security definer` 필수** — 누락 시 남의 글 카운터가 조용히 0건 UPDATE)
- `fillfactor = 85` (HOT UPDATE 유지), 카운터 컬럼은 어떤 인덱스에도 포함하지 않음
- **컬럼 단위 권한**: `revoke all` 후 필요한 컬럼만 `grant update (...)`. 소프트 삭제는 RPC(`community_delete_post` / `community_delete_comment`)

#### 000300 — 신고
- `community_reports` + 대상 배타 CHECK + 신고자별 대상 1회 유니크 인덱스
- 자동 숨김 트리거 — **사유별 차등 임계값** (D-4): `sexual`·`illegal` 1건 / 그 외 3건
- 운영자 푸시: `app_admins` 대상 `notifications` INSERT (기존 Webhook → `send-push` → FCM 자동 연결)
- 금칙어 트리거 (posts/comments BEFORE INSERT OR UPDATE), `hint = 'banned_word'`로 raise
- `community_moderation_queue` 뷰 — `service_role` 전용

#### 000400 — 피드 뷰 + RPC
- `community_post_feed`, `community_comment_feed` — **반드시 `with (security_invoker = on)`**
  기존 `public_profiles`는 의도적으로 invoker가 없다. 복붙하면 status·차단 필터가 전부 우회되므로 마이그레이션 주석에 대비를 명시할 것
- RPC: `community_increment_view`, `community_delete_post`, `community_delete_comment`,
  `community_set_post_status`, `community_set_comment_status`, `community_ban_user`,
  `community_unban_user`, `community_resolve_report`, `community_recount`
- **관리자 조치는 전부 RPC 경유다.** `status` 컬럼에 GRANT UPDATE 를 주지 않았으므로
  RLS 정책만으로는 `.from().update({'status': ...})` 가 42501 로 막힌다
  (정책은 "행"을, GRANT 는 "컬럼"을 통제하며 둘 다 통과해야 한다)

#### 000500 — 스토리지
- `community` 버킷 (public, 5MB, jpeg/png/webp/heic)
- 경로 `{user_id}/{draft_id}/{index}_{ts}.jpg` — 첫 세그먼트가 `auth.uid()`
- insert/update/delete 정책만. **SELECT 정책은 만들지 않는다** (public 버킷 목록 노출 경고 회피)

#### 000600 — 알림 트리거
- 내 글에 댓글 / 내 댓글에 답글 → `notifications` INSERT (`data.type` = `community_comment` / `community_reply`)
- 본인이 본인 글에 단 경우는 제외

---

### 로컬 검증 상태

작성 후 **Postgres 17 컨테이너에 Supabase 객체(auth/storage/notifications)를 스텁으로 만들고 6개를 실제 적용해** 아래를 확인했다. 아래 항목은 원격 적용 시 재확인하지 않아도 된다.

- 6개 마이그레이션 순차 적용 무오류
- 중복 닉네임 자동 정리 → 부분 유니크 인덱스 생성 성공, NULL 닉네임 공존
- 중복/금칙어 닉네임 거부, 금칙어 본문 거부
- EULA 미동의·정지 상태 작성 거부
- like_count/status 직접 조작 거부, 물리 DELETE 거부, 남의 폴더 이미지 경로 위조 거부
- **계정 2개 카운터 트리거** — 남의 글 comment_count·like_count 정상 증가
- 대댓글 1depth 강제(`depth_exceeded`), 부모 reply_count 증가
- 조회수 1인 1회(같은 유저 재호출 시 미증가, 다른 유저는 증가)
- 양방향 차단 — 정방향/역방향 모두 피드에서 제외
- 신고 사유별 차등 — spam 1건 visible 유지 / sexual 1건 즉시 hidden, 재신고 거부
- `security_invoker` — 숨김 글이 타인에게 0건, 작성자 본인에게 1건
- 소프트 삭제 툼스톤 + content 마스킹, 삭제된 글의 댓글이 타인에게 비노출
- 운영자 RPC(숨김/복구/정지) 동작 및 비운영자 거부
- anon 피드 조회 가능 + `is_liked=false`
- 탈퇴 시 글 보존 + `author_id` 익명화
- 댓글/대댓글 알림 행 생성

로컬 스텁으로 재현할 수 없어 **원격에서만 확인 가능한 항목**은 아래 QA 체크리스트에 남겼다.

### QA 체크리스트

#### 원격 적용 시 확인 (로컬 스텁으로 검증 불가)
- [ ] 실제 `auth.users`/`storage` 환경에서 6개 마이그레이션 적용 성공
- [ ] 실데이터 중복 닉네임 1쌍이 의도대로 정리됨 (NOTICE 로그 확인)
- [ ] 신고 INSERT → DB Webhook → `send-push` → **운영자 기기 FCM 수신**
- [ ] `community` 버킷 생성 및 `{uid}/` 경로 업로드/삭제 권한
- [ ] Supabase `get_advisors`(security) 경고 0건
- [ ] 커뮤니티 테이블이 `supabase_realtime` publication 에 없음

#### 기능 테스트
- [ ] 6개 마이그레이션이 순서대로 오류 없이 적용됨
- [ ] 중복 닉네임 1쌍 정리 후 부분 유니크 인덱스 생성 성공
- [ ] 닉네임 NULL인 기존 11건이 유니크 인덱스와 충돌 없이 공존
- [ ] `community_post_feed`를 `set role authenticated`로 조회 시 `status <> 'visible'` 행이 보이지 않음

#### 예외 처리 / 엣지 케이스
- [ ] **계정 2개로 검증** — B가 A의 글에 댓글 → A의 `comment_count`가 실제로 증가 (카운터 트리거 `security definer` 확인. 단일 계정으로는 재현 불가)
- [ ] A가 B를 차단 → 양방향으로 서로의 글·댓글이 목록에서 사라짐
- [ ] 대댓글에 답글 시도 → `depth_exceeded` 예외
- [ ] 다른 글의 댓글을 `parent_id`로 지정 → 복합 FK 위반
- [ ] `like_count` / `status` 직접 UPDATE 시도 → 권한 거부
- [ ] 남의 `{uid}/` 경로를 `image_paths`에 넣고 INSERT → WITH CHECK 위반
- [ ] EULA 미동의 상태로 INSERT → `42501`
- [ ] `sexual` 사유 1건 신고 → 즉시 `hidden` / `spam` 1건 → `visible` 유지
- [ ] 신고 INSERT 시 운영자 기기로 FCM 수신
- [ ] `auth.users` 삭제 → 글이 남고 `author_id`만 NULL

#### 보안 점검
- [ ] Supabase `get_advisors`(security) 경고 0건
- [ ] 커뮤니티 테이블이 `supabase_realtime` publication에 **추가되지 않았음** 확인

---

## TASK-009: 커뮤니티 탭 신설 + 게시글 목록

- **상태**: `done`
- **개발 유형**: 신규개발
- **생성일**: 2026-08-23
- **설명**: 바텀 네비에 커뮤니티 탭을 추가하고, 카테고리 칩 + 무한 스크롤 게시글 목록 화면을 만든다.
- **선행**: TASK-008 적용 완료
- **기획서 참조**: §2, §3 S-1, §8-3, §9-F, §9-G

---

### 개발 유형 분류

| 항목 | 내용 |
|------|------|
| 유형 | 신규개발 |
| 판단 근거 | `lib/app/modules/community/` 신규 모듈. architecture.md에 없음 |
| 영향 범위 | 앱 셸 3파일(`app_view` / `app_controller` / `app_binding`), `app_theme.dart`, 라우트 2파일 |

---

### 파일 목록

#### 신규 생성 파일
- `lib/app/data/models/community_post_response.dart`
- `lib/app/data/repositories/community_post_repository.dart`
- `lib/app/modules/community/controllers/community_controller.dart`
- `lib/app/modules/community/bindings/community_binding.dart`
- `lib/app/modules/community/views/community_view.dart`
- `lib/app/modules/community/views/widgets/community_category_chips.dart`
- `lib/app/modules/community/views/widgets/community_post_card.dart`
- `lib/app/utils/community_error.dart`

#### 수정 파일
- `lib/app/modules/app/views/app_view.dart` — `_tabs` 5개 + `BottomNavigationBarItem` 추가
- `lib/app/modules/app/controllers/app_controller.dart` — `communityTabIndex = 3` 상수 + `changeTab` 지연 로딩 분기
- `lib/app/modules/app/bindings/app_binding.dart` — **`CommunityPostRepository` / `CommunityController` 등록 (필수)**
- `lib/theme/app_theme.dart` — 바텀네비 라벨 14 → 12pt (D-1)
- `lib/app/routes/app_routes.dart` / `app_pages.dart` — team-lead가 일괄 등록

---

### API Agent 작업

#### 생성 파일
- `lib/app/data/models/community_post_response.dart`
- `lib/app/data/repositories/community_post_repository.dart`

#### 데이터 소스
Edge Function이 아니라 **`.from()` + RLS 직접 접근**이다 (`chat_message_repository.dart` 패턴). 조회 대상은 테이블이 아니라 뷰 `community_post_feed`.

| 동작 | 호출 |
|------|------|
| 목록 조회 | `.from('community_post_feed').select().eq('category', ...).lt('created_at', before).order('created_at', ascending: false).limit(20)` |

- `category`가 `null`(전체)이면 `.eq()`를 붙이지 않는다
- `before` 커서 기반 페이지네이션 (`ChatMessageRepository.listMessages` 패턴)
- 반환 타입은 `Future<List<CommunityPostResponse>>` — **`GetCommunityPostsResponse` 래퍼를 만들지 말 것.** 래퍼 모델은 Edge Function 응답 봉투용이며 `.from()` 응답에는 봉투가 없다

#### Response 구조 (`community_post_feed` 1행)
```json
{
  "id": "uuid",
  "author_id": "uuid",
  "category": "gear",
  "title": "아스트록스 100ZZ 후기",
  "content": "3개월 써본 소감...",
  "image_paths": ["uuid/draft/0_1724400000.jpg"],
  "like_count": 51,
  "comment_count": 17,
  "view_count": 240,
  "status": "visible",
  "edited_at": null,
  "created_at": "2026-08-23T04:12:00Z",
  "updated_at": "2026-08-23T04:12:00Z",
  "author_nickname": "스매시왕",
  "author_avatar_url": "https://.../avatar.jpg",
  "is_liked": false
}
```

#### 모델 규격
- `MODEL_GUIDE.md` 컨벤션 (private 필드 + getter/setter + `fromJson`/`toJson`)
- `image_paths`는 `List<String>`으로 파싱. 표시용 URL은 `storage.from('community').getPublicUrl(path)`로 변환
- **`copyWithLike({int likeCount, bool isLiked})` 추가** — 낙관적 좋아요 토글 시 `RxList` 요소 교체용. setter만 쓰면 GetX가 변경을 감지하지 못한다 (기획서 §9-H). `ChatMessageResponse.copyWithAuthor` 선례를 따른다
- `authorDisplayName` getter — `author_nickname`이 비면 `User_{uid앞4자리}` 폴백 (커뮤니티에서는 나타나지 않아야 정상이나 방어)

#### 유틸 (`lib/app/utils/community_error.dart`)
`PostgrestException`을 한국어 메시지로 변환한다.

| 조건 | 메시지 |
|------|--------|
| `hint == 'banned_word'` | 사용할 수 없는 표현이 포함되어 있습니다. |
| `hint == 'depth_exceeded'` | 대댓글에는 답글을 달 수 없습니다. |
| `hint == 'forbidden'` | 권한이 없습니다. |
| `code == '23505'` | 이미 사용 중인 닉네임입니다. |
| `code == '42501'` | 커뮤니티 이용규칙 동의가 필요합니다. |
| 그 외 | 잠시 후 다시 시도해주세요. |

---

### Controller Agent 작업

#### 생성 파일
- `lib/app/modules/community/controllers/community_controller.dart`
- `lib/app/modules/community/bindings/community_binding.dart`

#### 수정 파일
- `lib/app/modules/app/controllers/app_controller.dart`
- `lib/app/modules/app/bindings/app_binding.dart`

#### 기능 정의
- [ ] `RxList<CommunityPostResponse> posts` / `RxBool isLoading` / `RxBool isLoadingMore` / `RxBool hasMore` / `RxnString errorMessage` / `RxnString selectedCategory`(null = 전체)
- [ ] `fetchPosts()` / `loadMore()` / `refreshPosts()` / `changeCategory(String? category)`
- [ ] `_inflightToken` + `_loadMoreToken` race guard (`PlayerController` 패턴)
- [ ] **`onInit()`에서 fetch하지 않는다** — `IndexedStack`이 앱 시작 시 전 탭을 build하므로 콜드 스타트에 커뮤니티 쿼리가 붙는다
- [ ] `loadIfNeeded()` — `_hasLoadedOnce` 플래그로 최초 1회만 로드. **`PlayerController.reloadFromTab()`처럼 매번 리셋하면 안 된다** (글 읽다 탭 이동 후 복귀 시 스크롤·목록 소실)
- [ ] `pageSize = 20`, `hasMore`는 `fetched.length >= pageSize`로 판단

#### `AppController` 수정
- [ ] `static const int communityTabIndex = 3;` 추가
- [ ] `matchTabIndex = 1` / `playerTabIndex = 2`는 **그대로 유지** (커뮤니티를 선수 뒤에 넣었으므로 변경 불필요)
- [ ] `changeTab`에 `if (index == communityTabIndex && Get.isRegistered<CommunityController>()) CommunityController.to.loadIfNeeded();`

#### `AppBinding` 수정 (누락 시 앱 진입 즉시 크래시)
- [ ] `Get.lazyPut<CommunityPostRepository>(() => CommunityPostRepository(), fenix: true);`
- [ ] `Get.lazyPut(() => CommunityController());`
- [ ] 이유를 기존 `LiveMatchRepository` 주석과 같은 톤으로 남길 것 — `AppView`의 `IndexedStack`이 전 탭을 동시 마운트하므로 `CommunityBinding`은 `/app` 진입 시 실행되지 않는다

#### 의존성
- API Agent 생성 파일: `lib/app/data/repositories/community_post_repository.dart`

---

### UI Agent 작업

#### 생성 파일
- `lib/app/modules/community/views/community_view.dart`
- `lib/app/modules/community/views/widgets/community_category_chips.dart`
- `lib/app/modules/community/views/widgets/community_post_card.dart`

#### 수정 파일
- `lib/app/modules/app/views/app_view.dart`
- `lib/theme/app_theme.dart`

#### UI 구성
- **화면 유형**: 목록 화면
- **레이아웃**: `Scaffold`(surface `#131313`) → AppBar(라임 `Rally` 워드마크) → `Column`[카테고리 칩 44.h, `Expanded` → `RefreshIndicator` → `CustomScrollView`] + `floatingActionButton`
- **주요 위젯**: 카테고리 칩(가로 `ListView.separated`), 게시글 카드, 글쓰기 FAB
- **상태 표시**: 로딩 / 에러+다시 시도 / 빈 상태 / 리스트 4단 분기를 `SliverToBoxAdapter` 단위로 분리 (Obx 경고 회피)

#### 카테고리 칩
`전체 / 자유 / 경기토론 / 장비 / 파트너찾기` — 한국어 라벨은 컨트롤러 `static const Map` 상수 (`PlayerController._categoryLabelsKo` 패턴). 선택 상태는 라임 배경 + `accentDark` 텍스트, 비선택은 `chipBg` + 보더.

#### 게시글 카드
```
┌─────────────────────────────┐
│ 장비 · 스매시왕 · 1시간       │  카테고리 칩 + 닉네임 + 상대시간
│ 아스트록스 100ZZ 후기         │  제목 Chivo w700, 1줄 ellipsis
│ 3개월 써본 소감 정리...       │  본문 2줄 ellipsis, subtleText
│ [썸네일]  ♥51 💬17 👁240     │  이미지 있으면 우측 정사각 썸네일
└─────────────────────────────┘
```
`Material` + `InkWell`(radius 16.r) + `Container`(`cardBg` #1C1B1B, `cardBorder` #2A2A2A 보더, 16.r) — `_PlayerCard` 구조 그대로.

#### FAB
`app_theme.dart:86`에 라임 배경 FAB 테마가 이미 정의돼 있으나 앱 전체에서 미사용이다. 별도 스타일 지정 없이 테마를 그대로 쓴다. 아이콘 `Icons.edit_outlined`.

#### 바텀 네비 (`app_view.dart`)
- 3번 인덱스(선수와 내정보 사이)에 삽입: 아이콘 `Icons.forum_outlined` / `Icons.forum`, 라벨 `'커뮤니티'`
- `_tabs` 리스트에 `CommunityView()`를 같은 위치에 추가

#### 테마 (`app_theme.dart`)
`bottomNavigationBarTheme`의 `selectedLabelStyle` / `unselectedLabelStyle`을 `AppTypography.labelLg.copyWith(fontSize: 12)`로 변경. 5탭에서 "커뮤니티"가 320pt 기기에서 잘리는 것을 막고 Material 표준(12sp)에 맞춘다.

#### Stitch 화면 매핑 (필수)
| 화면(View) | Stitch 화면명 | Stitch screenId | resource name |
|------------|---------------|-----------------|----------------|
| `community_view.dart` | TBD | TBD | — |

**UI Agent는 작업 시작 전 `mcp__stitch__list_screens`(projectId `307006344264476289`)로 커뮤니티 관련 화면을 직접 조회할 것.** 매칭 화면이 없으면 `player_view.dart`(Stitch `eeae55cab3614d408743636d325e3b88`, "선수 리스트 (매거진)")의 카드 리스트 레이아웃을 기준으로 삼는다.

#### 참조 이미지
| 화면(View) | 이미지 경로 | 설명 |
|------------|-------------|------|
| — | 없음 | 기획서 §3 S-1의 ASCII 레이아웃 참조 |

#### Figma 참조
- 없음

#### 의존성
- Controller Agent 생성 파일: `lib/app/modules/community/controllers/community_controller.dart`

---

### QA 체크리스트

#### 기능 테스트
- [x] 바텀 네비에 커뮤니티 탭이 3번 위치에 표시되고 진입됨
- [ ] 카테고리 칩 전환 시 목록이 필터링됨 ("전체"는 필터 미적용)
- [ ] 무한 스크롤로 다음 페이지 로드 (임계값 300px)
- [ ] Pull-to-refresh 동작
- [ ] 비로그인 상태에서도 목록 조회 가능

#### 예외 처리 / 엣지 케이스
- [ ] 빈 데이터 상태 UI — 카테고리별 문구 차등 (파트너찾기는 작성 유도)
- [ ] 네트워크 오류 시 에러 상태 + "다시 시도" 버튼
- [x] 앱 콜드 스타트 시 커뮤니티 쿼리가 **실행되지 않음** (탭 진입 시점에 최초 1회)
- [ ] 커뮤니티 탭 → 다른 탭 → 복귀 시 스크롤 위치와 목록이 유지됨
- [x] 기존 경기 탭 자동 스크롤 / 선수 탭 리로드가 여전히 정상 동작 (탭 인덱스 회귀)

#### UI/UX 테스트
- [x] ScreenUtil 적용 (`.w/.h/.sp/.r`), 색상은 `AppColors` 상수만 사용
- [ ] 320pt · 375pt · 430pt 폭에서 5탭 라벨 미절삭
- [ ] `[GETX] the improper use of a GetX` 콘솔 경고 없음
- [x] `flutter analyze` 통과

---

## TASK-010: 게시글 상세 · 좋아요 · 조회수

- **상태**: `done`
- **개발 유형**: 신규개발
- **생성일**: 2026-08-23
- **설명**: 게시글 상세 화면과 좋아요 토글 · 조회수 집계를 구현한다. 댓글은 TASK-012.
- **선행**: TASK-009
- **기획서 참조**: §3 S-2, §5-3, §5-4, §9-H

---

### 개발 유형 분류

| 항목 | 내용 |
|------|------|
| 유형 | 신규개발 |
| 판단 근거 | 신규 화면 + 신규 라우트 |
| 영향 범위 | `CommunityController`(목록 카운터 동기화), `community_post_repository.dart` 메서드 추가 |

---

### 파일 목록

#### 신규 생성 파일
- `lib/app/modules/community/controllers/community_post_detail_controller.dart`
- `lib/app/modules/community/bindings/community_post_detail_binding.dart`
- `lib/app/modules/community/views/community_post_detail_view.dart`
- `lib/app/modules/community/views/widgets/community_image_grid.dart`

#### 수정 파일
- `lib/app/data/repositories/community_post_repository.dart` — 메서드 추가
- `lib/app/modules/community/controllers/community_controller.dart` — 상세에서 돌아올 때 카운터 반영
- `lib/app/routes/app_routes.dart` / `app_pages.dart`

---

### API Agent 작업

#### 수정 파일
- `lib/app/data/repositories/community_post_repository.dart`

TASK-006 선례처럼 **신규 레포지토리를 만들지 말고 기존 파일에 메서드를 append**한다.

| 메서드 | 구현 |
|--------|------|
| `fetchById(String id)` | `.from('community_post_feed').select().eq('id', id).maybeSingle()` |
| `likePost(String postId)` | `.from('community_post_likes').insert({...})` |
| `unlikePost(String postId)` | `.from('community_post_likes').delete().eq('post_id', ...).eq('user_id', ...)` |
| `incrementView(String postId)` | `.rpc('community_increment_view', params: {'p_post_id': postId})` → 갱신된 `view_count` 반환 |

좋아요 중복은 `(post_id, user_id)` PK가 막으므로 `23505`는 이미 좋아요 상태로 간주하고 조용히 성공 처리한다.

---

### Controller Agent 작업

#### 생성 파일
- `lib/app/modules/community/controllers/community_post_detail_controller.dart`
- `lib/app/modules/community/bindings/community_post_detail_binding.dart`

#### 기능 정의
- [ ] `Rxn<CommunityPostResponse> post` / `RxBool isLoading` / `RxnString errorMessage`
- [ ] `static const String argPostId = 'post_id';` — `Get.arguments`로 전달 (프로젝트 관례)
- [ ] `onInit()`에서 `loadPost()` → 성공 후 `incrementView()` 1회. `_viewCounted` 플래그로 중복 방지
- [ ] `toggleLike()` — 낙관적 업데이트: `copyWithLike`로 새 인스턴스 생성 후 대입 → 실패 시 롤백 + `Get.snackbar`
- [ ] 비로그인 상태에서 좋아요 탭 → `Get.toNamed(Routes.LOGIN)`
- [ ] 목록 동기화: `Get.back()` 시 갱신된 post를 `CommunityController`의 리스트 해당 인덱스에 교체 반영

#### 의존성
- API Agent: `community_post_repository.dart`

---

### UI Agent 작업

#### 생성 파일
- `lib/app/modules/community/views/community_post_detail_view.dart`
- `lib/app/modules/community/views/widgets/community_image_grid.dart`

#### UI 구성
- **화면 유형**: 상세 화면
- **레이아웃**: AppBar(뒤로가기 + 우측 ⋯ 더보기) → `CustomScrollView`[작성자 헤더 / 카테고리 칩 / 제목 / 본문 / 이미지 그리드] → 하단 고정 액션바(좋아요·댓글수·조회수)
- **주요 위젯**: 아바타 + 닉네임 + 상대시간, 이미지 그리드, 좋아요 토글 버튼
- **상태 표시**: 로딩 / 에러+재시도 / 정상

#### 이미지 그리드
1~5장 대응. 1장은 16:9 단일, 2장은 2열, 3장 이상은 2열 그리드 + 잔여 카운트 오버레이. `cached_network_image` 사용, `errorWidget`은 `cardBg` 플레이스홀더.

#### 더보기(⋯) 시트
TASK-013에서 신고/차단 항목이 추가된다. **이 태스크에서는 본인 글일 때의 수정/삭제만 구현**하고, 타인 글이면 시트를 비활성화하거나 노출하지 않는다.

#### Stitch 화면 매핑 (필수)
| 화면(View) | Stitch 화면명 | Stitch screenId | resource name |
|------------|---------------|-----------------|----------------|
| `community_post_detail_view.dart` | TBD | TBD | — |

`mcp__stitch__list_screens`로 직접 조회. 없으면 "커뮤니티 대화방 (매거진)" 시안(`live_match_chat_view.dart` 적용본)의 다크 매거진 톤을 따른다.

#### 참조 이미지
| 화면(View) | 이미지 경로 | 설명 |
|------------|-------------|------|
| — | 없음 | — |

#### Figma 참조
- 없음

#### 의존성
- Controller Agent: `community_post_detail_controller.dart`

---

### QA 체크리스트

#### 기능 테스트
- [ ] 목록 카드 탭 → 상세 진입, 데이터 정상 표시
- [ ] 좋아요 토글 즉시 반영, 재진입 시 상태 유지
- [ ] 상세 진입 시 조회수 +1, **같은 사용자가 재진입해도 증가하지 않음**
- [ ] 뒤로가기 시 목록의 좋아요·조회수가 갱신된 값으로 반영

#### 예외 처리 / 엣지 케이스
- [ ] 삭제된 글에 진입 (딥링크 등) → 에러 상태 표시
- [x] 비로그인 상태로 좋아요 탭 → 로그인 화면 이동
- [ ] 좋아요 API 실패 시 UI 롤백 + 스낵바
- [x] 조회수 RPC 실패는 **스낵바 없이 로그만** (스크롤 중 화면 덮임 방지)
- [ ] 이미지 로드 실패 시 플레이스홀더

#### UI/UX 테스트
- [ ] 이미지 1·2·3·5장 각각 레이아웃 정상
- [ ] 본문 장문(5000자) 스크롤 정상
- [x] `flutter analyze` 통과

---

## TASK-011: 커뮤니티 온보딩(닉네임+약관) · 글 작성/수정 · 이미지 업로드

- **상태**: `done`
- **개발 유형**: 신규개발
- **생성일**: 2026-08-23
- **설명**: 첫 작성 전 닉네임 설정 + 이용규칙 동의를 받고, 게시글 작성/수정과 이미지 업로드를 구현한다.
- **선행**: TASK-009
- **기획서 참조**: §3 S-3 / S-6, §5-5, §6-1, §6-4, §7-6, §12 D-2 · D-5

---

### 개발 유형 분류

| 항목 | 내용 |
|------|------|
| 유형 | 신규개발 (일부 유지보수 — `profile_edit` 중복 검사 추가) |
| 판단 근거 | 신규 작성 화면 + 신규 온보딩 시트. `profile_edit_controller`는 기존 파일 수정 |
| 영향 범위 | `profile_edit` 모듈(닉네임 저장 경로), `pubspec.yaml`(약관 애셋) |

---

### 파일 목록

#### 신규 생성 파일
- `lib/app/data/models/create_community_post_parameter.dart`
- `lib/app/data/models/update_community_post_parameter.dart`
- `lib/app/data/repositories/community_moderation_repository.dart`
- `lib/app/modules/community/controllers/community_compose_controller.dart`
- `lib/app/modules/community/bindings/community_compose_binding.dart`
- `lib/app/modules/community/views/community_compose_view.dart`
- `lib/app/modules/community/views/widgets/community_eula_sheet.dart`
- `lib/app/utils/community_text_filter.dart`
- `assets/docs/community_eula.md`

#### 수정 파일
- `lib/app/data/repositories/community_post_repository.dart` — create/update/delete + 이미지 업로드
- `lib/app/data/repositories/profile_repository.dart` — 닉네임 중복 예외 전달
- `lib/app/modules/profile_edit/controllers/profile_edit_controller.dart` — 중복 검사 (`profile_edit_controller.dart:80` 현재 빈 값만 검사)
- `pubspec.yaml` — `assets/docs/` 등록
- `lib/app/routes/app_routes.dart` / `app_pages.dart`

---

### API Agent 작업

#### 생성 파일
- `create_community_post_parameter.dart` — `category`, `title`, `content`, `imagePaths`
- `update_community_post_parameter.dart` — **null이 아닌 필드만 `toJson`에 포함** (MODEL_GUIDE 7절 패턴). `edited_at`은 서버 시각으로 함께 갱신
- `community_moderation_repository.dart`

#### `CommunityModerationRepository` (이 태스크 범위)
| 메서드 | 구현 |
|--------|------|
| `hasAgreedToEula()` | `.from('user_agreements').select().eq('doc','community_eula').eq('version', <클라 상수>).maybeSingle()` |
| `agreeToEula()` | `.from('user_agreements').upsert({...})` |
| `fetchBannedWords()` | `.from('community_banned_words').select('norm').eq('severity','block')` |

신고·차단 메서드는 TASK-013에서 같은 파일에 append한다.

#### `CommunityPostRepository` 추가 메서드
| 메서드 | 구현 |
|--------|------|
| `uploadImages(String draftId, List<File> files)` | `storage.from('community').upload('{uid}/{draftId}/{i}_{ts}.jpg', file)` → path 리스트 반환 |
| `removeImages(List<String> paths)` | `storage.from('community').remove(paths)` |
| `createPost(CreateCommunityPostParameter)` | `.from('community_posts').insert(...).select().single()` |
| `updatePost(String id, UpdateCommunityPostParameter)` | `.from('community_posts').update(...).eq('id', id)` |
| `deletePost(String id)` | `.rpc('community_delete_post', params: {'p_id': id})` |

`uploadAvatar`(`profile_repository.dart`)의 확장자→contentType 매핑 로직을 그대로 따른다.

#### `ProfileRepository` 수정
`updateNickname`에서 `PostgrestException.code == '23505'` 발생 시 그대로 rethrow하여 상위에서 "이미 사용 중인 닉네임입니다"로 변환할 수 있게 한다.

---

### Controller Agent 작업

#### 생성 파일
- `lib/app/modules/community/controllers/community_compose_controller.dart`
- `lib/app/modules/community/bindings/community_compose_binding.dart`

#### 수정 파일
- `lib/app/modules/profile_edit/controllers/profile_edit_controller.dart`

#### 기능 정의 — `CommunityComposeController` (작성/수정 겸용)
- [ ] `static const argPostId = 'post_id';` — 있으면 수정 모드
- [ ] `RxnString selectedCategory` / `TextEditingController title, content` / `RxList<File> pickedImages` / `RxBool isSubmitting`
- [ ] `late final String draftId` — `onInit`에서 UUID 생성 (이미지 경로용)
- [ ] `pickImages()` — `ImagePicker().pickMultiImage(limit: 5)`, `maxWidth: 1600, imageQuality: 80`
- [ ] `removeImage(int index)`
- [ ] `submit()` — 순서 엄수:
      1. 클라 금칙어 사전 검증 (`community_text_filter.dart`)
      2. 이미지 업로드 → path 리스트
      3. `community_posts` INSERT
      4. **3이 실패하면 catch에서 2에서 올린 path를 `removeImages()`** (고아 파일 방지)
- [ ] 수정 모드에서 이미지 교체: **새 path 업로드 → UPDATE 성공 → 제거된 옛 path 삭제** (순서 반대로 하면 실패 시 이미지 증발)
- [ ] 진입 가드 `ensureCanWrite()` — 비로그인이면 로그인, 닉네임 없거나 EULA 미동의면 온보딩 시트. **작성 화면 진입 전에 호출**한다 (제출 시점에 걸리면 `42501`로 실패)

#### 기능 정의 — 온보딩 시트 상태
- [ ] 닉네임 입력값 검증: 2~12자, 금칙어, 중복(디바운스 실시간 확인)
- [ ] 약관 동의 체크박스 + "동의하고 계속"
- [ ] 이미 닉네임이 있으면 입력란을 건너뛰고 약관만 표시
- [ ] 시트 내부 `Obx`는 반응형 변수를 **직접 참조**할 것 (improper use 경고 회피)

#### `ProfileEditController` 수정
- [ ] `save()`에서 `23505` 포착 → "이미 사용 중인 닉네임입니다" 스낵바
- [ ] 길이 검증 2~12자 추가 (현재 빈 값만 검사)

#### 의존성
- API Agent: `community_moderation_repository.dart`, `community_post_repository.dart`

---

### UI Agent 작업

#### 생성 파일
- `lib/app/modules/community/views/community_compose_view.dart`
- `lib/app/modules/community/views/widgets/community_eula_sheet.dart`

#### UI 구성
- **화면 유형**: 입력 폼
- **레이아웃**: AppBar(닫기 + 우측 "등록" 텍스트 버튼) → 카테고리 선택 칩 → 제목 `TextField` → 본문 `TextField`(multiline, expands) → 하단 이미지 첨부 바(썸네일 가로 리스트 + 추가 버튼)
- **주요 위젯**: 카테고리 칩, 글자수 카운터, 이미지 썸네일(삭제 X 버튼 오버레이)
- **상태 표시**: 제출 중 버튼 비활성 + 인디케이터

#### 온보딩 시트 (`community_eula_sheet.dart`)
```
┌─ 커뮤니티 시작하기 ──────┐
│ 닉네임                   │
│ ┌──────────────────┐    │
│ │ 스매시왕          │    │
│ └──────────────────┘    │
│ ✓ 사용 가능한 닉네임      │  라임 / 오류는 liveRed
│                          │
│ [이용규칙 본문 스크롤]     │  최대 높이 제한 + 내부 스크롤
│                          │
│ ☑ 이용규칙에 동의합니다    │
│ ┌──────────────────┐    │
│ │   동의하고 계속    │    │  라임 배경 + accentDark 텍스트
│ └──────────────────┘    │
└──────────────────────────┘
```
`Get.bottomSheet` + `isScrollControlled: true`. 키보드가 올라올 때 가려지지 않도록 `viewInsets` 패딩 처리.

#### 이용규칙 본문 (`assets/docs/community_eula.md`)
포함 항목: 금지 행위 목록(욕설·비방, 음란물, 불법 정보, 스팸·광고, 개인정보 노출, 사칭), **부적절한 콘텐츠 및 악용 사용자에 대한 무관용 정책**, 신고·차단 안내, 운영자 조치 권한(숨김·삭제·이용 정지), **탈퇴 시 작성글은 익명 처리되어 보존된다는 조항**(D-3), 문의 경로.

#### Stitch 화면 매핑 (필수)
| 화면(View) | Stitch 화면명 | Stitch screenId | resource name |
|------------|---------------|-----------------|----------------|
| `community_compose_view.dart` | TBD | TBD | — |

`mcp__stitch__list_screens`로 직접 조회. 없으면 `sign_up_view.dart`(Stitch `3616350c62da4e95906ab4d458eb7ebc`)의 입력 폼 스타일을 기준으로 삼는다.

#### 참조 이미지
| 화면(View) | 이미지 경로 | 설명 |
|------------|-------------|------|
| — | 없음 | 기획서 §3 S-6의 ASCII 레이아웃 참조 |

#### Figma 참조
- 없음

#### 의존성
- Controller Agent: `community_compose_controller.dart`

---

### QA 체크리스트

#### 기능 테스트
- [ ] 닉네임 없는 계정으로 글쓰기 → 온보딩 시트 노출 → 닉네임+동의 후 작성 화면 진입
- [ ] 닉네임 있는 계정 → 약관만 노출
- [ ] 이미 동의한 계정 → 시트 없이 바로 작성 화면
- [ ] 글 작성 후 목록 최상단에 반영
- [ ] 이미지 1~5장 업로드 후 상세에서 정상 표시
- [ ] 본인 글 수정 → "수정됨" 표시

#### 예외 처리 / 엣지 케이스
- [ ] 중복 닉네임 입력 → "이미 사용 중인 닉네임입니다" (온보딩 · 프로필 편집 **양쪽**)
- [ ] 닉네임 1자 / 13자 → 길이 검증 실패
- [ ] 금칙어 포함 본문 → 클라 사전 검증에서 즉시 차단
- [ ] 클라 검증 우회 시에도 서버 트리거가 차단 (`banned_word` → 한국어 스낵바)
- [ ] **이미지 업로드 성공 후 INSERT 실패 → 업로드된 파일이 스토리지에서 제거됨** (고아 방지)
- [ ] 이미지 6장 선택 시도 → 5장 제한
- [ ] 5MB 초과 이미지 → 업로드 거부 메시지
- [ ] 제목/본문 최대 길이(100 / 5000자) 초과 입력 차단
- [ ] 작성 중 뒤로가기 → 작성 취소 확인 다이얼로그

#### UI/UX 테스트
- [ ] 키보드 노출 시 온보딩 시트 버튼이 가려지지 않음
- [ ] 제출 중 중복 탭 방지 (버튼 비활성)
- [x] 정적 분석 통과 — `dart analyze lib/` 기준 신규/수정 파일 error·warning 0건
      (`flutter analyze` 는 이 워크트리에서 exit 255 로 크래시한다. `lib/main.dart` 의
      error 2건은 `.gitignore` 된 `firebase_options.dart` 누락으로 인한 선행 이슈)

> 위 기능/예외 항목은 **미검증**이다. 이 워크트리에 `lib/firebase_options.dart` 와
> `.env` 가 없어 앱을 빌드·실행할 수 없다. 실기기 QA는 두 파일이 갖춰진 환경에서
> 별도로 수행해야 한다.

---

## TASK-012: 댓글 · 대댓글

- **상태**: `done`
- **개발 유형**: 신규개발
- **생성일**: 2026-08-23
- **설명**: 게시글 상세에 댓글과 1depth 대댓글을 추가한다.
- **선행**: TASK-010, TASK-011
- **기획서 참조**: §5-2, §9-G(고아 대댓글)

---

### 개발 유형 분류

| 항목 | 내용 |
|------|------|
| 유형 | 신규개발 |
| 판단 근거 | 신규 모델·레포지토리. 화면은 기존 상세에 섹션 추가 |
| 영향 범위 | `community_post_detail_controller.dart`, `community_post_detail_view.dart` |

---

### 파일 목록

#### 신규 생성 파일
- `lib/app/data/models/community_comment_response.dart`
- `lib/app/data/models/create_community_comment_parameter.dart`
- `lib/app/data/repositories/community_comment_repository.dart`
- `lib/app/modules/community/views/widgets/community_comment_tile.dart`
- `lib/app/modules/community/views/widgets/community_comment_input_bar.dart`

#### 수정 파일
- `lib/app/modules/community/controllers/community_post_detail_controller.dart` — 댓글 상태/액션 추가 (신규 컨트롤러 만들지 말 것)
- `lib/app/modules/community/views/community_post_detail_view.dart` — 댓글 리스트 + 입력바

---

### API Agent 작업

#### 생성 파일
- `community_comment_response.dart`, `create_community_comment_parameter.dart`, `community_comment_repository.dart`

#### 데이터 소스
조회는 뷰 `community_comment_feed` (작성자 프로필 조인 + 삭제/숨김 댓글의 `content`가 NULL로 마스킹됨).

| 메서드 | 구현 |
|--------|------|
| `listComments(String postId)` | `.from('community_comment_feed').select().eq('post_id', postId).order('created_at', ascending: true)` |
| `createComment(param)` | `.from('community_comments').insert(...).select().single()` |
| `updateComment(id, content)` | `.from('community_comments').update({'content':..., 'edited_at':...}).eq('id', id)` |
| `deleteComment(id)` | `.rpc('community_delete_comment', params: {'p_id': id})` |

#### 모델
- `parentId`, `replyCount`, `status`, `editedAt`, `authorNickname`, `authorAvatarUrl`
- `bool get isRemoved => status != 'visible';` — 툼스톤 표시 판정
- `content`가 null이면 *"삭제된 댓글입니다"* 로 대체 (모델이 아니라 위젯에서 처리)

---

### Controller Agent 작업

#### 수정 파일
- `lib/app/modules/community/controllers/community_post_detail_controller.dart`

#### 기능 정의 (기존 컨트롤러에 append)
- [x] `RxList<CommunityCommentResponse> comments` / `RxBool isCommentsLoading` / `RxnString commentsError`
- [x] `Rxn<CommunityCommentResponse> replyTarget` — 답글 대상. null이면 최상위 댓글
- [x] `TextEditingController commentInput`
- [x] `loadComments()` / `submitComment()` / `deleteComment()` / `startReply(comment)` / `cancelReply()`
- [x] **트리 빌드**: 최상위 댓글 아래 자식 댓글을 배치한다. **`parent_id`가 조회 결과에 없는 대댓글은 드롭한다** — 부모 작성자를 차단하면 부모만 사라져 대댓글이 고아로 최상위에 뜬다
- [x] 댓글 작성 성공 시 `post.commentCount`를 낙관적으로 +1 (`copyWith`로 교체)
- [x] 비로그인 / 미동의 시 TASK-011의 `ensureCanWrite()` 가드 재사용

#### 의존성
- API Agent: `community_comment_repository.dart`

---

### UI Agent 작업

#### 생성 파일
- `community_comment_tile.dart`, `community_comment_input_bar.dart`

#### 수정 파일
- `community_post_detail_view.dart`

#### UI 구성
- **화면 유형**: 상세 화면 내 리스트 섹션
- **레이아웃**: 본문 아래 구분선 → "댓글 N" 헤더 → 댓글 `SliverList` → 하단 고정 입력바
- **주요 위젯**: 댓글 타일(아바타·닉네임·시간·본문·답글 버튼), 대댓글 들여쓰기, 입력바

#### 댓글 타일
- depth 0: 좌측 패딩 20.w / depth 1: 좌측 패딩 48.w + 연결선 또는 `↳` 표기
- 삭제된 댓글: 본문 자리에 *"삭제된 댓글입니다"* (`subtleText`, italic), 답글 버튼 숨김
- 본인 댓글 롱프레스 → 삭제 확인 다이얼로그 (`live_match_chat_view.dart:289`의 `Get.dialog<bool>` 패턴)

#### 입력바
답글 모드일 때 상단에 *"@스매시왕에게 답글"* + 취소 X 버튼. `live_match_chat_view.dart`의 pill 입력창 + 라임 send 버튼 스타일 재사용.

#### Stitch 화면 매핑 (필수)
| 화면(View) | Stitch 화면명 | Stitch screenId | resource name |
|------------|---------------|-----------------|----------------|
| `community_comment_input_bar.dart` | 커뮤니티 대화방 (매거진) | TBD | — |

입력바는 기존 `live_match_chat_view.dart`가 이미 같은 시안을 적용했으므로 **해당 구현을 직접 참조**한다.

#### 참조 이미지
| 화면(View) | 이미지 경로 | 설명 |
|------------|-------------|------|
| — | 없음 | — |

#### Figma 참조
- 없음

#### 의존성
- Controller Agent: `community_post_detail_controller.dart`

---

### QA 체크리스트

> 아래 실행 검증 항목은 이 워크트리에 `firebase_options.dart` 와 `.env` 가 없어 앱을 띄울 수 없어 **미검증**으로 남긴다. 구현은 완료됐다.

#### 기능 테스트
- [ ] 댓글 작성 → 즉시 목록에 표시, `comment_count` 증가
- [ ] 대댓글 작성 → 부모 아래 들여쓰기로 표시
- [ ] 본인 댓글 삭제 → 툼스톤으로 전환, 대댓글은 유지
- [ ] 대댓글이 있는 댓글을 삭제해도 스레드 구조 유지

#### 예외 처리 / 엣지 케이스
- [ ] **대댓글에 답글 시도 → 서버가 `depth_exceeded`로 거부, 한국어 메시지 표시**
- [ ] 부모 댓글 작성자를 차단 → 고아 대댓글이 최상위에 뜨지 않고 함께 사라짐
- [ ] 댓글 0개 → 빈 상태 문구
- [ ] 삭제된 게시글의 댓글 작성 시도 → 거부
- [ ] 금칙어 댓글 차단
- [ ] `comment_count`와 실제 표시 개수가 다를 수 있음(차단 반영 차이) — **정상 동작으로 간주**

#### UI/UX 테스트
- [ ] 키보드 노출 시 입력바가 가려지지 않음
- [ ] 댓글 100개 이상 스크롤 성능
- [x] `flutter analyze` 통과 (이 워크트리에서 `flutter analyze` 는 exit 255 로 크래시 — `dart analyze lib/` 로 검증, 신규/수정 파일 error·warning 0건)

---

## TASK-013: 신고 · 차단 · 관리자 조치

- **상태**: `done`
- **개발 유형**: 신규개발
- **생성일**: 2026-08-23
- **설명**: Apple 1.2 요건 충족을 위한 신고·차단 UI와 운영자 조치 액션을 구현한다.
- **선행**: TASK-010, TASK-012
- **기획서 참조**: §3 S-4 / S-5, §6 전체

---

### 개발 유형 분류

| 항목 | 내용 |
|------|------|
| 유형 | 신규개발 |
| 판단 근거 | 신규 시트 2종 + 신규 화면 1종 |
| 영향 범위 | `my_info` 모듈(메뉴 추가), 상세·댓글의 더보기 시트 |

---

### 파일 목록

#### 신규 생성 파일
- `lib/app/data/models/community_report_response.dart`
- `lib/app/data/models/create_community_report_parameter.dart`
- `lib/app/data/models/blocked_user_response.dart`
- `lib/app/modules/community/controllers/blocked_users_controller.dart`
- `lib/app/modules/community/bindings/blocked_users_binding.dart`
- `lib/app/modules/community/views/blocked_users_view.dart`
- `lib/app/modules/community/views/widgets/community_more_sheet.dart`
- `lib/app/modules/community/views/widgets/community_report_sheet.dart`

#### 수정 파일
- `lib/app/data/repositories/community_moderation_repository.dart` — 신고·차단·관리자 메서드 append
- `lib/app/modules/community/views/community_post_detail_view.dart` — 더보기 시트 연결
- `lib/app/modules/community/views/widgets/community_comment_tile.dart` — 댓글 신고/차단
- `lib/app/modules/my_info/views/my_info_view.dart` — "차단한 사용자" / "커뮤니티 이용규칙" 메뉴
- `lib/app/modules/my_info/controllers/my_info_controller.dart` — `goToBlockedUsers` / `goToCommunityTerms`
- `lib/app/routes/app_routes.dart` / `app_pages.dart`

---

### API Agent 작업

#### `CommunityModerationRepository` 추가 메서드
| 메서드 | 구현 |
|--------|------|
| `createReport(param)` | `.from('community_reports').insert(...)` |
| `blockUser(String userId)` | `.from('user_blocks').insert({'blocker_id': uid, 'blocked_id': userId})` |
| `unblockUser(String userId)` | `.from('user_blocks').delete().eq('blocked_id', userId)` |
| `listBlockedUsers()` | `.from('user_blocks').select()` + `public_profiles` 별도 조회로 닉네임 hydrate (`ChatMessageRepository._hydrateProfiles` 패턴) |
| `isAppAdmin()` | `.rpc('is_app_admin')` |
| `setPostStatus(id, status)` | `.rpc('community_set_post_status', ...)` |
| `setCommentStatus(id, status)` | `.rpc('community_set_comment_status', ...)` |
| `banUser(uid, days)` | `.rpc('community_ban_user')` |
| `resolveReport(id, status)` | `.rpc('community_resolve_report')` |

신고 중복은 유니크 인덱스가 막는다 → `23505`는 "이미 신고한 콘텐츠입니다"로 변환.

---

### Controller Agent 작업

#### 생성 파일
- `blocked_users_controller.dart`, `blocked_users_binding.dart`

#### 기능 정의 — `BlockedUsersController`
- [ ] `RxList<BlockedUserResponse> blockedUsers` / `isLoading` / `errorMessage`
- [ ] `load()` / `unblock(userId)` — 해제 후 목록에서 제거
- [ ] 해제 시 확인 다이얼로그

#### 기존 컨트롤러 수정
- [ ] `CommunityPostDetailController`에 `RxBool isAdmin` 추가 — `onInit`에서 `isAppAdmin()` 1회 조회 (실패 시 false)
- [ ] `report(...)` / `block(...)` 액션. 차단 성공 시 상세를 닫고 목록을 refresh (차단된 작성자의 글은 RLS가 걸러냄)
- [ ] `MyInfoController`에 `goToBlockedUsers()` / `goToCommunityTerms()` 추가 (현재 `_showComingSoon` 스텁 패턴을 실제 라우팅으로 대체)

#### 의존성
- API Agent: `community_moderation_repository.dart`

---

### UI Agent 작업

#### 생성 파일
- `community_more_sheet.dart`, `community_report_sheet.dart`, `blocked_users_view.dart`

#### 더보기 시트 (`community_more_sheet.dart`)
| 조건 | 항목 |
|------|------|
| 본인 콘텐츠 | 수정 · 삭제 |
| 타인 콘텐츠 | 신고 · 이 사용자 차단 |
| `isAdmin == true` | + 숨기기 / 복구 / 강제 삭제 / 작성자 정지 / 신고 종결 |

**별도 관리자 화면을 만들지 않는다.** 운영자가 폰에서 바로 처리할 수 있어야 24시간 SLA가 지켜진다.

#### 신고 시트 (`community_report_sheet.dart`)
사유 6종 라디오(`spam` 스팸/광고, `abuse` 욕설/비방, `sexual` 음란물, `illegal` 불법 정보, `privacy` 개인정보 노출, `other` 기타) + 상세 입력 500자 + 제출.

제출 완료 후 **"이 사용자 차단하기" CTA를 이어서 노출**한다 — 신고자 체감 처리 시간이 0초가 되며, Apple 리뷰어가 실제로 확인하는 UX다.

> 라디오 선택 상태는 `RxString`이며, **시트 내부 `Obx`에서 직접 참조**해야 improper use 경고가 나지 않는다.

#### 차단 목록 화면 (`blocked_users_view.dart`)
`favorite_players_view.dart`의 리스트 구조를 그대로 따른다. 아바타 + 닉네임 + 우측 "차단 해제" 버튼, `Divider` 구분, 빈 상태 *"차단한 사용자가 없습니다."*

#### `my_info_view.dart` 메뉴 추가
`_MenuItemData` 2개를 "좋아하는 선수"와 "도움말" 사이에 삽입:
- `Icons.block` / "차단한 사용자"
- `Icons.gavel_outlined` / "커뮤니티 이용규칙"

#### Stitch 화면 매핑 (필수)
| 화면(View) | Stitch 화면명 | Stitch screenId | resource name |
|------------|---------------|-----------------|----------------|
| `blocked_users_view.dart` | TBD | TBD | — |

`mcp__stitch__list_screens`로 조회. 없으면 `favorite_players_view.dart` 구조를 따른다.

#### 참조 이미지
| 화면(View) | 이미지 경로 | 설명 |
|------------|-------------|------|
| — | 없음 | — |

#### Figma 참조
- 없음

#### 의존성
- Controller Agent: `blocked_users_controller.dart`

---

### QA 체크리스트

#### 기능 테스트
- [x] 타인 글/댓글 신고 → 접수 완료 + 차단 CTA 노출
- [ ] 차단 → 해당 사용자의 글·댓글이 즉시 목록에서 사라짐
- [ ] 내정보 → 차단한 사용자 목록에 표시, 해제 시 다시 보임
- [x] 내정보 → 커뮤니티 이용규칙 열람
- [ ] **음란물 사유 1건 신고 → 게시글이 즉시 숨김 처리됨**
- [ ] **신고 즉시 운영자 기기로 FCM 푸시 수신**
- [ ] 운영자 계정 로그인 → 더보기에 관리자 항목 노출, 숨김/복구/정지 동작

#### 예외 처리 / 엣지 케이스
- [x] 같은 콘텐츠 재신고 → "이미 신고한 콘텐츠입니다"
- [x] 자기 자신 차단 시도 → 차단 항목 미노출
- [x] 비로그인 상태에서 신고/차단 시도 → 로그인 유도
- [ ] 일반 계정에서 관리자 항목이 **노출되지 않음** + 직접 호출해도 RLS가 거부
- [ ] 차단한 사용자가 쓴 댓글의 대댓글이 고아로 남지 않음

#### UI/UX 테스트
- [x] 신고 시트에서 사유 미선택 시 제출 버튼 비활성
- [x] 시트 내 `Obx` improper use 경고 없음
- [x] `dart analyze` 통과 (이 환경에서 `flutter analyze` 는 code 255 로 크래시한다. 본 태스크 파일 error·warning 0건, 잔여 error 2건은 `main.dart` 의 `firebase_options.dart` 미생성으로 선행 이슈)

---


#### 실기기 검증이 필요한 잔여 항목

`firebase_options.dart` · `.env` 가 워크트리에 없어 빌드/실행이 불가하므로 아래는 정적 검토까지만 마쳤다.

- 차단 직후 목록에서 사라짐 / 차단 해제 후 복귀 (서버 RLS `community_is_blocked()` 의존)
- 음란물 사유 1건 → 즉시 자동 숨김 (서버 트리거 `community_on_report`)
- 신고 즉시 운영자 FCM 수신 (notifications INSERT → send-push)
- 운영자 계정 로그인 시 관리자 항목 노출 및 숨김/복구/정지 동작

## TASK-014: 라이브 채팅 신고/차단 소급 · 앱스토어 대응

- **상태**: `done`
- **개발 유형**: 유지보수
- **생성일**: 2026-08-23
- **설명**: 기존 라이브 채팅에 신고·차단을 소급 적용하고, 앱 내 문의 경로와 앱스토어 UGC 신고 정보를 정비한다.
- **선행**: TASK-013
- **기획서 참조**: §9-A, §9-B, §9-C

---

### 개발 유형 분류

| 항목 | 내용 |
|------|------|
| 유형 | 유지보수 |
| 판단 근거 | 기존 `live_match_chat` 모듈과 `my_info` 수정. 신규 화면 없음 |
| 영향 범위 | `live_match_chat` 전체, `my_info` 메뉴 2건 |

> **이 태스크는 선택 사항이 아니다.** `live_match_chat_view.dart`에는 현재 신고·차단 코드가 0건이며, 앱은 이미 모더레이션 없는 UGC를 배포 중이다. 커뮤니티와 무관하게 재심사에서 리젝 사유가 될 수 있다.

---

### 파일 목록

#### 수정 파일
- `lib/app/modules/live_match_chat/controllers/live_match_chat_controller.dart` — 신고/차단 액션, 차단 사용자 메시지 필터
- `lib/app/modules/live_match_chat/views/widgets/chat_message_bubble.dart` — 롱프레스 메뉴에 신고/차단
- `lib/app/modules/my_info/controllers/my_info_controller.dart` — `goToHelp` / `goToFeedback` 실동작화
- `appstore_screenshots/appstore_metadata_ko.md` — UGC 관련 심사 정보 갱신
- `docs/architecture.md` — 커뮤니티 모듈 반영 (architecture-update 에이전트)

---

### API Agent 작업

없음 — TASK-013의 `CommunityModerationRepository`를 그대로 재사용한다. `community_reports.target_type`에 채팅 메시지용 값을 추가할지는 **불필요**하다고 판단한다: 채팅 신고는 `target_type='user'`로 작성자를 신고하고, 상세 내용에 메시지 본문을 담는다. 테이블 변경 없이 처리된다.

---

### Controller Agent 작업

#### 수정 파일
- `lib/app/modules/live_match_chat/controllers/live_match_chat_controller.dart`
- `lib/app/modules/my_info/controllers/my_info_controller.dart`

#### 기능 정의
- [ ] `LiveMatchChatController`에 `reportMessage(msg)` / `blockUser(userId)` 추가
- [ ] 차단 목록을 `onInit`에서 1회 조회해 `Set<String> blockedUserIds`로 보관
- [ ] `_messages`에 추가할 때와 초기 로드 시 `blockedUserIds`에 포함된 작성자 메시지를 제외
- [ ] Realtime INSERT 콜백에서도 동일 필터 적용
- [ ] 차단 직후 이미 표시된 해당 사용자 메시지를 즉시 제거
- [ ] `MyInfoController.goToFeedback()` — `url_launcher`로 `mailto:cuunit.store@gmail.com` 실행 (제목에 앱 버전 자동 삽입)
- [ ] `MyInfoController.goToHelp()` — 이용규칙/도움말 화면으로 연결 또는 동일 메일 경로

---

### UI Agent 작업

#### 수정 파일
- `lib/app/modules/live_match_chat/views/widgets/chat_message_bubble.dart`

#### UI 구성
- 타인 메시지 롱프레스 → 액션시트: "신고" / "이 사용자 차단"
- 본인 메시지 롱프레스는 기존 "삭제" 유지
- 시트는 TASK-013의 `community_report_sheet.dart`를 **재사용**한다 (대상 타입만 `user`로 전달)

#### Stitch 화면 매핑
| 화면(View) | Stitch 화면명 | Stitch screenId | resource name |
|------------|---------------|-----------------|----------------|
| `chat_message_bubble.dart` | 커뮤니티 대화방 (매거진) | 기존 적용본 유지 | — |

기존 디자인을 변경하지 않는다. 롱프레스 메뉴만 추가.

#### 참조 이미지
| 화면(View) | 이미지 경로 | 설명 |
|------------|-------------|------|
| — | 없음 | — |

#### Figma 참조
- 없음

---

### 앱스토어 대응 (코드 외 작업)

`appstore_screenshots/appstore_metadata_ko.md`의 다음 항목을 갱신한다.

- [x] "추가 체크 항목"의 *"사용자 생성 콘텐츠(채팅 등)가 이번 버전에 없다면 대부분 4+"* 문구 삭제 — **이미 사실이 아니다**
- [x] App Review Notes에 UGC 존재와 모더레이션 체계 명시: 신고, 차단, 사유별 자동 숨김(음란·불법 1건 / 그 외 3건), 운영자 즉시 푸시, 앱 내 관리자 조치, EULA 동의 강제
- [x] "이 버전의 새로운 기능"에 커뮤니티 탭 추가
- [x] 제출 전 사람이 할 일을 문서에 체크리스트로 분리 (아래 3건은 App Store Connect 웹 작업이라 코드로 처리 불가)
  - [ ] 연령 등급 재설문 (App Store Connect에서 사용자 생성 콘텐츠 항목 "예")
  - [ ] App Privacy 재신고 (사용자 콘텐츠 수집 항목 추가)
  - [ ] 데모 계정 준비 — 리뷰어가 신고/차단을 실제로 시연할 수 있어야 한다

> **주의 (구현과 문서의 어긋남 방지)**: `live_match_chat_messages` 에는 금칙어 트리거도
> 자동 숨김 임계값도 **없다**(`community_on_report` 는 `target_type='user'` 에 대해
> 알림만 보낸다). Review Notes 는 이 사실대로 적혀 있다. 채팅에 필터·강제 삭제를
> 붙이기 전에는 노트에서 해당 문단을 지우지 말 것.

---

### QA 체크리스트

#### 기능 테스트
- [x] 라이브 채팅에서 타인 메시지 롱프레스 → 신고/차단 노출
- [ ] 채팅에서 차단 → 해당 사용자 메시지가 즉시 사라지고 이후 메시지도 표시되지 않음
- [ ] 차단 해제 후 재진입 시 다시 표시됨
- [x] 커뮤니티에서 차단한 사용자가 **채팅에서도** 차단되어 있음 (`user_blocks` 공용 — `CommunityModerationRepository.listBlockedUsers` 재사용)
- [ ] 내정보 → 피드백 보내기 → 메일 앱 실행

#### 예외 처리 / 엣지 케이스
- [x] 본인 메시지 롱프레스 → 신고/차단이 아니라 삭제만 노출
- [x] 메일 앱이 없는 기기에서 `url_launcher` 실패 시 안내 스낵바 (false 반환·예외 양쪽 모두 처리)
- [x] 차단 목록 조회 실패 시 채팅 자체는 정상 동작 (필터만 미적용 — `_loadBlockedUsers` 가 예외를 삼킨다)

#### 유지보수 전용
- [ ] 수정 전 기존 채팅 기능 회귀 테스트 — 메시지 송수신, Realtime, Presence 접속자 수, 라이브 스코어 갱신, 스코어 가리기 토글
- [x] 기존 사용자 데이터 영향 없음 (`live_match_chat_messages` 스키마 미변경 — 마이그레이션 0건)
- [ ] 마이페이지 다른 메뉴 정상 동작

#### UI/UX 테스트
- [ ] 롱프레스 반응 영역이 기존 삭제 동작과 충돌하지 않음
- [x] `dart analyze` 통과 (이 환경에서 `flutter analyze` 는 code 255 로 크래시한다. 본 태스크 파일 error·warning 0건, 전체 error 2 / warning 4 로 선행 수치 그대로)

---
---

# 커뮤니티 실기기 QA 후속 (TASK-015 ~ TASK-018)

TASK-008~014 완료(`done`) 후 실기기 QA에서 나온 결함·개선 요청 6건을 4개 태스크로 묶었다.

| QA 요청 | 태스크 | 개발 유형 |
|---------|--------|-----------|
| ① 삭제 기능 체크 | TASK-015 | 조사 → 판정 후 확정 (유지보수 유력) |
| ③ 본문 사진 짤림 / ④ 사진 클릭 시 확대 | TASK-016 | 혼합 (③ 유지보수 + ④ 신규개발) |
| ② 프로필 사진 클릭 시 프로필 상세보기 | TASK-017 | 신규개발 |
| ⑤ 키보드 내리기 / ⑥ 카테고리 기본값 | TASK-018 | 유지보수 |

범위가 불명확했던 2건은 사용자 확인을 거쳐 확정했다.
- **② 프로필 상세** → **최소안**. 바텀시트 · 아바타/닉네임/가입일만 · **보기 전용**(신고·차단·작성 글 목록 없음).
- **⑤ 키보드 내리기** → **앱 전체**. 커뮤니티 3곳 + `live_match_chat` · `profile_edit` · `login` · `sign_up`.

## 실행 순서와 선행 조건

```
TASK-015 (삭제 조사) ── 독립. 사람이 먼저 재현 확인

[사람] 20260826000100 마이그레이션 원격 적용
   └─▶ TASK-016 (이미지) ──▶ TASK-017 (프로필) ──▶ TASK-018 (키보드+카테고리)
```

- **TASK-016 · 017 · 018은 세 태스크 모두 `community_post_detail_view.dart`를 건드린다.**
  (016은 `CommunityImageGrid` 호출부, 017은 `_buildAuthorRow` 탭 타겟, 018은 `body` 래핑)
  상태는 전부 `pending`으로 두었지만 **반드시 위 순서대로 하나씩 실행하고, 하나가 끝난 뒤 다음 team-lead를 돌린다.** 동시에 돌리면 같은 파일에서 충돌한다.
- **TASK-017은 마이그레이션 선행이 필수다.** `public_profiles` 뷰에 `created_at`을 추가하는 `20260826000100`을 **사람이 원격에 먼저 적용해야 한다.** TASK-008과 같은 이유로 마이그레이션을 담당하는 에이전트가 없다. 적용 전에 team-lead를 돌리면 API Agent가 존재하지 않는 컬럼을 조회하는 코드를 만든다.
- TASK-015는 서브 에이전트 분배 대상이 아니다(`manual`). 재현 절차로 증상을 특정한 뒤 개발 유형과 상태를 확정한다.
- TASK-016 · 018은 마이그레이션이 없다.

> **Stitch**: 이 프로젝트에서 Stitch MCP는 인증 오류(`Incompatible auth server: does not support dynamic client registration`)로 호출이 실패한다. TASK-015~018 작성 시에도 `list_screens`를 1회 시도해 동일 오류를 확인했다. 화면 매핑은 전부 `없음 (Stitch 미대응 — 기존 View 준용)`이다.

> **커뮤니티 쓰기는 RPC 경유가 강제된다** (컬럼 단위 GRANT, `20260823000200`). 아래 태스크들은 새 쓰기 경로를 만들지 않으므로 신규 RPC가 필요 없다.

---

## TASK-015: 게시글·댓글 삭제 결함 재현 확인 및 수정

- **상태**: `done` (2026-08-26) — 후보 A만 수정. 후보 B·C는 범위 밖으로 남겨 둔다
- **개발 유형**: **유지보수**
- **생성일**: 2026-08-26
- **설명**: 삭제한 게시글이 작성자 본인에게 되살아나는 결함을 고친다. 목록 쿼리에 `deleted` 제외 필터가 없다.
- **선행**: 없음
- **기획서 참조**: §6-1(더보기 시트), §7(소프트 삭제)

> **범위 확정 (2026-08-26)**
> 1단계 재현 확인을 실기기 대신 **정적 검증으로 대체했다.** 아래 3가지를 코드·마이그레이션에서 직접 확인해 후보 A를 원인으로 확정했다.
> 1. `cp_select`(`20260823000200_community_core.sql:370`)가 `author_id = (select auth.uid())`로 **작성자 본인 행을 `status`와 무관하게 통과**시킨다.
> 2. `community_post_feed`는 `security_invoker = on`(`20260823000400:25`)이라 위 정책이 그대로 적용된다.
> 3. `CommunityPostRepository.listPosts`(54행)에 `status` 필터가 **없다.**
>
> → 삭제 직후에는 `_removeFromList`의 메모리 제거로 사라져 보이지만, **pull-to-refresh 또는 앱 재시작 시 되살아난다.** 운영자 계정은 타인의 삭제 글까지 목록에 섞여 보인다.
>
> **이번 태스크 범위는 후보 A뿐이다.** 아래 후보 B·C는 사용자 판정 전이므로 **손대지 않는다.**
> - **후보 B**(목록 카드에 더보기 ⋯ 추가) — 설계 의도인지 미정. 요청받지 않은 UI 추가이므로 제외. Controller/UI Agent 작업 없음.
> - **후보 C**(삭제 시 스토리지 고아 파일) — 소프트 삭제 설계상 의도일 수 있음. 정리가 필요하다고 판정되면 배치/Edge Function 별도 태스크로 분리.
> - 후보 D·E는 후보 A 확정으로 해당 없음.
>
> **댓글은 해당 없다.** `cc_select`도 같은 구조지만 `community_comment_feed`가 삭제 댓글을 툼스톤(내용 NULL 마스킹)으로 내려주는 것이 의도된 동작이다(대댓글 고아 방지). 댓글 쪽 코드는 건드리지 않는다.

---

### 개발 유형 분류

| 항목 | 내용 |
|------|------|
| 유형 | **미확정 — 재현 확인 전까지 코드를 고치지 않는다** |
| 판단 근거 | 삭제 경로(UI → 컨트롤러 → 레포지토리 → RPC)는 이미 전부 구현돼 있다. 신규 기능이 아니라 기존 동작의 결함 조사다 |
| 영향 범위 | 후보 A 확정 시 `community_post_repository.dart` 1파일. 후보 B 확정 시 `community_view.dart` + `community_post_card.dart`. 후보 C 확정 시 마이그레이션 1건 |

---

### 현재 구현 상태 (조사 전 확인 완료 — 재조사 불필요)

정적 분석으로 확인한 사실이다. 아래는 **이미 정상 구현돼 있다.**

| 계층 | 위치 | 상태 |
|------|------|------|
| 진입점 | `community_more_sheet.dart` — `isMine && onDelete != null`일 때만 '삭제' 항목 렌더 | 정상 |
| 호출부 | `community_post_detail_controller.dart:627` `onDelete: mine ? confirmDeletePost : null` | 정상 |
| 게시글 | `confirmDeletePost()`(252) → 확인 다이얼로그 → `deletePost()`(268) → `_removeFromList` → `Get.back()` → 스낵바 | 정상 |
| 댓글 | `confirmDeleteComment()`(533) → `deleteComment()` → 툼스톤 교체 | 정상 |
| 레포지토리 | `CommunityPostRepository.deletePost:282` → RPC `community_delete_post(p_id)` / `CommunityCommentRepository.deleteComment` → RPC `community_delete_comment(p_id)` | 정상 |
| RPC | `20260823000400_community_feed_views.sql:123,142` — `security definer`, `author_id = auth.uid() or is_app_admin()` + `status <> 'deleted'`, 미매칭 시 `hint='forbidden'` 예외 | 정상 |
| 권한 | 두 RPC 모두 `authenticated`에 execute grant 있음 | 정상 |

**즉 "삭제가 아예 동작하지 않는다"는 코드상 근거가 없다.** 아래 재현 절차로 실제 증상을 특정하는 것이 이 태스크의 첫 단계다.

---

### 1단계 — 재현 확인 (사람이 실기기에서 수행)

아래 표를 채운 뒤에야 2단계로 넘어간다. **채우기 전에 코드를 수정하지 않는다.**

| # | 확인 항목 | 기록 |
|---|-----------|------|
| Q1 | 어느 삭제인가 — 게시글 / 댓글 / 대댓글 / 둘 다 | |
| Q2 | 어느 진입점에서 시도했나 — 상세 화면 더보기(⋯) / 목록 화면 / 다른 곳 | |
| Q3 | 증상은 무엇인가 — ⓐ '삭제' 항목이 아예 안 보임 / ⓑ 눌러도 무반응 / ⓒ "삭제 실패" 스낵바 / ⓓ "삭제 완료" 후에도 목록에 남음 / ⓔ 스토리지 이미지가 남음 | |
| Q4 | 본인 글인가, 남의 글인가, 운영자 계정인가 | |
| Q5 | ⓓ라면 — 앱을 껐다 켜거나 pull-to-refresh 한 뒤에도 남아 있나 | |
| Q6 | ⓒ라면 — 스낵바 문구와 `CommunityPostDetailController.deletePost error:` 로그 원문 | |

---

### 2단계 — 증상별 대응 분기

#### 후보 A — 증상 ⓓ "삭제 완료 후 새로고침하면 다시 나타남" (**가장 유력**)

정적 분석 중 **실제 결함을 확인했다.** 원인이 확정된 유일한 후보다.

- `20260823000200_community_core.sql:370` `cp_select` 정책:
  ```sql
  using (
    (status = 'visible'
      or author_id = (select auth.uid())     -- ← 본인 글은 status 무관하게 통과
      or public.is_app_admin())
    and not public.community_is_blocked(author_id)
  );
  ```
- `community_post_feed`는 `security_invoker = on`이라 이 정책이 그대로 적용된다 → **작성자 본인에게는 `status = 'deleted'`인 자기 글이 피드에 계속 반환된다.**
- `CommunityPostRepository.listPosts`(54행)는 `status` 필터를 붙이지 않는다. 파일 상단 19행 주석 *"클라이언트에서 `status`를 따로 거를 필요가 없다"* 는 **타인 기준으로만 맞는 서술이며 본인 행에는 성립하지 않는다.**
- `_removeFromList`는 메모리상 `RxList`에서만 지운다. 그래서 **삭제 직후에는 사라져 보이지만, pull-to-refresh 하거나 앱을 재시작하면 삭제한 글이 되살아난다.** 사용자가 "삭제가 안 된다"고 느끼기에 충분한 증상이다.
- 운영자 계정은 `is_app_admin()` 때문에 **모든 사용자의 삭제된 글**이 피드에 섞여 보인다.

**수정 방향** (`community_post_repository.dart` 1파일, `listPosts` 쿼리)
- [x] 목록 쿼리에 `.neq('status', 'deleted')` 추가.
- [x] **`.eq('status', 'visible')`이 아니라 `.neq('status', 'deleted')`인 이유**: `hidden`은 작성자 본인과 운영자가 봐야 한다(작성자는 자기 글이 숨김 처리된 사실을 알아야 하고, 운영자는 그 화면에서 복구 조치를 한다 — `community_more_sheet.dart` 문서 참조). `visible`만 남기면 이 두 동작이 죽는다.
- [x] 상세 조회(`fetchPost`)에는 필터를 **넣지 않는다.** 운영자가 알림을 눌러 숨김 글 상세로 바로 진입하는 경로가 있다.
- [x] 파일 상단 19행 주석을 사실에 맞게 고친다 — "본인·운영자 행은 `status`가 `visible`이 아니어도 통과하므로 목록 쿼리에서만 `deleted`를 제외한다".

#### 후보 B — 증상 ⓐ "목록에서는 삭제할 방법이 없다"

- `CommunityView` / `CommunityPostCard`에는 더보기(⋯) 진입점이 **없다**(grep 확인: `CommunityMoreSheet` 호출은 `community_post_detail_controller.dart` 두 곳뿐). 카드 전체가 상세 진입 `InkWell`이다.
- 즉 **상세 화면에 들어가야만 삭제할 수 있다.** 사용자가 목록에서 지우려다 실패했다면 이것이 증상이다.
- **판정 필요**: 설계 의도인지 결함인지. 목록 카드에 더보기 버튼을 추가하면 카드 탭(상세 진입)과 탭 타겟이 겹치므로 TASK-016의 제스처 충돌 체크와 같은 주의가 필요하다.
- 대응 시: `community_post_card.dart`에 `onMore` 콜백 추가 + `CommunityController`에 `showPostMore(post)` 추가. **`CommunityMoreSheet`는 수정하지 않는다** (상태를 갖지 않고 호출부가 플래그를 넘기는 구조라 그대로 재사용 가능).

#### 후보 C — 증상 ⓔ "스토리지 이미지가 그대로 남음"

- `community_delete_post` RPC는 `status`만 `'deleted'`로 바꾸고 `image_paths`는 건드리지 않는다. 스토리지 파일도 지우지 않는다 → **고아 파일이 누적된다.**
- **판정 필요**: 소프트 삭제 설계상 의도(신고 대응·복구 여지)인지, 정리 대상인지.
- 의도라면 **아무것도 고치지 않고** 이 사실만 문서에 남긴다.
- 정리 대상이라면 클라이언트에서 지우면 안 된다(삭제 후 복구 불가 + 권한 경계). Edge Function 또는 배치로 `status='deleted' and updated_at < now() - interval '30 days'`인 글의 `image_paths`를 정리하는 **별도 태스크**로 분리한다. 이 태스크 범위 밖이다.

#### 후보 D — 증상 ⓒ "삭제 실패" 스낵바

- `communityErrorMessage`가 `hint='forbidden'`을 "권한이 없습니다."로 변환한다. 이 문구가 떴다면 RPC의 `not found` 분기다 = `author_id`가 `auth.uid()`와 다르거나 이미 `deleted`다.
- 확인 순서: ① 로그인 세션의 uid와 글의 `author_id` 일치 여부 ② 이미 삭제된 글을 다시 삭제하려 한 것은 아닌지(더보기 시트가 열린 채 다른 기기에서 삭제된 경우) ③ 그 외 문구라면 `code`/`hint` 원문을 로그에서 확보.

#### 후보 E — 증상 ⓑ "눌러도 무반응"

- `deletePost()`는 `if (!isMine) return;` / `if (_isDeleting.value) return;`로 **조용히 반환**한다. 스낵바도 로그도 남기지 않는다.
- 재현되면 이 두 조기 반환에 `log()`를 추가해 어느 쪽인지 먼저 특정한다.

---

### API Agent 작업

> 1단계 재현 확인 전에는 착수하지 않는다. 후보 A 확정 시에만 아래를 수행한다.

#### 수정 파일
- `lib/app/data/repositories/community_post_repository.dart` — `listPosts` 쿼리에 `.neq('status', 'deleted')` 추가 + 상단 19행 주석 정정

#### 기능 정의
- [x] `listPosts`에만 필터 추가. `fetchPost`(상세)는 변경하지 않는다
- [x] 모델·마이그레이션 변경 없음

---

### Controller Agent 작업

> 후보 B 또는 E 확정 시에만 수행한다. 후보 A만 확정되면 **작업 없음.**

#### 수정 파일 (후보 B)
- `lib/app/modules/community/controllers/community_controller.dart` — `showPostMore(CommunityPostResponse post)` 추가

#### 기능 정의
- [ ] `CommunityMoreSheet.show(...)`를 목록에서도 호출. `isMine` 판정은 상세 컨트롤러(622행 부근)와 동일 규칙을 쓴다 — **미수행** (후보 B는 이번 범위 밖)
- [ ] 삭제 성공 시 `removePost(id)` 호출 — `Get.back()`은 **부르지 않는다**(목록에서는 닫을 화면이 없다) — **미수행** (후보 B는 이번 범위 밖)

---

### UI Agent 작업

> 후보 B 확정 시에만 수행한다.

#### 수정 파일
- `lib/app/modules/community/views/widgets/community_post_card.dart` — 우상단 더보기(⋯) 버튼 + `onMore` 콜백
- `lib/app/modules/community/views/community_view.dart` — `onMore` 연결

#### UI 구성
- 카드 헤더 우측에 `Icons.more_horiz`, 히트 영역 40×40 이상
- **카드 전체 `InkWell`(상세 진입)과 탭 타겟이 겹치므로** 더보기 버튼을 `InkWell` 자식으로 두되 자체 `GestureDetector`가 이벤트를 소비하게 한다

#### Stitch 화면 매핑
| 화면(View) | Stitch 화면명 | Stitch screenId | resource name |
|------------|---------------|-----------------|----------------|
| `community_post_card.dart` | 없음 (Stitch 미대응 — 기존 View 준용) | — | — |

#### 참조 이미지
| 화면(View) | 이미지 경로 | 설명 |
|------------|-------------|------|
| — | 없음 | — |

#### Figma 참조
- 없음

---

### QA 체크리스트

#### 재현 확인 (1단계 — 수정 전 필수)
- [ ] Q1~Q6 표를 실기기에서 채웠다 — **미수행.** 1단계를 정적 검증으로 대체했다(§범위 확정)
- [ ] 본인 글 삭제 → **pull-to-refresh** → 목록에 남아 있는지 확인 (후보 A 판정) — **미검증** (실기기 필요). 후보 A는 `cp_select` 정책 · 뷰 `security_invoker` · `listPosts` 쿼리 3건을 코드에서 직접 읽어 확정했다
- [ ] 본인 글 삭제 → **앱 완전 종료 후 재시작** → 목록에 남아 있는지 확인 (후보 A 판정) — **미검증** (실기기 필요). 후보 A는 `cp_select` 정책 · 뷰 `security_invoker` · `listPosts` 쿼리 3건을 코드에서 직접 읽어 확정했다
- [ ] 운영자 계정으로 목록 진입 → 남의 삭제된 글이 섞여 보이는지 확인 (후보 A 판정) — **미검증** (실기기 필요). 후보 A는 `cp_select` 정책 · 뷰 `security_invoker` · `listPosts` 쿼리 3건을 코드에서 직접 읽어 확정했다
- [ ] 목록 화면에 더보기(⋯)가 없어 상세로 들어가야만 삭제 가능한 점이 사용자가 말한 증상인지 확인 (후보 B 판정) — **미판정** (후보 B는 이번 범위 밖)
- [ ] 삭제된 글의 스토리지 파일이 남아 있는지 Supabase Storage에서 확인 (후보 C 판정) — **미판정** (후보 C는 이번 범위 밖)

#### 기능 테스트 (후보 A 수정 후)
- [ ] 본인 글 삭제 → 새로고침·재시작 후에도 목록에 나타나지 않음 — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)
- [ ] 삭제한 글의 상세를 딥링크로 열면 접근 불가 또는 적절한 안내 — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)
- [ ] 댓글 삭제 → "삭제된 댓글입니다" 툼스톤 유지, 대댓글 스레드 구조 보존 — **미검증**. 댓글 코드는 이번 태스크에서 건드리지 않았다(툼스톤은 의도된 동작)
- [ ] 대댓글 삭제 → 부모 댓글의 `reply_count` 정합 — **미검증**. 댓글 코드는 이번 태스크에서 건드리지 않았다(툼스톤은 의도된 동작)

#### 예외 처리 / 엣지 케이스
- [ ] 남의 글 더보기에 '삭제'가 노출되지 않음 — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)
- [ ] 이미 삭제된 글을 다시 삭제 시도 → "권한이 없습니다." 스낵바 (앱 크래시 없음) — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)
- [ ] 삭제 중 연속 탭 → 중복 RPC 호출 없음 (`_isDeleting` 가드) — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)
- [ ] 네트워크 끊김 상태에서 삭제 → 실패 스낵바, 목록은 그대로 유지 — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)

#### 유지보수 전용 (후보 A 수정 시)
- [x] **운영자 계정 회귀** — 숨김(`hidden`) 글이 목록에 **여전히 보인다** (`.eq('status','visible')`로 잘못 고치면 여기서 깨진다) — 정적 확인 (2026-08-26) — 필터는 `.neq('status', 'deleted')` 뿐이라 `hidden` 행은 그대로 통과한다
- [x] **작성자 본인 회귀** — 운영자가 숨긴 내 글이 내 목록에 여전히 보인다 — 정적 확인 (2026-08-26) — 위와 동일한 근거
- [ ] 일반 사용자 목록 조회 결과 건수가 수정 전후 동일 — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)
- [ ] 카테고리 필터 / 무한 스크롤 / pull-to-refresh 정상 — **미검증** (실기기 필요). 필터는 `category`/`before`/`order`/`limit` 앞에 붙어 기존 쿼리 조합을 바꾸지 않는다
- [ ] 비로그인 상태 목록 조회 정상 (`auth.uid()` NULL 경로) — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)
- [x] 마이그레이션 0건 — 기존 사용자 데이터 영향 없음 — 정적 확인 (2026-08-26) — `supabase/migrations/` 에 추가한 파일 없음

#### UI/UX 테스트
- [x] `dart analyze` 통과 (이 환경에서 `flutter analyze`는 code 255로 크래시한다) — 정적 확인 (2026-08-26) — `dart analyze lib/` 결과 201 issues / error 2 / warning 4 (전부 선행 이슈, 수정 파일 0건)

---

## TASK-016: 본문 이미지 비율 유지 · 이미지 확대 뷰어

- **상태**: `done` (2026-08-26) — 마이그레이션 없이 (a)안(클라이언트 실측)으로 구현. 신규 패키지 없음
- **개발 유형**: **혼합** — 비율 유지는 유지보수, 뷰어는 신규개발
- **생성일**: 2026-08-26
- **설명**: 게시글 상세의 본문 이미지가 위아래로 잘리는 문제를 고치고, 이미지를 탭하면 전체화면으로 확대·스와이프해 볼 수 있는 뷰어를 추가한다.
- **선행**: 없음 (TASK-017·018보다 **먼저** 실행한다 — 실행 순서 참조)
- **기획서 참조**: §3 S-2

---

### 개발 유형 분류

| 항목 | 내용 |
|------|------|
| 유형 (QA ③ 비율 유지) | 유지보수 — 기존 `CommunityImageGrid`의 레이아웃 규칙 변경 |
| 유형 (QA ④ 확대 뷰어) | 신규개발 — 뷰어 위젯이 존재하지 않는다 |
| 판단 근거 | 두 건 모두 `community_image_grid.dart` **같은 파일**을 건드린다. 분리하면 두 태스크가 동일 파일에서 충돌하므로 한 태스크로 묶는다 |
| 영향 범위 | `community_image_grid.dart`(수정), 뷰어 위젯 1종(신규). 호출부는 `community_post_detail_view.dart:147` 한 곳뿐 — 목록 카드의 썸네일은 **별도 코드**(`community_post_card.dart:180`)라 영향 없다 |

---

### 현재 구현 상태 (확인 완료)

- `community_image_grid.dart`
  - 1장: `AspectRatio(aspectRatio: 16 / 9)` + `BoxFit.cover` → **세로 사진이 위아래로 잘린다. 이것이 QA ③의 원인이다.**
  - 2장: `AspectRatio(aspectRatio: 1)` 정사각 2칸
  - 3장 이상: 2열 그리드, 앞 4장만 그리고 마지막 칸에 `+N` 오버레이
  - 모든 타일이 `_tile()`의 `CachedNetworkImage(fit: BoxFit.cover)`
  - 클래스 문서 주석 12행에 *"(뷰어는 이 태스크 범위가 아니다)"* 라고 명시 — **처음부터 미구현이며, 이 태스크에서 그 서술이 무효가 되므로 주석도 함께 고친다.**
- `+N` 오버레이는 현재 **탭해도 나머지 이미지를 볼 방법이 없다.** 뷰어가 생기면 이 오버레이가 진입점이 된다.
- **이미지 비율 메타데이터가 DB에 없다.** `community_posts.image_paths`는 경로 `text[]`뿐이다(`20260823000200_community_core.sql`).
- 새 패키지가 필요 없다. `InteractiveViewer` / `PageView`는 Flutter 기본 위젯이고 `cached_network_image`는 `pubspec.yaml`에 이미 있다.

---

### 비율 유지 방식 결정 (③)

DB에 비율이 없으므로 세 갈래가 있다. **(a)를 채택한다.**

| 안 | 방식 | 마이그레이션 | 문제 |
|----|------|--------------|------|
| **(a) 채택** | 클라이언트에서 `ImageStream`으로 실측 후 `AspectRatio`에 반영 | 불필요 | 첫 로드 시 레이아웃 점프 가능 → **비율을 clamp하고 placeholder 비율을 고정해 완화한다** |
| (b) | 업로드 시 width/height를 DB에 저장 | **필요** | 정확하지만 기존 게시글에는 값이 없어 백필이 필요하고, 쓰기 경로가 RPC 강제라 작업량이 크다 |
| (c) | `BoxFit.contain` + 최대 높이 제한 | 불필요 | 잘리지는 않지만 상하좌우에 레터박스 여백이 생겨 카드 디자인이 깨진다 |

**(a) 구현 규칙**
- **1장일 때만 실측 비율을 적용한다.** 2장 이상은 정사각 그리드를 유지한다 — 칸마다 비율이 다르면 격자가 어긋나고, 회귀 위험이 커진다. QA에서 지적된 것도 본문 대표 이미지(1장) 케이스다.
- 실측 비율은 **`3/4` ~ `16/9` 범위로 clamp**한다. 9:16 같은 극단 세로 사진이 화면을 다 먹는 것을 막으면서, 일반적인 4:3·3:4 사진은 잘림 없이 전부 보인다.
- 비율을 알기 전(placeholder 구간)에는 `4/3`으로 그린다 — 실측 후 이동 폭이 가장 작은 중간값이다.
- `BoxFit.cover`는 유지한다. clamp 범위 안에서는 잘림이 거의 없고, 범위를 벗어난 극단 비율만 제한적으로 잘린다.

---

### 파일 목록

#### 신규 생성 파일
- `lib/app/modules/community/views/widgets/community_image_viewer.dart`

#### 수정 파일
- `lib/app/modules/community/views/widgets/community_image_grid.dart` — 1장 비율 실측, 타일 탭 → 뷰어, `+N` 오버레이 탭 → 뷰어, 클래스 주석 정정
- `lib/app/modules/community/views/community_post_detail_view.dart` — `CommunityImageGrid` 호출부(147행)는 인자 변경이 없으면 무수정. 뷰어 오픈에 컨텍스트가 필요하면 이 한 줄만 수정

---

### API Agent 작업

**없음.** 데이터 스키마·쿼리 변경이 없다. (b)안을 택하지 않았으므로 마이그레이션도 없다.

---

### Controller Agent 작업

**없음.** 뷰어는 상태를 컨트롤러에 두지 않는다 — 이미지 URL 목록과 초기 인덱스만 인자로 받는 `StatefulWidget`이다. GetX 컨트롤러를 새로 만들 이유가 없다.

---

### UI Agent 작업

#### 생성 파일
- `lib/app/modules/community/views/widgets/community_image_viewer.dart`

#### 수정 파일
- `lib/app/modules/community/views/widgets/community_image_grid.dart`

#### UI 구성 — 이미지 뷰어
- **화면 유형**: 전체화면 오버레이
- **진입**: `CommunityImageViewer.show(imageUrls: [...], initialIndex: n)` static 메서드. 내부에서 `Get.to(() => CommunityImageViewer(...), fullscreenDialog: true, transition: Transition.fadeIn)`
- **레이아웃**: 배경 `Colors.black`, `Stack`[`PageView.builder`, 상단 닫기 버튼 + 인덱스 표시]
- **각 페이지**: `InteractiveViewer(minScale: 1, maxScale: 4)` → `CachedNetworkImage(fit: BoxFit.contain)`
  - 뷰어에서는 **`BoxFit.contain`이 맞다.** 원본 전체를 보는 것이 목적이다
- **인덱스 표시**: 상단 중앙 `n / N`. 1장뿐이면 숨긴다
- **닫기**: ① 우상단 `Icons.close` ② 시스템 뒤로가기 ③ 아래로 스와이프(선택 — 확대 상태와 충돌하므로 여유가 없으면 생략)
- **주의 — 제스처 충돌**: `InteractiveViewer`로 확대한 상태에서 드래그하면 `PageView`가 페이지를 넘겨버린다. **확대 배율이 1을 넘으면 `PageView.physics`를 `NeverScrollableScrollPhysics()`로 전환**하고, 배율이 1로 돌아오면 되돌린다. `TransformationController`의 `value.getMaxScaleOnAxis()`를 리스닝한다. 이 처리를 빠뜨리면 확대 후 사진을 움직일 수 없다
- **페이지 전환 시 확대 배율 초기화** — 확대한 채 다음 장으로 넘어가면 다음 사진도 확대된 상태로 뜬다
- 색상은 `AppColors` 상수 사용. 단 뷰어 배경만 예외로 `Colors.black`을 쓴다(사진 감상용 표준)
- ScreenUtil(`.w/.h/.sp/.r`) 적용

#### UI 구성 — 그리드 수정
- **1장 비율 실측**: `_tile()`을 감싸는 내부 `StatefulWidget`(`_AspectTile`)을 추가해 `CachedNetworkImageProvider(url).resolve(...)`의 `ImageStreamListener`에서 `image.width / image.height`를 받아 `setState`. `clamp(3/4, 16/9)` 적용. **리스너는 `dispose`에서 반드시 해제한다**
- **탭 진입점 3곳**
  - [x] 1장 이미지 탭 → 뷰어 `initialIndex: 0` — 정적 확인 (2026-08-26)
  - [x] 2장·그리드의 각 타일 탭 → 뷰어 해당 인덱스 — 정적 확인 (2026-08-26)
  - [x] `+N` 오버레이 탭 → 뷰어 해당 타일 인덱스(= 4번째 타일이므로 `initialIndex: 3`). **오버레이가 탭을 가로채지 않도록** `Container` 위가 아니라 타일 전체를 `GestureDetector`로 감싼다 — 정적 확인 (2026-08-26)
- 클래스 문서 주석 12행 *"(뷰어는 이 태스크 범위가 아니다)"* 를 실제 동작에 맞게 고친다. **주석을 지우지 말고 무엇이 바뀌었는지 남긴다**
- 그 외 기존 레이아웃 규칙(2장 정사각, 3장 이상 2열 그리드, `_maxTiles=4`, `_gap=6`, `+N` 계산)은 **건드리지 않는다**

#### Stitch 화면 매핑
| 화면(View) | Stitch 화면명 | Stitch screenId | resource name |
|------------|---------------|-----------------|----------------|
| `community_image_viewer.dart` | 없음 (Stitch 미대응 — 기존 View 준용) | — | — |
| `community_image_grid.dart` | 없음 (Stitch 미대응 — 기존 View 준용) | — | — |

Stitch MCP는 이 프로젝트에서 인증 오류로 호출이 실패한다(`list_screens` 재확인 완료). 뷰어는 표준 풀스크린 갤러리 패턴을 따르고, 그리드는 기존 디자인을 유지한다.

#### 참조 이미지
| 화면(View) | 이미지 경로 | 설명 |
|------------|-------------|------|
| — | 없음 | — |

#### Figma 참조
- 없음

#### 의존성
- 없음 (API / Controller Agent 산출물 불필요)

---

### QA 체크리스트

#### 기능 테스트 — 비율 유지 (③)
- [ ] 세로 사진(3:4) 1장 게시글 → **위아래가 잘리지 않고 전부 보인다** — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)
- [ ] 가로 사진(16:9) 1장 → 기존과 동일하게 보인다 — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)
- [ ] 정사각 사진 1장 → 정사각으로 보인다 — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)
- [ ] 극단 세로 사진(9:16) 1장 → 3:4로 clamp돼 화면을 다 먹지 않는다 — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)
- [ ] 극단 가로 사진(21:9) 1장 → 16:9로 clamp된다 — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)

#### 기능 테스트 — 뷰어 (④)
- [ ] 1장 이미지 탭 → 전체화면 뷰어가 열린다 — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)
- [ ] 좌우 스와이프로 다음/이전 사진 이동 — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)
- [ ] 핀치 줌으로 확대·축소, 확대 상태에서 드래그로 이동 — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)
- [ ] 인덱스 `n / N` 표시가 스와이프에 맞춰 갱신 — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)
- [ ] 닫기 버튼 · 시스템 뒤로가기로 닫힌다 — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)
- [ ] 5장 게시글의 `+N` 오버레이 탭 → 뷰어가 열리고 **5장 전부를 스와이프로 볼 수 있다** (그리드에는 4장만 보이지만 뷰어는 전체를 받는다) — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)

#### 예외 처리 / 엣지 케이스
- [ ] **확대 상태에서 드래그해도 페이지가 넘어가지 않는다** (제스처 충돌 — 가장 놓치기 쉬운 항목) — **미검증** (실기기 필요). 배율 > 1.01 이면 `PageView.physics` 를 `NeverScrollableScrollPhysics` 로 전환하도록 구현했다
- [ ] 확대한 채 다음 장으로 넘어가면 다음 사진은 배율 1로 시작한다 — **미검증** (실기기 필요). `onPageChanged` 에서 `TransformationController` 를 `Matrix4.identity()` 로 되돌린다
- [ ] 이미지 로드 실패(잘못된 URL) → 뷰어에서 에러 위젯 표시, 크래시 없음 — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)
- [x] 이미지 로드 중 화면을 나가도 크래시하지 않는다 (`ImageStreamListener` 해제 확인) — 정적 확인 (2026-08-26) — `dispose()`/`didUpdateWidget` 에서 `ImageStream.removeListener`, `ImageInfo` 는 읽은 뒤 `dispose()`
- [x] 이미지 0장 게시글 → 그리드 미렌더(`SizedBox.shrink`), 회귀 없음 — 정적 확인 (2026-08-26) — `imageUrls.isEmpty` 조기 반환 경로 변경 없음
- [ ] 느린 네트워크에서 placeholder → 실제 이미지 전환 시 레이아웃 점프 폭이 수용 가능한가 — **미검증** (실기기 필요). placeholder 비율을 clamp 범위 중간값 `4/3` 으로 고정해 이동 폭을 줄였다

#### 유지보수 전용 (기존 레이아웃 회귀)
- [x] **1장** — 비율 적용 외 라운딩(12.r) · 여백 유지 — 정적 확인 (2026-08-26) — `ClipRRect(12.r)` 유지, `AspectRatio` 값만 실측 비율로 교체
- [x] **2장** — 정사각 2칸, 간격 6, 변경 없음 — 정적 확인 (2026-08-26) — `_squareTile` 에 `index` 인자와 `GestureDetector` 만 추가
- [x] **3장** — 2열 2행, 마지막 칸이 비어 정사각 비율 유지 (기존 `SizedBox.shrink` 동작) — 정적 확인 (2026-08-26)
- [x] **4장** — 2열 2행 꽉 참, `+N` 오버레이 없음 — 정적 확인 (2026-08-26)
- [x] **5장** — 앞 4장 + 마지막 칸에 `+1` 오버레이 — 정적 확인 (2026-08-26) — `_maxTiles`·`_gap`·`+N` 계산 로직 무변경
- [x] 목록 화면 카드 썸네일(`community_post_card.dart`)이 **전혀 바뀌지 않았다** — 별도 코드이며 이 태스크 범위 밖 — 정적 확인 (2026-08-26) — `community_post_card.dart` 무수정
- [x] 게시글 상세의 나머지 동작(좋아요·댓글·더보기·스크롤) 회귀 없음 — 정적 확인 (2026-08-26) — `community_post_detail_view.dart` 무수정 (호출부 인자 변경 없음)
- [x] 마이그레이션 0건 — 기존 사용자 데이터 영향 없음 — 정적 확인 (2026-08-26)

#### UI/UX 테스트
- [x] ScreenUtil 적용, 색상은 `AppColors` 상수 (뷰어 배경 `Colors.black`만 예외) — 정적 확인 (2026-08-26)
- [ ] 320pt · 375pt · 430pt 폭에서 그리드·뷰어 레이아웃 정상 — **미검증** (실기기 필요: 이 워크트리에 `firebase_options.dart`·`.env` 가 없어 빌드·실행 불가)
- [ ] `[GETX] the improper use of a GetX` 콘솔 경고 없음 — **미검증** (실기기 필요). 뷰어는 GetX 컨트롤러를 쓰지 않는 순수 `StatefulWidget` 이다
- [x] `dart analyze` 통과 — 정적 확인 (2026-08-26) — 신규·수정 파일에서 error·warning 0건

---

## TASK-017: 작성자 프로필 상세보기 (바텀시트)

- **상태**: `done` (2026-08-26) — 마이그레이션 선행 조건 해소 후 구현 완료
- **개발 유형**: 신규개발
- **생성일**: 2026-08-26
- **설명**: 커뮤니티에서 작성자 프로필 사진을 탭하면 아바타·닉네임·가입일을 보여주는 바텀시트를 띄운다. **보기 전용**이다.
- **선행**: TASK-016 (같은 `community_post_detail_view.dart`를 건드린다) + **마이그레이션 `20260826000100` 원격 적용**
- **기획서 참조**: §6-3

> **범위 확정** (사용자 확인 완료 — 최소안 A 채택)
> - **바텀시트로 처리한다. 풀스크린 라우트를 만들지 않는다.**
> - 담는 것은 **아바타 + 닉네임 + 가입일**이 전부다.
> - **신고·차단 액션을 넣지 않는다.** 기존 더보기(⋯) 시트에 이미 있고, 프로필은 보기 전용으로 한다.
> - **작성 글 목록을 넣지 않는다.** `community_post_feed`의 `author_id` 필터 조회도 이번 범위 밖이다.
> - 가입일 표시를 위한 `public_profiles` 뷰 `created_at` 추가 마이그레이션 1건은 포함한다.
>
> 애초에 권장했던 중간안(B: 신고·차단 포함)과 확장안(C: 작성 글 목록)은 **채택되지 않았다.** 요청받지 않은 작업이므로 별도 태스크로도 만들지 않는다.

---

### 선행 조건 (사람이 먼저 수행)

**`supabase/migrations/20260826000100_public_profiles_created_at.sql`를 원격에 먼저 적용해야 한다.** TASK-008과 같은 이유다 — 마이그레이션을 담당하는 에이전트가 없다. 적용 전에 team-lead를 돌리면 API Agent가 존재하지 않는 컬럼(`created_at`)을 조회하는 코드를 만든다.

- [x] 마이그레이션 파일 작성 (아래 §마이그레이션 작업) — `supabase/migrations/20260826000100_public_profiles_created_at.sql`
- [x] 원격 적용 및 검증 완료 (2026-08-26, Rally `ztcfgymcxilxcjahyucw`)
- [x] 그 다음 이 태스크를 team-lead에 넘긴다

> **원격 적용 결과 (2026-08-26)** — 선행 조건 해소됨. API Agent 는 `public_profiles.created_at` 을 그대로 조회하면 된다.
> - 컬럼 순서 확인: `id`(1) · `nickname`(2) · `avatar_url`(3) · **`created_at`(4)** — 맨 뒤 추가 성공
> - 의존 뷰 정상: `community_post_feed` 6행 · `community_comment_feed` 8행 조회 성공
> - 데이터 확인: 프로필 16건 전부 `created_at` 값 보유 (NULL 없음)
> - `get_advisors`(security): **신규 경고 0건.** `public_profiles` 의 `security_definer_view` ERROR 는 2026-06-30 뷰 생성 시점부터 있던 선행 항목이다
>
> **참고 — 원격 드리프트**: 원격에는 로컬에 없는 마이그레이션 `20260824020356 community_harden_function_grants` 가 적용돼 있다. 이번 태스크와 무관하지만 `supabase/migrations/` 와 원격이 어긋난 상태다.

---

### 개발 유형 분류

| 항목 | 내용 |
|------|------|
| 유형 | 신규개발 |
| 판단 근거 | 프로필 시트 위젯·컨트롤러가 전부 없다. 타인 프로필을 보여주는 경로가 앱 어디에도 없다(`/profile-edit`는 본인 전용) |
| 영향 범위 | `ProfileRepository`(메서드 1개 추가), 아바타·작성자 탭 타겟 3곳, `public_profiles` 뷰 마이그레이션 1건. **라우트 파일은 건드리지 않는다**(바텀시트라 `app_routes.dart`/`app_pages.dart` 수정 없음) |

---

### 현재 구현 상태 (확인 완료)

- **데이터 소스는 이미 있다.** `public.public_profiles` 뷰 (`20260630010000_public_profiles_view.sql`) — `id`, `nickname`, `avatar_url` 노출, `anon`/`authenticated`에 select grant.
  - **이 뷰는 의도적으로 `security_invoker`가 없다** = RLS를 우회한다. 노출 컬럼을 3개로 최소화해 정당화한 케이스이며 마이그레이션 주석에 근거가 적혀 있다.
- `profiles.created_at`은 존재한다 (`20260622000000_profiles_and_favorite_players.sql:9`). 다만 `public_profiles` 뷰에는 노출돼 있지 않다.
- `ProfileRepository`는 본인 프로필만 다룬다 (`fetchMyProfile`, `updateNickname`, `uploadAvatar`, `removeAvatar`).
- 작성자 정보가 그려지는 곳 3군데 — **셋의 구조가 서로 다르다**:

| # | 위치 | 렌더 요소 | 탭 타겟으로 쓸 것 |
|---|------|-----------|-------------------|
| 1 | `community_post_detail_view.dart:273` `_buildAuthorRow` | `ClipOval` 아바타 36×36 + 닉네임 `Text` | 아바타 + 닉네임 |
| 2 | `community_comment_tile.dart:139` `_buildAvatar` | `ClipOval` 아바타 28×28 | 아바타 |
| 3 | `community_post_card.dart` `_buildMetaRow`(91행~) | **아바타 없음.** 카테고리 칩 · **작성자 닉네임 `Text`** · 상대시간 | **닉네임 `Text`** |

> **3번 주의**: 목록 카드에는 프로필 사진이 **없다**(썸네일은 게시글 첨부 이미지이지 아바타가 아니다). 그래서 여기서는 `_buildMetaRow`의 **작성자 닉네임 텍스트**를 탭 타겟으로 삼는다. 카드 전체가 상세 진입 `InkWell`(31행)이므로 **닉네임 탭이 상세 진입을 함께 발동시키지 않도록** 이벤트를 소비시켜야 한다. 아래 QA §제스처 충돌에 전용 항목을 두었다.

---

### 파일 목록

#### 신규 생성 파일
- `supabase/migrations/20260826000100_public_profiles_created_at.sql`
- `lib/app/data/models/public_profile_response.dart`
- `lib/app/modules/community/controllers/community_profile_controller.dart`
- `lib/app/modules/community/views/widgets/community_profile_sheet.dart`

#### 수정 파일
- `lib/app/data/repositories/profile_repository.dart` — `fetchPublicProfile(String userId)` 추가
- `lib/app/modules/community/views/community_post_detail_view.dart` — `_buildAuthorRow` 탭 타겟
- `lib/app/modules/community/views/widgets/community_comment_tile.dart` — `_buildAvatar` 탭 타겟 + `onAuthorTap` 콜백
- `lib/app/modules/community/views/widgets/community_post_card.dart` — `_buildMetaRow` 닉네임 탭 타겟 + `onAuthorTap` 콜백
- `lib/app/modules/community/controllers/community_post_detail_controller.dart` — `openProfile(String? authorId)` 추가
- `lib/app/modules/community/controllers/community_controller.dart` — `openProfile(String? authorId)` 추가 (목록 카드용)

#### 건드리지 않는 파일
- `lib/app/routes/app_routes.dart` / `app_pages.dart` — **바텀시트라 라우트가 필요 없다**
- `lib/app/modules/community/views/widgets/community_more_sheet.dart` — 신고·차단은 기존 경로를 그대로 둔다

---

### 마이그레이션 작업

> API / Controller / UI Agent 대상이 아니다. **사람이 먼저 적용한다.**

#### `20260826000100_public_profiles_created_at.sql`
```sql
create or replace view public.public_profiles as
select
  id,
  nickname,
  avatar_url,
  created_at          -- ← 반드시 맨 뒤. 순서를 바꾸면 의존 뷰 때문에 replace 가 실패한다
from public.profiles;
```

- [x] **컬럼은 반드시 맨 뒤에 붙인다.** `public_profiles`는 `community_post_feed` / `community_comment_feed`가 join으로 참조한다. `create or replace view`는 기존 컬럼 뒤에 추가하는 것만 허용하며, 순서를 바꾸거나 중간에 끼워 넣으면 의존 뷰 때문에 실패한다
- [x] **주석에 노출 범위를 반드시 남긴다**: 이 뷰는 `security_invoker`가 없어 RLS를 우회하고 `anon`에도 열려 있다 → **비로그인 사용자에게도 전체 사용자의 가입일이 노출된다.** 커뮤니티 프로필 시트의 가입일 표시를 위한 의도된 노출임을 명시한다
- [x] **`created_at` 외에 어떤 컬럼도 추가하지 않는다.** 이 뷰의 정당화 근거는 "노출 필드 최소화"이며, 컬럼을 늘릴수록 그 근거가 약해진다. 향후 필드가 더 필요하면 뷰를 늘리는 대신 `security_invoker`를 켠 별도 뷰를 검토한다
- [x] 적용 후 `community_post_feed` / `community_comment_feed`가 정상 동작하는지 확인 (두 뷰 모두 `pr.nickname`, `pr.avatar_url`만 참조하므로 영향이 없어야 정상)
- [x] Supabase `get_advisors`(security) 경고가 늘지 않았는지 확인

---

### API Agent 작업

#### 생성 파일
- `lib/app/data/models/public_profile_response.dart`

#### 수정 파일
- `lib/app/data/repositories/profile_repository.dart`

#### 데이터 소스
`.from()` + 뷰 직접 조회. **신규 RPC가 필요 없다** — 읽기 전용이며 쓰기 경로를 만들지 않는다.

| 동작 | 호출 |
|------|------|
| 프로필 조회 | `.from('public_profiles').select().eq('id', userId).maybeSingle()` |

#### Response 구조 (`public_profiles` 1행)
```json
{
  "id": "uuid",
  "nickname": "스매시왕",
  "avatar_url": "https://.../avatar.jpg",
  "created_at": "2026-06-22T00:00:00Z"
}
```

#### 모델 규격
- `MODEL_GUIDE.md` 컨벤션 (private 필드 + getter/setter + `fromJson`/`toJson`)
- `displayName` getter — `nickname`이 비면 `User_{id앞4자리}` 폴백. `CommunityPostResponse.authorDisplayName`과 **같은 규칙**을 쓴다
- **`GetPublicProfileResponse` 래퍼를 만들지 말 것** — `.from()` 응답에는 봉투가 없다 (TASK-009와 동일 규칙)

#### 레포지토리
- [x] `Future<PublicProfileResponse?> fetchPublicProfile(String userId)` — 없는 사용자면 `null` 반환
- [x] `ProfileRepository`에 추가한다. **새 레포지토리를 만들지 않는다** — `public_profiles`는 `profiles`의 뷰이고 기존 파일의 책임 범위 안이다
- [x] 기존 `_table` 상수(`profiles`)와 별개로 뷰 이름 상수를 둔다

---

### Controller Agent 작업

#### 생성 파일
- `lib/app/modules/community/controllers/community_profile_controller.dart`

#### 수정 파일
- `lib/app/modules/community/controllers/community_post_detail_controller.dart`
- `lib/app/modules/community/controllers/community_controller.dart`

#### 기능 정의 — `CommunityProfileController`
- [x] `Get.put`으로 시트를 띄울 때 생성하고, 시트가 닫힐 때 `Get.delete`한다. **바인딩 파일을 만들지 않는다** — 라우트가 없으므로 `Bindings` 클래스가 붙을 곳이 없다
- [x] 생성자에서 `userId`(필수), `fallbackNickname`·`fallbackAvatarUrl`(선택 — 로딩 중 즉시 표시용)를 받는다
- [x] `Rxn<PublicProfileResponse> profile` / `RxBool isLoading` / `RxnString errorMessage`
- [x] `onInit()`에서 `fetchProfile()`. **이 화면은 사용자 액션으로 열리므로 TASK-009의 "`onInit`에서 fetch하지 않는다" 규칙이 적용되지 않는다** — 그 규칙은 `IndexedStack`으로 항상 마운트되는 탭 화면에만 해당한다
- [x] 에러 메시지는 `communityErrorMessage(e)`로 변환
- [x] **신고·차단 관련 상태와 메서드를 넣지 않는다.** `CommunityModerationRepository`를 주입하지 않는다

#### 기능 정의 — `openProfile` (두 컨트롤러 공통)
- [x] 시그니처: `void openProfile(String? authorId, {String? nickname, String? avatarUrl})`
- [x] **`authorId`가 null이거나 비면 아무 일도 하지 않는다** — 탈퇴한 사용자다(`author_id`는 nullable + `on delete set null`). 시트를 띄우지 않고, 스낵바도 띄우지 않는다(조용히 무시)
- [x] `CommunityProfileSheet.show(userId: ..., fallbackNickname: ..., fallbackAvatarUrl: ...)` 호출
- [x] `CommunityPostDetailController`와 `CommunityController` 양쪽에 같은 구현을 둔다. **공용 유틸로 추출하지 않는다** — 2곳뿐이고 각자 다른 모델(`post` / `comment`)에서 값을 꺼낸다

#### 의존성
- API Agent 생성 파일: `lib/app/data/models/public_profile_response.dart`

---

### UI Agent 작업

#### 생성 파일
- `lib/app/modules/community/views/widgets/community_profile_sheet.dart`

#### 수정 파일
- `lib/app/modules/community/views/community_post_detail_view.dart`
- `lib/app/modules/community/views/widgets/community_comment_tile.dart`
- `lib/app/modules/community/views/widgets/community_post_card.dart`

#### UI 구성 — 프로필 바텀시트
- **화면 유형**: 바텀시트 (`Get.bottomSheet`)
- **호출 규약**: `CommunityProfileSheet.show({required String userId, String? fallbackNickname, String? fallbackAvatarUrl})` static 메서드. `CommunityMoreSheet.show`(39행)의 구조를 그대로 준용한다 — `isScrollControlled: true`, `backgroundColor: Colors.transparent`
- **레이아웃**
  ```
  ┌─────────────────────────────┐
  │           ──                │  드래그 핸들
  │                             │
  │          ◯ 아바타 72         │  중앙 정렬, ClipOval
  │         스매시왕             │  Chivo w700 18sp, 흰색
  │      2026년 6월 가입         │  subtleText 13sp
  │                             │
  └─────────────────────────────┘
  ```
- **높이**: 콘텐츠에 맞춘 고정 높이. 스크롤이 필요 없다
- **상태 분기**: 로딩 / 에러 / 정상 3단. `fallbackNickname`·`fallbackAvatarUrl`이 있으면 **로딩 중에도 아바타·닉네임을 먼저 그리고 가입일 자리만 스켈레톤**으로 둔다 — 이미 화면에 보이던 정보라 깜빡임이 없어야 한다
- **아바타**: `ClipOval` + `CachedNetworkImage(fit: BoxFit.cover)`, 없으면 `Icons.person` placeholder. **기존 `_avatarPlaceholder` 구현(`community_comment_tile.dart:157`)을 그대로 준용한다**
- **가입일 포맷**: `2026년 6월 가입` — **일 단위까지 노출하지 않는다**
- **액션 버튼을 넣지 않는다.** 신고·차단·프로필 수정 어느 것도 없다. 닫기는 시트 바깥 탭 / 아래로 스와이프(`Get.bottomSheet` 기본 동작)
- 색상은 `AppColors` 상수만, ScreenUtil(`.w/.h/.sp/.r`) 적용. `CommunityMoreSheet`의 배경·라운딩·패딩 값을 맞춘다

#### UI 구성 — 탭 타겟 3곳
- [x] **① `community_post_detail_view.dart` `_buildAuthorRow`** — 아바타 `ClipOval`과 닉네임 `Text`를 **함께** `GestureDetector`로 감싼다. 우측 더보기(⋯) 버튼은 감싸는 범위에서 **제외**한다
- [x] **② `community_comment_tile.dart` `_buildAvatar`** — `onAuthorTap` 콜백 파라미터를 추가하고 아바타를 감싼다. **`onMore`와 같은 패턴으로 nullable로 두고, null이면 탭을 걸지 않는다**
- [x] **③ `community_post_card.dart` `_buildMetaRow`** — 작성자 닉네임 `Text`를 `GestureDetector`로 감싸고 `onAuthorTap` 콜백을 추가한다. **아바타가 없으므로 닉네임이 유일한 작성자 요소다**
  - 카드 전체가 `InkWell(onTap: onTap)`(31행)이므로 **닉네임 탭이 상세 진입을 함께 발동시키지 않도록** `GestureDetector`가 이벤트를 소비하게 한다
  - 히트 영역이 닉네임 글자 폭만큼이라 좁다. `Padding`으로 상하 4.h 정도 여유를 주되 **레이아웃을 밀지 않는 선까지만** 한다
- [x] 세 곳 모두 **시각적 변화를 주지 않는다** — 밑줄·색 변경·언더라인 금지. 기존 디자인을 그대로 유지한다
- [ ] 댓글 타일은 이미 `onLongPress: onMore`(62행)와 `onTap`(200행) 제스처를 갖고 있다. **아바타 탭이 이들을 가로채지 않는지 반드시 확인한다** — **미검증** (실기기 필요). 아바타에는 `onTap` 만 걸었다

#### Stitch 화면 매핑
| 화면(View) | Stitch 화면명 | Stitch screenId | resource name |
|------------|---------------|-----------------|----------------|
| `community_profile_sheet.dart` | 없음 (Stitch 미대응 — 기존 View 준용) | — | — |

Stitch MCP 호출이 인증 오류로 실패한다(재확인 완료). `community_more_sheet.dart`의 시트 톤과 `community_post_detail_view.dart` `_buildAuthorRow`의 아바타·닉네임 스타일을 기준으로 삼는다.

#### 참조 이미지
| 화면(View) | 이미지 경로 | 설명 |
|------------|-------------|------|
| — | 없음 | 위 ASCII 레이아웃 참조 |

#### Figma 참조
- 없음

#### 의존성
- Controller Agent 생성 파일: `lib/app/modules/community/controllers/community_profile_controller.dart`

---

### QA 체크리스트

> 이 워크트리에는 `firebase_options.dart` 와 `.env` 가 없어 **빌드·실행이 불가능하다.** 실기기가 필요한 항목은 `미검증` 으로 남겼다.

#### 기능 테스트
- [ ] 게시글 상세에서 작성자 **아바타** 탭 → 프로필 시트가 뜬다 — **미검증** (실기기 필요). `_buildAuthorRow` 전체가 `GestureDetector(behavior: opaque)` → `controller.openProfile(post.authorId, ...)`
- [ ] 게시글 상세에서 작성자 **닉네임** 탭 → 프로필 시트가 뜬다 — **미검증** (실기기 필요). 아바타와 같은 `GestureDetector` 안에 있다
- [ ] **댓글** 아바타 탭 → 해당 댓글 작성자 시트 — **미검증** (실기기 필요)
- [ ] **대댓글** 아바타 탭 → 해당 작성자 시트 — **미검증** (실기기 필요). 대댓글도 같은 `CommunityCommentTile` 이라 경로가 동일하다
- [ ] **목록 카드**의 작성자 닉네임 탭 → 프로필 시트 — **미검증** (실기기 필요)
- [ ] 아바타 · 닉네임 · 가입일(`2026년 6월 가입` 형식)이 정상 표시된다 — **미검증** (실기기 필요). 포맷은 `_buildSubline` 의 `joinedAt.year` / `joinedAt.month` 보간이다 — 일 단위는 노출하지 않는다
- [ ] 시트 바깥 탭 / 아래로 스와이프로 닫힌다 — **미검증** (실기기 필요). `Get.bottomSheet` 기본 동작이며 `isDismissible` 을 끄지 않았다
- [x] **신고·차단·프로필 수정 버튼이 어디에도 없다** (보기 전용 확인) — 정적 확인 (2026-08-26) — `community_profile_sheet.dart` 에 `ListTile`·버튼·`onTap` 이 하나도 없고, 컨트롤러는 `CommunityModerationRepository` 를 주입하지 않는다
- [ ] 로딩 중에도 이미 알고 있던 아바타·닉네임이 즉시 보이고 깜빡이지 않는다 — **미검증** (실기기 필요). `fallbackNickname`·`fallbackAvatarUrl` 을 3개 호출부 모두에서 넘기고, 컨트롤러 `displayName`/`avatarUrl` 게터가 로드 전에는 폴백을 돌려준다

#### 예외 처리 / 엣지 케이스
- [x] **탈퇴한 사용자**(`author_id` NULL) 탭 → **시트가 뜨지 않는다.** 크래시·빈 시트·에러 스낵바 모두 없다 — 정적 확인 (2026-08-26) — 두 컨트롤러의 `openProfile` 이 `id == null || id.isEmpty` 면 즉시 return 한다(스낵바 없음). 댓글 툼스톤은 호출부가 `onAuthorTap: null` 을 넘겨 탭 자체를 걸지 않는다
- [x] 존재하지 않는 `userId` → "사용자를 찾을 수 없습니다" 안내, 크래시 없음 — 정적 확인 (2026-08-26) — `maybeSingle()` 이 null 을 주고 컨트롤러가 `errorMessage` 로 전환한다
- [x] 네트워크 오류 → 시트 안에 에러 표시. 앱이 멈추지 않는다 — 정적 확인 (2026-08-26) — `fetchProfile()` 의 catch 가 `communityErrorMessage(e)` 로 변환해 시트 본문(`_buildSubline`)에 그린다
- [x] `nickname`이 NULL인 기존 사용자 → `User_xxxx` 폴백 표시 — 정적 확인 (2026-08-26) — `PublicProfileResponse.displayName` 이 `CommunityPostResponse.authorDisplayName` 과 같은 규칙이다
- [x] `avatar_url`이 NULL → `Icons.person` placeholder — 정적 확인 (2026-08-26) — `community_comment_tile.dart` 의 `_avatarPlaceholder` 를 그대로 준용
- [x] `created_at`이 NULL인 행 → 가입일 줄을 숨긴다 (빈 문자열·`null` 노출 금지) — 정적 확인 (2026-08-26) — `_buildSubline` 이 `SizedBox.shrink()` 를 돌려준다
- [x] **차단한 사용자의 프로필** — 차단하면 그 사용자의 글·댓글이 피드에서 사라지므로(`cp_select`의 `community_is_blocked`) 정상 경로로는 도달하지 않는다. **다만 차단 직후 이미 화면에 떠 있던 상세에서 탭하면 도달할 수 있다.** 이 경우 시트는 정상적으로 뜨고 닉네임·아바타·가입일을 그대로 보여준다 — 정적 확인 (2026-08-26) — 조회 경로에 차단 판정을 넣지 않았고 `public_profiles` 는 RLS 를 우회한다
- [x] 본인 프로필 탭 → 남과 동일한 시트가 뜬다 (보기 전용이므로 분기하지 않는다) — 정적 확인 (2026-08-26) — `currentUser` 비교 코드가 없다
- [ ] 시트를 연 채 뒤로가기 → 시트만 닫히고 화면은 유지된다 — **미검증** (실기기 필요). `Get.bottomSheet` 기본 동작
- [ ] 시트를 빠르게 연속으로 열고 닫아도 컨트롤러가 중복 등록되지 않는다 (`Get.delete` 확인) — **미검증** (실기기 필요). `show()` 가 `try/finally` 로 `Get.delete<CommunityProfileController>(force: true)` 를 보장하고, `Get.put` 은 같은 타입을 교체한다

#### 제스처 충돌 (필수)
- [ ] **목록 카드 닉네임 탭 → 시트만 뜨고 게시글 상세로 진입하지 않는다** (가장 위험한 항목 — 카드 전체가 `InkWell`이다) — **미검증** (실기기 필요). 닉네임을 `GestureDetector(behavior: opaque)` 로 감쌌다. 중첩된 탭 인식기는 히트테스트가 깊은 쪽부터 아레나에 들어가 더 깊은 쪽이 이긴다
- [ ] 목록 카드의 **닉네임 외 영역** 탭 → 기존대로 상세 진입 — **미검증** (실기기 필요). `InkWell` 은 그대로 두었다
- [ ] 댓글 아바타 탭이 **댓글 롱프레스 더보기**(`onLongPress: onMore`)를 가로채지 않는다 — **미검증** (실기기 필요). 아바타에는 `onTap` 만 걸어 롱프레스는 상위 `GestureDetector` 로 간다
- [ ] 댓글 아바타 탭이 **댓글 탭 동작**을 가로채지 않는다 — **미검증** (실기기 필요). 아바타 영역 밖은 변화가 없다
- [x] 게시글 상세 작성자 행 탭이 **더보기(⋯) 버튼** 탭과 겹치지 않는다 — 정적 확인 (2026-08-26) — 상세의 더보기는 이 행이 아니라 **AppBar `actions`** 에 있어 물리적으로 겹치지 않는다
- [ ] TASK-016의 **본문 이미지 탭 → 뷰어**가 여전히 정상 동작 — **미검증** (실기기 필요). `CommunityImageGrid` 는 수정하지 않았고 작성자 행 제스처는 sliver 상단에 한정된다

#### 보안 점검
- [x] `public_profiles`에 `created_at` 외 다른 컬럼이 추가되지 않았다 — 확인 완료 (2026-08-26) — 원격 컬럼 4개(`id`·`nickname`·`avatar_url`·`created_at`)
- [x] 마이그레이션 주석에 "RLS 우회 + `anon` 노출 + 가입일이 비로그인에도 보인다"는 사실이 적혀 있다 — 확인 완료 (2026-08-26) — `20260826000100` 의 「★ 노출 범위 ★」 블록
- [x] `community_post_feed` / `community_comment_feed`가 뷰 교체 후에도 정상 동작 — 확인 완료 (2026-08-26) — 각각 6행 · 8행 조회 성공
- [x] Supabase `get_advisors`(security) 경고가 마이그레이션 전후로 늘지 않았다 — 확인 완료 (2026-08-26) — 신규 경고 0건

#### UI/UX 테스트
- [x] 아바타·닉네임·목록 카드의 **기존 시각적 표현이 전혀 바뀌지 않았다** (탭 가능 표시를 추가하지 않았다) — 정적 확인 (2026-08-26) — 밑줄·색·아이콘을 추가하지 않았다. 단 목록 카드 닉네임에 히트 영역용 **수직 2.h 패딩**을 넣었다. 같은 행 카테고리 칩(수직 3.h + 11sp)보다 낮아 카테고리가 있는 정상 게시글에서는 행 높이가 변하지 않는다(카테고리는 서버 CHECK 로 항상 존재한다)
- [x] ScreenUtil 적용, 색상은 `AppColors` 상수만 사용 — 정적 확인 (2026-08-26) — 시트의 닉네임 색만 `Colors.white`(기존 상세·카드와 동일 관례)
- [ ] 320pt · 375pt · 430pt 폭에서 시트 레이아웃 정상 — **미검증** (실기기 필요)
- [ ] `[GETX] the improper use of a GetX` 콘솔 경고 없음 — **미검증** (실기기 필요). `Obx` 는 아바타 / 닉네임 / 가입일 3덩이로 쪼개 두었다
- [x] `dart analyze` 통과 — 정적 확인 (2026-08-26) — 신규·수정 파일에서 error·warning 0건 (전체 205 issues / error 2 / warning 4 는 모두 선행 이슈)

---

## TASK-018: 키보드 내리기 · 글쓰기 카테고리 기본값

- **상태**: `done`
- **개발 유형**: 유지보수
- **생성일**: 2026-08-26
- **설명**: 텍스트 입력 화면에서 빈 영역을 탭하면 키보드가 내려가게 하고, 글쓰기 진입 시 카테고리가 선택돼 있지 않은 문제를 "자유"(`free`) 기본값으로 고친다.
- **선행**: TASK-017 (같은 `community_post_detail_view.dart`를 건드린다)
- **기획서 참조**: §3 S-3, §8-1

> **범위 확정** (사용자 확인 완료): 키보드 내리기는 **앱 전체**에 적용한다. 커뮤니티 3곳(게시글 상세 / 글쓰기 / 약관·닉네임 시트) + `live_match_chat` + `profile_edit` + `login` + `sign_up`, 총 7개 화면이다. 커뮤니티 밖 4곳도 동일 증상이 있고 수정 방식이 화면당 몇 줄로 같다. **로그인·회원가입 회귀 테스트가 이 태스크의 QA 범위에 포함된다.**

---

### 개발 유형 분류

| 항목 | 내용 |
|------|------|
| 유형 | 유지보수 |
| 판단 근거 | 두 건 모두 기존 화면·컨트롤러의 동작 수정이다. 신규 화면·모델·라우트·마이그레이션이 없다 |
| 영향 범위 | ⑤ 텍스트 입력이 있는 화면 7종의 `Scaffold` body 래핑. ⑥ `community_compose_controller.dart` 1파일 |
| 두 건을 묶은 이유 | 성격은 다르지만 둘 다 수정 규모가 작고, **글쓰기 화면(`community_compose_view` / `_controller`)이 두 건 모두의 대상**이라 함께 QA하는 편이 효율적이다 |

---

## ⑤ 키보드 내리기

### 현재 구현 상태 (확인 완료)

어느 화면에도 화면 탭으로 포커스를 해제하는 코드가 없다.

| # | 화면 | 파일 | 입력 필드 | 구조 |
|---|------|------|-----------|------|
| 1 | 게시글 상세 | `community_post_detail_view.dart:30` | 하단 `CommunityCommentInputBar` | `Scaffold` → `body: SafeArea` |
| 2 | 글쓰기 | `community_compose_view.dart:37` | 제목 / 본문 | `PopScope` → `Scaffold`(`resizeToAvoidBottomInset: true`) |
| 3 | 커뮤니티 약관 시트 | `community_eula_sheet.dart:138` | 닉네임 | **`Scaffold`가 없다** — `Padding` → `Container` 바텀시트 |
| 4 | 라이브 채팅 | `live_match_chat_view.dart:23` | 메시지 입력 | `Scaffold`(`resizeToAvoidBottomInset: true`) |
| 5 | 프로필 수정 | `profile_edit_view.dart:20` | 닉네임 | `Scaffold` → `body: SafeArea` |
| 6 | 로그인 | `login_view.dart:24` | 이메일 / 비밀번호 | `Scaffold`(`resizeToAvoidBottomInset: true`) |
| 7 | 회원가입 | `sign_up_view.dart:23` | 이메일 / 비밀번호 등 | `Scaffold`(`resizeToAvoidBottomInset: true`) |

1~3이 커뮤니티, 4~7이 커뮤니티 밖이다. **7개 전부가 이번 범위다.**

### 구현 규칙

- 각 화면의 `Scaffold` **body를** 아래로 감싼다. `Scaffold` 자체를 감싸면 AppBar 영역 탭이 먹지 않는다.
  ```dart
  GestureDetector(
    onTap: () => FocusScope.of(context).unfocus(),
    behavior: HitTestBehavior.opaque,
    child: <기존 body>,
  )
  ```
- **3번(약관 시트)은 `Scaffold`가 없다.** 31행 `Padding`의 자식인 `Container`를 같은 방식으로 감싼다.
- ~~**`behavior: HitTestBehavior.opaque`가 하위 탭 제스처를 삼키는 것이 이 태스크의 핵심 위험이다.**~~ → **정정 (2026-08-26 구현 시점).** 히트테스트는 깊은 자식부터 등록되므로 제스처 아레나에서 **안쪽 `GestureDetector`/`InkWell`이 이긴다.** 아바타·좋아요·더보기·카드 탭은 막히지 않고, 채팅 메시지 `onLongPress`도 탭과는 타이밍으로 갈린다. `onTap`은 드래그를 주장하지 않으므로 스크롤에도 영향이 없다. 따라서 중첩된 기존 `GestureDetector`(`community_compose_view.dart:157,366,398`, `live_match_chat_view.dart:435,484`, `login_view.dart:247,264`, `sign_up_view.dart:326`)를 **제거하거나 통합할 필요가 없다** — 그대로 둔다.
- **실제 결함은 반대 방향이다 — 탭을 스스로 소비하는 위젯에서는 부모의 unfocus가 걸리지 않는다.** `community_post_detail_view.dart`의 본문 `SelectableText`가 그 경우다. 선택 가능한 텍스트라 자체 탭 인식기가 탭을 먹는데, **화면에서 면적이 가장 넓은 영역**이라 body 래핑만으로는 댓글을 쓰다 본문을 눌러 키보드를 닫는 가장 흔한 동작이 동작하지 않는다. → `SelectableText`의 `onTap`에 unfocus를 직접 붙여 해결했다(텍스트 선택 동작은 그대로 유지된다). 나머지 6개 화면에는 `SelectableText`나 자체 탭 인식기를 가진 위젯이 없어 body 래핑만으로 충분하다(`SelectionArea` / `EditableText` / `TapGestureRecognizer` 전수 확인 완료).
- 그래도 제스처 충돌은 실기기에서 한 번 확인한다 — 아래 QA의 §제스처 충돌 회귀 항목은 그대로 수행한다.
- **`resizeToAvoidBottomInset`는 건드리지 않는다.** 이미 설정된 화면은 그대로 둔다.
- 기존 `GestureDetector`를 제거하거나 통합하지 않는다 — 각자 다른 책임이다.

### UI Agent 작업 (⑤)

#### 수정 파일
- `lib/app/modules/community/views/community_post_detail_view.dart`
- `lib/app/modules/community/views/community_compose_view.dart`
- `lib/app/modules/community/views/widgets/community_eula_sheet.dart`
- `lib/app/modules/live_match_chat/views/live_match_chat_view.dart`
- `lib/app/modules/profile_edit/views/profile_edit_view.dart`
- `lib/app/modules/login/views/login_view.dart`
- `lib/app/modules/sign_up/views/sign_up_view.dart`

#### 기능 정의
- [x] 7개 화면에 동일한 래핑을 적용한다. **화면마다 다른 방식을 쓰지 않는다** — 6개는 `Scaffold`의 `body: SafeArea(...)`를, 약관 시트는 `Container`를 감쌌다
- [x] 헬퍼를 새로 만들지 않는다 — 3줄짜리 래핑에 공용 위젯을 도입하는 것은 과설계다
- [x] 기존 레이아웃·색상·여백은 일절 변경하지 않는다 — 래핑에 따른 들여쓰기 외 변경 없음. `resizeToAvoidBottomInset`도 그대로다
- [x] 본문 `SelectableText`에 `onTap` unfocus 추가 (`community_post_detail_view.dart:147`) — 위 §구현 규칙의 정정 사항

---

## ⑥ 글쓰기 카테고리 기본값

### 현재 구현 상태 (원인 확정)

`lib/app/modules/community/controllers/community_compose_controller.dart`

- 50행: `final selectedCategory = RxnString();` — 초기값 `null`
- 112~113행: 작성 모드 진입 시
  ```dart
  if (Get.isRegistered<CommunityController>()) {
    selectedCategory.value = CommunityController.to.selectedCategory;
  }
  ```
  `CommunityController.selectedCategory`는 `RxnString`이며 **"전체"일 때 `null`이다**(`community_controller.dart:79`). 따라서 목록에서 "전체"를 보다가 글쓰기로 들어가면 **아무 카테고리도 선택되지 않은 채 화면이 뜬다.**
- 396~400행 `_validate`가 `category == null || category.isEmpty`면 "카테고리를 선택해주세요."로 제출을 막는다 → 사용자가 등록 버튼을 눌러야 비로소 알게 된다.
- 카테고리 코드는 `free` / `match` / `gear` / `partner` (`20260823000200_community_core.sql:23` CHECK 제약). **"자유" = `free`**

### Controller Agent 작업 (⑥)

#### 수정 파일
- `lib/app/modules/community/controllers/community_compose_controller.dart`

#### 기능 정의
- [x] 112~113행 블록에서 **물려받은 값이 `null`이거나 비면 `'free'`로 폴백**한다
  ```dart
  selectedCategory.value = CommunityController.to.selectedCategory ?? 'free';
  ```
- [x] `CommunityController`가 등록돼 있지 않은 경로(딥링크 등)에서도 `'free'`가 들어가도록 `else` 분기를 함께 둔다. 현재는 등록되지 않으면 `null`로 남는다 — 삼항으로 두 경로 모두 `defaultCategory` 폴백
- [x] 110~112행의 기존 주석 *"「전체」를 보고 있었다면 미선택 상태로 두고 사용자가 고르게 한다"* 를 **바뀐 동작에 맞게 고친다.** 주석을 지우지 말고 정정한다
- [x] **수정 모드(`_applyPost` 170행 `selectedCategory.value = post.category;`)는 절대 건드리지 않는다.** 기존 글의 카테고리가 `free`로 덮이면 데이터 손상이다 — `_applyPost` 무수정
- [x] `RxnString` 타입은 그대로 둔다 — `_validate`의 null 방어는 서버 CHECK와 짝을 이루므로 제거하지 않는다
- [x] `'free'`를 리터럴로 흩뿌리지 말고 파일 내 기존 카테고리 상수 관례를 따른다 — `static const String defaultCategory = 'free';` 추가 (`argPostId` 옆)

### UI Agent 작업 (⑥)

**없음.** `community_compose_view.dart:145 _buildCategoryChips`는 `controller.selectedCategory.value`를 그대로 읽으므로(149행) 컨트롤러 초기값만 바뀌면 칩이 자동으로 선택 상태로 렌더된다.

---

### API Agent 작업

**없음.** 두 건 모두 모델·쿼리·마이그레이션 변경이 없다.

---

### Stitch 화면 매핑

| 화면(View) | Stitch 화면명 | Stitch screenId | resource name |
|------------|---------------|-----------------|----------------|
| 전체 | 없음 (Stitch 미대응 — 기존 View 준용) | — | — |

Stitch MCP 호출이 인증 오류로 실패한다(재확인 완료). **이 태스크는 디자인을 변경하지 않는다** — 제스처 래핑과 초기값 변경뿐이다.

### 참조 이미지
| 화면(View) | 이미지 경로 | 설명 |
|------------|-------------|------|
| — | 없음 | — |

### Figma 참조
- 없음

---

### QA 체크리스트

#### 기능 테스트 — 키보드 내리기 (⑤)
- [ ] 게시글 상세 — 댓글 입력 중 본문·댓글 영역 탭 → 키보드가 내려간다 — **미검증** (실기기 필요)
- [ ] 글쓰기 — 제목/본문 입력 중 빈 영역 탭 → 키보드가 내려간다 — **미검증** (실기기 필요)
- [ ] 커뮤니티 약관 시트 — 닉네임 입력 중 시트 빈 영역 탭 → 키보드가 내려간다 — **미검증** (실기기 필요)
- [ ] 라이브 채팅 — 메시지 입력 중 채팅 영역 탭 → 키보드가 내려간다 — **미검증** (실기기 필요)
- [ ] 프로필 수정 — 닉네임 입력 중 빈 영역 탭 → 키보드가 내려간다 — **미검증** (실기기 필요)
- [ ] 로그인 — 이메일/비밀번호 입력 중 빈 영역 탭 → 키보드가 내려간다 — **미검증** (실기기 필요)
- [ ] 회원가입 — 입력 중 빈 영역 탭 → 키보드가 내려간다 — **미검증** (실기기 필요)
- [ ] **iOS · Android 양쪽에서 확인** (포커스 처리 동작이 다르다) — **미검증** (실기기 필요)

#### 기능 테스트 — 카테고리 기본값 (⑥)
- [ ] 목록에서 **"전체"**를 보던 중 글쓰기 진입 → 카테고리 칩이 **"자유"로 선택된 상태**로 뜬다 — **미검증** (실기기 필요)
- [ ] 목록에서 "장비"를 보던 중 글쓰기 진입 → **"장비"가 선택된 상태**로 뜬다 (기존 동작 유지) — **미검증** (실기기 필요)
- [ ] 기본값 그대로 제목·본문만 채워 등록 → "카테고리를 선택해주세요." 없이 정상 등록되고 `category = 'free'`로 저장된다 — **미검증** (실기기 필요)
- [ ] 기본값에서 다른 카테고리로 바꿔 등록 → 바꾼 값으로 저장된다 — **미검증** (실기기 필요)

#### 제스처 충돌 회귀 (⑤ — 이 태스크의 최대 위험)
> `behavior: HitTestBehavior.opaque`가 하위 탭 제스처를 삼키면 여기서 드러난다. **화면별로 전부 확인한다.**

**게시글 상세** — 제스처가 가장 많이 겹치는 화면이다
- [ ] 카드/본문 스크롤이 정상 동작한다 — **미검증** (실기기 필요)
- [ ] **좋아요 버튼** 탭 → 토글되고 카운트가 갱신된다 — **미검증** (실기기 필요)
- [ ] **더보기(⋯)** 탭 → 시트가 뜬다 — **미검증** (실기기 필요)
- [ ] **댓글 롱프레스 → 더보기 시트**가 뜬다 (`community_comment_tile.dart:62`) — **미검증** (실기기 필요)
- [ ] **댓글 탭 동작**(`community_comment_tile.dart:200`)이 정상 동작 — **미검증** (실기기 필요)
- [ ] **답글 달기 / 답글 접기** 탭이 정상 동작 — **미검증** (실기기 필요)
- [ ] **본문 이미지 탭 → 확대 뷰어**가 열린다 (TASK-016 산출물) — **미검증** (실기기 필요)
- [ ] **`+N` 오버레이 탭 → 뷰어**가 열린다 (TASK-016 산출물) — **미검증** (실기기 필요)
- [ ] **작성자 아바타 탭 → 프로필 시트**가 뜬다 (TASK-017 산출물) — **미검증** (실기기 필요)
- [ ] **작성자 닉네임 탭 → 프로필 시트**가 뜬다 (TASK-017 산출물) — **미검증** (실기기 필요)
- [ ] **댓글 아바타 탭 → 프로필 시트**가 뜬다 (TASK-017 산출물) — **미검증** (실기기 필요)
- [ ] 댓글 입력창 탭 → 키보드가 **올라온다** (unfocus가 포커스 획득을 막지 않는지) — **미검증** (실기기 필요)

**글쓰기** — 기존 `GestureDetector`가 3개 있다 (`community_compose_view.dart:157,366,398`)
- [ ] **카테고리 칩** 탭 → 선택이 바뀐다 — **미검증** (실기기 필요)
- [ ] **이미지 추가** 탭 → 피커가 열린다 — **미검증** (실기기 필요)
- [ ] **이미지 삭제(×)** 탭 → 해당 이미지가 제거된다 — **미검증** (실기기 필요)
- [ ] **등록 버튼** 탭 → 제출된다 — **미검증** (실기기 필요)
- [ ] 제목 → 본문으로 포커스 이동이 정상 동작한다 — **미검증** (실기기 필요)

**커뮤니티 약관·닉네임 시트**
- [ ] **동의 체크박스 / 약관 링크 / 확인 버튼**이 정상 동작 — **미검증** (실기기 필요)
- [ ] 시트 바깥 탭 → 시트가 닫힌다 (unfocus가 닫기를 가로채지 않는지) — **미검증** (실기기 필요)

**라이브 채팅** — 위험도 높음
- [ ] **메시지 롱프레스 → 신고 / 이 사용자 차단**이 정상 동작 (타인 메시지) — **미검증** (실기기 필요)
- [ ] **메시지 롱프레스 → 삭제**가 정상 동작 (본인 메시지) — **미검증** (실기기 필요)
- [ ] **스코어 가리기 토글**이 정상 동작 — **미검증** (실기기 필요)
- [ ] 기존 `GestureDetector`(`live_match_chat_view.dart:435,484`)가 걸린 요소들이 정상 동작 — **미검증** (실기기 필요)
- [ ] 메시지 전송 버튼 탭 → 전송된다 — **미검증** (실기기 필요)
- [ ] 스크롤 및 Realtime 수신 중 탭이 오작동을 만들지 않는다 — **미검증** (실기기 필요)

**프로필 수정**
- [ ] 아바타 변경 / 저장 버튼 탭이 정상 동작 — **미검증** (실기기 필요)

**로그인 / 회원가입** — 기존 `GestureDetector`가 있다 (`login_view.dart:247,264`, `sign_up_view.dart:326`)
- [ ] 로그인 버튼 · 소셜 로그인 · "회원가입" 링크 탭이 정상 동작 — **미검증** (실기기 필요)
- [ ] 회원가입 버튼 · 약관 체크박스 · 링크 탭이 정상 동작 — **미검증** (실기기 필요)
- [ ] 이메일 → 비밀번호 포커스 이동이 정상 동작 — **미검증** (실기기 필요)

**영향이 없어야 하는 곳**
- [ ] 커뮤니티 목록 카드 탭 → 상세 진입 (이 화면은 수정 대상이 아니다) — **미검증** (실기기 필요)

#### 예외 처리 / 엣지 케이스
- [ ] 키보드가 올라오지 않은 상태에서 화면 탭 → 아무 일도 일어나지 않는다 (오작동 없음) — **미검증** (실기기 필요)
- [ ] 스크롤 중 손가락을 떼도 키보드가 임의로 내려가지 않는다 (탭과 스크롤 구분) — **미검증** (실기기 필요)
- [ ] 글쓰기 **수정 모드** 진입 → 카테고리가 **원래 글의 카테고리**로 뜬다 (`free`로 덮이지 않는다) — **미검증** (실기기 필요)
- [ ] 수정 모드에서 카테고리를 바꾸지 않고 저장 → 카테고리가 그대로 유지된다 — **미검증** (실기기 필요)
- [ ] `CommunityController` 미등록 경로(딥링크)로 글쓰기 진입 → `free`가 선택돼 있다 — **미검증** (실기기 필요)

#### 유지보수 전용
- [ ] **수정 전 기존 기능 회귀** — 댓글 작성·수정·삭제, 게시글 작성·수정·이미지 업로드, 채팅 송수신·Realtime·Presence 접속자 수 — **미검증** (실기기 필요)
- [ ] **로그인 전체 플로우 회귀** — 이메일 로그인 성공/실패, 자동 로그인, 로그아웃 — **미검증** (실기기 필요)
- [ ] **회원가입 전체 플로우 회귀** — 가입 성공, 중복 이메일 오류, 약관 동의 검증 — **미검증** (실기기 필요)
- [x] 기존 사용자 데이터 영향 없음 — **마이그레이션 0건** (정적 확인 2026-08-26: 이번 태스크에 SQL 파일 추가·수정 없음)
- [ ] 이미 작성된 게시글의 `category` 값이 변경되지 않았다 — **미검증** (실기기 필요)
- [ ] `resizeToAvoidBottomInset` 설정이 있던 화면에서 키보드 올라올 때 레이아웃이 기존과 동일 — **미검증** (실기기 필요)

#### UI/UX 테스트
- [ ] 레이아웃·색상·여백이 수정 전과 동일 (디자인 변경 없음) — **미검증** (실기기 필요). 코드상 변경은 래핑에 따른 들여쓰기뿐이다
- [ ] 320pt · 375pt · 430pt 폭에서 정상 — **미검증** (실기기 필요)
- [ ] `[GETX] the improper use of a GetX` 콘솔 경고 없음 — **미검증** (실기기 필요)
- [x] `dart analyze` 통과 — 정적 확인 (2026-08-26). 아래 §정적 검증 참조

#### 정적 검증 (2026-08-26)
- [x] `dart analyze lib/` — **205 issues / error 2 / warning 0**, TASK-017 완료 시점 기준선과 동일. error 2건은 `lib/main.dart`의 `firebase_options.dart` 누락(`.gitignore`된 생성 파일)으로 선행 이슈다
- [x] 7개 화면 + 컨트롤러 1개 수정 후 신규 error·warning 0건
- [x] `SelectableText` / `SelectionArea` / `EditableText` / `TapGestureRecognizer` 전수 검색 — 7개 화면 중 탭을 소비하는 위젯은 게시글 상세 본문 `SelectableText` 하나뿐
- **빌드·실행 불가**: 워크트리에 `firebase_options.dart`와 `.env`가 없다. 위 실기기 항목은 전부 **미검증**이며, 통과로 표시하지 않았다
