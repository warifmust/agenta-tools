#!/bin/bash
# SENTRI - Find File Tool
# Parameters passed via AGENTA_TOOL_PARAMS env var as JSON

SEARCH_PATH=$(echo "$AGENTA_TOOL_PARAMS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('path') or d.get('directory') or d.get('search_path') or d.get('folder') or '')" 2>/dev/null)
PATTERN=$(echo "$AGENTA_TOOL_PARAMS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('pattern', '*'))" 2>/dev/null)

# Default to home if path empty
if [ -z "$SEARCH_PATH" ]; then
    SEARCH_PATH="$HOME"
fi

# Expand ~ manually
SEARCH_PATH="${SEARCH_PATH/#\~/$HOME}"

# If relative path, resolve from home
if [[ "$SEARCH_PATH" != /* ]]; then
    SEARCH_PATH="$HOME/$SEARCH_PATH"
fi

# Block system-sensitive paths
BLOCKED_PATHS=("/etc/shadow" "/private/etc/shadow" "/System/Library/Keychains" "/Library/Keychains")
for blocked in "${BLOCKED_PATHS[@]}"; do
    if [[ "$SEARCH_PATH" == "$blocked"* ]]; then
        echo "ERROR: Access to this path is restricted."
        exit 1
    fi
done

if [ ! -d "$SEARCH_PATH" ]; then
    echo "ERROR: Directory does not exist: $SEARCH_PATH"
    exit 1
fi

echo "Files in $SEARCH_PATH:"
echo ""
RESULTS=$(find "$SEARCH_PATH" -name "$PATTERN" -maxdepth 5 -not -name ".DS_Store" 2>/dev/null | grep -v "^$SEARCH_PATH$" | head -50)

if [ -z "$RESULTS" ]; then
    echo "No files found matching '$PATTERN'."
else
    echo "$RESULTS" | while IFS= read -r file; do
        if [ -d "$file" ]; then
            echo "  📁 $file"
        else
            echo "  📄 $file"
        fi
    done
fi
echo ""
echo "Total: $(echo "$RESULTS" | grep -c . 2>/dev/null || echo 0) item(s)"
