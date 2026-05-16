# Rally Batch Jobs

Rally 프로젝트의 배치 작업을 관리하는 디렉토리. Flutter 앱과 완전히 분리되어 있으며 Python으로 작성됩니다.

## 구조

```
batch/
├── jobs/                # 개별 배치 작업 (작업당 폴더 1개)
│   └── <job_name>/
│       ├── main.py      # 진입점
│       └── README.md    # 작업별 문서
├── shared/              # 작업 간 공통 유틸 (Supabase 클라이언트, 로거 등)
├── tests/               # 테스트 + fixture
└── scripts/             # 일회성 수동 실행 스크립트
```

## 로컬 실행

```bash
# 프로젝트 루트에서
python -m venv batch/.venv
source batch/.venv/bin/activate
pip install -r batch/requirements.txt
playwright install chromium  # 크롤링 작업이 필요한 경우

cp batch/.env.example batch/.env
# batch/.env에 SUPABASE_SERVICE_KEY 입력

# 작업 실행 (루트에서 패키지 경로로 호출)
python -m batch.jobs.<job_name>.main
```

## 환경변수

| 이름 | 설명 |
|---|---|
| `SUPABASE_URL` | 프로젝트 URL |
| `SUPABASE_SERVICE_KEY` | service_role 키 (절대 커밋 금지) |

GitHub Actions에서는 Repository Secrets로 주입됩니다.

## 새 배치 작업 추가

1. `jobs/<new_job>/` 폴더 생성
2. `main.py`에 `run()` 함수 + `if __name__ == '__main__': run()` 작성
3. `jobs/<new_job>/README.md`에 작업 설명
4. `.github/workflows/batch-<new_job>.yml`에 cron 워크플로우 추가

## 작업 목록

| 작업 | 스케줄 | 설명 |
|---|---|---|
| [`bwf_rankings`](jobs/bwf_rankings/README.md) | 매주 월 09:00 KST | BWF 세계 랭킹 5개 종목 크롤링 → `bwf_rankings` 테이블 upsert |
