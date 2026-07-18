# TermHost

> Termux Web Hosting Manager

Full-featured web hosting manager for Termux with Virtual Hosts, Auto Start, and easy public access.

## One-Command Installation (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/install.sh | bash
```

Or using wget:

```bash
wget -qO- https://raw.githubusercontent.com/InetByOu/TermHost/main/install.sh | bash
```

After installation, simply run:
```bash
termhost
```

## Features

- Proper Virtual Hosts (`http://namawebsite.localhost:8080`)
- Auto Start when Termux opens
- Ngrok, Cloudflare Tunnel, localhost.run
- Interactive CLI menu
- Database management
- One-run installer

## Manual Installation

```bash
git clone https://github.com/InetByOu/TermHost.git
cd TermHost
bash install.sh
```

## Usage

```bash
termhost
```

## Author
InetByOu