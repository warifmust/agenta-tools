#!/usr/bin/env bash
set -eu

# Load API key from ~/.agenta/.env
if [ -f "$HOME/.agenta/.env" ]; then
    source "$HOME/.agenta/.env"
fi

if [ -z "${TAVILY_API_KEY:-}" ]; then
    echo '{"error": "TAVILY_API_KEY not set in ~/.agenta/.env"}' >&2
    exit 1
fi

# Get input from env var or stdin
INPUT="${AGENTA_TOOL_PARAMS:-}"
if [ -z "$INPUT" ]; then INPUT="$(cat)"; fi

# Extract parameters
QUERY=$(echo "$INPUT" | jq -r '.query // empty')
MAX_RESULTS=$(echo "$INPUT" | jq -r '.max_results // 5')
SEARCH_DEPTH=$(echo "$INPUT" | jq -r '.search_depth // "basic"')

if [ -z "$QUERY" ]; then
    echo '{"error": "No query provided"}' >&2
    exit 1
fi

# Call Tavily API
RESPONSE=$(curl -s --max-time 30 \
    -X POST "https://api.tavily.com/search" \
    -H "Content-Type: application/json" \
    -d "{
        \"api_key\": \"$TAVILY_API_KEY\",
        \"query\": $(echo "$QUERY" | jq -R .),
        \"search_depth\": \"$SEARCH_DEPTH\",
        \"max_results\": $MAX_RESULTS,
        \"include_answer\": true,
        \"include_raw_content\": false
    }")

if [ -z "$RESPONSE" ]; then
    echo '{"error": "No response from Tavily API"}' >&2
    exit 1
fi

echo "$RESPONSE"
