# TermHost v2.1

> Termux Web Hosting Manager - Full Interactive Version

Powerful tool to run web hosting (Nginx + PHP-FPM + MariaDB) directly from Termux with easy public access via tunnels.

## Features

- One command installer
- Beautiful interactive CLI menu
- Create unlimited websites
- Each website accessible at `http://localhost:8080/namawebsite/`
- Start/Stop all services easily
- Multiple public hosting options:
  - Ngrok (with token & free)
  - Cloudflare Tunnel (quick + with custom domain)
  - localhost.run
- Shows active public URLs automatically
- Basic database management
- Built-in troubleshooting guide
- Ready to use & stable

## Quick Start

```bash
git clone https://github.com/InetByOu/TermHost.git
cd TermHost
bash install.sh
bash termhost.sh
```

## How to Access Your Websites

After creating a website named `mysite`, open in browser:
```
http://localhost:8080/mysite/
```

## Online Access (Public URL)

Use menu **5) Setup Online Tunnel** to get public URL using:
- Ngrok
- Cloudflare Tunnel
- localhost.run

## Author
InetByOu

## License
MIT