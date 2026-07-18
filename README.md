# TermHost v2.2

> Termux Web Hosting Manager with Virtual Host Support

Full-featured web hosting manager for Termux with proper Nginx virtual hosts.

## Features

- One-run installer (Nginx + PHP-FPM + MariaDB)
- **Proper Virtual Hosts** - Access sites via `http://namawebsite.localhost:8080`
- Create unlimited websites with virtual host
- Interactive CLI menu
- Multiple tunneling options (Ngrok, Cloudflare Tunnel, localhost.run)
- Shows active public URLs
- Basic database management
- Built-in troubleshooting

## How Virtual Host Works

When you create a website named `mysite`, you can access it at:

```
http://mysite.localhost:8080
```

This is much cleaner than using subfolders.

## Quick Start

```bash
git clone https://github.com/InetByOu/TermHost.git
cd TermHost
bash install.sh
bash termhost.sh
```

## Author
InetByOu