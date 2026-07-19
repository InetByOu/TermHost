# TermHost v7.5

> Binaries Downloaded Only During Installation

## Key Change in v7.5

Static binaries (`ngrok` and `cloudflared`) are now downloaded **only once** during installation from GitHub Releases.

After installation, the binaries are stored in `~/termhost/bin/` and reused.

## Installation
```bash
curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/install.sh | bash
termhost
```

## Author
InetByOu