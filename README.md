# TermHost v4.5

> Termux Web Hosting Manager with Change Port Feature

## One Command Installation

```bash
curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/install.sh | bash
```

Run:
```bash
termhost
```

## New Feature: Change Port

You can now change the port used by Nginx directly from the menu:

**Menu 10) Change Port**

- Non-root users: Recommended to use port ≥ 1024 (e.g. 8080, 3000)
- Root users: Can use any port including 80

## Features

- Virtual Hosts with custom port
- SD Card Hosting
- Termux:Boot Support (Root)
- Auto Swap for Low RAM (Root)
- Error Handling

## Author
InetByOu