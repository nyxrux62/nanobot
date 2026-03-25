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

- `docker-entrypoint.sh` — 환경변수로 `config.json` 자동 생성
- `docker-compose.yml` — YAML 앵커 기반 멀티 인스턴스 템플릿
- `Dockerfile` — entrypoint 변경, 기본 CMD를 `gateway`로
- 민감 정보는 `.env` 파일로 분리 (`.gitignore` 포함)

상세: [docs/MULTI_INSTANCE_DEPLOY.md](./MULTI_INSTANCE_DEPLOY.md)
