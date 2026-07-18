#!/data/data/com.termux/files/usr/bin/bash

# TermHost Installer v3.2 - Better Package Handling

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

INSTALL_DIR="$HOME/termhost"
BIN_PATH="$PREFIX/bin/termhost"

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           TermHost Installer v3.2                  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""

# ==================== FIX BROKEN DPKG ====================
echo -e "${YELLOW}[Pre-check]${NC} Fixing broken packages if any..."
dpkg --configure -a 2>/dev/null || true
apt --fix-broken install -y 2>/dev/null || true

# ==================== UPDATE & UPGRADE REPO ====================
echo -e "${YELLOW}[1/7]${NC} Updating package list and upgrading..."
pkg update -y && pkg upgrade -y || {
    echo -e "${YELLOW}Warning: Upgrade had issues. Fixing dpkg...${NC}"
    dpkg --configure -a 2>/dev/null || true
    pkg update -y
}

# ==================== CHECK PACKAGE AVAILABILITY ====================
echo -e "${YELLOW}[2/7]${NC} Checking available packages..."

PHP_MYSQL_PKG=""
if pkg list-all 2>/dev/null | grep -q "php-mysql"; then
    PHP_MYSQL_PKG="php-mysql"
    echo -e "${GREEN}Found: php-mysql${NC}"
else
    echo -e "${YELLOW}php-mysql not available. Using alternative (php).${NC}"
fi

# ==================== ROOT DETECTION ====================
if [ "$(id -u)" -eq 0 ]; then
    echo -e "${PURPLE}[INFO] Running as ROOT user${NC}"
    echo -e "${YELLOW}Extra features will be enabled.${NC}"
    echo ""
fi

# ==================== INSTALL PACKAGES ====================
echo -e "${YELLOW}[3/7]${NC} Installing required packages..."

PACKAGES="nginx php-fpm php git curl wget jq unzip"

if [ -n "$PHP_MYSQL_PKG" ]; then
    PACKAGES="$PACKAGES $PHP_MYSQL_PKG"
fi

pkg install -y $PACKAGES || {
    echo -e "${RED}Some packages failed. Trying to fix...${NC}"
    dpkg --configure -a
    apt --fix-broken install -y
    pkg install -y $PACKAGES
}

echo -e "${YELLOW}[4/7]${NC} Setting up TermHost directory..."
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Updating existing TermHost...${NC}"
    cd "$INSTALL_DIR" && git pull
else
    git clone https://github.com/InetByOu/TermHost.git "$INSTALL_DIR"
fi

mkdir -p "$INSTALL_DIR/vhosts" "$INSTALL_DIR/logs"

if [ ! -f "$INSTALL_DIR/config/config.json" ]; then
cat > "$INSTALL_DIR/config/config.json" << 'EOF'
{
  "default_port": 8080,
  "use_mariadb": true
}
EOF
fi

echo -e "${YELLOW}[5/7]${NC} Configuring Nginx & PHP-FPM..."

cat > $PREFIX/etc/php-fpm.d/www.conf << 'PHPEOF'
[www]
user = $(whoami)
group = $(whoami)
listen = 127.0.0.1:9000
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
PHPEOF

cat > $PREFIX/etc/nginx/nginx.conf << 'NGINXEOF'
worker_processes auto;
events { worker_connections 1024; }

http {
    include       mime.types;
    default_type  application/octet-stream;

    server {
        listen       8080;
        server_name  localhost;

        root   ~/termhost/sites/default;
        index  index.php index.html;

        location / {
            try_files \$uri \$uri/ /index.php?\$args;
        }

        location ~ \\.php\$ {
            fastcgi_pass   127.0.0.1:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
            include        fastcgi_params;
        }
    }
}
NGINXEOF

mkdir -p "$INSTALL_DIR/sites/default"
cat > "$INSTALL_DIR/sites/default/index.php" << 'EOF'
<?php echo "TermHost is ready!"; ?>
EOF

echo -e "${YELLOW}[6/7]${NC} Creating 'termhost' command..."
chmod +x "$INSTALL_DIR/termhost.sh"
if [ -L "$BIN_PATH" ]; then rm -f "$BIN_PATH"; fi
ln -s "$INSTALL_DIR/termhost.sh" "$BIN_PATH"

echo -e "${YELLOW}[7/7]${NC} Starting services..."
pkill nginx 2>/dev/null || true
pkill php-fpm 2>/dev/null || true
pkill mysqld 2>/dev/null || true

php-fpm >/dev/null 2>&1
nginx >/dev/null 2>&1

if [ "$(jq -r '.use_mariadb' $INSTALL_DIR/config/config.json 2>/dev/null)" = "true" ]; then
    mysqld_safe --datadir=$PREFIX/var/lib/mysql >/dev/null 2>&1 &
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     TermHost installed successfully!               ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Run: ${YELLOW}termhost${NC}"
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "${PURPLE}Running as ROOT - Extra features enabled.${NC}"
    fi
