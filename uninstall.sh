#!/data/data/com.termux/files/usr/bin/bash

# TermHost Uninstaller

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

echo -e "${YELLOW}This will remove TermHost from your system.${NC}"
    echo ""

# Stop all services
    echo -e "${YELLOW}Stopping all services...${NC}"
    pkill nginx 2>/dev/null || true
    pkill php-fpm 2>/dev/null || true
    pkill mysqld 2>/dev/null || true
    pkill -f "ngrok http" 2>/dev/null || true
    pkill -f cloudflared 2>/dev/null || true
    echo -e "${GREEN}Services stopped.${NC}"
    echo ""

# Remove binary
    if [ -L "$BIN_PATH" ]; then
        echo -e "${YELLOW}Removing termhost command...${NC}"
        rm -f "$BIN_PATH"
        echo -e "${GREEN}Command removed.${NC}"
    fi
    echo ""

# Ask about removing the repository
    read -p "Do you want to remove the TermHost folder (~/termhost)? [y/N]: " remove_repo

    if [[ "$remove_repo" =~ ^[Yy]$ ]]; then
        if [ -d "$INSTALL_DIR" ]; then
            echo -e "${YELLOW}Removing TermHost directory...${NC}"
            rm -rf "$INSTALL_DIR"
            echo -e "${GREEN}TermHost directory removed.${NC}"
        fi
    else
        echo -e "${YELLOW}Keeping TermHost directory.${NC}"
    fi
    echo ""

# Ask about restoring default Nginx/PHP-FPM config
    read -p "Do you want to restore default Nginx & PHP-FPM config? [y/N]: " restore_config

    if [[ "$restore_config" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Restoring default configurations...${NC}"

        # Backup current configs
        [ -f $PREFIX/etc/nginx/nginx.conf ] && cp $PREFIX/etc/nginx/nginx.conf $PREFIX/etc/nginx/nginx.conf.bak 2>/dev/null
        [ -f $PREFIX/etc/php-fpm.d/www.conf ] && cp $PREFIX/etc/php-fpm.d/www.conf $PREFIX/etc/php-fpm.d/www.conf.bak 2>/dev/null

        # Remove TermHost specific configs (they will be regenerated on reinstall)
        rm -f $PREFIX/etc/nginx/nginx.conf
        rm -f $PREFIX/etc/php-fpm.d/www.conf

        echo -e "${GREEN}Default configurations restored (backups created).${NC}"
    fi

    echo ""
    echo -e "${GREEN}TermHost has been uninstalled.${NC}"
    echo -e "Thank you for using TermHost!"
    echo ""
