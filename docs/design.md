# 디자인 가이드

Rally 앱의 UI 작성 규칙. 모든 화면/위젯은 `lib/theme/` 의 토큰을 사용하고,
하드코딩된 색상·폰트·간격을 새로 만들지 않는다.

- 기준 디자인: **iPhone 14 Pro (393 × 852)** — `main.dart`의 `ScreenUtilInit(designSize: Size(393, 852))`
- 앱 테마: **다크 고정** (`themeMode: ThemeMode.dark`). 라이트 스킴은 정의만 되어 있고 현재 사용하지 않는다.

---

## 1. 파일 구성

| 파일 | 역할 |
| --- | --- |
| `lib/theme/app_colors.dart` | 색상 팔레트 + `ColorScheme` (dark / light) |
| `lib/theme/app_typography.dart` | 폰트 패밀리, `TextStyle` 프리셋, `TextTheme` |
| `lib/theme/app_spacing.dart` | `AppSpacing` (간격), `AppRadius` (모서리) |
| `lib/theme/app_theme.dart` | 위 셋을 묶은 `ThemeData` (컴포넌트 테마 전부) |

새 토큰이 필요하면 화면 파일에 상수를 만들지 말고 위 파일에 추가한다.

---

## 2. 색상

### 2.1 브랜드 컬러

라임/네온 계열이 Rally의 시그니처다. 다크 배경 위에서 액션·강조에만 쓴다.

| 토큰 | 값 | 용도 |
| --- | --- | --- |
| `AppColors.accent` | `#C3F400` | 주 강조색. 버튼, 활성 탭, 라벨 |
| `AppColors.accentDark` | `#283500` | accent 배경 위의 텍스트/아이콘 |
| `AppColors.accentLime` | `#D7FF00` | 밝은 라임 (하이라이트) |
| `AppColors.accentNeon` | `#E0EC30` | 보조 강조 (secondary) |

### 2.2 배경 / 표면

깊이는 그림자가 아니라 **표면 밝기**로 표현한다 (`elevation: 0`이 기본).

| 토큰 | 값 | 용도 |
| --- | --- | --- |
| `surfaceContainerLowest` | `#0E0E0E` | 가장 깊은 배경 |
| `surface` | `#131313` | Scaffold 기본 배경 |
| `surfaceContainerLow` | `#1C1B1B` | 카드 |
| `surfaceContainer` | `#201F1F` | 카드·칩·입력창·네비게이션 바 |
| `surfaceContainerHigh` | `#2A2A2A` | 다이얼로그, 보더 |
| `surfaceContainerHighest` | `#353534` | 최상위 표면 |

### 2.3 텍스트 / 보더

| 토큰 | 값 | 용도 |
| --- | --- | --- |
| `onSurface` | `#E5E2E1` | 기본 본문 |
| `AppColors.subtleText` | `#9CA3A1` | 보조 설명, 메타 정보 |
| `AppColors.hint` | `#5C5F5D` | 힌트, 비활성 |
| `AppColors.muted` | `#6B6B6B` | 흐린 텍스트 |
| `outlineVariant` | `#444933` | 카드/입력창 테두리, Divider |

### 2.4 상태 색상

| 토큰 | 값 | 용도 |
| --- | --- | --- |
| `AppColors.liveRed` | `#FF3B30` | LIVE 인디케이터 |
| `AppColors.upGreen` | `#4ADE80` | 상승 / 승 |
| `AppColors.downRed` | `#FF6B6B` | 하락 / 패 |
| `AppColors.inactive` | `#3A3A3A` | 비활성 요소 |

### 2.5 사용 규칙

- **`ColorScheme`(`AppColors.dark`) 우선.** 표면/텍스트/보더는 스킴 토큰으로 쓴다.
- `AppColors.xxx` 상수는 스킴에 매핑하기 애매한 톤(브랜드 라임, 상태 색)에만 쓴다.
- `Color(0xFF...)`를 위젯 안에 직접 쓰지 않는다. 새 색이 필요하면 `app_colors.dart`에 이름을 붙여 추가한다.
- 카드 안에서 반복되는 색은 위젯 상단에 `static const Color _accent = AppColors.accent;` 처럼
  별칭을 두는 패턴을 따른다 (`today_match_card.dart` 참고).

---

## 3. 타이포그래피

폰트는 두 가지만 쓴다.

- **Chivo** — 제목, 라벨, 숫자 (SemiBold 600 / Bold 700 / ExtraBold 800)
- **Source Sans 3** — 본문 (Regular 400). 앱 기본 `fontFamily`.

| 프리셋 | 크기 / 굵기 | 행간 | 용도 |
| --- | --- | --- | --- |
| `displayLg` | 40 / w800 | 48 | 최상위 대형 타이틀 |
| `headlineLg` | 32 / w700 | 38 | 화면 타이틀 |
| `headlineLgMobile` | 28 / w700 | 34 | 좁은 화면용 타이틀 |
| `headlineMd` | 24 / w600 | 30 | 섹션 제목, AppBar, 다이얼로그 제목 |
| `bodyLg` | 18 / w400 | 28 | 강조 본문 |
| `bodyMd` | 16 / w400 | 24 | 기본 본문 |
| `labelLg` | 14 / w700 | 20 | 버튼, 칩, 라벨 (자간 +0.05em) |
| `statsNumber` | 22 / w800 | 24 | 점수·통계 숫자 |

