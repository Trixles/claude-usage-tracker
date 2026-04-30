#!/usr/bin/env python3
"""
CUT Backend — Claude Usage Tracker
Reads the OAuth token stored by Claude Code at ~/.claude/.credentials.json,
hits the official Anthropic usage endpoint, and writes a JSON file that the
Plasma widget reads.

Endpoint (reverse-engineered from Claude Desktop network traffic):
  GET https://api.anthropic.com/api/oauth/usage
  anthropic-beta: oauth-2025-04-20

Credentials file (Claude Code, Linux):
  ~/.claude/.credentials.json

Output:
  ~/.local/share/cut/usage.json
"""

import json
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone
from pathlib import Path

# ── Paths ─────────────────────────────────────────────────────────────────────
CREDENTIALS_FILE = Path.home() / ".claude" / ".credentials.json"
OUTPUT_DIR       = Path.home() / ".local" / "share" / "cut"
OUTPUT_FILE      = OUTPUT_DIR / "usage.json"

USAGE_URL        = "https://api.anthropic.com/api/oauth/usage"
BETA_HEADER      = "oauth-2025-04-20"

POLL_INTERVAL    = 300   # 5 min
POLL_INTERVAL_HI = 600   # 10 min when >80%

# ── Helpers ───────────────────────────────────────────────────────────────────

def log(msg):
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] {msg}", flush=True)


def token_needs_refresh(creds):
    expires_ms = creds.get("claudeAiOauth", {}).get("expiresAt", 0)
    return time.time() >= (expires_ms / 1000) - 300


def refresh_via_cli():
    import subprocess
    try:
        subprocess.run(["claude", "auth", "status"], capture_output=True, timeout=15)
        log("Token refresh triggered via CLI.")
    except Exception as e:
        log(f"CLI refresh attempt failed (non-fatal): {e}")


def fetch_usage(token):
    req = urllib.request.Request(
        USAGE_URL,
        headers={
            "Authorization":  f"Bearer {token}",
            "anthropic-beta": BETA_HEADER,
            "Content-Type":   "application/json",
            "User-Agent":     "CUT/1.0 (Claude Usage Tracker; Linux)",
        }
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        log(f"HTTP {e.code}: {e.reason} — {body[:200]}")
    except urllib.error.URLError as e:
        log(f"Network error: {e.reason}")
    except Exception as e:
        log(f"Unexpected error: {e}")
    return None


def fmt_countdown(iso_str):
    try:
        dt    = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        secs  = int((dt - datetime.now(timezone.utc)).total_seconds())
        if secs <= 0:
            return "resetting soon"
        h, rem = divmod(secs, 3600)
        return f"{h}h {rem // 60}m"
    except Exception:
        return ""


def parse_response(raw):
    five  = raw.get("five_hour", {})
    seven = raw.get("seven_day", {})

    session_pct   = float(five.get("utilization",  0))
    weekly_pct    = float(seven.get("utilization", 0))
    session_reset = five.get("resets_at",  "")
    weekly_reset  = seven.get("resets_at", "")

    parts = []
    if session_reset:
        parts.append(f"Session resets in {fmt_countdown(session_reset)}")
    if weekly_reset:
        parts.append(f"Weekly resets in {fmt_countdown(weekly_reset)}")

    return {
        "session_pct":   session_pct,
        "weekly_pct":    weekly_pct,
        "session_reset": session_reset,
        "weekly_reset":  weekly_reset,
        "reset_label":   "  ·  ".join(parts),
        "updated_at":    datetime.now(timezone.utc).isoformat(),
    }


def write_output(payload):
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    tmp = OUTPUT_FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps(payload, indent=2))
    tmp.replace(OUTPUT_FILE)


def write_error(msg):
    write_output({"error": msg, "updated_at": datetime.now(timezone.utc).isoformat()})


# ── Main loop ─────────────────────────────────────────────────────────────────

def main():
    log("CUT backend starting — Claude Usage Tracker")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    failures = 0

    while True:
        try:
            creds = json.loads(CREDENTIALS_FILE.read_text())
        except Exception as e:
            log(f"Cannot read credentials: {e}")
            write_error("Cannot read ~/.claude/.credentials.json — is Claude Code installed and signed in?")
            time.sleep(60)
            continue

        if token_needs_refresh(creds):
            log("Token near expiry — refreshing via CLI...")
            refresh_via_cli()
            try:
                creds = json.loads(CREDENTIALS_FILE.read_text())
            except Exception:
                pass

        token = creds.get("claudeAiOauth", {}).get("accessToken")
        if not token:
            log("No access token in credentials file.")
            write_error("No OAuth token found. Try: claude auth login")
            time.sleep(60)
            continue

        raw = fetch_usage(token)
        if raw is None:
            failures += 1
            if failures >= 3:
                write_error(f"Failed to fetch usage data after {failures} attempts.")
            time.sleep(60)
            continue

        failures = 0
        payload  = parse_response(raw)
        write_output(payload)
        log(f"session={payload['session_pct']:.1f}%  weekly={payload['weekly_pct']:.1f}%  {payload['reset_label']}")

        interval = POLL_INTERVAL_HI if max(payload["session_pct"], payload["weekly_pct"]) > 80 else POLL_INTERVAL
        log(f"Next poll in {interval // 60} minutes.")
        time.sleep(interval)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("Stopped.")
        sys.exit(0)
