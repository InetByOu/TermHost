# TermHost v5.2

> Lightweight & Smart Upgrade System

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/install.sh | bash
```

Run:
```bash
termhost
```

## Smart Upgrade System

TermHost now has a dedicated upgrade tool that:

- Only downloads the core script (not the full repo)
- Automatically checks current vs latest version
- Creates automatic backup before upgrading
- Preserves all your websites and configuration

### How to Upgrade:

**Option 1:** From inside TermHost
Choose **Menu 11) Upgrade TermHost**

**Option 2:** Run directly
```bash
bash ~/termhost/upgrade.sh
```

**Option 3:** One-liner
```bash
curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/upgrade.sh | bash
```

## Features

- Traditional Stable Menu
- Smart Upgrade (core only + backup)
- Change Port (with automatic backup)
- SD Card Hosting
- Termux:Boot & Auto Swap (Root)

## Author
InetByOu