### 사용 규칙

- `TextStyle(fontFamily: ...)`를 새로 만들지 않는다. 프리셋 + `copyWith`로 변형한다.
  ```dart
  style: AppTypography.labelLg.copyWith(color: AppColors.accent, fontSize: 11.sp)
  ```
- 크기 조정은 `.sp`를 붙인다 (`fontSize: 11.sp`).
- 프리셋에 색이 없으므로 `copyWith(color: ...)`로 항상 색을 지정한다.
  (`Theme.of(context).textTheme.*`를 쓰면 `onSurface`가 이미 적용된 스타일을 받는다.)

---

## 4. 간격 · 모서리

### AppSpacing

| 토큰 | 값 | 용도 |
| --- | --- | --- |
| `base` | 8 | 기본 단위 |
| `containerPadding` | 20 | 화면 좌우 패딩 |
| `stackGapSm` | 12 | 요소 사이 좁은 간격 |
| `stackGapMd` | 24 | 요소 사이 기본 간격 |
| `stackGapLg` | 40 | 넓은 간격 |
| `sectionMargin` | 48 | 섹션 구분 |

### AppRadius

| 토큰 | 값 | 용도 |
| --- | --- | --- |
| `sm` / `base` / `md` | 2 / 4 / 6 | 작은 뱃지 |
| `lg` | 8 | 버튼, 입력창, 스낵바 (기본) |
| `xl` | 12 | 카드, 다이얼로그 |
| `full` | 9999 | 칩, 원형 |

### 사용 규칙

- 실제 화면 코드에서 자주 쓰는 간격은 `SizedBox(height: 10.h / 14.h / 24.h / 32.h)` 형태다.
  새 화면도 이 리듬(10 / 14 / 24 / 32)을 따른다.
- 카드 내부 패딩은 `EdgeInsets.all(14.w)`, 화면 좌우는 20 기준.
- 반응형 단위: 가로/패딩 `.w`, 세로 `.h`, 폰트 `.sp`, 모서리 `.r`.
  ```dart
  Container(
    width: 310.w,
    padding: EdgeInsets.all(14.w),
    decoration: BoxDecoration(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: scheme.outlineVariant),
    ),
  )
  ```

---

## 5. 컴포넌트

`app_theme.dart`에서 이미 스타일이 잡혀 있다. 위젯에서 `style:`을 다시 지정하지 않는다.

| 컴포넌트 | 규칙 |
| --- | --- |
| AppBar | 배경 = `surface`, elevation 0, 좌측 정렬, `headlineMd` |
| Card | 배경 = `surfaceContainer`, radius `lg`, `outlineVariant` 1px 보더, margin 0 |
| ElevatedButton | 배경 = accent(`primaryContainer`), 최소 48×48, radius `lg`, `labelLg` |
| OutlinedButton | 투명 배경 + accent 1px 보더, 최소 48×48 |
| TextButton | accent 텍스트, 최소 48×48 |
| FAB | accent 배경, radius `lg`, elevation 0 |
| TextField | `filled`, 배경 = `surfaceContainer`, 포커스 시 accent 2px |
| Chip | radius `full`, accent 1px 보더, 선택 시 accent 배경 |
| Divider | `outlineVariant` 1px |
| BottomNavigationBar | 배경 = `surfaceContainer`, 선택 = accent, **라벨 12pt 고정** (320pt 기기에서 5탭 라벨 잘림 방지) |
| Dialog | 배경 = `surfaceContainerHigh`, radius `xl` |
| SnackBar | floating, `inverseSurface` 배경, radius `lg` |

### 공통 규칙

- **elevation은 항상 0.** 그림자 대신 표면 밝기와 보더로 계층을 만든다.
- `surfaceTintColor: Colors.transparent` — Material 3 자동 틴트를 쓰지 않는다.
- 터치 타깃은 최소 48×48.
- 탭 가능한 카드는 `Material(color: transparent) > InkWell(borderRadius: ...)`로 감싸
  리플이 모서리를 넘지 않게 한다.

---

## 6. 체크리스트

새 화면/위젯을 만들 때:

- [ ] `Color(0xFF...)` 직접 사용 없음 → `AppColors` / `ColorScheme`
- [ ] `TextStyle(fontFamily:)` 직접 생성 없음 → `AppTypography` 프리셋 + `copyWith`
- [ ] 크기·간격에 `.w` / `.h` / `.sp` / `.r` 적용
- [ ] radius는 `AppRadius` 값 (8 / 12 / full) 사용
- [ ] elevation 0, 보더는 `outlineVariant`
- [ ] 터치 영역 48×48 이상
- [ ] 텍스트 오버플로 처리 (`maxLines` + `TextOverflow.ellipsis`)
- [ ] 좁은 기기(320pt)에서 라벨 잘림 확인
