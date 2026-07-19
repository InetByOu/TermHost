# TermHost v6.0 - Production Ready

> Complete Environment Initialization + Robust Tunnel Support

## Major Improvements in v6.0

### Full Environment Initialization
- Automatic creation of all required directories on startup
- Automatic creation of default `config.json`
- Proper log directory handling

### Robust Path Handling
- Correctly detects installation path whether running as normal user or root (`.suroot`)

### Improved Tunnel System (`setup_tunnel`)
- Auto-installs `ngrok` and `cloudflared` if missing
- Creates log directory before writing logs
- Clearer error messages

### Production-Ready Stability
- Better error handling throughout
- Safer service startup/shutdown
- Consistent behavior across normal user and root environments

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/install.sh | bash
```

Run:
```bash
termhost
```

## Features
- Production-ready environment
- Auto TinyFM on every website
- File Manager Settings (hashed password)
- Delete Website (full purge)
- Smart Upgrade
- Robust Tunnel support (Ngrok / Cloudflare / localhost.run)

## Author
InetByOu