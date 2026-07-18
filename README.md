# TermHost v2

> Termux Web Hosting Manager - Full Version

Powerful interactive CLI tool to manage web hosting directly from Termux with support for local + public hosting.

## Features

- One-run installer (Nginx + PHP-FPM + MariaDB)
- Full interactive CLI menu
- Create multiple websites easily
- Start/Stop services with one command
- Online tunneling support:
  - Ngrok (with & without token)
  - Cloudflare Tunnel (quick + custom domain)
  - localhost.run
- Real-time status + active public URLs
- Built-in troubleshooting guide
- Ready to use

## Installation

```bash
pkg install git -y
git clone https://github.com/InetByOu/TermHost.git
cd TermHost
bash install.sh
bash termhost.sh
```

## Usage

Just run:
```bash
bash termhost.sh
```

Then use the interactive menu.

## Project Structure

```
TermHost/
├── install.sh
├── termhost.sh
├── config/
│   └── config.json
├── sites/           # Your websites go here
├── logs/
└── modules/
```

## Author
InetByOu

## License
MIT