# Claude Usage Tracker

A KDE Plasma 6 panel widget that displays your Claude AI session (5-hour) and weekly (7-day) usage limits as live progress bars.

![Claude Usage Tracker](screenshots/claude-usage-tracker-v1.1.0.png)

## Requirements

- KDE Plasma 6
- Python 3.10+
- systemd (standard on modern Linux)
- Claude Desktop or Claude Code installed and signed in

## Install

```bash
unzip CUT-v1.1.0.zip
cd CUT-v1.1.0
chmod +x install.sh
./install.sh
```

**Important:** You must log out and log back in after installing for the widget to work. This is because the installer sets an environment variable (`QML_XHR_ALLOW_FILE_READ=1`) that Qt needs to allow the widget to read local files.

After logging back in:
1. Right-click your panel → **Add Widgets**
2. Search for "Claude Usage Tracker"
3. Drag it onto your panel

## Uninstall

```bash
chmod +x uninstall.sh
./uninstall.sh
```

## How It Works

- A Python backend reads your OAuth token from `~/.claude/.credentials.json` and checks the Anthropic usage API every 5 minutes
- Usage data is written to `~/.local/share/cut/usage.json`
- The Plasma widget reads that file every 60 seconds and displays two progress bars
- Color coding: green/blue (normal) → orange (>70%) → red (>90%)

## File Locations

| File | Path |
|------|------|
| Backend script | `~/.local/share/cut/claude_usage.py` |
| Usage data | `~/.local/share/cut/usage.json` |
| systemd service | `~/.config/systemd/user/claude-usage-tracker.service` |
| Plasma widget | `~/.local/share/plasma/plasmoids/com.github.trixles.claudeusagetracker/` |
| Env config | `~/.config/environment.d/cut.conf` |

## Troubleshooting

**Widget shows "–%" or no data:**
- Check the backend is running: `systemctl --user status claude-usage-tracker.service`
- Check for credentials: `ls ~/.claude/.credentials.json`
- Check logs: `journalctl --user -u claude-usage-tracker.service -f`

**Widget not appearing in Add Widgets:**
- Make sure you logged out and back in after install
- Try: `killall plasmashell; plasmashell &`

**After updating, widget looks the same:**
- Remove the widget from your panel and re-add it to force Plasma to reload the cached popup size

## Changelog

### v1.1.0
- Improved popup layout with balanced spacing between sections and around the Refresh button
- Switched to Noto Serif font throughout the popup
- Panel widget font size increased to 12px for better readability
- Popup height tuned to accommodate the new font

### v1.0.0
- Initial release
