# TermHost v6.2

> Improved PHP-FPM Startup Diagnostics

## Fix in v6.2

- Added configuration test before starting PHP-FPM (`php-fpm -t`)
- Better error messages when PHP-FPM fails to start
- Added helpful tips (e.g. "Try running 'pkill php-fpm'")
- More robust service startup process

## Common Fix for PHP-FPM Error

If you still get "Failed to start PHP-FPM":

```bash
pkill php-fpm
termhost
```

Then choose **5) Start All Services** again.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/install.sh | bash
```

Run:
```bash
termhost
```

## Author
InetByOu