#!/data/data/com.termux/files/usr/bin/bash

# TermHost Smart Installer v3.3

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
    echo -e "${BLUE}║           TermHost Smart Installer v3.3            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""

# ==================== FIX BROKEN DPKG ====================
echo -e "${YELLOW}[Pre-check]${NC} Fixing broken dpkg if needed..."
dpkg --configure -a 2>/dev/null || true
apt --fix-broken install -y 2>/dev/null || true

# ==================== UPDATE & UPGRADE ====================
echo -e "${YELLOW}[1/8]${NC} Updating package repositories..."
pkg update -y && pkg upgrade -y || {
    echo -e "${YELLOW}Fixing dpkg after upgrade issue...${NC}"
    dpkg --configure -a 2>/dev/null || true
    pkg update -y
}

# ==================== SMART PACKAGE CHECK ====================
echo -e "${YELLOW}[2/8]${NC} Checking available packages in repository..."

AVAILABLE_PACKAGES=$(pkg list-all 2>/dev/null)

check_pkg() {
    echo "$AVAILABLE_PACKAGES" | grep -q "^$1 "
}

PACKAGES_TO_INSTALL=""

add_pkg() {
    if check_pkg "$1"; then
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $1"
        echo -e "  ${GREEN}✓${NC} $1"
    else
        echo -e "  ${YELLOW}✗${NC} $1 (not available, skipping)"
    fi
}

add_pkg nginx
add_pkg php-fpm
add_pkg php
add_pkg php-pdo
add_pkg php-pdo-mysql
add_pkg php-mysql
add_pkg git
add_pkg curl
add_pkg wget
add_pkg jq
add_pkg unzip
add_pkg mariadb

# ==================== ROOT DETECTION ====================
if [ "$(id -u)" -eq 0 ]; then
    echo -e "${PURPLE}[INFO] Running as ROOT${NC}"
fi

# ==================== INSTALL PACKAGES ====================
echo -e "${YELLOW}[3/8]${NC} Installing available packages..."

if [ -n "$PACKAGES_TO_INSTALL" ]; then
    pkg install -y $PACKAGES_TO_INSTALL || {
        echo -e "${RED}Some packages failed. Fixing dpkg...${NC}"
        dpkg --configure -a
        apt --fix-broken install -y
        pkg install -y $PACKAGES_TO_INSTALL
    }
else
    echo -e "${RED}No packages to install!${NC}"
fi

# ==================== CHECK & CREATE DIRECTORIES ====================
echo -e "${YELLOW}[4/8]${NC} Checking and creating required directories..."

mkdir -p "$INSTALL_DIR/sites/default"
mkdir -p "$INSTALL_DIR/vhosts"
mkdir -p "$INSTALL_DIR/logs"
mkdir -p "$INSTALL_DIR/config"

# Check important system directories
if [ ! -d "$PREFIX/etc/nginx" ]; then
    mkdir -p "$PREFIX/etc/nginx"
fi

if [ ! -d "$PREFIX/etc/php-fpm.d" ]; then
    mkdir -p "$PREFIX/etc/php-fpm.d"
fi

# ==================== CREATE DEFAULT CONFIG ====================
echo -e "${YELLOW}[5/8]${NC} Creating default configuration..."

if [ ! -f "$INSTALL_DIR/config/config.json" ]; then
cat > "$INSTALL_DIR/config/config.json" << 'EOF'
{
  "default_port": 8080,
  "use_mariadb": true
}
EOF
fi

# ==================== CONFIGURE NGINX & PHP-FPM ====================
echo -e "${YELLOW}[6/8]${NC} Configuring Nginx and PHP-FPM..."

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

cat > "$INSTALL_DIR/sites/default/index.php" << 'EOF'
<?php echo "TermHost is ready!"; ?>
EOF

# ==================== CREATE BINARY ====================
echo -e "${YELLOW}[7/8]${NC} Creating 'termhost' command..."
chmod +x "$INSTALL_DIR/termhost.sh"
if [ -L "$BIN_PATH" ]; then rm -f "$BIN_PATH"; fi
ln -s "$INSTALL_DIR/termhost.sh" "$BIN_PATH"

# ==================== START SERVICES ====================
echo -e "${YELLOW}[8/8]${NC} Starting services for the first time..."

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
    echo -e "You can now run: ${YELLOW}termhost${NC}"
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "${PURPLE}Running as ROOT - Extra features enabled.${NC}"
    fi
