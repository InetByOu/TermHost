# TermHost v2.9

> Termux Web Hosting Manager with Auto Swap for Low RAM

## One Command Installation

```bash
curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/install.sh | bash
```

## Auto Swap for Low RAM (Root Only)

If TermHost detects RAM < 2GB on a root device, it will offer to:

- Create a swap file automatically
- Enable swap on boot using **Magisk service** (preferred) or **Termux:Boot**

Go to menu **11) Swap Management** to manage this manually.

## Features

- SD Card Hosting
- Virtual Hosts
- Error Handling
- Root + Termux:Boot
- Auto Swap for Low RAM Devices

## Author
InetByOu