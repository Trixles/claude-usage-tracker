# Changelog

All notable changes to Claude Usage Tracker will be documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [1.1.2] - 2026-05-01
### Changed
- Auth source switched from Claude Code to **Claude Desktop** as the primary token source
  - Decrypts `oauth:tokenCache` from `~/.config/Claude/config.json` using AES-128-CBC
  - KWallet (`Chromium Keys / Chromium Safe Storage`) provides the encryption password via `qdbus6`
  - Claude Code (`~/.claude/.credentials.json`) retained as fallback
- KWallet startup retry: on first run, waits up to 30 seconds (6 × 5s) for KWallet to become available after reboot
- Fixed asymmetric spacing in compact bar rows: removed fixed-width padding from all four label/percentage Text elements so both sides use natural text width with equal `spacing: 4` gaps on each side of the bar

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
