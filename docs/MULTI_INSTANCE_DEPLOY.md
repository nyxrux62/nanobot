# Multi-Instance Docker Deployment

사용자별로 독립된 nanobot 게이트웨이를 Docker Compose로 운영하는 가이드.

## 개요

같은 채널(예: Telegram)을 사용하되, 사용자마다:
- 별도 봇 토큰
- 별도 데이터 (세션, 워크스페이스, 로그)
- 선택적으로 다른 모델/provider

를 가진 독립 인스턴스를 운영한다.

## 아키텍처

```
호스트                              컨테이너
~/.nanobot-alice/  ─── mount ───►  /root/.nanobot/  →  nanobot-gateway-alice (:18790)
~/.nanobot-bob/    ─── mount ───►  /root/.nanobot/  →  nanobot-gateway-bob   (:18791)
~/.nanobot-carol/  ─── mount ───►  /root/.nanobot/  →  nanobot-gateway-carol (:18792)
```

- 각 컨테이너의 내부 포트는 18790 (기본값)
- 호스트 포트만 사용자별로 다르게 매핑
- 볼륨 분리로 세션/데이터 완전 격리

## 파일 구조

에이전트별 독립 compose 파일로 운영한다:

```
docker-compose.lato.yml     # lato 에이전트 (자체 완결형)
docker-compose.bob.yml      # bob 에이전트 (자체 완결형)
.env                        # 공용 환경변수 (토큰, API 키)
```

각 에이전트는 완전히 독립적으로 관리:

```bash
docker compose -f docker-compose.lato.yml up -d
docker compose -f docker-compose.lato.yml up -d --build
docker compose -f docker-compose.lato.yml down
```

## 구현

### 1. `scripts/docker-entrypoint.sh`

컨테이너 시작 시 `config.json`이 없으면 환경변수로부터 자동 생성한다.

#### 환경변수

| 변수 | 설명 | 기본값 |
|---|---|---|
| `NANOBOT_CHANNEL` | 채널 종류 (telegram, discord, slack 등) | 필수 |
| `NANOBOT_BOT_TOKEN` | 봇 토큰 | 필수 |
| `NANOBOT_ALLOW_FROM` | 허용 사용자 ID (쉼표 구분) | `*` |
| `NANOBOT_PROVIDER` | provider 이름 | `auto` |
| `NANOBOT_MODEL` | 모델 이름 | `anthropic/claude-opus-4-5` |
| `NANOBOT_API_KEY` | provider API 키 | (없음) |

#### 동작 흐름

1. `config.json` 존재 → 그대로 사용 (수동 편집 보존)
2. `config.json` 없음 + 환경변수 설정됨 → 자동 생성
3. `exec nanobot "$@"` — 쉘을 nanobot 프로세스로 교체

> **onboard 없이 동작하는 이유:**
> - `sync_workspace_templates`는 `gateway` 시작 시 자동 호출됨
> - workspace 디렉토리 생성도 gateway가 자동 처리
> - entrypoint에서 채널 설정을 직접 포함하므로 `_onboard_plugins` 불필요

### 2. 에이전트 compose 파일

각 에이전트는 독립된 `docker-compose.{name}.yml` 파일을 가진다:

```yaml
name: nanobot-{name}

services:
  nanobot-gateway-{name}:
    container_name: nanobot-gateway-{name}
    build:
      context: .
      dockerfile: Dockerfile
    command: ["gateway"]
    restart: unless-stopped
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 1G
        reservations:
          cpus: '0.25'
          memory: 256M
    volumes:
      - ~/.nanobot-{name}:/root/.nanobot
    ports:
      - "{port}:18790"
    environment:
      NANOBOT_CHANNEL: telegram
      NANOBOT_BOT_TOKEN: "${NAME_BOT_TOKEN}"
      NANOBOT_ALLOW_FROM: "${NAME_ALLOW_FROM}"
      NANOBOT_PROVIDER: "${NAME_PROVIDER}"
      NANOBOT_MODEL: "${NAME_MODEL}"
      NANOBOT_API_KEY: "${NAME_API_KEY}"

  nanobot-cli-{name}:
    container_name: nanobot-cli-{name}
    build:
      context: .
      dockerfile: Dockerfile
    profiles:
      - cli
    stdin_open: true
    tty: true
    volumes:
      - ~/.nanobot-{name}:/root/.nanobot
    command: ["status"]
```

민감 정보는 `.env` 파일에 저장한다 (`.gitignore`에 포함됨):

```bash
# .env
LATO_BOT_TOKEN=123456:AAF-lato-bot-token
LATO_ALLOW_FROM=lato_telegram_id
LATO_PROVIDER=ollama_cloud
LATO_MODEL=glm-5:cloud
LATO_API_KEY=your-lato-api-key

BOB_BOT_TOKEN=789012:AAF-bob-bot-token
BOB_ALLOW_FROM=bob_telegram_id
BOB_PROVIDER=anthropic
BOB_MODEL=anthropic/claude-opus-4-5
BOB_API_KEY=your-bob-api-key
```

## 사용자 추가

1. `docker-compose.{name}.yml` 파일 생성 (위 템플릿 참고, `name:` 필드 포함)
2. `.env`에 해당 사용자의 환경변수 추가
3. `docker compose -f docker-compose.{name}.yml up -d`

## 운영

```bash
# === 개별 에이전트 관리 ===

# 시작
docker compose -f docker-compose.lato.yml up -d

# 재빌드 후 시작
docker compose -f docker-compose.lato.yml up -d --build

# 로그 확인
docker compose -f docker-compose.lato.yml logs -f

# CLI로 상태 확인
docker compose -f docker-compose.lato.yml run --rm nanobot-cli-lato status

# 중지
docker compose -f docker-compose.lato.yml down

# 설정 수동 편집 후 반영
vim ~/.nanobot-lato/config.json
docker compose -f docker-compose.lato.yml restart nanobot-gateway-lato

# 설정 초기화 (환경변수에서 재생성)
rm ~/.nanobot-lato/config.json
docker compose -f docker-compose.lato.yml restart nanobot-gateway-lato

```

## 리소스

인스턴스당 리소스 제한:
- CPU: 최대 1코어 (최소 0.25코어)
- 메모리: 최대 1GB (최소 256MB)

5명 운영 시 최대 5코어, 5GB RAM 필요 (실제 사용량은 훨씬 낮음).
