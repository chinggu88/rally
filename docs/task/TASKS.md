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
