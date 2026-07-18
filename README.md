# TermHost v3.1

> Improved Process Management

## Key Improvements

- Better process handling using dedicated `stop_service()` and `stop_all_services()` functions
- Safer start/stop of Nginx, PHP-FPM, MariaDB, and tunnels
- Reduced risk of runaway processes
- Cleaner and more reliable service management

## One Command Installation

```bash
curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/install.sh | bash
```

Run:
```bash
termhost
```

## Author
InetByOu