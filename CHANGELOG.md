# Changelog

All notable changes to Claude Usage Tracker will be documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.1.3] - 2026-05-01
### Changed
- Desktop widget now displays the full view (sections, reset countdowns, Refresh button) directly, with no compact bars and no popup — identical to what the panel popup shows
- Panel widget behavior is unchanged
- Fixed bar width stability in compact panel view: percentage labels now use a fixed 26px width so bars stay the same size regardless of whether the value is 1, 2, or 3 digits
- Percentage labels in compact view are now bold to match the 5H/7D labels on the left
- Percentage labels use `AlignHCenter` within their fixed-width box for balanced visual spacing
- Fixed `uninstall.sh` plasmashell restart command to use `kquitapp6 plasmashell; kstart plasmashell`

## [1.1.2] - 2026-05-01
### Changed
- Auth source switched from Claude Code to **Claude Desktop** as the primary token source
  - Decrypts `oauth:tokenCache` from `~/.config/Claude/config.json` using AES-128-CBC
  - KWallet (`Chromium Keys / Chromium Safe Storage`) provides the encryption password via `qdbus6`
  - Claude Code (`~/.claude/.credentials.json`) retained as fallback
- KWallet startup retry: on first run, waits up to 30 seconds (6 × 5s) for KWallet to become available after reboot

### Added
- New dependency: Python `cryptography` package (for AES decryption)
- New system dependency: `qdbus6` (ships with KDE Plasma 6)

## [1.1.0] - 2026-04-30
### Changed
- Improved popup layout with balanced spacing between sections and around the Refresh button
- Switched to Noto Serif font throughout the popup and panel widget
- Panel widget font size increased to 12px for better readability
- Popup height tuned to accommodate the new font

## [1.0.0] - 2026-04-30
### Added
- Initial release
