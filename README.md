# agenta-tools

Atomic, reusable tools for [agenta](https://github.com/warifmust/agenta) agents.

Each tool is a self-contained folder: a `manifest.json` describing the tool and a handler script that executes it.

## Install a tool

```bash
agenta pull tool tavily_search
```

## Structure

```
<tool_name>/
  manifest.json   ← name, description, parameters schema, env requirements
  <handler>.sh    ← the actual executor
```

## Available tools

| Tool | Description | Requires |
|------|-------------|----------|
| `tavily_search` | Web search via Tavily API | `TAVILY_API_KEY` |
| `find_file` | Search for files by name pattern, returns full paths | — |
| `send_telegram` | Send a message or document to Telegram | `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` |
| `send_file_telegram` | Send a specific local file to Telegram | `SENTRI_BOT_TOKEN`, `TELEGRAM_CHAT_ID` |
| `system_monitor` | CPU, memory, disk, uptime, top processes snapshot | — |
| `create_notion_page` | Create a Notion page from a markdown article | `NOTION_TOKEN`, `NOTION_PARENT_PAGE_ID` |
| `proxmox_health_recover` | Check Proxmox health and reboot via SSH if down | `PROXMOX_HOST`, `PROXMOX_HEALTH_URL`, `PROXMOX_SSH_USER`, `PROXMOX_SSH_HOST` |

## manifest.json schema

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

## How tools work

- Parameters are passed to the handler via the `AGENTA_TOOL_PARAMS` environment variable as a JSON string
- The handler reads params, does the work, and prints output to stdout
- A non-zero exit code signals failure — always print an error message before exiting
