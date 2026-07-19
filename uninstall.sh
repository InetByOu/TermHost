#!/data/data/com.termux/files/usr/bin/bash

# TermHost Uninstaller v7.0

INSTALL_DIR="$HOME/termhost"
BIN_PATH="$PREFIX/bin/termhost"

pkill nginx php-fpm mysqld 2>/dev/null || true
rm -f "$BIN_PATH"

read -p "Remove TermHost folder? [y/N]: " ans
[ "$ans" = "y" ] && rm -rf "$INSTALL_DIR"

echo "Uninstalled."