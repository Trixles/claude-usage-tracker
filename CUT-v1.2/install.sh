#!/usr/bin/env bash
set -euo pipefail

# ── CUT — Claude Usage Tracker — Installer ────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

BACKEND_DIR="$HOME/.local/share/cut"
PLASMOID_DIR="$HOME/.local/share/plasma/plasmoids/com.github.trixles.claudeusagetracker"
SERVICE_DIR="$HOME/.config/systemd/user"
ENV_DIR="$HOME/.config/environment.d"

echo "╔══════════════════════════════════════════╗"
echo "║   CUT — Claude Usage Tracker Installer   ║"
echo "║               v1.2.0                     ║"
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

DESKTOP_CONFIG="$HOME/.config/Claude/config.json"
CODE_CREDENTIALS="$HOME/.claude/.credentials.json"

if [ ! -f "$DESKTOP_CONFIG" ]; then
    if [ ! -f "$CODE_CREDENTIALS" ]; then
        echo "⚠  Neither Claude Desktop nor Claude Code credentials found."
        echo "   Continuing install — the backend will wait for credentials."
    else
        echo "⚠  Claude Desktop config not found. Claude Code credentials found as fallback."
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
    if python3 -m pip install --user cryptography; then
        echo "   ✓ cryptography installed."
    else
        echo ""
        echo "   ⚠  Could not install cryptography automatically."
        echo "   Please run: python3 -m pip install --user cryptography"
        echo "   Without it, only Claude Code credentials will work (not Claude Desktop)."
        echo ""
    fi
fi

# ── Stop existing service ─────────────────────────────────────────────────────
if systemctl --user is-active claude-usage-tracker.service &>/dev/null; then
    echo "⏹  Stopping existing CUT service..."
    systemctl --user stop claude-usage-tracker.service
fi

# ── Install backend ──────────────────────────────────────────────────────────
echo "📦 Installing backend..."
mkdir -p "$BACKEND_DIR"
cp "$SCRIPT_DIR/claude_usage.py"  "$BACKEND_DIR/claude_usage.py"
cp "$SCRIPT_DIR/cut-refresh.py"   "$BACKEND_DIR/cut-refresh.py"
chmod +x "$BACKEND_DIR/claude_usage.py"
chmod +x "$BACKEND_DIR/cut-refresh.py"

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
mkdir -p "$PLASMOID_DIR/contents/config"
cp "$SCRIPT_DIR/plasmoid/metadata.json"                      "$PLASMOID_DIR/metadata.json"
cp "$SCRIPT_DIR/plasmoid/contents/ui/main.qml"               "$PLASMOID_DIR/contents/ui/main.qml"
cp "$SCRIPT_DIR/plasmoid/contents/ui/ConfigPage.qml"         "$PLASMOID_DIR/contents/ui/ConfigPage.qml"
cp "$SCRIPT_DIR/plasmoid/contents/config/main.xml"           "$PLASMOID_DIR/contents/config/main.xml"
cp "$SCRIPT_DIR/plasmoid/contents/config/config.qml"         "$PLASMOID_DIR/contents/config/config.qml"

# ── Set QML environment variable ─────────────────────────────────────────────
echo "📦 Setting QML_XHR_ALLOW_FILE_READ=1..."
mkdir -p "$ENV_DIR"
if [ ! -f "$ENV_DIR/cut.conf" ]; then
    echo "QML_XHR_ALLOW_FILE_READ=1" > "$ENV_DIR/cut.conf"
else
    echo "   (cut.conf already exists, skipping)"
fi

echo ""
echo "✅ CUT v1.2.0 installed successfully!"
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│  NOTE: The installer set QML_XHR_ALLOW_FILE_READ=1 in      │"
echo "│  ~/.config/environment.d/cut.conf                          │"
echo "│                                                             │"
echo "│  This allows the widget to read usage.json from disk.      │"
echo "│  It applies to plasmashell only in practice, but is set    │"
echo "│  at the user environment level. Removing CUT (uninstall.sh)│"
echo "│  will delete this file and restore the default.            │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""
echo "┌─────────────────────────────────────────────────────────────┐"
echo "│  Remove the old widget from your panel/desktop, then:       │"
echo "│  Right-click panel → Add Widgets → Claude Usage Tracker     │"
echo "│                                                             │"
echo "│  If the widget shows –%, restart plasmashell:               │"
echo "│    kquitapp6 plasmashell; kstart plasmashell                │"
echo "└─────────────────────────────────────────────────────────────┘"
echo ""
echo "Backend status:"
systemctl --user status claude-usage-tracker.service --no-pager -l 2>/dev/null || true
