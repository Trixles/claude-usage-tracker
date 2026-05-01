#!/usr/bin/env python3
"""
CUT Backend — Claude Usage Tracker v1.1.2
Decrypts the OAuth token from Claude Desktop's encrypted token cache
and polls the Anthropic usage endpoint.

Token source (Claude Desktop, Linux):
  ~/.config/Claude/config.json  (oauth:tokenCache, encrypted with v11/AES-128-CBC)
  KWallet "Chromium Keys" / "Chromium Safe Storage"  (encryption password)

Fallback (Claude Code, if installed):
  ~/.claude/.credentials.json

Output:
  ~/.local/share/cut/usage.json
"""

import base64
import json
import shutil
import subprocess
import sys
import time
import urllib.request
import urllib.error
from datetime import datetime, timezone
from pathlib import Path

# ── Paths ─────────────────────────────────────────────────────────────────────
DESKTOP_CONFIG   = Path.home() / ".config" / "Claude" / "config.json"
CODE_CREDENTIALS = Path.home() / ".claude" / ".credentials.json"
OUTPUT_DIR       = Path.home() / ".local" / "share" / "cut"
OUTPUT_FILE      = OUTPUT_DIR / "usage.json"

USAGE_URL        = "https://api.anthropic.com/api/oauth/usage"
BETA_HEADER      = "oauth-2025-04-20"

POLL_INTERVAL    = 300   # 5 min
POLL_INTERVAL_HI = 600   # 10 min when >80%

KWALLET_RETRIES  = 6     # retry KWallet this many times on startup
KWALLET_DELAY    = 5     # seconds between retries

# ── Helpers ───────────────────────────────────────────────────────────────────

def log(msg):
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] {msg}", flush=True)


def open_kwallet():
    """Open KWallet and return (handle, qdbus_path) or (None, None)."""
    qdbus = shutil.which("qdbus6") or shutil.which("qdbus")
    if not qdbus:
        return None, None

    try:
        r = subprocess.run(
            [qdbus, "org.kde.kwalletd6", "/modules/kwalletd6",
             "org.kde.KWallet.open", "kdewallet", "0", "CUT"],
            capture_output=True, text=True, timeout=10
        )
        handle = r.stdout.strip()
        if handle and handle != "-1":
            return handle, qdbus
    except Exception:
        pass
    return None, None


def open_kwallet_with_retry():
    """Try to open KWallet, retrying if KDE session isn't ready yet."""
    handle, qdbus = open_kwallet()
    if handle:
        return handle, qdbus

    log(f"KWallet not ready — retrying up to {KWALLET_RETRIES} times "
        f"({KWALLET_DELAY}s apart)...")
    for attempt in range(1, KWALLET_RETRIES + 1):
        time.sleep(KWALLET_DELAY)
        handle, qdbus = open_kwallet()
        if handle:
            log(f"KWallet opened on attempt {attempt + 1}.")
            return handle, qdbus
        log(f"KWallet retry {attempt}/{KWALLET_RETRIES}...")

    log("KWallet did not become available.")
    return None, None


