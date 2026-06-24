#!/bin/bash
# SENTRI - Send File to Telegram Tool
# Parameters passed via AGENTA_TOOL_PARAMS env var as JSON

FILE_PATH=$(echo "$AGENTA_TOOL_PARAMS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('path') or d.get('file_path') or d.get('filepath') or '')" 2>/dev/null)
# chat_id from tool params, fallback to TELEGRAM_CHAT_ID env var
CHAT_ID=$(echo "$AGENTA_TOOL_PARAMS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('chat_id', ''))" 2>/dev/null)
if [ -z "$CHAT_ID" ]; then
    CHAT_ID="${TELEGRAM_CHAT_ID}"
fi
CAPTION=$(echo "$AGENTA_TOOL_PARAMS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('caption', 'Here is your file.'))" 2>/dev/null)

# Expand ~
FILE_PATH="${FILE_PATH/#\~/$HOME}"

# If relative, resolve from home
if [[ "$FILE_PATH" != /* ]]; then
    FILE_PATH="$HOME/$FILE_PATH"
fi

BOT_TOKEN="${SENTRI_BOT_TOKEN}"
if [ -z "$BOT_TOKEN" ]; then
    echo "ERROR: SENTRI_BOT_TOKEN not set."
    exit 1
fi

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
    echo "ERROR: File does not exist: $FILE_PATH"
    exit 1
fi

# Limit to 50MB
FILE_SIZE=$(wc -c < "$FILE_PATH")
if [ "$FILE_SIZE" -gt 52428800 ]; then
    echo "ERROR: File too large to send via Telegram (max 50MB)."
    exit 1
fi

echo "Sending file: $FILE_PATH to chat $CHAT_ID..."
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
    -F "chat_id=${CHAT_ID}" \
    -F "document=@${FILE_PATH}" \
    -F "caption=${CAPTION}")

OK=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('ok', False))" 2>/dev/null)
if [ "$OK" = "True" ]; then
    echo "SUCCESS: File sent to Telegram."
else
    echo "ERROR: Failed to send file. Response: $RESPONSE"
    exit 1
fi
