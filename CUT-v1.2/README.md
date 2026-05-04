# Claude Usage Tracker

A KDE Plasma 6 widget that displays your Claude AI session (5-hour) and weekly (7-day) usage limits as live progress bars.

Works on both the panel and the desktop:
- **Panel:** Compact progress bars with labeled percentages; click to expand a popup showing reset countdowns and a Refresh button
- **Desktop:** Always shows the full view (reset countdowns + Refresh button) directly — no compact bars, no popup

---

## Requirements

- KDE Plasma 6
- Python 3.10+
- Python `cryptography` package (`pip install cryptography`)
- `qdbus6` (included with KDE Plasma 6)
- KWallet (must be unlocked — happens automatically on KDE login)
- systemd (standard on modern Linux)
- **Claude Desktop** or **Claude Code** installed and signed in

---

## Install

```bash
tar -xzf CUT-v1.2.tar.gz
cd CUT-v1.2
chmod +x install.sh
./install.sh
```

**Important:** You must log out and log back in after installing. The installer sets an environment variable (`QML_XHR_ALLOW_FILE_READ=1`) that Qt requires to allow the widget to read local files. Without this step the widget will show no data.

After logging back in:
1. Right-click your panel → **Add Widgets**
2. Search for **Claude Usage Tracker**
3. Drag it onto your panel or desktop

---

## Uninstall

```bash
chmod +x uninstall.sh
./uninstall.sh
```

After the script finishes, remove the widget from your panel or desktop manually, then restart Plasmashell:

```bash
kquitapp6 plasmashell; kstart plasmashell
```

---

## How It Works

A Python backend service decrypts your OAuth token from Claude Desktop's encrypted token cache (`~/.config/Claude/config.json`) using your KWallet password, then polls the Anthropic usage API every 60 seconds. If Claude Desktop credentials aren't available, Claude Code (`~/.claude/.credentials.json`) is used as a fallback.

Usage data is written to `~/.local/share/cut/usage.json`. The Plasma widget reads that file every 60 seconds and displays two progress bars — one for your 5-hour session usage and one for your 7-day weekly usage.

---

## How to Use

### Panel view

The panel widget shows two compact bars (session and weekly), each with a percentage on the right. The bar color changes as your usage climbs. On the left of the bar, there is a timer for when each limit will reset.

Click the widget to open the popup. The popup shows:
- A percentage and colored progress bar for each limit
- "Resets in X h Y m" below each bar
- A **Refresh** button to force an immediate data fetch. If the backend is rate-limited or encounters an error, the Refresh button is replaced by the error message in the same spot — the popup height never changes.

### Desktop view

When placed on the desktop, the widget skips the compact bars and shows the full view directly at all times — no clicking required.

### Customizing colors

Right-click the widget → **Configure** → **Appearance** to open the color settings.

You can change:
- **Session bar color** (normal, under 70%)
- **Weekly bar color** (normal, under 70%)
- **Warning color** (applied to both bars when usage exceeds 70%)
- **Critical color** (applied to both bars when usage exceeds 90%)
- **Text color** (labels and percentages)

Each field accepts a hex color code (e.g. `#ff5f5f`). A color swatch next to each field updates live as you type. Invalid hex values are ignored. Click **Reset to Defaults** to restore the original color scheme.

### Desktop notifications

The backend sends a system notification when you cross **70%** or **90%** of either limit. Each threshold fires once per reset cycle — you won't get spammed. The flags reset automatically when your usage rolls over to a new cycle.

---

## File Locations

| File | Path |
|------|------|
| Backend script | `~/.local/share/cut/claude_usage.py` |
| Usage data | `~/.local/share/cut/usage.json` |
| systemd service | `~/.config/systemd/user/claude-usage-tracker.service` |
| Plasma widget | `~/.local/share/plasma/plasmoids/com.github.trixles.claudeusagetracker/` |
| Env config | `~/.config/environment.d/cut.conf` |

---

## Troubleshooting

**Widget shows "–%" or no data:**
- Check the backend is running: `systemctl --user status claude-usage-tracker.service`
- Check logs: `journalctl --user -u claude-usage-tracker.service -f`

**"No credentials found" in logs:**
- Make sure Claude Desktop is installed and you're signed in
- Make sure KWallet is unlocked (happens automatically on KDE login)
- If you just signed in to Claude Desktop, click **Refresh** in the popup to retry auth

**KWallet not available after reboot:**
- The backend retries KWallet for up to 30 seconds on startup — this is normal
- If it still fails: `systemctl --user restart claude-usage-tracker.service`

**Missing `cryptography` package:**
- `pip install cryptography` or `pip install --user cryptography`

**Widget not appearing in Add Widgets:**
- Make sure you logged out and back in after install
- Try: `kquitapp6 plasmashell; kstart plasmashell`

**Configure → Appearance tab is blank or missing:**
- Make sure `contents/config/config.qml` is present in the installed plasmoid directory
- Reinstall and re-add the widget

**After updating, widget looks the same:**
- Remove the widget from your panel or desktop and re-add it to force Plasma to reload the cached size

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for full version history.
