#!/usr/bin/env bash
set -euo pipefail

# ── CUT — Claude Usage Tracker — Installer ────────────────────────────────────
# Installs the Python backend, systemd service, Plasma 6 widget, and env config.
# Requirements: KDE Plasma 6, Python 3.10+, systemd, Claude Desktop
# ──────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Destination paths
BACKEND_DIR="$HOME/.local/share/cut"
PLASMOID_DIR="$HOME/.local/share/plasma/plasmoids/com.github.trixles.claudeusagetracker"
SERVICE_DIR="$HOME/.config/systemd/user"
ENV_DIR="$HOME/.config/environment.d"

echo "╔══════════════════════════════════════════╗"
echo "║   CUT — Claude Usage Tracker Installer   ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Preflight checks ─────────────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
    echo "❌ python3 not found. Please install Python 3.10+."
    exit 1
fi

PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PY_MAJ=$(echo "$PY_VER" | cut -d. -f1)
PY_MIN=$(echo "$PY_VER" | cut -d. -f2)
if [ "$PY_MAJ" -lt 3 ] || { [ "$PY_MAJ" -eq 3 ] && [ "$PY_MIN" -lt 10 ]; }; then
    echo "❌ Python 3.10+ required (found $PY_VER)."
    exit 1
fi

if ! command -v systemctl &>/dev/null; then
    echo "❌ systemctl not found. systemd is required."
    exit 1
fi

if ! command -v qdbus6 &>/dev/null && ! command -v qdbus &>/dev/null; then
    echo "⚠  qdbus6 not found. KWallet access may not work."
    echo "   qdbus6 is normally included with KDE Plasma 6."
    echo ""
fi

# ── Check for Claude Desktop config ──────────────────────────────────────────
DESKTOP_CONFIG="$HOME/.config/Claude/config.json"
CODE_CREDENTIALS="$HOME/.claude/.credentials.json"

if [ ! -f "$DESKTOP_CONFIG" ]; then
    if [ ! -f "$CODE_CREDENTIALS" ]; then
        echo "⚠  Neither Claude Desktop nor Claude Code credentials found."
        echo "   CUT needs Claude Desktop installed and signed in to work."
        echo "   Continuing install — the backend will wait for credentials."
    else
        echo "⚠  Claude Desktop config not found at $DESKTOP_CONFIG"
        echo "   Claude Code credentials found as fallback."
        echo "   For best results, install and sign in to Claude Desktop."
    fi
    echo ""
else
    echo "✓  Claude Desktop config found."
fi

# ── Install cryptography package ──────────────────────────────────────────────
echo "📦 Installing Python dependencies..."
if python3 -c "import cryptography" 2>/dev/null; then
    echo "   (cryptography already installed, skipping)"
else
    echo "   Installing 'cryptography' package..."
    if pip install --user cryptography 2>/dev/null || pip3 install --user cryptography 2>/dev/null; then
        echo "   ✓ cryptography installed."
    else
        echo "   ⚠  Could not install cryptography automatically."
        echo "   Please run: pip install cryptography"
    fi
fi

# ── Stop existing service if running ──────────────────────────────────────────
if systemctl --user is-active claude-usage-tracker.service &>/dev/null; then
    echo "⏹  Stopping existing CUT service..."
    systemctl --user stop claude-usage-tracker.service
fi

# ── Install backend ──────────────────────────────────────────────────────────
echo "📦 Installing backend..."
mkdir -p "$BACKEND_DIR"
cp "$SCRIPT_DIR/claude_usage.py" "$BACKEND_DIR/claude_usage.py"
chmod +x "$BACKEND_DIR/claude_usage.py"

# ── Install systemd service ──────────────────────────────────────────────────
echo "📦 Installing systemd service..."
mkdir -p "$SERVICE_DIR"
cp "$SCRIPT_DIR/claude-usage-tracker.service" "$SERVICE_DIR/claude-usage-tracker.service"
systemctl --user daemon-reload
systemctl --user enable claude-usage-tracker.service
systemctl --user start claude-usage-tracker.service

# ── Install Plasma widget ────────────────────────────────────────────────────
echo "📦 Installing Plasma widget..."
mkdir -p "$PLASMOID_DIR/contents/ui"
cp "$SCRIPT_DIR/plasmoid/metadata.json" "$PLASMOID_DIR/metadata.json"
cp "$SCRIPT_DIR/plasmoid/contents/ui/main.qml" "$PLASMOID_DIR/contents/ui/main.qml"

# ── Set QML environment variable ─────────────────────────────────────────────
echo "📦 Setting QML_XHR_ALLOW_FILE_READ=1..."
mkdir -p "$ENV_DIR"
if [ ! -f "$ENV_DIR/cut.conf" ]; then
    echo "QML_XHR_ALLOW_FILE_READ=1" > "$ENV_DIR/cut.conf"
else
    echo "   (cut.conf already exists, skipping)"
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "✅ CUT installed successfully!"
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  IMPORTANT: You must log out and log back in for the    │"
echo "│  environment variable to take effect.                   │"
echo "│                                                         │"
echo "│  After logging back in:                                 │"
echo "│  1. Right-click your panel → Add Widgets               │"
echo "│  2. Search for \"Claude Usage Tracker\"                   │"
echo "│  3. Drag it onto your panel                             │"
echo "└─────────────────────────────────────────────────────────┘"
echo ""
echo "Backend status:"
systemctl --user status claude-usage-tracker.service --no-pager -l 2>/dev/null || true
