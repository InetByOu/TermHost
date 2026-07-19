#!/data/data/com.termux/files/usr/bin/bash

# TermHost Uninstaller v2 - Interactive

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="$HOME/termhost"
BIN_PATH="$PREFIX/bin/termhost"

clear
echo -e "${BLUE}TermHost Uninstaller${NC}"
    echo "===================================="
    echo ""

echo -e "${YELLOW}This script will help you uninstall TermHost safely.${NC}"
    echo ""

pkill nginx 2>/dev/null || true
pkill php-fpm 2>/dev/null || true
pkill mysqld 2>/dev/null || true
pkill -f "ngrok http" 2>/dev/null || true
pkill -f cloudflared 2>/dev/null || true
echo -e "${GREEN}Services stopped.${NC}"
    echo ""

if [ -L "$BIN_PATH" ]; then
    rm -f "$BIN_PATH"
    echo -e "${GREEN}Command removed.${NC}"
fi
    echo ""

echo -e "${YELLOW}What would you like to do?${NC}"
    echo "1) Minimal Uninstall (only remove command)"
    echo "2) Full Purge (remove everything)"
    echo "3) Custom Uninstall"
    echo "0) Cancel"
    echo ""

read -p "Choose option [0-3]: " choice

case $choice in
    1)
        echo -e "${GREEN}Minimal uninstall completed.${NC}"
        ;;
    2)
        if [ -d "$INSTALL_DIR" ]; then
            rm -rf "$INSTALL_DIR"
            echo -e "${GREEN}TermHost folder removed.${NC}"
        fi
        ;;
    3)
        read -p "Remove TermHost folder? [y/N]: " remove_folder
        if [[ "$remove_folder" =~ ^[Yy]$ ]]; then
            rm -rf "$INSTALL_DIR" 2>/dev/null || true
        fi

        read -p "Restore default Nginx & PHP-FPM config? [y/N]: " restore_cfg
        if [[ "$restore_cfg" =~ ^[Yy]$ ]]; then
            [ -f $PREFIX/etc/nginx/nginx.conf ] && cp $PREFIX/etc/nginx/nginx.conf $PREFIX/etc/nginx/nginx.conf.bak 2>/dev/null
            [ -f $PREFIX/etc/php-fpm.d/www.conf ] && cp $PREFIX/etc/php-fpm.d/www.conf $PREFIX/etc/php-fpm.d/www.conf.bak 2>/dev/null
            rm -f $PREFIX/etc/nginx/nginx.conf
            rm -f $PREFIX/etc/php-fpm.d/www.conf
        fi
        ;;
    0)
        echo -e "${YELLOW}Uninstall cancelled.${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option.${NC}"
        ;;
esac

echo ""
echo -e "${GREEN}Thank you for using TermHost!${NC}"
    echo ""
