# Customizations

upstream [nanobot](https://github.com/nyxrux62/nanobot) 대비 커스텀 변경 사항 요약.

## Ollama Cloud Provider

Ollama Cloud API를 LLM provider로 사용할 수 있도록 추가.

- `ollama_cloud` ProviderSpec 추가 (`registry.py`)
- `ollama_cloud` config 필드 추가 (`schema.py`)
- Bearer 토큰 인증, base URL `https://ollama.com/v1`

| 항목 | 값 |
|---|---|
| LiteLLM prefix | `openai` (OpenAI 호환 /v1 endpoint 사용) |
| env key | `OLLAMA_CLOUD_API_KEY` |
| 감지 키워드 | api_base에 `ollama.com` 포함 시 자동 감지 |

> **Note**: 초기에는 `ollama_chat` prefix를 사용했으나, LiteLLM의 ollama_chat 변환이
> tool 메시지의 `tool_calls`, `name` 필드를 누락시켜 Ollama Cloud에서 500 에러가
> 발생하는 버그가 있음. `openai` prefix + `/v1` endpoint로 전환하여 tool calling이
> 모델에 무관하게 정상 동작하도록 수정함.

## Multi-Instance Docker Deployment

사용자별 독립 게이트웨이를 Docker Compose로 운영하는 구조.

- 에이전트별 독립 compose 파일 (`docker-compose.{name}.yml`) — 개별 빌드/배포 가능
- `docker-entrypoint.sh` — 환경변수로 `config.json` 자동 생성 (매 시작마다 재생성)
- 민감 정보는 `.env` 파일로 분리 (`.gitignore` 포함)

상세: [docs/MULTI_INSTANCE_DEPLOY.md](./MULTI_INSTANCE_DEPLOY.md)

## Persistent Runtime Packages

에이전트가 런타임에 설치하는 pip/npm 패키지를 컨테이너 재시작 후에도 보존.

- `PIP_USER=1` + `PYTHONUSERBASE=/root/.nanobot/pip` — pip 패키지를 마운트 볼륨에 설치
- `NPM_CONFIG_PREFIX` + `NPM_CONFIG_CACHE` → `/root/.nanobot/npm` — npm/npx 패키지 보존
- `PATH`에 해당 경로 추가
- `TOOLS.md` 템플릿에 패키지 지속성 정보 추가 (에이전트가 올바른 안내를 제공하도록)

## Hot Reload allowFrom

채널의 `allowFrom` 설정 변경 시 컨테이너 재시작 없이 자동 반영.

- `ChannelManager._watch_allow_from()` — config.json 파일 변경을 5초 간격으로 감지
- 변경 감지 시 각 채널의 `allow_from` 리스트를 즉시 업데이트
- dict config (플러그인)과 Pydantic config (빌트인 채널) 모두 지원

| 동작 | 설명 |
|---|---|
| 파일 감지 | `stat().st_mtime` 비교로 변경 감지 |
| 적용 범위 | 활성화된 모든 채널의 `allowFrom` |
| 사용법 | config.json의 `allowFrom` 수정 → 5초 내 자동 반영 |

## Hot Reload MCP Servers

MCP 서버 설정 변경 시 컨테이너 재시작 없이 재연결하는 기능.

- `reload_mcp` tool 추가 — LLM이 직접 호출하여 MCP 서버를 재로드
- `AgentLoop.reconnect_mcp()` — 기존 MCP 연결 해제 → config.json 재로드 → 재연결
- 기존 non-MCP 도구는 영향 없음, `mcp_` prefix 도구만 교체

| 동작 | 설명 |
|---|---|
| 기존 연결 해제 | `AsyncExitStack.aclose()`로 모든 MCP 세션 정리 |
| config 재로드 | `load_config()`로 config.json 다시 읽기 |
| 재연결 | `_connect_mcp()` lazy 로직 재활용 |

## Entrypoint: env 기반 config 재생성

`.env` 변경 후 컨테이너 재시작 시 config.json이 갱신되지 않던 문제 수정.

- 기존: config.json이 이미 존재하면 환경변수를 무시하고 바로 실행
- 수정: 환경변수가 있으면 매 시작마다 config.json을 재생성

## Streaming 에러 시 응답 누락 수정

LLM API 에러 발생 시 스트리밍 모드에서 에러 메시지가 사용자에게 전달되지 않던 버그 수정.

**문제**: 스트리밍 delta가 전송되기 전에 에러가 발생하면 — stream buffer가 비어있어 stream_end에서 아무것도 안 보내고, final 메시지는 `_streamed` 플래그로 인해 무시됨. 사용자에게는 typing indicator만 보이고 응답 없음.

**수정**:
- `BaseChannel.has_stream_buf()` / `TelegramChannel.has_stream_buf()` 추가
- `ChannelManager._dispatch_outbound()` — `_streamed` 메시지라도 stream buffer에 전달된 내용이 없으면 일반 전송으로 fallback
- `TelegramChannel._stream_delivered` — 스트림 완료 추적으로 정상 완료 시 중복 전송 방지

## 시스템 프롬프트에 모델명 포함

`ContextBuilder`에 현재 사용 모델명을 전달하여 시스템 프롬프트 Runtime 섹션에 표시. 에이전트가 자신의 모델을 tool 호출 없이 직접 답할 수 있음.

## Telegram: 미허용 sender에게 typing indicator 노출 방지

`allowFrom`에 등록되지 않은 sender의 메시지에 대해 typing indicator가 시작된 후 권한 체크에서 드랍되어, 상대방에게 "입력 중..."이 무한 표시되던 문제 수정. 권한 체크를 typing indicator 시작 전으로 이동.
