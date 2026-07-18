# TermHost v2.3

> Termux Web Hosting Manager with Auto Start

Complete web hosting solution for Termux with virtual hosts and auto-start support.

## Features

- Proper Virtual Hosts (`http://namawebsite.localhost:8080`)
- Auto Start services when Termux opens
- Ngrok, Cloudflare Tunnel, localhost.run support
- Interactive CLI with beautiful menu
- Database management
- One-run installer

## Auto Start

You can enable services to start automatically when you open Termux:

Go to menu **9) Settings / Auto Start** → Choose **Enable Auto Start**

After enabling, restart Termux once.

## Quick Start

```bash
git clone https://github.com/InetByOu/TermHost.git
cd TermHost
bash install.sh
bash termhost.sh
```

## Author
InetByOu