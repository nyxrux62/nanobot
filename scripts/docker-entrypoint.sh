#!/bin/sh
set -e

CONFIG_PATH="/root/.nanobot/config.json"

# If config.json already exists, skip generation
if [ -f "$CONFIG_PATH" ]; then
    exec nanobot "$@"
fi

# Require at least channel + bot token to generate config
if [ -z "$NANOBOT_CHANNEL" ] || [ -z "$NANOBOT_BOT_TOKEN" ]; then
    exec nanobot "$@"
fi

PROVIDER="${NANOBOT_PROVIDER:-auto}"
MODEL="${NANOBOT_MODEL:-anthropic/claude-opus-4-5}"
ALLOW_FROM="${NANOBOT_ALLOW_FROM:-*}"
API_KEY="${NANOBOT_API_KEY:-}"

# Build allowFrom JSON array from comma-separated string
ALLOW_JSON="["
first=true
IFS=','
for id in $ALLOW_FROM; do
    id=$(echo "$id" | xargs)  # trim whitespace
    if [ "$first" = true ]; then
        first=false
    else
        ALLOW_JSON="$ALLOW_JSON,"
    fi
    ALLOW_JSON="$ALLOW_JSON\"$id\""
done
unset IFS
ALLOW_JSON="$ALLOW_JSON]"

# Build provider config block
PROVIDER_BLOCK=""
if [ -n "$API_KEY" ] && [ "$PROVIDER" != "auto" ]; then
    PROVIDER_BLOCK=$(cat <<PEOF
  "providers": {
    "$PROVIDER": {
      "apiKey": "$API_KEY"
    }
  },
PEOF
)
fi

mkdir -p "$(dirname "$CONFIG_PATH")"

cat > "$CONFIG_PATH" <<EOF
{
  "agents": {
    "defaults": {
      "model": "$MODEL",
      "provider": "$PROVIDER"
    }
  },
  "channels": {
    "$NANOBOT_CHANNEL": {
      "enabled": true,
      "token": "$NANOBOT_BOT_TOKEN",
      "allowFrom": $ALLOW_JSON,
      "streaming": true
    }
  },
$PROVIDER_BLOCK
  "gateway": {
    "host": "0.0.0.0",
    "port": 18790
  }
}
EOF

echo "Config generated from environment variables: $CONFIG_PATH"

exec nanobot "$@"
