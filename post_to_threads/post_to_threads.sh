#!/usr/bin/env bash
set -euo pipefail
#
# post_to_threads — publish a text post to Threads (Meta Graph API).
#
# Two-step flow: create a TEXT media container, wait for it to finish
# processing, then publish it. Input arrives as JSON in $AGENTA_TOOL_PARAMS;
# credentials come from the environment.
#
#   Input : {"text": "<post text, up to 500 chars>"}
#   Env   : THREADS_USER_ID, THREADS_ACCESS_TOKEN
#   Needs : curl, jq
#   Output: {"post_id": "<id>"} on success; a clear error on stderr otherwise.

text=$(printf '%s' "${AGENTA_TOOL_PARAMS:-}" | jq -r '.text // empty')
if [ -z "$text" ]; then
  echo "error: missing 'text' input" >&2
  exit 1
fi
: "${THREADS_USER_ID:?THREADS_USER_ID not set}"
: "${THREADS_ACCESS_TOKEN:?THREADS_ACCESS_TOKEN not set}"

base="https://graph.threads.net/v1.0"

# Step 1 — create a TEXT media container.
create=$(curl -sS -X POST "$base/$THREADS_USER_ID/threads" \
  --data-urlencode "media_type=TEXT" \
  --data-urlencode "text=$text" \
  --data-urlencode "access_token=$THREADS_ACCESS_TOKEN")
cid=$(printf '%s' "$create" | jq -r '.id // empty')
if [ -z "$cid" ]; then
  echo "container creation failed: $create" >&2
  exit 1
fi

# Step 2 — poll until the container is FINISHED (don't guess a fixed sleep).
status=""
for _ in $(seq 1 10); do
  s=$(curl -sS "$base/$cid?fields=status,error_message&access_token=$THREADS_ACCESS_TOKEN")
  status=$(printf '%s' "$s" | jq -r '.status // empty')
  case "$status" in
    FINISHED) break ;;
    ERROR|EXPIRED)
      echo "container not publishable ($status): $s" >&2
      exit 1 ;;
  esac
  sleep 2
done
if [ "$status" != "FINISHED" ]; then
  echo "container not ready after polling (last status: ${status:-unknown})" >&2
  exit 1
fi

# Step 3 — publish the container.
publish=$(curl -sS -X POST "$base/$THREADS_USER_ID/threads_publish" \
  --data-urlencode "creation_id=$cid" \
  --data-urlencode "access_token=$THREADS_ACCESS_TOKEN")
pid=$(printf '%s' "$publish" | jq -r '.id // empty')
if [ -z "$pid" ]; then
  echo "publish failed: $publish" >&2
  exit 1
fi

printf '{"post_id": "%s"}\n' "$pid"
