#!/usr/bin/env bash
set -eu
# Creates a Notion page from the corrected article under a parent page.
# Requires NOTION_TOKEN and NOTION_PARENT_PAGE_ID in ~/.agenta/.env

ENV_FILE="$HOME/.agenta/.env"
[ -f "$ENV_FILE" ] && { set -a; source "$ENV_FILE"; set +a; }

if [ -z "${NOTION_TOKEN:-}" ]; then
    echo "ERROR: NOTION_TOKEN not set. Add to ~/.agenta/.env"
    echo "Get it from: https://www.notion.so/profile/integrations"
    exit 1
fi
if [ -z "${NOTION_PARENT_PAGE_ID:-}" ]; then
    echo "ERROR: NOTION_PARENT_PAGE_ID not set. Add to ~/.agenta/.env"
    echo "Get it from your Notion parent page URL (the 32-char ID after the workspace name)"
    exit 1
fi

DATA_DIR="$HOME/.agenta/data"

# Prefer today's corrected article; fall back to yesterday, then most-recent by filename
ARTICLE=""
for days_back in 0 1 2; do
    DATE_TAG=$(date -v -${days_back}d +%Y%m%d 2>/dev/null || date -d "-${days_back} days" +%Y%m%d)
    if [ -f "$DATA_DIR/article_${DATE_TAG}_corrected.md" ]; then
        ARTICLE="$DATA_DIR/article_${DATE_TAG}_corrected.md"
        break
    fi
    # Also accept uncorrected if MAE hasn't run yet
    if [ -f "$DATA_DIR/article_${DATE_TAG}.md" ]; then
        ARTICLE="$DATA_DIR/article_${DATE_TAG}.md"
        break
    fi
done

# Last resort: newest by filename (not mtime)
if [ -z "$ARTICLE" ]; then
    ARTICLE=$(ls "$DATA_DIR"/article_*.md 2>/dev/null | sort | tail -1 || true)
fi

if [ -z "$ARTICLE" ]; then
    echo "ERROR: No article file found"
    exit 1
fi

python3 - "$ARTICLE" "$NOTION_TOKEN" "$NOTION_PARENT_PAGE_ID" << 'PYEOF'
import sys, json, re
import urllib.request, urllib.error

article_path, token, parent_page_id = sys.argv[1], sys.argv[2], sys.argv[3]
content = open(article_path).read()

# Parse title from first # heading
title_match = re.search(r'^# (.+)$', content, re.MULTILINE)
title = title_match.group(1).strip() if title_match else "Weekly AI Newsletter"

# Convert markdown to Notion blocks (line-by-line to avoid heading+paragraph merging)
blocks = []
lines = content.strip().split('\n')
i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.strip()

    if not stripped:
        i += 1
        continue

    if stripped.startswith('# '):
        text = re.sub(r'\*\*(.+?)\*\*', r'\1', stripped[2:].strip())
        blocks.append({"object":"block","type":"heading_1",
            "heading_1":{"rich_text":[{"type":"text","text":{"content":text}}]}})
        i += 1
    elif stripped.startswith('## '):
        text = re.sub(r'\*\*(.+?)\*\*', r'\1', stripped[3:].strip())
        blocks.append({"object":"block","type":"heading_2",
            "heading_2":{"rich_text":[{"type":"text","text":{"content":text}}]}})
        i += 1
    elif stripped.startswith('### '):
        text = re.sub(r'\*\*(.+?)\*\*', r'\1', stripped[4:].strip())
        blocks.append({"object":"block","type":"heading_3",
            "heading_3":{"rich_text":[{"type":"text","text":{"content":text}}]}})
        i += 1
    elif stripped.startswith('---'):
        blocks.append({"object":"block","type":"divider","divider":{}})
        i += 1
    elif re.match(r'^\*\*[^*]+\*\*$', stripped):
        # Standalone **bold** line → heading_2 (subheadline from MAE)
        text = stripped.strip('*').strip()
        blocks.append({"object":"block","type":"heading_2",
            "heading_2":{"rich_text":[{"type":"text","text":{"content":text}}]}})
        i += 1
    elif stripped.startswith('- ') or stripped.startswith('* '):
        text = re.sub(r'\*\*(.+?)\*\*', r'\1', stripped[2:])
        blocks.append({"object":"block","type":"bulleted_list_item",
            "bulleted_list_item":{"rich_text":[{"type":"text","text":{"content":text}}]}})
        i += 1
    else:
        # Collect consecutive non-special lines into one paragraph
        para_lines = []
        while i < len(lines):
            l = lines[i].strip()
            if not l or l.startswith('#') or l.startswith('- ') or l.startswith('* ') or l.startswith('---'):
                break
            para_lines.append(l)
            i += 1
        text = ' '.join(para_lines)
        text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)  # strip **bold**
        text = re.sub(r'\*\*', '', text)               # remove unmatched **
        text = re.sub(r'\*(.+?)\*', r'\1', text)       # strip *italic*
        for j in range(0, len(text), 1900):
            blocks.append({"object":"block","type":"paragraph",
                "paragraph":{"rich_text":[{"type":"text","text":{"content":text[j:j+1900]}}]}})

import random
cover_images = [
    "https://images.unsplash.com/photo-1677442135703-1787eea5ce01?w=1600&q=80",  # AI neural network
    "https://images.unsplash.com/photo-1620712943543-bcc4688e7485?w=1600&q=80",  # robot/AI
    "https://images.unsplash.com/photo-1655720828018-edd2daec9349?w=1600&q=80",  # tech abstract
    "https://images.unsplash.com/photo-1676299081847-824916de030a?w=1600&q=80",  # AI generative
    "https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=1600&q=80",  # robot
    "https://images.unsplash.com/photo-1531746790731-6c087fecd65a?w=1600&q=80",  # futuristic tech
    "https://images.unsplash.com/photo-1518770660439-4636190af475?w=1600&q=80",  # circuit board
    "https://images.unsplash.com/photo-1550751827-4bd374c3f58b?w=1600&q=80",  # cybersecurity
    "https://images.unsplash.com/photo-1504711434969-e33886168f5c?w=1600&q=80",  # data streams
    "https://images.unsplash.com/photo-1564865878688-9a244444042a?w=1600&q=80",  # machine learning
]
cover_url = random.choice(cover_images)

payload = json.dumps({
    "parent": {"page_id": parent_page_id},
    "cover": {
        "type": "external",
        "external": {
            "url": cover_url
        }
    },
    "properties": {
        "title": {"title": [{"type":"text","text":{"content": title}}]}
    },
    "children": blocks[:100]  # Notion API limit: 100 blocks per request
}).encode()

req = urllib.request.Request(
    "https://api.notion.com/v1/pages",
    data=payload,
    headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Notion-Version": "2022-06-28"
    }
)

try:
    resp = urllib.request.urlopen(req)
    data = json.loads(resp.read())
    page_url = data.get("url", "")
    page_id = data.get("id", "")
    print(f"Notion page created successfully")
    print(f"Title: {title}")
    print(f"Page ID: {page_id}")
    print(f"URL: {page_url}")
except urllib.error.HTTPError as e:
    err = e.read().decode()
    print(f"ERROR creating Notion page: {e.code} {err}")
    sys.exit(1)
PYEOF
