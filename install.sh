#!/data/data/com.termux/files/usr/bin/bash

# TermHost Smart Installer v3.4 - Stable + Logging

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

INSTALL_DIR="$HOME/termhost"
BIN_PATH="$PREFIX/bin/termhost"
LOG_FILE="$HOME/termhost_install.log"

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           TermHost Smart Installer v3.4            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""

# Start logging
echo "=== TermHost Installation Log - $(date) ===" > "$LOG_FILE"

log() {
    echo -e "$1"
    echo "$(date '+%H:%M:%S') - $1" >> "$LOG_FILE"
}

# ==================== FIX BROKEN DPKG ====================
log "[Pre-check] Fixing broken dpkg..."
dpkg --configure -a >> "$LOG_FILE" 2>&1 || true
apt --fix-broken install -y >> "$LOG_FILE" 2>&1 || true

# ==================== UPDATE & UPGRADE ====================
log "[1/7] Updating package repositories..."
pkg update -y >> "$LOG_FILE" 2>&1 || true
pkg upgrade -y >> "$LOG_FILE" 2>&1 || {
    log "${YELLOW}Warning: Upgrade had issues. Fixing dpkg...${NC}"
    dpkg --configure -a >> "$LOG_FILE" 2>&1 || true
}

# ==================== INSTALL PACKAGES (SAFE LIST) ====================
log "[2/7] Installing required packages..."

# Safe and commonly available packages in Termux
pkg install -y nginx php-fpm php php-pdo git curl wget jq unzip mariadb >> "$LOG_FILE" 2>&1 || {
    log "${YELLOW}Some packages failed. Trying to fix and retry...${NC}"
    dpkg --configure -a >> "$LOG_FILE" 2>&1 || true
    apt --fix-broken install -y >> "$LOG_FILE" 2>&1 || true
    pkg install -y nginx php-fpm php php-pdo git curl wget jq unzip mariadb >> "$LOG_FILE" 2>&1 || true
}

log "${GREEN}Package installation completed.${NC}"

# ==================== CREATE DIRECTORIES ====================
log "[3/7] Creating required directories..."
mkdir -p "$INSTALL_DIR/sites/default"
mkdir -p "$INSTALL_DIR/vhosts"
mkdir -p "$INSTALL_DIR/logs"
mkdir -p "$INSTALL_DIR/config"

mkdir -p "$PREFIX/etc/nginx"
mkdir -p "$PREFIX/etc/php-fpm.d"

# ==================== CREATE CONFIG ====================
log "[4/7] Creating default configuration..."

if [ ! -f "$INSTALL_DIR/config/config.json" ]; then
cat > "$INSTALL_DIR/config/config.json" << 'EOF'
{
  "default_port": 8080,
  "use_mariadb": true
}
EOF
fi

# ==================== CONFIGURE SERVICES ====================
log "[5/7] Configuring Nginx and PHP-FPM..."

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
log "[6/7] Creating 'termhost' command..."
chmod +x "$INSTALL_DIR/termhost.sh"
if [ -L "$BIN_PATH" ]; then rm -f "$BIN_PATH"; fi
ln -s "$INSTALL_DIR/termhost.sh" "$BIN_PATH"

# ==================== START SERVICES ====================
log "[7/7] Starting services..."

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
    echo -e "Installation log saved to: ${CYAN}$LOG_FILE${NC}"
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "${PURPLE}Running as ROOT - Extra features enabled.${NC}"
    fi
