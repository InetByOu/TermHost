# TermHost v2.7

> Termux Web Hosting Manager with Termux:Boot Support

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/install.sh | bash
```

Run:
```bash
termhost
```

## Termux:Boot (Auto Start on Device Boot) - Root Only

For **root users**, TermHost now supports Termux:Boot:

- Menu **10) Termux:Boot Setup**
- Automatically creates boot script in `~/.termux/boot/`
- Services will start automatically when device boots

**Note:** You still need to install the Termux:Boot app from F-Droid manually for best compatibility.

## Features

- SD Card Hosting
- Virtual Hosts
- Error Handling
- Root + Termux:Boot Support

## Author
InetByOu