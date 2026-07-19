# TermHost v7.3

> Automatic Architecture Detection for Static Binaries

## Key Improvement

The binary downloader now automatically detects your device architecture and downloads the correct version of `ngrok` and `cloudflared`.

Supported architectures:
- `arm64` (aarch64) - Most common
- `arm` (armv7l)
- `amd64` (x86_64)
- `386` (i686)

## Installation
```bash
curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/install.sh | bash
termhost
```

## Author
InetByOu