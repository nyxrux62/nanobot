# Customizations

upstream [nanobot](https://github.com/nyxrux62/nanobot) 대비 커스텀 변경 사항 요약.

## Ollama Cloud Provider

Ollama Cloud API를 LLM provider로 사용할 수 있도록 추가.

- `ollama_cloud` ProviderSpec 추가 (`registry.py`)
- `ollama_cloud` config 필드 추가 (`schema.py`)
- Bearer 토큰 인증, base URL `https://ollama.com`

| 항목 | 값 |
|---|---|
| LiteLLM prefix | `ollama_chat` (로컬 Ollama와 동일) |
| env key | `OLLAMA_CLOUD_API_KEY` |
| 감지 키워드 | api_base에 `ollama.com` 포함 시 자동 감지 |

## Multi-Instance Docker Deployment

사용자별 독립 게이트웨이를 Docker Compose로 운영하는 구조.

- 에이전트별 독립 compose 파일 (`docker-compose.{name}.yml`) — 개별 빌드/배포 가능
- `docker-entrypoint.sh` — 환경변수로 `config.json` 자동 생성
- 민감 정보는 `.env` 파일로 분리 (`.gitignore` 포함)

상세: [docs/MULTI_INSTANCE_DEPLOY.md](./MULTI_INSTANCE_DEPLOY.md)

## Persistent Runtime Packages

에이전트가 런타임에 설치하는 pip/npm 패키지를 컨테이너 재시작 후에도 보존.

- `PIP_USER=1` + `PYTHONUSERBASE=/root/.nanobot/pip` — pip 패키지를 마운트 볼륨에 설치
- `NPM_CONFIG_PREFIX` + `NPM_CONFIG_CACHE` → `/root/.nanobot/npm` — npm/npx 패키지 보존
- `PATH`에 해당 경로 추가
- `TOOLS.md` 템플릿에 패키지 지속성 정보 추가 (에이전트가 올바른 안내를 제공하도록)

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
