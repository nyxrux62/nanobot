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

### 2. `Dockerfile` 변경

```dockerfile
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["gateway"]
```

### 3. `docker-compose.yml`

```yaml
x-common-build: &common-build
  build:
    context: .
    dockerfile: Dockerfile

x-gateway-base: &gateway-base
  <<: *common-build
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

x-cli-base: &cli-base
  <<: *common-build
  profiles:
    - cli
  stdin_open: true
  tty: true

services:
  # === User: alice ===
  nanobot-gateway-alice:
    container_name: nanobot-gateway-alice
    <<: *gateway-base
    volumes:
      - ~/.nanobot-alice:/root/.nanobot
    ports:
      - "18790:18790"
    environment:
      NANOBOT_CHANNEL: telegram
      NANOBOT_BOT_TOKEN: "${ALICE_BOT_TOKEN}"
      NANOBOT_ALLOW_FROM: "${ALICE_ALLOW_FROM}"
      NANOBOT_PROVIDER: "${ALICE_PROVIDER}"
      NANOBOT_MODEL: "${ALICE_MODEL}"
      NANOBOT_API_KEY: "${ALICE_API_KEY}"

  nanobot-cli-alice:
    container_name: nanobot-cli-alice
    <<: *cli-base
    volumes:
      - ~/.nanobot-alice:/root/.nanobot
    command: ["status"]

  # === User: bob ===
  nanobot-gateway-bob:
    container_name: nanobot-gateway-bob
    <<: *gateway-base
    volumes:
      - ~/.nanobot-bob:/root/.nanobot
    ports:
      - "18791:18790"
    environment:
      NANOBOT_CHANNEL: telegram
      NANOBOT_BOT_TOKEN: "${BOB_BOT_TOKEN}"
      NANOBOT_ALLOW_FROM: "${BOB_ALLOW_FROM}"
      NANOBOT_PROVIDER: "${BOB_PROVIDER}"
      NANOBOT_MODEL: "${BOB_MODEL}"
      NANOBOT_API_KEY: "${BOB_API_KEY}"

  nanobot-cli-bob:
    container_name: nanobot-cli-bob
    <<: *cli-base
    volumes:
      - ~/.nanobot-bob:/root/.nanobot
    command: ["status"]
```

민감 정보는 `.env` 파일에 저장한다 (`.gitignore`에 포함됨):

```bash
# .env
ALICE_BOT_TOKEN=123456:AAF-alice-bot-token
ALICE_ALLOW_FROM=alice_telegram_id
ALICE_PROVIDER=ollama_cloud
ALICE_MODEL=glm-5:cloud
ALICE_API_KEY=your-alice-api-key

BOB_BOT_TOKEN=789012:AAF-bob-bot-token
BOB_ALLOW_FROM=bob_telegram_id
BOB_PROVIDER=anthropic
BOB_MODEL=anthropic/claude-opus-4-5
BOB_API_KEY=your-bob-api-key
```

## 사용자 추가

새 사용자 추가 시 `docker-compose.yml`에 gateway + cli 서비스 쌍을 복사하고:

1. 서비스명/컨테이너명 변경: `nanobot-gateway-{name}`, `nanobot-cli-{name}`
2. 볼륨 경로 변경: `~/.nanobot-{name}:/root/.nanobot`
3. 호스트 포트 변경: `1879N:18790`
4. 환경변수에 해당 사용자의 봇 토큰, provider, 모델, API 키 설정

## 운영

```bash
# 전체 시작
docker compose up -d

# 개별 시작
docker compose up -d nanobot-gateway-alice

# 로그 확인
docker compose logs -f nanobot-gateway-alice

# CLI로 상태 확인
docker compose run --rm nanobot-cli-alice status

# 설정 수동 편집 후 반영
vim ~/.nanobot-alice/config.json
docker compose restart nanobot-gateway-alice

# 설정 초기화 (환경변수에서 재생성)
rm ~/.nanobot-alice/config.json
docker compose restart nanobot-gateway-alice

# 전체 중지
docker compose down

# 이미지 재빌드 후 재시작
docker compose up -d --build
```

## 리소스

인스턴스당 리소스 제한:
- CPU: 최대 1코어 (최소 0.25코어)
- 메모리: 최대 1GB (최소 256MB)

5명 운영 시 최대 5코어, 5GB RAM 필요 (실제 사용량은 훨씬 낮음).