def decrypt_desktop_token(kwallet_retry=False):
    """Decrypt Claude Desktop's oauth:tokenCache using KWallet."""
    if not DESKTOP_CONFIG.exists():
        return None, None

    try:
        config = json.loads(DESKTOP_CONFIG.read_text())
    except Exception as e:
        log(f"Cannot read Desktop config: {e}")
        return None, None

    encrypted_b64 = config.get("oauth:tokenCache")
    if not encrypted_b64:
        log("No oauth:tokenCache in Desktop config.")
        return None, None

    raw = base64.b64decode(encrypted_b64)
    if raw[:3] != b"v11":
        log(f"Unsupported encryption prefix: {raw[:3]}")
        return None, None

    # Get password from KWallet via qdbus
    qdbus = shutil.which("qdbus6") or shutil.which("qdbus")
    if not qdbus:
        log("Cannot find qdbus6 or qdbus — KWallet unavailable.")
        return None, None

    if kwallet_retry:
        handle, qdbus = open_kwallet_with_retry()
    else:
        handle, qdbus = open_kwallet()

    if not handle:
        return None, None

    try:
        r = subprocess.run(
            [qdbus, "org.kde.kwalletd6", "/modules/kwalletd6",
             "org.kde.KWallet.readPassword", handle, "Chromium Keys",
             "Chromium Safe Storage", "CUT"],
            capture_output=True, text=True, timeout=10
        )
        password = r.stdout.strip()
        if not password:
            log("No 'Chromium Safe Storage' password in KWallet.")
            return None, None
    except Exception as e:
        log(f"KWallet D-Bus error: {e}")
        return None, None

    # Decrypt: PBKDF2(password, "saltysalt", 1 iter, 16 bytes) + AES-128-CBC
    try:
        from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
        from cryptography.hazmat.primitives import hashes
        from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

        kdf = PBKDF2HMAC(algorithm=hashes.SHA1(), length=16,
                          salt=b"saltysalt", iterations=1)
        key = kdf.derive(password.encode("utf-8"))
        encrypted = raw[3:]  # strip "v11"
        dec = Cipher(algorithms.AES(key), modes.CBC(b" " * 16)).decryptor()
        padded = dec.update(encrypted) + dec.finalize()
        padded = padded[:-padded[-1]]  # PKCS7 unpad

        data = json.loads(padded.decode("utf-8"))
    except ImportError:
        log("Missing 'cryptography' package. Install: pip install cryptography")
        return None, None
    except Exception as e:
        log(f"Decryption failed: {e}")
        return None, None

    # Pick the best token entry.
    # Prefer the Desktop-only entry (no claude_code scope).
    best = None
    for key_name, val in data.items():
        token = val.get("token") or val.get("accessToken")
        if not token:
            continue
        expires_ms = val.get("expiresAt", 0)
        if best is None:
            best = val
        elif "sessions:claude_code" not in key_name:
            best = val
        elif expires_ms > (best.get("expiresAt", 0)):
            best = val

    if not best:
        log("No token entries found in decrypted cache.")
        return None, None

    token = best.get("token") or best.get("accessToken")
    expires_ms = best.get("expiresAt", 0)

    if time.time() >= (expires_ms / 1000):
        log("Desktop token is expired.")
        return token, best.get("refreshToken")

    return token, None


def get_token_from_code():
    """Fallback: read OAuth token from Claude Code's credentials file."""
    if not CODE_CREDENTIALS.exists():
        return None
    try:
        creds = json.loads(CODE_CREDENTIALS.read_text())
        oauth = creds.get("claudeAiOauth", {})
        token = oauth.get("accessToken")
        expires_ms = oauth.get("expiresAt", 0)
        if token and time.time() < (expires_ms / 1000):
            return token
        elif token:
            log("Claude Code token is expired.")
        return None
    except Exception as e:
        log(f"Could not read Code credentials: {e}")
    return None


def get_token(kwallet_retry=False):
    """Try Desktop first, then Code as fallback."""
    token, _refresh = decrypt_desktop_token(kwallet_retry=kwallet_retry)
    if token:
        log("Using Claude Desktop token.")
        return token

    code_token = get_token_from_code()
    if code_token:
        log("Using Claude Code token (fallback).")
        return code_token

    return None


def fetch_usage(token):
    req = urllib.request.Request(
        USAGE_URL,
        headers={
            "Authorization":  f"Bearer {token}",
            "anthropic-beta": BETA_HEADER,
            "Content-Type":   "application/json",
            "User-Agent":     "CUT/1.1.2 (Claude Usage Tracker; Linux)",
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
    log("CUT backend v1.1.2 starting — Claude Usage Tracker")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    failures = 0
    first_run = True

    while True:
        # On first run, use KWallet retry logic to wait for KDE session
        token = get_token(kwallet_retry=first_run)
        first_run = False

        if not token:
            log("No valid token from Desktop or Code.")
            write_error("No credentials found. Is Claude Desktop running and signed in?")
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
