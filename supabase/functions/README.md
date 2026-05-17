# Supabase Edge Functions

Rally 앱이 호출하는 모든 서버 측 로직. **앱은 DB와 직접 통신하지 않고 항상 Edge Function을 경유**.

## 구조

```
supabase/functions/
├── _shared/             # 모든 함수에서 재사용하는 공통 유틸 (배포 안 됨)
│   ├── cors.ts          # CORS 헤더 + preflight 핸들러
│   ├── supabase.ts      # serviceClient() / userClient(req) 팩토리
│   ├── auth.ts          # requireUser(req) — JWT 검증
│   └── response.ts      # json() / error() 응답 헬퍼
└── <function-name>/     # 함수 1개 = 폴더 1개 = 엔드포인트 1개
    └── index.ts
```

> `_shared/` 처럼 **언더스코어로 시작하는 폴더는 Supabase가 배포 대상에서 제외**합니다. 공통 코드 두기에 안전한 위치.

## 새 함수 추가

```bash
supabase functions new <function-name>
# → supabase/functions/<function-name>/index.ts 생성됨
```

기본 템플릿 (이걸 복붙해서 시작):

```typescript
import { handlePreflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { json, error } from "../_shared/response.ts";

Deno.serve(async (req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  try {
    const supabase = serviceClient();
    // ...로직...
    return json({ ok: true });
  } catch (e) {
    return error(e instanceof Error ? e.message : "unknown", 500);
  }
});
```

## 로컬 실행

```bash
# 모든 함수를 한 번에 띄움 (Docker 필요)
supabase functions serve

# 특정 함수만
supabase functions serve <function-name>
```

호출:
```bash
curl -i 'http://127.0.0.1:54321/functions/v1/<function-name>' \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY"
```

## 배포

```bash
supabase functions deploy <function-name>     # 1개만
supabase functions deploy                     # 전체
```

배포 후 endpoint: `https://ztcfgymcxilxcjahyucw.supabase.co/functions/v1/<function-name>`

## 환경 변수

Supabase가 자동 주입:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

추가 시크릿이 필요하면:
```bash
supabase secrets set MY_API_KEY=...
supabase secrets list
```

## 두 가지 클라이언트 패턴

| 상황 | 사용할 클라이언트 |
|---|---|
| 공개 데이터 조회 (BWF 랭킹 등) | `serviceClient()` |
| 사용자 본인 데이터 CRUD | `userClient(req)` — JWT 그대로 전달, RLS 적용 |
| 검증 후 어드민 작업 | `requireUser(req)`로 인증 → `serviceClient()`로 작업 |

## Flutter에서 호출

```dart
final res = await Supabase.instance.client.functions.invoke(
  'get-rankings',
  body: {'category': 'MS', 'limit': 20},
);
final data = res.data;
```

## 디렉토리 규칙

- 함수 1개 = 폴더 1개 = `index.ts` 1개 (URL path와 1:1)
- 폴더명은 **kebab-case** (URL에 그대로 노출됨)
- 비즈니스 로직은 `index.ts` 안에 두되, 길어지면 `lib/`로 분리
- 공통 코드는 반드시 `_shared/`로 (다른 함수에서 import)
