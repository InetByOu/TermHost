# TermHost v5.4

> Root User Path Fix & Stability

## Critical Fixes in v5.4

- Fixed `backup_config: command not found` error
- Fixed wrong config path when running as root (`.suroot`)
- Added robust path detection for normal user vs root/su
- `change_port` now works correctly for both normal users and root
- Added validation: non-root users cannot use ports < 1024

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/install.sh | bash
```

Run:
```bash
termhost
```

## Recommendation

For best experience, run TermHost as your **normal Termux user** (not as root).
Only use root when you specifically need features like:
- Termux:Boot
- Low port numbers (e.g. port 80)
- Swap management

## Features

- Stable Traditional Menu
- Smart Upgrade
- Change Port (works for root & normal users)
- SD Card Hosting
- Termux:Boot & Auto Swap (Root)

## Author
InetByOu