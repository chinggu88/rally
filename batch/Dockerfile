# syntax=docker/dockerfile:1.6
# Playwright + Chromium 사전설치 (멀티아키: linux/amd64, linux/arm64)
FROM mcr.microsoft.com/playwright/python:v1.49.0-jammy

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    TZ=Asia/Seoul

# tzdata + supercronic (멀티아키 — TARGETARCH 빌드 인자로 amd64/arm64 분기)
ARG TARGETARCH
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        tzdata ca-certificates curl && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    case "${TARGETARCH}" in \
        amd64) SC_SHA="cd48d45c4b10f3f0bfdd3a57d054cd05ac96812b" ;; \
        arm64) SC_SHA="512f6736450c56555e01b363144c3c9d23abed4c" ;; \
        *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    curl -fsSLo /usr/local/bin/supercronic \
        "https://github.com/aptible/supercronic/releases/download/v0.2.29/supercronic-linux-${TARGETARCH}" && \
    echo "${SC_SHA}  /usr/local/bin/supercronic" | sha1sum -c - && \
    chmod +x /usr/local/bin/supercronic && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 의존성 먼저 (캐시 최적화)
COPY batch/requirements.txt /app/batch/requirements.txt
RUN pip install --no-cache-dir -r /app/batch/requirements.txt

# 배치 코드 복사 — batch 패키지로 import 되려면 /app 이 PYTHONPATH 가 되어야 함
COPY batch /app/batch

ENV PYTHONPATH=/app

# 기본 CMD 없음 — 서비스별로 docker-compose에서 지정
