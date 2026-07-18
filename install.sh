#!/data/data/com.termux/files/usr/bin/bash

# TermHost Smart Installer v3.6 - Stable & Robust

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="$HOME/termhost"
BIN_PATH="$PREFIX/bin/termhost"

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           TermHost Smart Installer v3.6            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""

# Function to show status
echo_status() {
    echo -e "${YELLOW}[$1]${NC} $2... "
}

echo_success() {
    echo -e "${GREEN}Done${NC}"
}

echo_error() {
    echo -e "${RED}Failed${NC}"
}

# ==================== FIX BROKEN DPKG ====================
echo_status "1/8" "Fixing broken packages"
(dpdk --configure -a && apt --fix-broken install -y) >> /dev/null 2>&1 || true
echo_success

# ==================== UPDATE PACKAGES ====================
echo_status "2/8" "Updating package list"
pkg update -y >> /dev/null 2>&1 || true
echo_success

# ==================== INSTALL PACKAGES ====================
echo_status "3/8" "Installing required packages"

PACKAGES="nginx php-fpm php php-pdo git curl wget jq unzip mariadb"

if pkg install -y $PACKAGES >> /dev/null 2>&1; then
    echo_success
else
    echo_error
    echo -e "${YELLOW}Trying to fix dpkg and retry...${NC}"
    dpkg --configure -a >> /dev/null 2>&1 || true
    apt --fix-broken install -y >> /dev/null 2>&1 || true
    
    if pkg install -y $PACKAGES >> /dev/null 2>&1; then
        echo_success
    else
        echo -e "${RED}Failed to install packages. Please run manually:${NC}"
        echo "pkg install -y $PACKAGES"
        exit 1
    fi
fi

# ==================== CLONE / UPDATE REPO ====================
echo_status "4/8" "Setting up TermHost directory"

if [ -d "$INSTALL_DIR" ]; then
    cd "$INSTALL_DIR" && git pull >> /dev/null 2>&1 || true
else
    if ! git clone https://github.com/InetByOu/TermHost.git "$INSTALL_DIR" >> /dev/null 2>&1; then
        echo_error
        echo -e "${RED}Failed to clone repository. Check your internet connection.${NC}"
        exit 1
    fi
fi
echo_success

# Check if termhost.sh exists
if [ ! -f "$INSTALL_DIR/termhost.sh" ]; then
    echo -e "${RED}Error: termhost.sh not found after cloning!${NC}"
    echo -e "Please report this issue."
    exit 1
fi

# ==================== CREATE DIRECTORIES ====================
echo_status "5/8" "Creating directories"
mkdir -p "$INSTALL_DIR/sites/default" "$INSTALL_DIR/vhosts" "$INSTALL_DIR/logs" "$INSTALL_DIR/config"
mkdir -p "$PREFIX/etc/nginx" "$PREFIX/etc/php-fpm.d"
echo_success

# ==================== CREATE CONFIG ====================
echo_status "6/8" "Creating default configuration"

if [ ! -f "$INSTALL_DIR/config/config.json" ]; then
cat > "$INSTALL_DIR/config/config.json" << 'EOF'
{
  "default_port": 8080,
  "use_mariadb": true
}
EOF
fi
echo_success

# ==================== CONFIGURE SERVICES ====================
echo_status "7/8" "Configuring Nginx and PHP-FPM"

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
echo_success

# ==================== CREATE BINARY ====================
echo_status "8/8" "Creating 'termhost' command"
chmod +x "$INSTALL_DIR/termhost.sh"
if [ -L "$BIN_PATH" ]; then rm -f "$BIN_PATH"; fi
ln -s "$INSTALL_DIR/termhost.sh" "$BIN_PATH"
echo_success

# ==================== START SERVICES ====================
echo -e "${YELLOW}Starting services...${NC}"
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
