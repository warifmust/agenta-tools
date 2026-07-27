#!/usr/bin/env python3
"""humanize_text — Rewrite an AI-generated article so it reads like a real person wrote it.
Provider-agnostic: any OpenAI-compatible chat API. Handles long text via chunking."""

import json, os, re, sys, urllib.request, urllib.error

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
BASE_URL = os.environ.get("HUMANIZE_BASE_URL", "http://localhost:11434/v1")
DEFAULT_MODEL = os.environ.get("HUMANIZE_MODEL", "llama3.1:8b")
API_KEY = os.environ.get("HUMANIZE_API_KEY", "")

SYSTEM_PROMPT = (
    "You rewrite one passage of text so it reads like a thoughtful person wrote it, "
    "not an AI. Output ONLY the rewritten passage — no preamble, no explanation, no quotes.\n\n"
    "Rules:\n"
    "- Keep the original MEANING, facts, numbers, names, and level of certainty exactly. "
    "Do NOT add claims, and do NOT turn hedged statements (\"often\", \"tends to\") into absolutes.\n"
    "- Keep roughly the same length. Do not summarize or expand.\n"
    "- Remove AI tells: hedging openers (\"it is worth noting\", \"it should be noted that\"), "
    "formulaic transitions (\"moreover\", \"furthermore\", \"additionally\", \"in addition\"), "
    "puffery (\"vibrant\", \"rich tapestry\", \"landscape\", \"realm\", \"delve\", \"pivotal\", "
    "\"testament to\", \"beacon of\", \"showcase\", \"seamless\", \"robust\"), "
    "overused emphasis words (\"crucial\", \"essential\", \"key\"), "
    "the \"not just X, but also Y\" frame, "
    "empty summary/closing sentences (\"in conclusion\", \"in summary\", \"to sum up\"), "
    "callback phrases (\"as previously mentioned\", \"as we have seen\"), "
    "lazy time openers (\"in today's world\", \"in the modern era\"), "
    "and rule-of-three padding.\n"
    "- Write like a human: vary sentence length, plain everyday words, contractions where natural. "
    "Prefer concrete over abstract.\n"
    "- Never use a negation-contrast frame (\"it's not X, it's Y\" / \"not just X, but Y\" / "
    "\"more than X, it's Y\"). State the point directly and positively instead. "
    "BAD: \"It's not merely a tool; it's a paradigm shift.\" "
    "GOOD: \"It changes how the work gets done.\"\n"
    "- Do not preserve the original's length by padding, and do not summarize either; "
    "say the same things, plainly.\n"
    "- Do not use em-dashes to stitch clauses; use normal punctuation."
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def estimate_tokens(text: str) -> int:
    """Rough token count: ~4 chars per token for English."""
    return max(1, len(text) // 4)


def is_passthrough_block(block: str) -> bool:
    """Return True if the block should be passed through unchanged."""
    stripped = block.strip()
    if not stripped:
        return True  # blank line
    # Markdown heading
    if stripped.startswith("#"):
        return True
    # Code fence
    if stripped.startswith("```"):
        return True
    # List item
    if re.match(r"^[-*]\s|^\d+\.\s", stripped):
        return True
    # Blockquote
    if stripped.startswith(">"):
        return True
    # Table row
    if stripped.startswith("|"):
        return True
    # Very short block (~4 words or fewer)
    if len(stripped.split()) < 4:
        return True
    return False


def rewrite_block(block: str, model: str) -> str:
    """Send one block to the LLM for rewriting. Returns the rewritten text or raises."""
    payload = {
        "model": model,
        "stream": False,
        "max_tokens": max(1024, estimate_tokens(block) * 2),
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": block},
        ],
    }
    data = json.dumps(payload).encode("utf-8")

    url = BASE_URL.rstrip("/") + "/chat/completions"
    headers = {"Content-Type": "application/json"}
    if API_KEY:
        headers["Authorization"] = "Bearer " + API_KEY

    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            body = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {e.code}: {err_body}") from None
    except urllib.error.URLError as e:
        raise RuntimeError(f"Connection error: {e.reason}") from None

    content = body.get("choices", [{}])[0].get("message", {}).get("content", "")
    rewritten = content.strip()
    if not rewritten:
        raise RuntimeError("Model returned empty response")
    return rewritten


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    raw = os.environ.get("AGENTA_TOOL_PARAMS", "")
    if not raw:
        # Also try stdin
        raw = sys.stdin.read()
    try:
        params = json.loads(raw)
    except json.JSONDecodeError as e:
        print(json.dumps({"error": f"Invalid JSON input: {e}"}))
        sys.exit(1)

    text = params.get("text", "")
    if not text or not text.strip():
        print(json.dumps({"error": "'text' parameter is required and must not be empty"}))
        sys.exit(1)

    model = params.get("model") or DEFAULT_MODEL

    # Split into blocks on blank lines, keeping separators
    # Strategy: split on double-newline, then re-join with double-newline after processing
    blocks = re.split(r"(\n\n+)", text)

    warnings = []
    rewritten_blocks = []
    paragraphs_rewritten = 0
    first_call_done = False

    for i, block in enumerate(blocks):
        # Separators (blank-line runs) pass through
        if re.match(r"^\n+$", block):
            rewritten_blocks.append(block)
            continue

        if is_passthrough_block(block):
            rewritten_blocks.append(block)
            continue

        # Prose block — send to model
        try:
            rewritten = rewrite_block(block, model)
            rewritten_blocks.append(rewritten)
            paragraphs_rewritten += 1
            first_call_done = True
        except Exception as e:
            msg = f"Block {paragraphs_rewritten + 1}: {e}"
            warnings.append(msg)
            if not first_call_done:
                # First call failed — hard error
                print(json.dumps({
                    "error": f"First API call failed — check configuration ({msg})",
                    "original": text,
                    "humanized": None,
                    "paragraphs_rewritten": 0,
                    "warnings": warnings,
                }))
                sys.exit(1)
            # Subsequent failure — keep original block
            rewritten_blocks.append(block)

    result = {
        "original": text,
        "humanized": "".join(rewritten_blocks),
        "paragraphs_rewritten": paragraphs_rewritten,
        "warnings": warnings,
    }
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
