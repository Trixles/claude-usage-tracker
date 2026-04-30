#!/usr/bin/env bash
set -euo pipefail

# ── CUT — Claude Usage Tracker — Uninstaller ──────────────────────────────────
# Removes the backend, systemd service, Plasma widget, and env config.
# ──────────────────────────────────────────────────────────────────────────────

BACKEND_DIR="$HOME/.local/share/cut"
PLASMOID_DIR="$HOME/.local/share/plasma/plasmoids/com.github.trixles.claudeusagetracker"
SERVICE_FILE="$HOME/.config/systemd/user/claude-usage-tracker.service"
ENV_FILE="$HOME/.config/environment.d/cut.conf"

echo "╔══════════════════════════════════════════╗"
echo "║  CUT — Claude Usage Tracker Uninstaller  ║"
echo "╚══════════════════════════════════════════╝"
echo ""

read -rp "This will remove CUT completely. Continue? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""

# ── Stop and disable service ─────────────────────────────────────────────────
if systemctl --user is-active claude-usage-tracker.service &>/dev/null; then
    echo "⏹  Stopping service..."
    systemctl --user stop claude-usage-tracker.service
fi

if systemctl --user is-enabled claude-usage-tracker.service &>/dev/null; then
    echo "🔌 Disabling service..."
    systemctl --user disable claude-usage-tracker.service
fi

if [ -f "$SERVICE_FILE" ]; then
    echo "🗑  Removing systemd service file..."
    rm -f "$SERVICE_FILE"
    systemctl --user daemon-reload
fi

# ── Remove backend ───────────────────────────────────────────────────────────
if [ -d "$BACKEND_DIR" ]; then
    echo "🗑  Removing backend ($BACKEND_DIR)..."
    rm -rf "$BACKEND_DIR"
fi

# ── Remove Plasma widget ────────────────────────────────────────────────────
if [ -d "$PLASMOID_DIR" ]; then
    echo "🗑  Removing Plasma widget..."
    rm -rf "$PLASMOID_DIR"
fi

# ── Remove environment config ────────────────────────────────────────────────
if [ -f "$ENV_FILE" ]; then
    echo "🗑  Removing environment config (cut.conf)..."
    rm -f "$ENV_FILE"
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "✅ CUT has been fully uninstalled."
echo ""
echo "┌─────────────────────────────────────────────────────────┐"
echo "│  NOTE: You may need to remove the widget from your      │"
echo "│  panel manually if it's still showing, then restart      │"
echo "│  plasmashell:  killall plasmashell; plasmashell &        │"
echo "└─────────────────────────────────────────────────────────┘"
