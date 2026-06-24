<p align="center">
  <img src="tools.png" width="250" alt="agenta-tools">
</p>

<h1 align="center">Agenta Tools</h1>

<p align="center">
  <strong>Atomic, reusable tools for <a href="https://github.com/warifmust/agenta">agenta</a> agents.</strong>
</p>

<p align="center">
  Each tool is a self-contained folder: a <code>manifest.json</code> that describes the tool and a shell handler that executes it. Drop a folder in, pull it with the CLI — done.
</p>

---

## Available Tools

| Tool | Description | Env Required |
|------|-------------|--------------|
| `tavily_search` | Search the web for information. Returns titles, URLs, and summaries. | `TAVILY_API_KEY` |
| `find_file` | Search for files by name pattern. Supports wildcards. Returns full absolute paths. | — |
| `send_telegram` | Send a text message or document to a Telegram chat. | `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` |
| `send_file_telegram` | Send a specific local file to a Telegram chat with optional caption. | `SENTRI_BOT_TOKEN`, `TELEGRAM_CHAT_ID` |
| `system_monitor` | Full system snapshot: CPU, memory, disk, uptime, top processes, network. | — |
| `create_notion_page` | Create a Notion page from a markdown article with AI-themed cover image. | `NOTION_TOKEN`, `NOTION_PARENT_PAGE_ID` |
| `proxmox_health_recover` | Check Proxmox host health via HTTP and auto-reboot via SSH if unresponsive. Includes cooldown lock to prevent reboot storms. | `PROXMOX_HOST`, `PROXMOX_HEALTH_URL`, `PROXMOX_SSH_USER`, `PROXMOX_SSH_HOST` |

---

## Install a Tool

```bash
agenta pull tool tavily_search
```

This fetches the tool from this repo and registers it with your local agenta daemon.

---

## Attach a Tool to an Agent

```bash
agenta update CORAL --tools ~/.agenta/tools/search_tools.json
```

---

## Structure

Every tool follows the same convention:

```
<tool_name>/
  manifest.json      ← name, description, parameters schema, env requirements
  <handler>.sh       ← the executor
```

---

## How Tools Work

- Parameters are passed to the handler via the `AGENTA_TOOL_PARAMS` environment variable as a JSON string
- The handler reads the params, does the work, and prints output to stdout
- A non-zero exit code signals failure — always print an error message before exiting
- Tool output is capped at 8,000 characters to protect the agent's context window

---

## manifest.json Schema

```json
{
  "name": "tool_name",
  "description": "What this tool does — shown to the model in the system prompt.",
  "parameters": {
    "type": "object",
    "properties": {
      "param_name": { "type": "string", "description": "..." }
    },
    "required": ["param_name"]
  },
  "handler": "script.sh",
  "env": ["ENV_VAR_REQUIRED"]
}
```

- `description` — shown directly to the model. Be specific: the agent uses this to decide when and how to call the tool.
- `parameters` — JSON Schema object. The agent's tool call is validated against this before the handler runs.
- `env` — list of environment variables the handler requires. These must be set in `~/.agenta/.env`.

---

## Writing a Tool

**1. Create the folder and manifest:**

```bash
mkdir my_tool
cat > my_tool/manifest.json << 'EOF'
{
  "name": "my_tool",
  "description": "What this tool does.",
  "parameters": {
    "type": "object",
    "properties": {
      "input": { "type": "string", "description": "The input value." }
    },
    "required": ["input"]
  },
  "handler": "my_tool.sh",
  "env": []
}
EOF
```

**2. Write the handler:**

```bash
cat > my_tool/my_tool.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

INPUT=$(echo "$AGENTA_TOOL_PARAMS" | jq -r '.input')

if [[ -z "$INPUT" ]]; then
  echo "Error: input is required" >&2
  exit 1
fi

echo "Result: $INPUT"
EOF

chmod +x my_tool/my_tool.sh
```

**3. Test it locally:**

```bash
AGENTA_TOOL_PARAMS='{"input": "hello"}' bash my_tool/my_tool.sh
```

---

## Contributing

Tool PRs welcome. Keep each tool atomic — one folder, one job. If it needs more than one script, the extra scripts should be internal helpers not exposed as separate tools.
