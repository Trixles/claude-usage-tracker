# Changelog — Claude Usage Tracker (CUT)

All notable changes documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [1.2.0] - 2026-05-03

### Added

- **Limit timers now visible on panel** — removed 5H and 7H labels and replaced them with timers for limit reset.
- **Color customization** — right-click the widget → Configure → Appearance to set your own colors for:
  - Session bar (normal)
  - Weekly bar (normal)
  - Warning color (>70%)
  - Critical color (>90%)
  - Label text color
  - Each color field has a live swatch and hex validation. Defaults can be restored with the Reset button.
- **`config.qml`** — new file required by Plasma 6 to register the Appearance tab in the Configure dialog. Without it the tab never shows up.

### Changed
- **Popup redesign** — Larger Refresh button. If API is rate-limited or errors out, displays an error message in place of the button until the data pipeline is re-established, then the Refresh button returns.
- **Backend polling** — now polls every 60 seconds (down from 5 minutes). The widget has always refreshed every 60s; now the backend actually keeps up with it.

- **`colorText` schema entry** — added to `main.xml` and wired into `main.qml` as the label color, replacing the hardcoded `dimColor`.

---

## [1.1.3] - 2026-05-01

### Changed
- Desktop widget now displays the full view (sections, reset countdowns, Refresh button) directly — no compact bars, no popup
- Panel widget behavior unchanged
- Fixed bar width stability in compact panel view: percentage labels now use a fixed 26px width so bars don't shift between 1-, 2-, and 3-digit values
- Percentage labels in compact view are now bold to match the 5H/7D labels on the left
- Fixed `uninstall.sh` plasmashell restart command

---

## [1.1.2] - 2026-05-01

### Changed
- Auth source switched to **Claude Desktop** as primary (Claude Code retained as fallback)
  - Decrypts `oauth:tokenCache` from `~/.config/Claude/config.json` using AES-128-CBC
  - KWallet (`Chromium Keys / Chromium Safe Storage`) provides the decryption password via `qdbus6`
- KWallet startup retry: up to 30 seconds (6 × 5s) on first run to handle slow KDE session startup

### Added
- Python `cryptography` package dependency (for AES decryption)
- `qdbus6` system dependency (ships with KDE Plasma 6)

---

## [1.1.0] - 2026-04-30

### Changed
- Improved popup layout with balanced spacing
- Switched to Noto Serif font throughout
- Panel widget font size increased to 12px

---

## [1.0.0] - 2026-04-30

### Added
- Initial release
