<p align="center">
  <img src="t.svg" width="72" alt="t*">
</p>

<h1 align="center">agenta tools</h1>

<p align="center">
  <strong>Atomic, reusable tools for <a href="https://github.com/warifmust/agenta">a*</a> agents.</strong>
</p>

<p align="center">
  Each tool is a self-contained folder — a <code>manifest.json</code> that describes it and a handler script that runs it.<br>
  Write it in <strong>any language</strong> (bash, python, node, …), drop the folder in, pull it with the CLI. Done.
</p>

---

## Available tools

### Web &amp; data
| Tool | Description | Env |
|------|-------------|-----|
| `fetch_url` | Fetch the raw text/HTML of a URL (GET), truncated to a safe size. | — |
| `html_to_text` ✦ | Fetch a URL and return **clean readable text** — HTML tags, scripts, and styles stripped. | — |
| `rss_fetch` ✦ | Fetch an RSS or Atom feed and return recent items as JSON (title, link, published). | — |
| `get_weather` ✦ | Current weather for a city via Open-Meteo — no API key. | — |
| `tavily_search` | Web search. Returns titles, URLs, and summaries. | `TAVILY_API_KEY` |

### Utilities
| Tool | Description | Env |
|------|-------------|-----|
| `calculator` | Evaluate a basic arithmetic expression (`+ - * / // % **`) safely. | — |
| `current_datetime` | Current date and time, optionally in a given IANA timezone. | — |
| `find_file` | Search for files by name pattern (wildcards). Returns absolute paths. | — |
| `system_monitor` | Full system snapshot: CPU, memory, disk, uptime, top processes, network. | — |

### Messaging &amp; publishing
| Tool | Description | Env |
|------|-------------|-----|
| `post_to_threads` ✦ | Publish a text post to Threads (Meta Graph API — create a container, poll, publish). | `THREADS_USER_ID`, `THREADS_ACCESS_TOKEN` |
| `send_telegram` | Send a plain text message to a Telegram chat. | `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` |
| `send_file_telegram` | Send a local file to a Telegram chat. | `SENTRI_BOT_TOKEN`, `TELEGRAM_CHAT_ID` |
| `create_notion_page` | Create a Notion page from a markdown article, with an AI-themed cover. | `NOTION_TOKEN`, `NOTION_PARENT_PAGE_ID` |

### Infrastructure
| Tool | Description | Env |
|------|-------------|-----|
| `proxmox_health_recover` | Check a Proxmox host over HTTP and auto-reboot via SSH if unresponsive (with a cooldown lock). | `PROXMOX_HOST`, `PROXMOX_HEALTH_URL`, `PROXMOX_SSH_USER`, `PROXMOX_SSH_HOST` |

<sub>✦ = newest additions.</sub>

---

## Install a tool

```bash
agenta pull tool html_to_text
```

Fetches the tool from this repo and registers it with your local agenta daemon.

## Attach it to an agent

```bash
agenta update MIND --add-tool html_to_text
```

---

## How a tool works

- Input parameters arrive as a JSON string in the **`AGENTA_TOOL_PARAMS`** environment variable (also on stdin).
- The handler reads the params, does the work, and prints its result to **stdout**.
- Any allowlisted secrets are injected as environment variables; everything else is withheld.
- A non-zero exit signals failure — always print a clear error before exiting.
- Output is capped (~8,000 chars) to protect the agent's context window.

## Any language, via the shebang

A handler runs through its **shebang** — the first line decides the interpreter, so a tool can be bash, python, node, ruby, anything on the host:

```bash
#!/usr/bin/env bash      # get_weather.sh   → bash
#!/usr/bin/env python3   # html_to_text.py  → python
#!/usr/bin/env node      # my_tool.js       → node
```

List any non-bash runtime (and helper commands like `jq`) under `requires` so a missing dependency is caught up front.

---

## Structure

```
<tool_name>/
  manifest.json        ← name, description, parameters, env, requires, side_effect
  <tool_name>.<ext>    ← the handler (.sh / .py / .js …), executable, with a shebang
```

### manifest.json

```json
{
  "name": "html_to_text",
  "description": "What this tool does — shown to the model so it knows when to call it.",
  "parameters": {
    "type": "object",
    "additionalProperties": false,
    "properties": {
      "url": { "type": "string", "description": "The URL to fetch." }
    },
    "required": ["url"]
  },
  "handler": "html_to_text.py",
  "env": [],
  "requires": ["python3"],
  "side_effect": "read_only"
}
```

- **`description`** — shown directly to the model; be specific, it drives when the tool is called.
- **`parameters`** — JSON Schema; the tool call is validated against it before the handler runs.
- **`handler`** — the script filename (its extension/shebang picks the interpreter).
- **`env`** — environment variables the handler is allowed to read (set them in `~/.agenta/.env`).
- **`requires`** — commands/interpreters that must be on `PATH` (e.g. `python3`, `curl`, `jq`).
- **`side_effect`** — `read_only`, `write`, or `destructive` (drives the confirm-before-run guard).

---

## Write your own

**1. Folder + manifest:**

```bash
mkdir my_tool
cat > my_tool/manifest.json << 'EOF'
{
  "name": "my_tool",
  "description": "What this tool does.",
  "parameters": {
    "type": "object",
    "additionalProperties": false,
    "properties": { "input": { "type": "string", "description": "The input value." } },
    "required": ["input"]
  },
  "handler": "my_tool.sh",
  "env": [],
  "requires": ["jq"],
  "side_effect": "read_only"
}
EOF
```

**2. Handler** (bash here — swap the shebang for `python3`/`node`/… as needed):

```bash
cat > my_tool/my_tool.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

input=$(printf '%s' "$AGENTA_TOOL_PARAMS" | jq -r '.input // empty')
if [ -z "$input" ]; then
  echo "error: 'input' is required" >&2
  exit 1
fi

printf '{"result": "%s"}\n' "$input"
EOF
chmod +x my_tool/my_tool.sh
```

**3. Test it locally:**

```bash
AGENTA_TOOL_PARAMS='{"input": "hello"}' ./my_tool/my_tool.sh
```

---

## Contributing

Tool PRs welcome. Keep each tool **atomic** — one folder, one job. If it needs more than one script, the extras should be internal helpers, not separate tools. Declare every dependency in `requires`, keep secrets out of the script (read them from `env`), and classify `side_effect` honestly.
