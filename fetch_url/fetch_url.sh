#!/usr/bin/env bash
# Fetches the body of a URL (GET) via python3, truncated to max_chars.
exec /usr/bin/env python3 - <<'PYEOF'
import json,os,urllib.request
p=json.loads(os.environ.get('AGENTA_TOOL_PARAMS') or '{}')
url=p.get('url','')
max_chars=int(p.get('max_chars',5000))
if not url.startswith(('http://','https://')):
 print(json.dumps({'error':'url must start with http:// or https://'})); raise SystemExit(1)
try:
 req=urllib.request.Request(url, headers={'User-Agent':'agenta-fetch-url/1.0'})
 with urllib.request.urlopen(req, timeout=10) as resp:
  body=resp.read(max_chars+1).decode('utf-8', errors='replace')
  status=resp.status
 print(json.dumps({'status':status, 'content': body[:max_chars], 'truncated': len(body)>max_chars}))
except Exception as e:
 print(json.dumps({'error': str(e)}))
 raise SystemExit(1)
PYEOF
