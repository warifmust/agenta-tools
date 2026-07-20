#!/usr/bin/env bash
# Returns current date/time (optionally in a given IANA timezone) via python3.
exec /usr/bin/env python3 - <<'PYEOF'
import json,os
from datetime import datetime
try:
 from zoneinfo import ZoneInfo
except Exception:
 ZoneInfo=None
p=json.loads(os.environ.get('AGENTA_TOOL_PARAMS') or '{}')
tz=p.get('timezone')
try:
 if tz and ZoneInfo:
  now=datetime.now(ZoneInfo(tz))
 else:
  now=datetime.utcnow()
  tz=tz or 'UTC'
 print(json.dumps({'datetime': now.isoformat(), 'timezone': tz}))
except Exception as e:
 print(json.dumps({'error': str(e)}))
 raise SystemExit(1)
PYEOF
