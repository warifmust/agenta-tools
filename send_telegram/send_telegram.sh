#!/usr/bin/env bash
set -eu
# Send a plain text message to a Telegram chat.
#
# Params (AGENTA_TOOL_PARAMS JSON):
#   message    — required, the text to send
#   bot_token  — optional, overrides TELEGRAM_BOT_TOKEN env var
#   chat_id    — optional, overrides TELEGRAM_CHAT_ID env var
#   parse_mode — optional, "Markdown" or "HTML" to format; default is plain text
#                (plain is safest — Telegram Markdown 400s on stray _ * [ chars)

ENV_FILE="$HOME/.agenta/.env"
[ -f "$ENV_FILE" ] && { set -a; source "$ENV_FILE"; set +a; }

INPUT="${AGENTA_TOOL_PARAMS:-}"
if [ -z "$INPUT" ]; then INPUT="$(cat)"; fi

read_param() {
    printf '%s' "$INPUT" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('$1',''))
except Exception: print('')" 2>/dev/null || true
}

MESSAGE=$(read_param message)
PARAM_BOT_TOKEN=$(read_param bot_token)
PARAM_CHAT_ID=$(read_param chat_id)
PARSE_MODE=$(read_param parse_mode)

BOT_TOKEN="${PARAM_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN:-}}"
CHAT_ID="${PARAM_CHAT_ID:-${TELEGRAM_CHAT_ID:-}}"

if [ -z "$MESSAGE" ]; then
    echo '{"error": "message is required"}'; exit 1
fi
if [ -z "$BOT_TOKEN" ]; then
    echo '{"error": "no bot token — pass bot_token, or set TELEGRAM_BOT_TOKEN in ~/.agenta/.env"}'; exit 1
fi
if [ -z "$CHAT_ID" ]; then
    echo '{"error": "no chat id — pass chat_id, or set TELEGRAM_CHAT_ID in ~/.agenta/.env"}'; exit 1
fi

ARGS=(-s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage"
      -d "chat_id=${CHAT_ID}"
      --data-urlencode "text=${MESSAGE}")
[ -n "$PARSE_MODE" ] && ARGS+=(-d "parse_mode=${PARSE_MODE}")

RESPONSE=$(curl "${ARGS[@]}" || true)
OK=$(printf '%s' "$RESPONSE" | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('ok', False))
except Exception: print(False)" 2>/dev/null || echo False)

if [ "$OK" = "True" ]; then
    echo '{"status": "sent"}'
else
    ERR=$(printf '%s' "$RESPONSE" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo '""')
    echo "{\"error\": \"Telegram rejected the message\", \"response\": ${ERR}}"
    exit 1
fi
