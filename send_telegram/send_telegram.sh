#!/usr/bin/env bash
set -eu
# Sends a message/document to Telegram.
# Supports both parameter-based (Option B) and env-var-based configs.
#
# Parameters (via AGENTA_TOOL_PARAMS JSON):
#   bot_token  — optional, overrides TELEGRAM_BOT_TOKEN env var
#   chat_id    — optional, overrides TELEGRAM_CHAT_ID env var
#   message    — optional, custom message text (skips article lookup)

ENV_FILE="$HOME/.agenta/.env"
[ -f "$ENV_FILE" ] && { set -a; source "$ENV_FILE"; set +a; }

# Parse tool parameters
INPUT="${AGENTA_TOOL_PARAMS:-}"
if [ -z "$INPUT" ]; then INPUT="$(cat)"; fi

PARAM_BOT_TOKEN=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('bot_token',''))" 2>/dev/null || true)
PARAM_CHAT_ID=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('chat_id',''))" 2>/dev/null || true)
PARAM_MESSAGE=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message',''))" 2>/dev/null || true)

# Resolve bot token — parameter takes precedence over env var
BOT_TOKEN="${PARAM_BOT_TOKEN:-${TELEGRAM_BOT_TOKEN:-}}"
CHAT_ID="${PARAM_CHAT_ID:-${TELEGRAM_CHAT_ID:-}}"

if [ -z "$BOT_TOKEN" ]; then
    echo "ERROR: bot_token not provided as parameter and TELEGRAM_BOT_TOKEN not set in ~/.agenta/.env"
    exit 1
fi
if [ -z "$CHAT_ID" ]; then
    echo "ERROR: chat_id not provided as parameter and TELEGRAM_CHAT_ID not set in ~/.agenta/.env"
    exit 1
fi

# If a custom message was passed — just send it as a text message and exit
if [ -n "$PARAM_MESSAGE" ]; then
    curl -sf -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "parse_mode=Markdown" \
        --data-urlencode "text=${PARAM_MESSAGE}" > /dev/null
    echo "Telegram message sent successfully"
    exit 0
fi

# Default behaviour — send the latest newsletter article
DATA_DIR="$HOME/.agenta/data"
DATE_TAG=$(date +%Y%m%d)

ARTICLE=$(ls -t "$DATA_DIR"/article_${DATE_TAG}_corrected.md 2>/dev/null | head -1 || \
          ls -t "$DATA_DIR"/article_*.md 2>/dev/null | head -1 || true)

if [ -z "$ARTICLE" ]; then
    echo "ERROR: No article file found"
    exit 1
fi

# Extract title (first # heading)
TITLE=$(grep -m1 '^# ' "$ARTICLE" | sed 's/^# //' || echo "Weekly AI Newsletter")

# Send preview message
PREVIEW=$(head -c 600 "$ARTICLE")
curl -sf -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "parse_mode=Markdown" \
    --data-urlencode "text=📰 *Weekly AI Newsletter — Ready for Review*

*${TITLE}*

${PREVIEW}...

_(Full article attached as document)_" > /dev/null

# Send full article as document
curl -sf -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
    -F "chat_id=${CHAT_ID}" \
    -F "document=@${ARTICLE}" \
    -F "caption=Full article: ${TITLE}" > /dev/null

echo "Telegram message sent successfully"
echo "Article: $ARTICLE"
echo "Title: $TITLE"
